#!/bin/bash

# --- Comprehensive Cleanup ---
echo "-------------------------------------------------------------------------"
echo "Starting comprehensive cleanup..."
echo "-------------------------------------------------------------------------"

# Kill any lingering minikube tunnel processes
echo "Killing any existing minikube tunnel processes..."
pkill -f "minikube tunnel" &>/dev/null

# Stop and delete minikube cluster for a clean start
echo "Stopping and deleting minikube cluster..."
minikube stop &>/dev/null
minikube delete &>/dev/null

# Delete specific namespaces (if they somehow persist or are created outside minikube lifecycle)
echo "Deleting specific namespaces..."
kubectl delete ns awx --ignore-not-found --timeout=60s
kubectl delete ns application --ignore-not-found --timeout=60s
kubectl delete ns opentelemetry --ignore-not-found --timeout=60s
kubectl delete ns monitoring --ignore-not-found --timeout=60s

# Delete all Persistent Volumes and Claims
echo "Deleting all Persistent Volumes and Claims..."
kubectl delete pv --all --timeout=60s --ignore-not-found
kubectl delete pvc --all --timeout=60s --ignore-not-found

# Kill any lingering kubectl port-forward processes
echo "Killing any existing kubectl port-forward processes..."
killall -9 kubectl &>/dev/null

sleep 5 # Give some time for resources to terminate

echo "Cleanup complete."
echo "-------------------------------------------------------------------------"


# --- Minikube Start ---
echo "-------------------------------------------------------------------------"
echo "Starting Minikube cluster..."
echo "-------------------------------------------------------------------------"
minikube start --driver=docker # Or your preferred driver like hyperkit/virtualbox/etc.
echo "Minikube cluster started."
echo "-------------------------------------------------------------------------"


echo "-------------------------------------------------------------------------"
echo "Install AWX"
echo "-------------------------------------------------------------------------"

# Ensure Helm is installed
if ! command -v helm &> /dev/null
then
    echo "Helm not found, installing Helm..."
    # For Linux users, you'd typically use a package manager or curl to install helm
    # Example for Debian/Ubuntu: curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
    brew install helm # Assumes macOS with Homebrew
fi

helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/ --force-update
helm install my-awx-operator awx-operator/awx-operator -n awx --create-namespace


echo "-------------------------------------------------------------------------"
echo "Configure AWX"
echo "-------------------------------------------------------------------------"

echo "Waiting for AWX operator pod to be running..."
kubectl wait --for=condition=ready pod -l control-plane=awx-operator -n awx --timeout=300s

kubectl apply -f awx-demo.yml

echo "Waiting for awx-demo-service and AWX pods to become available..."
# Wait for the main AWX deployment to be available
kubectl wait --for=condition=available deployment/awx-demo -n awx --timeout=600s
# Wait for specific AWX core pods to be ready (awx-web, awx-task, awx-ee)
kubectl wait --for=condition=ready pod -l app.kubernetes.io/managed-by=awx -n awx --timeout=600s

sleep 10 # Give a bit more time for service to propagate fully

echo "Getting all pods status:"
kubectl get pods -A

echo "AWX Admin Password:"
kubectl get secret awx-demo-admin-password -o jsonpath="{.data.password}" -n awx | base64 --decode ; echo

# Open AWX UI automatically
AWX_URL=$(minikube service awx-demo-service -n awx --url)
if [ -n "$AWX_URL" ]; then
    echo "Opening AWX UI: $AWX_URL"
    if command -v xdg-open >/dev/null; then
        xdg-open "$AWX_URL" &
    elif command -v open >/dev/null; then
        open "$AWX_URL" &
    else
        echo "Could not open browser. Please navigate to $AWX_URL manually."
    fi
else
    echo "Could not determine AWX service URL."
fi


echo "-------------------------------------------------------------------------"
echo "Execute an ansible playbook (initial test/setup)"
echo "-------------------------------------------------------------------------"
ansible-playbook -i inventory.ini collect-status-application.yaml


echo "-------------------------------------------------------------------------"
echo "Install the rest of the Infra"
echo "-------------------------------------------------------------------------"

kubectl apply -f storage.yaml;
kubectl apply -f deployment.yaml;
kubectl apply -f otel-collector.yaml;
kubectl apply -f jaeger.yaml;
kubectl apply -f prometheus.yaml;
kubectl apply -f grafana-loki.yaml;
kubectl apply -f grafana.yaml;

echo "-------------------------------------------------------------------------"
echo "Waiting for Infra components to be ready..."
echo "-------------------------------------------------------------------------"
sleep 15 # Give some time for pods to start before checking their status

# Wait for essential monitoring components to be ready
echo "Waiting for Grafana pod to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
echo "Waiting for Prometheus pod to be ready..."
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s
echo "Waiting for Jaeger pod to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=jaeger -n opentelemetry --timeout=300s
echo "Waiting for Loki pod to be ready..."
kubectl wait --for=condition=ready pod -l app=loki -n opentelemetry --timeout=300s # Loki is typically in opentelemetry or monitoring
echo "Waiting for OpenTelemetry Collector pod to be ready..."
kubectl wait --for=condition=ready pod -l app=otel-collector -n opentelemetry --timeout=300s


echo "All critical pods status:"
kubectl get pods -A

# --- Open other UIs automatically ---
echo "-------------------------------------------------------------------------"
echo "Opening other UIs..."
echo "-------------------------------------------------------------------------"

# Open Grafana UI
GRAFANA_URL=$(minikube service grafana-service -n monitoring --url) # Using grafana-service based on your kubectl apply
if [ -n "$GRAFANA_URL" ]; then
    echo "Opening Grafana UI: $GRAFANA_URL"
    if command -v xdg-open >/dev/null; then
        xdg-open "$GRAFANA_URL" &
    elif command -v open >/dev/null; then
        open "$GRAFANA_URL" &
    else
        echo "Could not open browser. Please navigate to $GRAFANA_URL manually."
    fi
else
    echo "Could not determine Grafana service URL."
fi

# Open Prometheus UI
PROMETHEUS_URL=$(minikube service prometheus-service -n monitoring --url) # Using prometheus-service based on your kubectl apply
if [ -z "$PROMETHEUS_URL" ]; then
    # Fallback for simpler prometheus deployment names if stack is not used
    PROMETHEUS_URL=$(minikube service prometheus -n monitoring --url)
fi

if [ -n "$PROMETHEUS_URL" ]; then
    echo "Opening Prometheus UI: $PROMETHEUS_URL"
    if command -v xdg-open >/dev/null; then
        xdg-open "$PROMETHEUS_URL" &
    elif command -v open >/dev/null; then
        open "$PROMETHEUS_URL" &
    else
        echo "Could not open browser. Please navigate to $PROMETHEUS_URL manually."
    fi
else
    echo "Could not determine Prometheus service URL."
fi

# Open Jaeger UI
JAEGER_URL=$(minikube service jaeger-service -n opentelemetry --url) # Using jaeger-service based on your kubectl apply
if [ -n "$JAEGER_URL" ]; then
    echo "Opening Jaeger UI: $JAEGER_URL"
    if command -v xdg-open >/dev/null; then
        xdg-open "$JAEGER_URL" &
    elif command -v open >/dev/null; then
        open "$JAEGER_URL" &
    else
        echo "Could not open browser. Please navigate to $JAEGER_URL manually."
    fi
else
    echo "Could not determine Jaeger service URL."
fi

# Open Kubernetes Dashboard (runs in background and opens browser)
echo "Opening Kubernetes Dashboard..."
minikube dashboard &
sleep 5 # Give it a moment to launch

echo "Script execution complete."
echo "-------------------------------------------------------------------------"