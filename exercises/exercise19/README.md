# Chaos Engineering - Testing System Resilience

## Table of Contents

- [Scenario: Production Under Stress](#scenario-production-under-stress)
- [Why Chaos Engineering Matters for SRE](#why-chaos-engineering-matters-for-sre)
- [Learning Objectives](#learning-objectives)
- [Prerequisites and GitHub Repo Setup](#prerequisites-and-github-repo-setup)
- [Phase 1: Deploy Target Application](#phase-1-deploy-target-application)
- [Phase 2: Install and Configure LitmusChaos](#phase-2-install-and-configure-litmuschaos)
- [Phase 3: Basic Chaos Experiments](#phase-3-basic-chaos-experiments)
- [Phase 4: Rollback Under Chaos](#phase-4-rollback-under-chaos)
- [Phase 5: Advanced Chaos Scenarios](#phase-5-advanced-chaos-scenarios)
- [Phase 6: Measuring Chaos Impact](#phase-6-measuring-chaos-impact)
- [Cleanup](#cleanup)

---

## Scenario: Production Under Stress

It's Black Friday, and your e-commerce platform is under immense pressure, with traffic ten times higher than normal. To make matters worse, you need to deploy a critical security patch right in the middle of this surge. However, your production environment isn't behaving as expected. You're seeing network latency spikes disrupting service communication, memory pressure causing pods to unexpectedly restart, CPU throttling on some nodes, and intermittent monitoring connectivity issues.

As the SRE on call, you have a critical mission. First, you must **deploy the security patch** despite the unstable environment. You also need to be prepared to **safely roll back** if the deployment fails, all while **maintaining service availability** for your customers. Throughout this process, you must also **measure the impact** of these challenging conditions on your recovery procedures. The ultimate question is this: Will your deployment and rollback procedures work when production is already under so much stress?

---

## Why Chaos Engineering Matters for SRE

In previous exercises, you mastered deployment automation, GitOps practices, and rollback procedures under **controlled and ideal conditions**. But real-world production environments are rarely ideal. This is where **Chaos Engineering** comes in. By intentionally injecting controlled failures, Chaos Engineering helps SREs validate their assumptions about how a system behaves under pressure. It's a proactive way to discover weaknesses before they lead to real outages. This practice builds confidence in your recovery procedures, allowing you to measure the true Mean Time to Recovery (MTTR) under realistic failure conditions and ultimately improve your system design based on observed failure modes. Through these experiments, you can answer critical questions, like whether your rollback procedure works when pods are crashing or how network latency impacts deployment times.

---

## Learning Objectives

By completing this exercise, you will gain practical experience with Chaos Engineering. You'll begin by **installing and configuring LitmusChaos** for your Kubernetes environment. From there, you will **design chaos experiments** to simulate realistic production failures and then **execute rollback procedures** under these stressful conditions. You'll learn to **measure and compare MTTR** between normal and chaotic scenarios and **analyze system behavior** as you inject failures. This process will help you build confidence in your deployment and recovery capabilities while applying the core SRE principle of proactive reliability testing.

---

## Prerequisites and GitHub Repo Setup

### **Prerequisites**

- A running Kubernetes cluster (Minikube)
- `kubectl` configured and working  
- Basic understanding of Kubernetes deployments and services
- Familiarity with deployment and rollback concepts

### **Create Your GitHub Repository**

1. **Create a new repository**:

   - Visit [https://github.com/new](https://github.com/new)
   - Repository name: `sre-chaos-engineering`
   - Visibility: Public
   - Leave "Initialize with README" unchecked  
   - Click **Create repository**

2. **Initialize locally**:

```bash
mkdir -p ~/Projects/sre-chaos-engineering
cd ~/Projects/sre-chaos-engineering
git init
git branch -M main
```

3. **Link to remote** (replace YOUR-USERNAME):

```bash
git remote add origin https://github.com/YOUR-USERNAME/sre-chaos-engineering.git
```

4. **Create initial structure**:

```bash
# Create directory structure
mkdir -p manifests/stable manifests/unstable scripts

# Create initial README
echo "# SRE Chaos Engineering Lab" > README.md
echo "Testing deployment resilience under controlled failure conditions" >> README.md

git add README.md
git commit -m "Initial commit: chaos engineering lab setup"
git push -u origin main
```

---

## Phase 1: Deploy Target Application

We'll create a simple but realistic web application that we can stress test and practice rollbacks with.

### Step 1: Create Stable Application Manifests

```bash
# Create stable deployment
cat > manifests/stable/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chaos-target-app
  labels:
    app: chaos-target-app
    version: stable
spec:
  replicas: 3
  selector:
    matchLabels:
      app: chaos-target-app
  template:
    metadata:
      labels:
        app: chaos-target-app
        version: stable
    spec:
      containers:
      - name: app
        image: nginx:1.21-alpine
        ports:
        - containerPort: 80
        # Resource limits for realistic testing
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        # Health checks
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        # Mount custom content
        volumeMounts:
        - name: content
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
      volumes:
      - name: content
        configMap:
          name: app-content
EOF

# Create service
cat > manifests/stable/service.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: chaos-target-service
  labels:
    app: chaos-target-app
spec:
  selector:
    app: chaos-target-app
  ports:
  - port: 80
    targetPort: 80
  type: NodePort
EOF

# Create content ConfigMap  
cat > manifests/stable/configmap.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Chaos Engineering Target</title>
        <style>
            body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #e8f5e8; }
            .status { color: #2d5a3d; font-size: 1.5em; margin: 20px 0; }
            .info { background: #d4edda; padding: 15px; border-radius: 5px; display: inline-block; }
        </style>
    </head>
    <body>
        <h1>Chaos Engineering Target Application</h1>
        <div class="status">Status: STABLE</div>
        <div class="info">
            <strong>Version:</strong> 1.0-stable<br>
            <strong>Purpose:</strong> Testing resilience under chaos<br>
            <strong>Timestamp:</strong> <span id="time"></span>
        </div>
        <script>
            document.getElementById('time').textContent = new Date().toLocaleString();
        </script>
    </body>
    </html>
EOF
```

### Step 2: Create Unstable Application (For Rollback Testing)

```bash
# Create unstable deployment with broken image
cat > manifests/unstable/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chaos-target-app
  labels:
    app: chaos-target-app
    version: unstable
spec:
  replicas: 3
  selector:
    matchLabels:
      app: chaos-target-app
  template:
    metadata:
      labels:
        app: chaos-target-app
        version: unstable
    spec:
      containers:
      - name: app
        image: nginx:nonexistent-tag  # This will cause ImagePullBackOff
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        volumeMounts:
        - name: content
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
      volumes:
      - name: content
        configMap:
          name: app-content-unstable
EOF

# Copy service for unstable version
cp manifests/stable/service.yaml manifests/unstable/service.yaml

# Create unstable content ConfigMap
cat > manifests/unstable/configmap.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-content-unstable
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Chaos Engineering Target - UNSTABLE</title>
        <style>
            body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #ffe6e6; }
            .status { color: #d63384; font-size: 1.5em; margin: 20px 0; }
            .info { background: #f8d7da; padding: 15px; border-radius: 5px; display: inline-block; }
        </style>
    </head>
    <body>
        <h1>Chaos Engineering Target - BROKEN</h1>
        <div class="status">Status: UNSTABLE</div>
        <div class="info">
            <strong>Version:</strong> 2.0-unstable<br>
            <strong>Issue:</strong> Image pull failure<br>
            <strong>Action:</strong> Should rollback immediately
        </div>
    </body>
    </html>
EOF
```

### Step 3: Deploy and Verify Stable Application

```bash
# Deploy stable version
kubectl apply -f manifests/stable/
```

```bash
# Wait for deployment
kubectl rollout status deployment/chaos-target-app
```

```bash
# Verify pods are running
kubectl get pods -l app=chaos-target-app
```

```bash
# Test the service
kubectl port-forward svc/chaos-target-service 8080:80 --address 0.0.0.0 &
SERVICE_PID=$!
```

```bash
# Test in browser
http://localhost:8080
```

```bash
# Test in terminal
curl http://localhost:8080
```

---

## Phase 2: Install and Configure LitmusChaos

In this phase, you'll install LitmusChaos, a popular open-source Chaos Engineering framework for Kubernetes. LitmusChaos lets you inject faults like pod failures, memory pressure, and network latency to simulate real-world outages. You’ll deploy its operator and define the experiments needed to stress your application in a controlled, measurable way.

### Step 1: Install LitmusChaos Operator

```bash
# Create dedicated namespace
kubectl create namespace litmus
```

```bash
# Install LitmusChaos operator
kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v3.0.0.yaml -n litmus
```

```bash
# Wait for installation to complete
echo "Waiting for LitmusChaos operator to be ready..."
kubectl wait --for=condition=Ready pods --all -n litmus --timeout=300s
```

```bash
# Verify installation
kubectl get pods -n litmus
kubectl get crds | grep chaos
```

---

## Phase 3: Basic Chaos Experiments

This phase introduces **three chaos scenarios**: pod deletion, simulated memory pressure, and simulated network latency. Each is designed to help you observe system behavior under failure using **real-time monitoring** and a **controlled chaos injection script**.

You’ll use **two terminals**:

* **Terminal 1**: Monitors app availability (simulates users accessing the service)
* **Terminal 2**: Runs chaos scripts (simulates system failures)

---

### Step 1: Pod Deletion Chaos

In this experiment, we simulate pod crashes by force-deleting pods.

---

#### Terminal 1 — Monitor App in Real Time

Run this in **Terminal 1** to continuously test the app’s availability:

```bash
echo "Testing service availability during pod deletion:"
for i in {1..20}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 || echo "000")
  echo "$(date '+%H:%M:%S') - HTTP $STATUS"
  sleep 3
done
```

**What to expect:**

* Mostly `HTTP 200` responses
* Occasional `HTTP 000` indicates temporary disruption while a pod is being recreated

---

#### Terminal 2 — Run Chaos Script

Open a **second terminal** and run:

```bash
cat > scripts/manual-pod-chaos.sh <<'EOF'
#!/bin/bash
echo "=== Manual Pod Deletion Chaos ==="
echo "Deleting one pod every 15 seconds (4 rounds)"
echo "Starting chaos at: $(date)"
echo ""

for i in {1..4}; do
  PODS=($(kubectl get pods -l app=chaos-target-app -o jsonpath='{.items[*].metadata.name}'))
  POD_TO_DELETE=${PODS[0]}
  
  echo "[$(date '+%H:%M:%S')] Round $i: Deleting pod $POD_TO_DELETE"
  kubectl delete pod "$POD_TO_DELETE" --grace-period=0
  
  sleep 15
done

echo "Chaos completed at: $(date)"
EOF

chmod +x scripts/manual-pod-chaos.sh
./scripts/manual-pod-chaos.sh
```

**What to observe:**

* Pods go from `Running` → `Terminating` → disappear → new pods appear as `Pending` or `ContainerCreating`
* Total pod count stays at 3
* Terminal 1 shows real-time impact on service availability

---

### Step 2: Simulated Memory Pressure

We simulate a memory-stressed crash by deleting a pod while under simulated load.

---

#### Terminal 1 — Monitor App Availability

Run in **Terminal 1**:

```bash
echo "Testing service availability during simulated memory pressure:"
for i in {1..20}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 || echo "000")
  echo "$(date '+%H:%M:%S') - HTTP $STATUS"
  sleep 3
done
```

---

#### Terminal 2 — Run Memory Chaos (Simulated)

Run in **Terminal 2**:

```bash
echo "Simulating memory pressure by deleting a pod..."
POD=$(kubectl get pods -l app=chaos-target-app -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod "$POD" --grace-period=0
```

Wait 60 seconds:

```bash
sleep 60
```

Then confirm recovery:

```bash
kubectl get pods -l app=chaos-target-app
```

**What to observe:**

* One pod is terminated, and a replacement pod is created
* Terminal 1 may show `HTTP 000` if the app momentarily becomes unavailable

This mirrors what would happen if a pod exceeded memory limits and was killed by the kernel.

---

### Step 3: Simulated Network Latency

We simulate high-latency behavior by intentionally delaying client requests. This helps visualize degraded user experience without requiring kernel-level tools.

---

#### Terminal 1 — Send Baseline Requests

```bash
echo "Baseline response times:"
for i in {1..5}; do
  curl -w "Attempt $i - Time: %{time_total}s\n" -o /dev/null -s http://localhost:8080
  sleep 2
done
```

You should see response times under 0.1 seconds.

---

#### Terminal 2 — Inject Artificial Delay (Simulated Latency)

Now simulate client-side latency by adding artificial `sleep` to the request loop:

```bash
echo "Simulating client-side delay to mimic network latency:"
for i in {1..5}; do
  curl -w "Attempt $i - Time: %{time_total}s\n" -o /dev/null -s http://localhost:8080
  sleep 3
done
```

You won’t see real impact on pods, but this helps students visualize **how network degradation affects user-perceived latency**.

> Optional: Pair this with a system monitoring tool like `htop`, `kubectl top pods`, or a Prometheus+Grafana setup to visualize resource trends under chaos.

---

## Summary of Expected Behavior

| Scenario               | Terminal 1 Output                                 | Terminal 2 Action                    | Kubernetes Behavior                                 |
| ---------------------- | ------------------------------------------------- | ------------------------------------ | --------------------------------------------------- |
| Pod Deletion           | `HTTP 200` with occasional `HTTP 000`             | Force-delete pods manually           | New pods auto-created to maintain replica count     |
| Simulated Memory Crash | `HTTP 200` with minor service blip (1 pod down)   | Delete one pod to mimic OOM or crash | Replacement pod created; service stabilizes         |
| Simulated Latency      | Slower `curl` response time output (manual delay) | Add delay between client requests    | No actual pod changes; client simulates degraded UX |

---

## Phase 4: Rollback Under Chaos

In this phase, you'll simulate a failed deployment and measure how long it takes to recover — a key Site Reliability Engineering (SRE) metric known as **Mean Time to Recovery (MTTR)**. You'll implement a Python script that deploys an unstable application version, optionally introduces chaos (e.g., pod crashes), performs an automatic rollback, and measures how long it takes the system to stabilize.

To fully observe what's happening, this phase uses **two terminals**:

* **Terminal 1**: Monitor pod behavior in real time with `watch kubectl get pods`.
* **Terminal 2**: Run the MTTR measurement script.

---

### Step 1: Create the MTTR Measurement Script

You only need to do this once. The script is reusable across all scenarios.

```bash
cat > scripts/measure-rollback-mttr.py <<'EOF'
#!/usr/bin/env python3
import subprocess
import time
import argparse
import sys
import threading
import os

CHAOS_SCRIPT = "scripts/manual-pod-chaos.sh"

def run_command(cmd, timeout=300):
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", "Command timed out"

def deploy_broken_version():
    print("Deploying unstable version...")
    success, _, stderr = run_command("kubectl apply -f manifests/unstable/")
    if not success:
        print(f"Failed to deploy unstable version: {stderr}")
        return False
    print("Waiting for deployment to fail...")
    time.sleep(15)
    return True

def start_manual_chaos(chaos_type):
    if chaos_type == "pod-delete":
        print(f"Starting manual pod deletion chaos in background...")
        os.chmod(CHAOS_SCRIPT, 0o755)
        thread = threading.Thread(target=lambda: os.system(f"./{CHAOS_SCRIPT}"))
        thread.daemon = True
        thread.start()
        time.sleep(5)
        return True
    elif chaos_type == "memory-hog":
        print("Simulating memory pressure (deleting one pod)...")
        success, out, _ = run_command("kubectl delete pod $(kubectl get pods -l app=chaos-target-app -o jsonpath='{.items[0].metadata.name}') --grace-period=0")
        time.sleep(5)
        return success
    elif chaos_type == "network-latency":
        print("Simulating network latency using artificial delay...")
        return True
    else:
        print("Unsupported or no chaos type")
        return True

def execute_rollback():
    print("Executing rollback...")
    start_time = time.time()
    success, _, stderr = run_command("kubectl rollout undo deployment/chaos-target-app")
    if not success:
        print(f"Rollback failed: {stderr}")
        return None
    success, _, stderr = run_command("kubectl rollout status deployment/chaos-target-app --timeout=300s")
    end_time = time.time()
    if success:
        print("Rollback completed successfully")
        return end_time - start_time
    else:
        print(f"Rollback status check failed: {stderr}")
        return None

def measure_rollback_mttr(chaos_type=None):
    print(f"Measuring rollback MTTR" + (f" under {chaos_type} chaos" if chaos_type else " (baseline)"))
    print("-" * 60)
    if not deploy_broken_version():
        return None
    if not start_manual_chaos(chaos_type):
        return None
    mttr = execute_rollback()
    if mttr:
        print(f"\nMTTR Result: {mttr:.1f} seconds")
        return mttr
    else:
        print("\nMTTR measurement failed")
        return None

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Measure rollback MTTR under chaos conditions")
    parser.add_argument("--chaos", choices=["pod-delete", "memory-hog", "network-latency"], help="Chaos type")
    parser.add_argument("--baseline", action="store_true", help="Run baseline without chaos")
    args = parser.parse_args()
    chaos = None if args.baseline else args.chaos
    mttr = measure_rollback_mttr(chaos)
    sys.exit(0 if mttr else 1)
EOF

chmod +x scripts/measure-rollback-mttr.py
```

---

## Scenario Instructions: One Terminal to Watch, One to Act

Before running any of the following steps:

### In Terminal 1 (Watch the Rollout in Real Time)

```bash
watch kubectl get pods -l app=chaos-target-app
```

This allows you to observe changes as they happen — such as pods failing, being deleted, or being recreated during the rollback.

---

### Step 2: Baseline Rollback (No Chaos)

#### In Terminal 2:

```bash
# Start clean
kubectl apply -f manifests/stable/
kubectl rollout status deployment/chaos-target-app
```

```bash
# Run MTTR test with no injected failures
python3 scripts/measure-rollback-mttr.py --baseline
```

**Expected Behavior**:

* You’ll briefly see pods in `ImagePullBackOff` or `CrashLoopBackOff` (due to the unstable version).
* Then pods will be replaced with stable ones.
* MTTR should be low (usually under 50 seconds).

---

### Step 3: Rollback During Pod Deletion Chaos

#### In Terminal 2:

```bash
kubectl apply -f manifests/stable/
kubectl rollout status deployment/chaos-target-app
```

```bash
python3 scripts/measure-rollback-mttr.py --chaos pod-delete
```

**Expected Behavior**:

* Unstable pods will fail as before, but **chaos will also start deleting healthy pods** during rollback.
* The watcher will show continuous pod terminations and recreations.
* MTTR will increase due to the instability added by chaos.

---

### Step 4: Rollback During Memory Pressure Chaos

#### In Terminal 2:

```bash
kubectl apply -f manifests/stable/
kubectl rollout status deployment/chaos-target-app
```

```bash
python3 scripts/measure-rollback-mttr.py --chaos memory-hog
```

**Expected Behavior**:

* One pod will be force-deleted to simulate OOM behavior.
* Expect to see additional recovery time and possible restarts.
* MTTR may increase due to delayed scheduling.

---

### Step 5: Rollback During Network Latency Chaos

#### In Terminal 2:

```bash
kubectl apply -f manifests/stable/
kubectl rollout status deployment/chaos-target-app
```

```bash
python3 scripts/measure-rollback-mttr.py --chaos network-latency
```

**Expected Behavior**:

* No pod deletions or crashes will occur.
* However, command responses and rollout progression may be delayed (simulated latency).
* MTTR will reflect those delays.

---

## What to Pay Attention To

* **Pod lifecycle changes** in Terminal 1 (e.g., `Terminating`, `ContainerCreating`, restarts).
* **MTTR output** in Terminal 2.
* Compare how long each test takes and **how rollback is affected by different chaos types**.

---

## Phase 5: Advanced Chaos Scenarios

In this phase, we move beyond isolated failures and introduce **multiple concurrent failures** to simulate more realistic and high-impact production incidents. You'll define a custom chaos script that combines **pod deletion and memory pressure**, running them simultaneously while measuring MTTR. This scenario mirrors real-world outages where multiple components fail at once.

To visualize system behavior clearly, you’ll again use **two terminals**:

* **Terminal 1**: Monitor the application with `watch kubectl get pods`.
* **Terminal 2**: Trigger the chaos scenario and run the rollback MTTR measurement.

---

### Step 1: Create the Multi-Failure Chaos Script

This script deletes two different pods every 15 seconds — one simulating pod crash, the other simulating memory exhaustion.

```bash
cat > scripts/manual-multi-chaos.sh <<'EOF'
#!/bin/bash
echo "=== Multi-Failure Chaos: Pod Deletion + Memory Pressure ==="
echo "Duration: ~60 seconds, running in parallel"
echo ""

for i in {1..4}; do
    PODS=($(kubectl get pods -l app=chaos-target-app -o jsonpath='{.items[*].metadata.name}'))

    # Pod Deletion - delete one pod
    if [ ${#PODS[@]} -ge 1 ]; then
        echo "[$(date '+%H:%M:%S')] Round $i: Deleting pod ${PODS[0]}"
        kubectl delete pod "${PODS[0]}" --grace-period=0
    fi

    # Memory Pressure Simulation - delete another pod
    if [ ${#PODS[@]} -ge 2 ]; then
        echo "[$(date '+%H:%M:%S')] Round $i: Simulating memory pressure by deleting ${PODS[1]}"
        kubectl delete pod "${PODS[1]}" --grace-period=0
    fi

    echo "Waiting 15 seconds..."
    sleep 15
done

echo "Multi-chaos completed at: $(date)"
EOF

chmod +x scripts/manual-multi-chaos.sh
```

---

### Step 2: Run Rollback MTTR Test Under Multi-Failure Chaos

You’ll now reuse the same rollback measurement script from Phase 4 and run both the **chaos script** and the **rollback test** in parallel.

---

### In Terminal 1: Watch Live Pod Behavior

```bash
watch kubectl get pods -l app=chaos-target-app
```

🔎 **What to watch for**:

* Pods being deleted in pairs every \~15 seconds.
* Kubernetes quickly recreating pods (ContainerCreating → Running).
* Increased churn in pod status.

---

### In Terminal 2: Trigger the Rollback + Chaos Test

Start with a clean state:

```bash
kubectl apply -f manifests/stable/
kubectl rollout status deployment/chaos-target-app
```

Then launch the chaos script in the background:

```bash
scripts/manual-multi-chaos.sh &
CHAOS_PID=$!
```

Immediately after that, while the chaos is ongoing, run the MTTR test:

```bash
python3 scripts/measure-rollback-mttr.py --baseline
```

Wait for both processes to complete:

```bash
wait $CHAOS_PID || true
```

---

### Expected Output and Behavior

* Terminal 1 will show **two pods being deleted and recreated** every 15 seconds.
* Terminal 2 will display the full MTTR measurement as the system attempts to recover during this instability.
* MTTR will likely be **higher** than all previous phases due to **concurrent stressors**.

---

### Step 3 (Optional): Run All Chaos Scenarios Automatically

To compare MTTR across **baseline**, **single-chaos**, and **multi-chaos** cases, run the following comprehensive script:

```bash
cat > scripts/comprehensive-chaos-test.sh <<'EOF'
#!/bin/bash
set -e

echo "Comprehensive Chaos Engineering Test"
echo "Testing rollback resilience under various failure conditions"
echo "======================================================================"

declare -A results

run_test() {
    label=$1
    chaos=$2

    echo "Test: $label"
    kubectl apply -f manifests/stable/ > /dev/null
    kubectl rollout status deployment/chaos-target-app > /dev/null

    if [ "$chaos" == "multi-failure" ]; then
        scripts/manual-multi-chaos.sh &
        CHAOS_PID=$!
        result=$(python3 scripts/measure-rollback-mttr.py --baseline 2>/dev/null | grep "MTTR Result" | awk '{print $3}')
        wait $CHAOS_PID || true
    elif [ "$chaos" == "none" ]; then
        result=$(python3 scripts/measure-rollback-mttr.py --baseline 2>/dev/null | grep "MTTR Result" | awk '{print $3}')
    else
        result=$(python3 scripts/measure-rollback-mttr.py --chaos "$chaos" 2>/dev/null | grep "MTTR Result" | awk '{print $3}')
    fi

    results["$label"]=$result
    echo "$label MTTR: $result"
    echo ""
}

run_test "Baseline" "none"
run_test "Pod Deletion" "pod-delete"
run_test "Memory Pressure" "memory-hog"
run_test "Network Latency" "network-latency"
run_test "Multi-Failure" "multi-failure"

echo "MTTR Comparison Summary"
echo "======================================================================"
for key in "Baseline" "Pod Deletion" "Memory Pressure" "Network Latency" "Multi-Failure"; do
    echo "$key: ${results[$key]} seconds"
done
EOF

chmod +x scripts/comprehensive-chaos-test.sh
./scripts/comprehensive-chaos-test.sh
```

This script automatically runs each scenario and summarizes the MTTR for all cases. Use it if you want a full comparison in one go.

---

## Phase 6: Measuring Chaos Impact

In this final phase, you’ll **analyze the results** of your chaos experiments and **generate a professional-grade report**. This helps quantify how different failure types impact MTTR (Mean Time to Recovery), allowing you to define better SLAs, inform system design decisions, and improve your incident response strategy.

You’ll use two scripts:

* One to **analyze MTTR results** and extract patterns and insights.
* One to **generate a markdown report** summarizing the environment, tests, findings, and SRE recommendations.

---

### Step 1: Create the MTTR Analysis Script

This script assumes you've run at least 3 samples per chaos type and stored them inside the `results` dictionary. It calculates averages and the percentage increase compared to the baseline.

```bash
cat > scripts/analyze-chaos-impact.py <<EOF
#!/usr/bin/env python3
import statistics

def analyze_mttr_results():
    """Analyze and report on MTTR results"""

    # Example results – replace with your actual values
    results = {
        "baseline": [45.2, 43.8, 46.1],
        "pod-delete": [67.3, 71.2, 65.8],
        "memory-hog": [89.4, 95.1, 87.2],
        "network-latency": [156.7, 162.3, 149.8],
        "multi-failure": [173.2, 181.6, 165.9]
    }

    print("Chaos Engineering Impact Analysis")
    print("=" * 50)

    baseline_avg = statistics.mean(results["baseline"])

    for scenario, times in results.items():
        avg_time = statistics.mean(times)
        impact = ((avg_time - baseline_avg) / baseline_avg) * 100 if scenario != "baseline" else 0.0
        print(f"{scenario:15}: {avg_time:6.1f}s (avg) | Impact: {impact:+5.1f}%")

    print("\nKey Insights:")
    print("- Pod deletion adds ~50% to rollback time")
    print("- Memory pressure nearly doubles recovery time")
    print("- Network latency causes the highest MTTR (3–4x baseline)")
    print("- Combined failures have compounding effects")

    print("\nSRE Recommendations:")
    print("- Set rollback SLA targets accounting for chaos conditions")
    print("- Monitor network latency as a leading indicator")
    print("- Prepare escalation paths for compound failure scenarios")
    print("- Practice rollbacks regularly under load and stress")

if __name__ == "__main__":
    analyze_mttr_results()
EOF
```

Make it executable and run it:

```bash
chmod +x scripts/analyze-chaos-impact.py
python3 scripts/analyze-chaos-impact.py
```

---

### Expected Output (Example)

```bash
Chaos Engineering Impact Analysis
==================================================
baseline       :   45.0s (avg) | Impact:  +0.0%
pod-delete     :   68.1s (avg) | Impact: +51.3%
memory-hog     :   90.6s (avg) | Impact: +101.4%
network-latency:  156.3s (avg) | Impact: +247.3%
multi-failure  :  173.6s (avg) | Impact: +285.7%

Key Insights:
- Pod deletion adds ~50% to rollback time
- Memory pressure nearly doubles recovery time
- Network latency causes the highest MTTR (3–4x baseline)
- Combined failures have compounding effects

SRE Recommendations:
- Set rollback SLA targets accounting for chaos conditions
- Monitor network latency as a leading indicator
- Prepare escalation paths for compound failure scenarios
- Practice rollbacks regularly under load and stress
```

---

### Step 2: Generate the Final Chaos Report

Now you’ll generate a Markdown report summarizing:

* Cluster and app info
* Chaos scenarios executed
* Key findings
* SRE recommendations

```bash
cat > scripts/generate-report.sh <<EOF
#!/bin/bash

echo "# Chaos Engineering Report" > chaos-report.md
echo "" >> chaos-report.md
echo "## Test Environment" >> chaos-report.md
echo "- **Cluster**: \$(kubectl config current-context)" >> chaos-report.md
echo "- **Date**: \$(date)" >> chaos-report.md
echo "- **Application**: chaos-target-app (3 replicas)" >> chaos-report.md
echo "" >> chaos-report.md

echo "## Experiments Conducted" >> chaos-report.md
echo "1. **Pod Deletion** – Random pod termination every 15 seconds" >> chaos-report.md
echo "2. **Memory Pressure** – Simulated by deleting pods repeatedly" >> chaos-report.md  
echo "3. **Network Latency** – Simulated curl delays to mimic latency impact" >> chaos-report.md
echo "4. **Multi-Failure** – Pod deletion and memory pressure combined" >> chaos-report.md
echo "" >> chaos-report.md

echo "## Key Findings" >> chaos-report.md
echo "- Rollback procedures succeeded under all tested chaos conditions" >> chaos-report.md
echo "- Network latency had the highest impact on rollback time" >> chaos-report.md
echo "- Memory pressure caused moderate delays in recovery" >> chaos-report.md
echo "- Pod deletion had the lowest impact due to Kubernetes self-healing" >> chaos-report.md
echo "- Multi-failure scenarios produced the slowest MTTR overall" >> chaos-report.md
echo "" >> chaos-report.md

echo "## Recommendations" >> chaos-report.md
echo "1. **Monitor network health** as a predictor of rollback performance" >> chaos-report.md
echo "2. **Set realistic MTTR targets** that account for degraded conditions" >> chaos-report.md
echo "3. **Run regular rollback drills** under chaos to improve MTTR" >> chaos-report.md
echo "4. **Review resource limits and autoscaling policies** to reduce memory-related failures" >> chaos-report.md
echo "" >> chaos-report.md

echo "Report generated: chaos-report.md"
EOF
```

Make it executable and run it:

```bash
chmod +x scripts/generate-report.sh
./scripts/generate-report.sh
```

You’ll now have a complete `chaos-report.md` file in your project folder that you can commit or share with your team.

---

## Cleanup

Once you’ve finished the experiment and generated your report, it’s time to clean up the environment.

```bash
# Stop any active port-forward
kill $SERVICE_PID 2>/dev/null || true

# Remove all versions of the application
kubectl delete -f manifests/stable/ --ignore-not-found
kubectl delete -f manifests/unstable/ --ignore-not-found

# Delete any running chaos experiments
kubectl delete chaosengines --all --ignore-not-found

# Optionally remove LitmusChaos components
kubectl delete namespace litmus --ignore-not-found

echo "Cleanup completed"
```

This will stop any active services, remove deployed resources, and optionally delete the LitmusChaos namespace. If you plan to continue exploring chaos experiments, you may choose to keep the `litmus` namespace.

---

## Commit Your Work

Before wrapping up, make sure your repository reflects all changes made during this lab.

```bash
# Stage all new files
git add .

# Commit your complete chaos engineering setup
git commit -m "Complete chaos engineering lab"

# Push to your GitHub repo
git push origin main
```

Your GitHub repository should now contain all configuration files, scripts, and generated reports.

---

## Final Thoughts

You’ve just completed a full **Chaos Engineering exercise**, and more importantly, you did it in a **realistic Kubernetes environment**. You didn’t rely on theory alone—you:

* Built a resilient application from scratch.
* Deployed controlled failures using chaos scripts.
* Measured **Mean Time to Recovery (MTTR)** across various failure types.
* Validated your **rollback strategy** under degraded conditions.
* Practiced the SRE mindset of **proactive failure testing**.

This isn’t just a lab. This is the foundation for real production resilience.

---

## Final Note: You've Completed the SRE Academy

This was the final exercise of the SRE Academy—and likely the most demanding one. You didn’t just build a deployment pipeline or configure dashboards. You **put your entire stack under stress**, validated how it behaves under failure, and measured how fast it can recover. That’s what Site Reliability Engineering is all about: designing for failure, observing it in action, and constantly improving.

Throughout this journey, you’ve learned to:

* Build and package apps with containers
* Deploy and manage them in Kubernetes
* Monitor health with Prometheus, Grafana, and alerting systems
* Roll out changes with CI/CD pipelines and GitOps strategies
* Automate recovery through runbooks and rollback procedures
* And now, apply **Chaos Engineering** to test your systems under real-world failure conditions

Each exercise built on top of the last. What started as simple `kubectl` commands evolved into production-grade workflows. And now, you've reached the point where your systems aren’t just working—they're **battle-tested**.

---

**Congratulations.** You've completed the full SRE Academy.

> Your deployments aren’t just functional—they’re resilient, observable, and ready for production-grade challenges.
