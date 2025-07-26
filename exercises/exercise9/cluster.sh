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
  "$@" || log "Command failed: $*"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# -------------------------------
# Kubernetes Cluster Cleanup
# -------------------------------
log "Cleaning up Kubernetes cluster..."
safe_run kubectl delete ns application opentelemetry monitoring --ignore-not-found=true
sleep 5

# -------------------------------
# Kubernetes Deployment
# -------------------------------
log "Applying Kubernetes configurations..."
for file in \
  ./deployment.yaml \
  ./otel-collector.yaml \
  ../exercise8/jaeger.yaml \
  ./prometheus.yaml \
  ./grafana.yaml
do
  safe_run kubectl apply -f "$file"
done
sleep 5

# -------------------------------
# Pod Initialization Wait
# -------------------------------
log "Waiting for pod readiness..."
safe_run kubectl wait --for=condition=Ready pods --all --all-namespaces --timeout=120s || log "Some pods failed to become Ready"

safe_run kubectl get pods -A
log "Script finished."
