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
# Toolchain Check
# -------------------------------
log "=== EXERCISE 12: Alerting with Grafana Setup ==="
log "Checking toolchain dependencies..."
for tool in colima minikube kubectl docker; do
  ensure_tool "$tool"
done
pause 2

# -------------------------------
# Environment Cleanup
# -------------------------------
log "Performing full cleanup of Minikube and Colima environments..."
safe_run minikube delete --all

log "Stopping and cleaning up Colima..."
safe_run colima stop --force
safe_run colima delete --force
pause 5

# -------------------------------
# Startup Phase (Colima and Minikube)
# -------------------------------
log "Initializing and Starting Colima with Docker runtime..."
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
# Kubernetes Cluster Cleanup
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
# Kubernetes Deployment (Exercise 12 specific files)
# -------------------------------
log "Applying Kubernetes configurations for Exercise 12 (Alerting with Grafana)..."

# Check if all required files exist before deployment
required_files=(
  "./storage.yaml"
  "./deployment.yaml"
  "./otel-collector.yaml"
  "./jaeger.yaml"
  "./prometheus-rbac-cluster.yaml"
  "./prometheus.yaml"
  "./grafana-loki.yaml"
  "./grafana.yaml"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    log "ERROR: Required file $file not found!"
    log "Please run the copy-files.sh script first to copy files from previous exercises."
    exit 1
  fi
done

# Deploy in the correct order for Exercise 12
for file in \
  ./storage.yaml \
  ./deployment.yaml \
  ./otel-collector.yaml \
  ./jaeger.yaml \
  ./prometheus-rbac-cluster.yaml \
  ./prometheus.yaml \
  ./grafana-loki.yaml \
  ./grafana.yaml
do
  log "Applying $file..."
  safe_run kubectl apply -f "$file"
done
pause 5

# -------------------------------
# Pod Initialization Wait and Verification
# -------------------------------
log "Waiting for pod readiness..."
safe_run kubectl wait --for=condition=Ready pods --all --all-namespaces --timeout=300s || log "Some pods failed to become Ready within timeout"

log "Current pod status:"
safe_run kubectl get pods -A

log "Verifying Exercise 12 components..."
log "Checking Grafana deployment..."
kubectl get pods -n monitoring | grep grafana || log "Grafana pods not found"

log "Checking Loki deployment..."
kubectl get pods -n opentelemetry | grep loki || log "Loki pods not found"

log "Checking Prometheus deployment..."
kubectl get pods -n monitoring | grep prometheus || log "Prometheus pods not found"

# -------------------------------
# Service Access Setup
# -------------------------------
log "=== Exercise 12 Setup Complete ==="
log "Opening Grafana UI for alerting configuration..."
minikube service grafana-service -n monitoring > /dev/null 2>&1 &

log "Opening Prometheus UI for metrics verification..."
minikube service prometheus-service -n monitoring > /dev/null 2>&1 &