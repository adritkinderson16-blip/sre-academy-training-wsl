#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# SRE Academy cluster bootstrap
#
# Supported environments:
#   - macOS arm64: Colima + Docker + Minikube Docker driver
#   - Ubuntu Linux/WSL2 amd64: Docker Engine + Minikube Docker driver
#
# WARNING:
# --start and --stop are destructive.
# They remove Minikube profiles and local cluster data.
# On macOS, they remove the Colima profile.
# On Ubuntu/WSL, they prune unused Docker objects and volumes.
# =============================================================================

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
readonly COLIMA_CPUS=6
readonly COLIMA_MEMORY_GIB=12
readonly COLIMA_DISK_GIB=80

readonly MINIKUBE_CPUS=5
readonly MINIKUBE_MEMORY_MB=6656
readonly MINIKUBE_DISK_SIZE=60g
readonly MINIKUBE_PROFILE=minikube
readonly MINIKUBE_DRIVER=docker
readonly MINIKUBE_RUNTIME=docker

readonly AWX_NAMESPACE=awx
readonly AWX_NAME=awx-demo
readonly AWX_OPERATOR_RELEASE=my-awx-operator
readonly AWX_OPERATOR_REPOSITORY=awx-operator
readonly AWX_OPERATOR_CHART=awx-operator/awx-operator

readonly KUBECTL_RETRIES=10
readonly RETRY_SLEEP_SECONDS=5

PLATFORM=""
ARCH=""
ACTION=""

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
log() {
  local level=$1
  shift
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*"
}

info() {
  log "INFO" "$*"
}

warn() {
  log "WARN" "$*"
}

error() {
  log "ERROR" "$*"
}

debug() {
  log "DEBUG" "$*"
}

die() {
  error "$*"
  exit 1
}

on_error() {
  local rc=$?
  local line=$1
  local command=$2

  error "Command failed at line ${line} (exit=${rc}): ${command}"
  exit "$rc"
}

trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

# -----------------------------------------------------------------------------
# Environment detection
# -----------------------------------------------------------------------------
detect_environment() {
  local os_name
  local raw_arch

  os_name=$(uname -s)
  raw_arch=$(uname -m)

  case "$raw_arch" in
    arm64|aarch64)
      ARCH="arm64"
      ;;
    x86_64|amd64)
      ARCH="amd64"
      ;;
    *)
      die "Unsupported CPU architecture: ${raw_arch}"
      ;;
  esac

  if [[ "$os_name" == "Darwin" && "$ARCH" == "arm64" ]]; then
    PLATFORM="macos"
    info "Detected supported environment: macOS arm64."
    return 0
  fi

  if [[ "$os_name" == "Linux" && "$ARCH" == "amd64" ]]; then
    [[ -f /etc/os-release ]] || die "Cannot identify Linux distribution: /etc/os-release does not exist."

    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ "${ID:-}" != "ubuntu" ]]; then
      die "Unsupported Linux distribution: ${PRETTY_NAME:-unknown}. Ubuntu is required."
    fi

    if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
      PLATFORM="wsl"
      info "Detected supported environment: Ubuntu WSL2 amd64."
    else
      PLATFORM="ubuntu"
      info "Detected supported environment: Ubuntu Linux amd64."
    fi

    return 0
  fi

  die "Unsupported environment: OS=${os_name}, architecture=${ARCH}. Supported: macOS arm64, Ubuntu Linux amd64, and Ubuntu WSL2 amd64."
}

# -----------------------------------------------------------------------------
# CLI arguments
# -----------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage:
  ./cluster.sh --start
  ./cluster.sh --stop

Options:
  --start    Fully remove and recreate the local Minikube environment, then
             deploy AWX and the remaining infrastructure.

  --stop     Fully remove Minikube profiles and local cluster data. On macOS,
             also stop and delete Colima. On Ubuntu/WSL, prune unused Docker
             objects and volumes.

  --help     Show this help message.
EOF
}

parse_arguments() {
  if [[ $# -ne 1 ]]; then
    usage
    die "Exactly one argument is required: --start or --stop."
  fi

  if [[ "$1" == "--start" ]]; then
    ACTION="start"
    return 0
  fi

  if [[ "$1" == "--stop" ]]; then
    ACTION="stop"
    return 0
  fi

  if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    usage
    exit 0
  fi

  usage
  die "Unsupported option: $1"
}

# -----------------------------------------------------------------------------
# Dependency and capacity checks
# -----------------------------------------------------------------------------
require_tools() {
  local tool
  local tools=(minikube kubectl docker helm ansible-playbook)

  if [[ "$PLATFORM" == "macos" ]]; then
    tools+=(colima)
  fi

  info "Checking required tools."

  for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
      info "Dependency found: ${tool}."
    else
      die "Missing required dependency: ${tool}"
    fi
  done
}

warn_resource_capacity() {
  local cpus
  local memory_mb
  local disk_gib

  if [[ "$PLATFORM" == "macos" ]]; then
    cpus=$(sysctl -n hw.ncpu)
    memory_mb=$(( $(sysctl -n hw.memsize) / 1024 / 1024 ))
  else
    cpus=$(nproc)
    memory_mb=$(( $(awk '/MemTotal:/ {print $2}' /proc/meminfo) / 1024 ))
  fi

  disk_gib=$(df -Pk . | awk 'NR == 2 {print int($4 / 1024 / 1024)}')

  info "Detected capacity: CPUs=${cpus}, RAM=${memory_mb}MiB, free disk=${disk_gib}GiB."

  if (( cpus < MINIKUBE_CPUS )); then
    warn "Minikube requests ${MINIKUBE_CPUS} CPUs but only ${cpus} are visible."
  fi

  if (( memory_mb < MINIKUBE_MEMORY_MB + 2048 )); then
    warn "Minikube requests ${MINIKUBE_MEMORY_MB}MiB. Low host/VM headroom may cause OOM kills."
  fi

  if (( disk_gib < 70 )); then
    warn "Only ${disk_gib}GiB free disk detected. The full lab is more reliable with 70GiB or more."
  fi

  if [[ "$PLATFORM" == "macos" ]] && (( memory_mb < COLIMA_MEMORY_GIB * 1024 + 2048 )); then
    warn "Colima requests ${COLIMA_MEMORY_GIB}GiB. The Mac may not have enough memory headroom."
  fi
}

# -----------------------------------------------------------------------------
# Retry helpers
# -----------------------------------------------------------------------------
retry() {
  local description=$1
  local attempts=$2
  local sleep_seconds=$3
  shift 3

  local attempt=1

  while (( attempt <= attempts )); do
    if "$@"; then
      return 0
    fi

    if (( attempt == attempts )); then
      error "${description} failed after ${attempts} attempts."
      return 1
    fi

    warn "${description} failed (${attempt}/${attempts}); retrying in ${sleep_seconds}s."
    sleep "$sleep_seconds"
    ((attempt++))
  done
}

kubectl_retry() {
  retry "kubectl $*" "$KUBECTL_RETRIES" "$RETRY_SLEEP_SECONDS" kubectl "$@"
}

wait_for_api() {
  info "Waiting for Kubernetes API server readiness."

  retry \
    "Kubernetes API readiness check" \
    60 \
    5 \
    bash -c "kubectl get --raw='/readyz' 2>/dev/null | grep -qx 'ok'"

  info "Kubernetes API server is ready."
}

ensure_namespace() {
  local namespace=$1

  if kubectl get namespace "$namespace" >/dev/null 2>&1; then
    debug "Namespace '${namespace}' already exists."
    return 0
  fi

  info "Creating namespace '${namespace}'."
  kubectl_retry create namespace "$namespace"
}

# -----------------------------------------------------------------------------
# Docker and Colima preparation
# -----------------------------------------------------------------------------
docker_ready() {
  docker info >/dev/null 2>&1
}

start_docker_runtime() {
  if [[ "$PLATFORM" == "macos" ]]; then
    info "Starting Colima: CPUs=${COLIMA_CPUS}, memory=${COLIMA_MEMORY_GIB}GiB, disk=${COLIMA_DISK_GIB}GiB."

    colima start \
      --runtime docker \
      --cpus "$COLIMA_CPUS" \
      --memory "$COLIMA_MEMORY_GIB" \
      --disk "$COLIMA_DISK_GIB"
  fi

  if [[ "$PLATFORM" != "macos" ]] && ! docker_ready; then
    warn "Docker is not reachable."

    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
      info "Starting Docker through systemd."
      sudo systemctl enable --now docker || true
    else
      warn "systemd is unavailable. Ensure Docker Engine is running before retrying."
    fi
  fi

  retry "Docker daemon readiness check" 30 2 docker_ready

  if ! docker ps >/dev/null 2>&1; then
    die "Current user cannot access Docker. Run: sudo usermod -aG docker \$USER, then start a new shell or run: newgrp docker"
  fi

  info "Docker is ready."
  docker info | grep -E 'CPUs|Total Memory|Docker Root Dir' || true
}

# -----------------------------------------------------------------------------
# Full destructive cleanup
# -----------------------------------------------------------------------------
clean_environment() {
  warn "Removing local Kubernetes environment and persistent local cluster data."

  info "Deleting all Minikube profiles and purging Minikube state."
  minikube delete --all --purge || warn "Minikube cleanup did not complete cleanly."

  if [[ "$PLATFORM" == "macos" ]]; then
    info "Stopping Colima."
    colima stop || warn "Colima did not stop cleanly."

    info "Deleting Colima."
    colima delete --force || warn "Colima deletion did not complete cleanly."
  else
    info "Pruning unused Docker containers, images, networks, and volumes."
    docker system prune -af --volumes || warn "Docker cleanup did not complete cleanly."
  fi
}

stop_cluster() {
  warn "Starting full teardown."
  warn "This removes ALL Minikube local cluster data."

  clean_environment

  info "Full teardown completed."
}

# -----------------------------------------------------------------------------
# Minikube
# -----------------------------------------------------------------------------
collect_minikube_diagnostics() {
  error "Collecting Minikube diagnostics."

  minikube status -p "$MINIKUBE_PROFILE" || true
  docker ps -a --filter "name=${MINIKUBE_PROFILE}" || true
  docker logs "$MINIKUBE_PROFILE" --tail=300 || true
  minikube logs -p "$MINIKUBE_PROFILE" --file=minikube-startup.log || true
}

start_minikube() {
  info "Starting Minikube: CPUs=${MINIKUBE_CPUS}, memory=${MINIKUBE_MEMORY_MB}MiB, disk=${MINIKUBE_DISK_SIZE}, runtime=${MINIKUBE_RUNTIME}."

  if ! minikube start \
    --profile="$MINIKUBE_PROFILE" \
    --driver="$MINIKUBE_DRIVER" \
    --container-runtime="$MINIKUBE_RUNTIME" \
    --cpus="$MINIKUBE_CPUS" \
    --memory="$MINIKUBE_MEMORY_MB" \
    --disk-size="$MINIKUBE_DISK_SIZE" \
    --wait=all \
    --wait-timeout=10m; then
    collect_minikube_diagnostics
    die "Minikube startup failed."
  fi

  wait_for_api

  info "Waiting for Minikube node readiness."
  kubectl_retry wait \
    --for=condition=Ready \
    "node/${MINIKUBE_PROFILE}" \
    --timeout=300s

  info "Waiting for CoreDNS pod readiness."
  kubectl_retry wait \
    --namespace kube-system \
    --for=condition=Ready \
    pod \
    --selector=k8s-app=kube-dns \
    --timeout=300s

  info "Creating AWX log directory inside Minikube."
  minikube ssh -p "$MINIKUBE_PROFILE" -- 'sudo mkdir -p /var/log/awx'

  info "Minikube is ready."
  kubectl_retry get nodes -o wide
  kubectl_retry get pods -n kube-system -o wide
  kubectl_retry get storageclass
}

# -----------------------------------------------------------------------------
# AWX
# -----------------------------------------------------------------------------
collect_namespace_diagnostics() {
  local namespace=$1

  error "Collecting diagnostics for namespace '${namespace}'."

  kubectl get all -n "$namespace" || true
  kubectl get pods -n "$namespace" -o wide || true
  kubectl get events -n "$namespace" --sort-by=.lastTimestamp | tail -100 || true
}

install_awx_operator() {
  info "Adding or updating AWX Operator Helm repository."

  helm repo add \
    "$AWX_OPERATOR_REPOSITORY" \
    https://ansible-community.github.io/awx-operator-helm/ \
    --force-update

  helm repo update

  ensure_namespace "$AWX_NAMESPACE"

  info "Installing or upgrading AWX Operator."

  helm upgrade --install \
    "$AWX_OPERATOR_RELEASE" \
    "$AWX_OPERATOR_CHART" \
    --namespace "$AWX_NAMESPACE" \
    --wait \
    --timeout=10m

  info "Waiting for AWX Operator controller manager."

  kubectl_retry rollout status \
    --namespace "$AWX_NAMESPACE" \
    deployment/awx-operator-controller-manager \
    --timeout=300s
}

apply_awx_instance() {
  if [[ -f "awx-demo.yml" ]]; then
    info "Applying AWX configuration from awx-demo.yml."
    kubectl_retry apply -f awx-demo.yml
    return 0
  fi

  warn "awx-demo.yml was not found. Applying fallback AWX definition."

  cat <<'EOF' | kubectl_retry apply -f -
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-demo
  namespace: awx
spec:
  service_type: nodeport
  web_resource_requirements:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "750m"
  task_resource_requirements:
    requests:
      memory: "768Mi"
      cpu: "250m"
    limits:
      memory: "1536Mi"
      cpu: "1"
  postgres_resource_requirements:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "750m"
  postgres_storage_requirements:
    requests:
      storage: 8Gi
EOF
}

awx_workloads_exist() {
  kubectl get deployment "${AWX_NAME}-web" -n "$AWX_NAMESPACE" >/dev/null 2>&1 \
    && kubectl get deployment "${AWX_NAME}-task" -n "$AWX_NAMESPACE" >/dev/null 2>&1 \
    && kubectl get statefulset "${AWX_NAME}-postgres-15" -n "$AWX_NAMESPACE" >/dev/null 2>&1
}

wait_for_awx() {
  info "Waiting for AWX workloads to be created."

  if ! retry "AWX workload creation" 60 10 awx_workloads_exist; then
    collect_namespace_diagnostics "$AWX_NAMESPACE"
    kubectl describe awx "$AWX_NAME" -n "$AWX_NAMESPACE" || true
    die "AWX workloads were not created."
  fi

  info "Waiting for AWX web deployment."
  kubectl_retry wait \
    --namespace "$AWX_NAMESPACE" \
    --for=condition=Available \
    "deployment/${AWX_NAME}-web" \
    --timeout=900s

  info "Waiting for AWX task deployment."
  kubectl_retry wait \
    --namespace "$AWX_NAMESPACE" \
    --for=condition=Available \
    "deployment/${AWX_NAME}-task" \
    --timeout=900s

  info "Waiting for AWX PostgreSQL StatefulSet."
  kubectl_retry rollout status \
    --namespace "$AWX_NAMESPACE" \
    "statefulset/${AWX_NAME}-postgres-15" \
    --timeout=900s

  info "AWX is ready."
}

show_awx_access() {
  local minikube_ip
  local awx_port
  local admin_password

  minikube_ip=$(minikube ip -p "$MINIKUBE_PROFILE")

  awx_port=$(
    kubectl get svc "${AWX_NAME}-service" \
      -n "$AWX_NAMESPACE" \
      -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null \
      || true
  )

  kubectl_retry get svc -n "$AWX_NAMESPACE"

  if [[ -z "$awx_port" ]]; then
    warn "AWX NodePort is not available yet."
    return 0
  fi

  info "AWX URL: http://${minikube_ip}:${awx_port}"
  info "AWX username: admin"

  admin_password=$(
    kubectl get secret "${AWX_NAME}-admin-password" \
      -n "$AWX_NAMESPACE" \
      -o jsonpath='{.data.password}' 2>/dev/null \
      | base64 --decode 2>/dev/null \
      || true
  )

  if [[ -n "$admin_password" ]]; then
    info "AWX admin password: ${admin_password}"
  else
    warn "AWX admin password is not available yet."
  fi
}

# -----------------------------------------------------------------------------
# Optional Ansible playbook
# -----------------------------------------------------------------------------
run_ansible_playbook() {
  if [[ -f "../exercise4.1/ansible_quickstart/inventory.ini" && -f "collect-status-application.yaml" ]]; then
    info "Running Ansible playbook with exercise inventory."

    ansible-playbook \
      -i ../exercise4.1/ansible_quickstart/inventory.ini \
      collect-status-application.yaml

    return 0
  fi

  if [[ -f "inventory.ini" && -f "collect-status-application.yaml" ]]; then
    info "Running Ansible playbook with local inventory."

    ansible-playbook \
      -i inventory.ini \
      collect-status-application.yaml

    return 0
  fi

  warn "Ansible inventory or collect-status-application.yaml is missing. Skipping playbook."
}

# -----------------------------------------------------------------------------
# Infrastructure manifests
# -----------------------------------------------------------------------------
apply_manifest() {
  local file=$1
  local description=$2

  if [[ ! -f "$file" ]]; then
    warn "${description} manifest was not found: ${file}. Skipping."
    return 0
  fi

  info "Applying ${description}: ${file}"
  kubectl_retry apply -f "$file"

  debug "Waiting 5 seconds before the next component."
  sleep 5
}

apply_infrastructure() {
  info "Deploying remaining infrastructure components."

  apply_manifest "./storage.yaml" "Storage configuration"
  apply_manifest "./deployment.yaml" "Application deployment"
  apply_manifest "./otel-collector.yaml" "OpenTelemetry Collector"
  apply_manifest "./jaeger.yaml" "Jaeger"
  apply_manifest "./prometheus.yaml" "Prometheus"
  apply_manifest "./grafana-loki.yaml" "Loki"
  apply_manifest "./grafana.yaml" "Grafana"

  info "Waiting 30 seconds for initial workload scheduling."
  sleep 30

  info "Final node status:"
  kubectl_retry get nodes -o wide

  info "Final pod status:"
  kubectl_retry get pods -A -o wide
}

# -----------------------------------------------------------------------------
# Cluster lifecycle
# -----------------------------------------------------------------------------
start_cluster() {
  info "Starting cluster bootstrap."

  clean_environment
  start_docker_runtime
  start_minikube

  echo "-------------------------------------------------------------------------"
  echo "Install AWX Operator"
  echo "-------------------------------------------------------------------------"
  install_awx_operator

  echo "-------------------------------------------------------------------------"
  echo "Configure AWX"
  echo "-------------------------------------------------------------------------"
  apply_awx_instance
  wait_for_awx
  show_awx_access

  echo "-------------------------------------------------------------------------"
  echo "Execute Ansible Playbook"
  echo "-------------------------------------------------------------------------"
  run_ansible_playbook

  echo "-------------------------------------------------------------------------"
  echo "Install Remaining Infrastructure"
  echo "-------------------------------------------------------------------------"
  apply_infrastructure

  info "Cluster bootstrap completed successfully."
}

main() {
  parse_arguments "$@"
  detect_environment
  require_tools

  if [[ "$ACTION" == "start" ]]; then
    warn_resource_capacity
    start_cluster
    return 0
  fi

  if [[ "$ACTION" == "stop" ]]; then
    stop_cluster
    return 0
  fi

  die "Internal error: unsupported action '${ACTION}'."
}

main "$@"