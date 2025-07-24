#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "-------------------------------------------------------------------------"
echo "Performing full cleanup of Minikube, Podman, and Colima environments..."
echo "-------------------------------------------------------------------------"
# Delete Minikube cluster (all profiles)
minikube delete --all || true

# Stop and remove Podman machine if it exists
if podman machine list | grep -q "podman-machine-default"; then
  podman machine stop || true
  podman machine rm --force || true
fi

# Stop and delete Colima instance
colima stop || true
colima delete || true

sleep 5; # Give some time for deletion to propagate
echo "Cleanup complete. Waiting for 5 seconds..."

echo "-------------------------------------------------------------------------"
echo "Initializing and Starting Colima (for Minikube Docker driver)..."
echo "-------------------------------------------------------------------------"
# Start Colima with reduced memory to accommodate system limits
# Defaulting to 2GB (2048MB), which is generally safer for 8GB RAM Macs.
# You can increase this if your system has more available RAM (e.g., --memory 3072 for 3GB)
colima start --cpu 2 --memory 2048 --disk 100

sleep 5; # Give Colima time to settle
echo "Colima started. Waiting for 5 seconds..."

echo "-------------------------------------------------------------------------"
echo "Starting Minikube using the Docker driver..."
echo "-------------------------------------------------------------------------"
minikube start --driver=docker

sleep 5; # Give Minikube time to settle
echo "Minikube started. Waiting for 5 seconds..."

echo "-------------------------------------------------------------------------"
echo "Creating /data/sre-app/logs directory in Minikube VM..."
echo "-------------------------------------------------------------------------"
# Create the directory and set permissions inside the Minikube VM
minikube ssh "sudo mkdir -p /data/sre-app/logs && sudo chmod 777 /data/sre-app/logs"

sleep 5; # Give Minikube time to apply changes
echo "Log directory created. Waiting for 5 seconds..."

echo "-------------------------------------------------------------------------"
echo "Starting cleanup of existing Kubernetes resources within Kubernetes cluster (if any)..."
echo "-------------------------------------------------------------------------"
# Delete namespaces and PVCs/PVs, ignoring errors if they don't exist
kubectl delete ns application opentelemetry monitoring --ignore-not-found=true || true
kubectl delete pvc --all --ignore-not-found=true || true
kubectl delete pv --all --ignore-not-found=true || true

sleep 5; # Give time for deletion to propagate
echo "Waiting 5 seconds for cleanup to propagate..."


echo "-------------------------------------------------------------------------"
echo "Building application image with Docker (Colima)..."
echo "-------------------------------------------------------------------------"
# Build the Docker images. Since Minikube is using the Colima-provided Docker daemon,
# these images will be directly available to Minikube.
docker build -t cguillenmendez/sre-abc-training-python-app:latest .
docker build -t cguillenmendez/sre-abc-training-python-app:0.0.23 .

sleep 5; # For consistency, though build is synchronous
echo "Image built. Waiting for 5 seconds..."

echo "-------------------------------------------------------------------------"
echo "Applying new Kubernetes configurations..."
echo "-------------------------------------------------------------------------"
kubectl apply -f ./storage.yaml
kubectl apply -f ./deployment.yaml
kubectl apply -f ./otel-collector.yaml
kubectl apply -f ../exercise8/jaeger.yaml # Path relative to current directory
kubectl apply -f ../exercise9/prometheus.yaml # Path relative to current directory
kubectl apply -f ./grafana-loki.yaml
kubectl apply -f ./grafana.yaml
kubectl apply -f ./prometheus-rbac-cluster.yaml # Ensure RBAC for Prometheus is applied

sleep 5; # Give Kubernetes API server time to process
echo "Kubernetes configurations applied. Waiting for 5 seconds..."

echo "-------------------------------------------------------------------------"
echo "Waiting 30 seconds for pods to start and getting final status..."
echo "-------------------------------------------------------------------------"
sleep 30; # Give pods ample time to start, pull images, etc.
kubectl get pods -A
echo "Initial pod status retrieved."

echo "-------------------------------------------------------------------------"
echo "Script finished. Please check logs and UIs for full status."
echo "-------------------------------------------------------------------------"