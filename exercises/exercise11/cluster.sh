   #!/bin/bash

   # Exit on failure (controlled via safe_run), but allow resilience elsewhere.
   set -e

   # ----------------------
   # Utility Functions
   # ----------------------

   log() {
     echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
   }

   safe_run() {
     "$@" || { log "Command failed: $*"; exit 1; }
   }

   command_exists() {
     command -v "$1" >/dev/null 2>&1
   }

   ensure_tool() {
     local tool="$1"
     if command_exists "$tool"; then
       log "$tool is installed."
     else
       log "$tool is not installed."
       if command_exists brew; then
         log "Installing $tool via Homebrew..."
         brew install "$tool" || { log "Failed to install $tool"; exit 1; }
       else
         log "Homebrew is missing. Please install it from https://brew.sh/"
         exit 1
       fi
     fi
   }

   start_if_not_running() {
     local svc="$1"
     if command_exists "$svc"; then
       "$svc" status >/dev/null 2>&1 || {
         log "Starting $svc..."
         safe_run "$svc" start
         sleep 5
       }
     else
       log "Cannot start $svc — binary not found."
       exit 1
     fi
   }

   pause() {
     log "Waiting for $1 seconds..."
     sleep "$1"
   }

   # -------------------------------
   # Toolchain Check (before anything else)
   # -------------------------------
   log "Checking toolchain dependencies..."
   for tool in colima podman minikube kubectl docker; do
     ensure_tool "$tool"
   done
   pause 2

   # -------------------------------
   # Full Environment Cleanup (Crucial for a clean slate)
   # -------------------------------
   log "Performing full cleanup of Minikube, Podman, and Colima environments..."
   safe_run minikube delete --all

   if podman machine list | grep -q "podman-machine-default"; then
     safe_run podman machine stop
     safe_run podman machine rm --force
   fi

   safe_run colima stop
   safe_run colima delete --force
   pause 5

   # -------------------------------
   # Startup Phase (Re-initialize Minikube/Colima)
   # -------------------------------
   log "Initializing and Starting Colima (for Minikube Docker driver)..."
   start_if_not_running colima
   safe_run colima start --cpu 2 --memory 2048 --disk 100
   pause 5

   log "Starting Minikube with Docker driver..."
   safe_run minikube start --driver=docker
   pause 5

   log "Creating log directory inside Minikube VM..."
   safe_run minikube ssh "sudo mkdir -p /data/sre-app/logs && sudo chmod 777 /data/sre-app/logs"
   pause 5

   # -------------------------------
   # Kubernetes Cluster Cleanup (before applying new configs)
   # -------------------------------
   log "Cleaning up Kubernetes cluster..."
   safe_run kubectl delete ns application opentelemetry monitoring --ignore-not-found=true
   safe_run kubectl delete pvc --all --ignore-not-found=true
   safe_run kubectl delete pv --all --ignore-not-found=true
   pause 5

   # -------------------------------
   # Docker Image Build
   # -------------------------------
   log "Building Docker image..."
   safe_run docker build -t cguillenmendez/sre-abc-training-python-app:latest .
   safe_run docker tag cguillenmendez/sre-abc-training-python-app:latest cguillenmendez/sre-abc-training-python-app:0.0.23
   pause 5

   # -------------------------------
   # Kubernetes Deployment
   # -------------------------------
   log "Applying Kubernetes configurations..."
   for file in \
     ./storage.yaml \
     ./deployment.yaml \
     ./otel-collector.yaml \
     ./jaeger.yaml \
     ./grafana-loki.yaml \
     ./prometheus.yaml \
     ./prometheus-rbac-cluster.yaml \
     ./grafana.yaml
   do
     safe_run kubectl apply -f "$file"
   done
   pause 5

   # -------------------------------
   # Pod Initialization Wait
   # -------------------------------
   log "Waiting for pod readiness..."
   safe_run kubectl wait --for=condition=Ready pods --all --all-namespaces --timeout=180s || log "Some pods failed to become Ready within timeout"

   safe_run kubectl get pods -A
   log "Script finished. Check Grafana, Prometheus, Jaeger, and logs for full status."

   log "Opening Grafana UI in your browser..."
   minikube service grafana-service -n monitoring > /dev/null 2>&1 &

   log "Opening Prometheus UI in your browser..."
   minikube service prometheus-service -n monitoring > /dev/null 2>&1 &