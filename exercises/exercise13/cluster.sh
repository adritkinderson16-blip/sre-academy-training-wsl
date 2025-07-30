#!/bin/bash

# Enhanced logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to wait for pods with better error handling and kubectl retries
wait_for_pods() {
    local namespace=$1
    local label_selector=$2
    local timeout=${3:-300}  # 5 minutes default
    local counter=0
    local retry_count=0
    local max_retries=3
    
    log "Waiting for pods with selector '$label_selector' in namespace '$namespace'..."
    
    while [ $counter -lt $timeout ]; do
        # Retry kubectl commands if they fail due to API server issues
        local pods_status=""
        retry_count=0
        
        while [ $retry_count -lt $max_retries ]; do
            if pods_status=$(kubectl get pods -n "$namespace" -l "$label_selector" --no-headers 2>/dev/null); then
                break
            else
                log "kubectl command failed, retrying... ($((retry_count + 1))/$max_retries)"
                sleep 5
                retry_count=$((retry_count + 1))
            fi
        done
        
        if [ $retry_count -eq $max_retries ]; then
            log "ERROR: kubectl commands consistently failing - API server may be overloaded"
            return 1
        fi
        
        if echo "$pods_status" | grep -q "Running"; then
            log "Pods are running!"
            return 0
        fi
        
        # Show current pod status for debugging
        log "Current pod status:"
        if [ -n "$pods_status" ]; then
            echo "$pods_status" | sed 's/^/  /'
        else
            log "  No pods found yet"
        fi
        
        sleep 15  # Increased sleep time to reduce API server load
        counter=$((counter + 15))
        log "Waiting... (${counter}s/${timeout}s)"
    done
    
    log "ERROR: Timeout waiting for pods to be ready"
    return 1
}

# Function to check if namespace exists
ensure_namespace() {
    local namespace=$1
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log "Creating namespace: $namespace"
        kubectl create namespace "$namespace"
    else
        log "Namespace $namespace already exists"
    fi
}

log "Checking toolchain dependencies..."

# Check dependencies
for tool in colima minikube kubectl docker helm ansible-playbook; do
    if command -v $tool >/dev/null 2>&1; then
        log "$tool is installed."
    else
        log "ERROR: $tool is not installed or not in PATH"
        exit 1
    fi
done

log "Waiting for 2 seconds..."
sleep 2

log "Performing full cleanup of Minikube and Colima environments..."
minikube delete --all
log "Stopping and cleaning up Colima..."
colima stop
colima delete --force

log "Waiting for 5 seconds..."
sleep 5

log "Initializing and Starting Colima with more resources..."
log "Starting colima with increased memory and CPU..."
# Increase resources for better AWX performance
colima start --runtime docker --memory 4 --cpu 4

log "Waiting for 5 seconds..."
sleep 5

log "Starting Minikube with more resources..."
# Start minikube with more resources
minikube start --driver=docker --memory=3900 --cpus=3

log "Waiting for 5 seconds..."
sleep 5

log "Creating log directory inside Minikube VM..."
minikube ssh -- 'sudo mkdir -p /var/log/awx'

log "Waiting for 5 seconds..."
sleep 5

log "Cleaning up Kubernetes cluster..."
kubectl delete ns awx --ignore-not-found=true
kubectl delete ns application --ignore-not-found=true
kubectl delete ns opentelemetry --ignore-not-found=true
kubectl delete ns monitoring --ignore-not-found=true
kubectl delete pv --all --ignore-not-found=true
kubectl delete pvc --all --ignore-not-found=true

log "Waiting for 5 seconds..."
sleep 5

echo "-------------------------------------------------------------------------"
echo "Install AWX"
echo "-------------------------------------------------------------------------"

# Add AWX operator Helm repository
log "Adding AWX operator Helm repository..."
helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/ 2>/dev/null || log "Repository already exists"
helm repo update

# Ensure namespace exists
ensure_namespace awx

# Install AWX operator with explicit wait
log "Installing AWX operator..."
helm install my-awx-operator awx-operator/awx-operator -n awx --wait --timeout=10m

echo "-------------------------------------------------------------------------"
echo "Configure AWX"
echo "-------------------------------------------------------------------------"

# Wait for AWX operator pod to be running with proper error handling
log "Checking for AWX operator pod..."
if kubectl get pods -n awx --no-headers 2>/dev/null | grep -q "awx-operator.*Running"; then
    log "AWX operator is already running!"
else
    if wait_for_pods "awx" "control-plane=controller-manager" 300; then
        log "AWX operator is ready!"
    else
        log "ERROR: AWX operator failed to start"
        log "Debugging information:"
        kubectl get all -n awx
        kubectl logs -n awx -l "control-plane=controller-manager" --tail=50
        exit 1
    fi
fi

# Show pod details for confirmation
kubectl get pods -n awx

# Apply AWX instance configuration from awx-demo.yml
log "Creating AWX instance from awx-demo.yml..."
if [ -f "awx-demo.yml" ]; then
    kubectl apply -f awx-demo.yml
else
    log "awx-demo.yml not found, creating default AWX instance with resource limits..."
    cat <<EOF | kubectl apply -f -
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-demo
  namespace: awx
spec:
  service_type: nodeport
  web_resource_requirements:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
  task_resource_requirements:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
  postgres_resource_requirements:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
  postgres_storage_requirements:
    requests:
      storage: 8Gi
EOF
fi

# Wait longer and check for AWX deployment readiness instead of pods
log "Waiting for AWX deployments to be ready..."
counter=0
timeout=900  # 15 minutes for AWX with resource constraints

while [ $counter -lt $timeout ]; do
    # Check if all AWX deployments are ready
    web_ready=$(kubectl get deployment awx-demo-web -n awx -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    task_ready=$(kubectl get deployment awx-demo-task -n awx -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    postgres_ready=$(kubectl get statefulset awx-demo-postgres-15 -n awx -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    
    log "AWX component status: web=$web_ready, task=$task_ready, postgres=$postgres_ready"
    
    if [ "$web_ready" = "1" ] && [ "$task_ready" = "1" ] && [ "$postgres_ready" = "1" ]; then
        log "AWX instance is ready!"
        break
    fi
    
    # Show current status for debugging
    kubectl get deployments,statefulsets -n awx 2>/dev/null || log "Unable to get deployment status"
    
    sleep 30  # Check every 30 seconds
    counter=$((counter + 30))
    log "Waiting for AWX... (${counter}s/${timeout}s)"
done

if [ $counter -ge $timeout ]; then
    log "ERROR: AWX instance failed to start within timeout"
    log "Final debugging information:"
    kubectl get all -n awx 2>/dev/null || log "Unable to get cluster status"
    kubectl describe awx awx-demo -n awx 2>/dev/null || log "Unable to describe AWX resource"
    exit 1
fi

# Get access details
log "Getting AWX service information..."
kubectl get svc -n awx

MINIKUBE_IP=$(minikube ip)
AWX_PORT=$(kubectl get svc awx-demo-service -n awx -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)

if [ -n "$AWX_PORT" ]; then
    log "AWX is accessible at: http://$MINIKUBE_IP:$AWX_PORT"
    log "Default admin username: admin"
    
    # Get admin password
    log "Getting admin password..."
    ADMIN_PASSWORD=$(kubectl get secret awx-demo-admin-password -o jsonpath="{.data.password}" -n awx 2>/dev/null | base64 --decode 2>/dev/null || echo "Password not ready yet")
    log "Admin password: $ADMIN_PASSWORD"
else
    log "Service not ready yet"
fi

# Show all current pods
log "Current pod status across all namespaces:"
kubectl get pods -A

echo "-------------------------------------------------------------------------"
echo "Execute an ansible playbook"
echo "-------------------------------------------------------------------------"

if [ -f "../exercise4.1/ansible_quickstart/inventory.ini" ] && [ -f "collect-status-application.yaml" ]; then
    log "Running ansible playbook..."
    ansible-playbook -i ../exercise4.1/ansible_quickstart/inventory.ini collect-status-application.yaml
elif [ -f "inventory.ini" ] && [ -f "collect-status-application.yaml" ]; then
    log "Running ansible playbook with local inventory..."
    ansible-playbook -i inventory.ini collect-status-application.yaml
else
    log "Ansible files not found, skipping playbook execution"
fi

echo "-------------------------------------------------------------------------"
echo "Install the rest of the Infrastructure"
echo "-------------------------------------------------------------------------"

# Apply infrastructure components with delays to prevent API server overload
log "Deploying infrastructure components with delays..."

components=(
    "./storage.yaml:Storage configuration"
    "./deployment.yaml:Application deployment"
    "./otel-collector.yaml:OpenTelemetry collector" 
    "./jaeger.yaml:Jaeger"
    "./prometheus.yaml:Prometheus"
    "./grafana-loki.yaml:Grafana Loki"
    "./grafana.yaml:Grafana"
)

for component in "${components[@]}"; do
    IFS=':' read -r file description <<< "$component"
    if [ -f "$file" ]; then
        log "Applying $description..."
        kubectl apply -f "$file"
        sleep 5  # Give API server time to process
    else
        log "Warning: $file not found"
    fi
done

echo "-------------------------------------------------------------------------"
echo "Waiting for deployments to stabilize..."
echo "-------------------------------------------------------------------------"

log "Waiting 30 seconds for pods to start..."
sleep 30

log "Final pod status across all namespaces:"
kubectl get pods -A

log "Script completed successfully!"