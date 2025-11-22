# Chaos Engineering - Testing System Resilience

## Table of Contents

  - [Scenario: Production Under Stress](https://www.google.com/search?q=%23scenario-production-under-stress)
  - [Why Chaos Engineering Matters for SRE](https://www.google.com/search?q=%23why-chaos-engineering-matters-for-sre)
  - [Learning Objectives](https://www.google.com/search?q=%23learning-objectives)
  - [Prerequisites and GitHub Repo Setup](https://www.google.com/search?q=%23prerequisites-and-github-repo-setup)
  - [Phase 1: Deploy Target Application](https://www.google.com/search?q=%23phase-1-deploy-target-application)
  - [Phase 2: Install and Configure LitmusChaos](https://www.google.com/search?q=%23phase-2-install-and-configure-litmuschaos)
  - [Phase 3: Basic Chaos Experiments (Cloud-Native)](https://www.google.com/search?q=%23phase-3-basic-chaos-experiments-cloud-native)
  - [Phase 4: Rollback Under Chaos](https://www.google.com/search?q=%23phase-4-rollback-under-chaos)
  - [Phase 5: Automated Stress Testing](https://www.google.com/search?q=%23phase-5-automated-stress-testing)
  - [Phase 6: Measuring Chaos Impact](https://www.google.com/search?q=%23phase-6-measuring-chaos-impact)
  - [Cleanup](https://www.google.com/search?q=%23cleanup)

-----

## Scenario: Production Under Stress

It's Black Friday, and your e-commerce platform is under immense pressure, with traffic ten times higher than normal. To make matters worse, you need to deploy a critical security patch right in the middle of this surge. However, your production environment isn't behaving as expected. You're seeing network latency spikes disrupting service communication and pods unexpectedly restarting.

As the SRE on call, you have a critical mission. First, you must **deploy the security patch** despite the unstable environment. You also need to be prepared to **safely roll back** if the deployment fails, all while **maintaining service availability** for your customers. Throughout this process, you must also **measure the impact** of these challenging conditions on your recovery procedures. The ultimate question is this: Will your deployment and rollback procedures work when production is already under so much stress?

-----

## Why Chaos Engineering Matters for SRE

In previous exercises, you mastered deployment automation and rollback procedures under **controlled and ideal conditions**. But real-world production environments are rarely ideal. This is where **Chaos Engineering** comes in. By intentionally injecting controlled failures, Chaos Engineering helps SREs validate their assumptions about how a system behaves under pressure. It's a proactive way to discover weaknesses before they lead to real outages. This practice builds confidence in your recovery procedures, allowing you to measure the true Mean Time to Recovery (MTTR) under realistic failure conditions.

-----

## Learning Objectives

By completing this exercise, you will gain practical experience with Cloud-Native Chaos Engineering. You'll begin by **installing LitmusChaos** in your Kubernetes environment. From there, you will **define chaos experiments as code (YAML)** using `ChaosEngine` CRDs—the professional standard for SREs. You will then **execute automated rollbacks** while the Chaos Operator actively attacks your cluster. Finally, you will **measure MTTR** to quantify how instability affects your ability to recover.

-----

## Prerequisites and GitHub Repo Setup

### **Prerequisites**

  - A running Kubernetes cluster (Minikube)
  - `kubectl` configured and working
  - Python 3 installed
  - Basic understanding of Kubernetes deployments

### **Create Your GitHub Repository**

1.  **Create a new repository**:

      - Visit [https://github.com/new](https://github.com/new)
      - Repository name: `sre-chaos-engineering`
      - Visibility: Public
      - Leave "Initialize with README" unchecked
      - Click **Create repository**

2.  **Initialize locally**:

<!-- end list -->

```bash
mkdir -p ~/Projects/sre-chaos-engineering
cd ~/Projects/sre-chaos-engineering
git init
git branch -M main
```

3.  **Link to remote** (replace YOUR-USERNAME):

<!-- end list -->

```bash
git remote add origin https://github.com/YOUR-USERNAME/sre-chaos-engineering.git
```

4.  **Create initial structure**:

<!-- end list -->

```bash
# Create directory structure
mkdir -p manifests/stable manifests/unstable manifests/chaos scripts

# Create initial README
echo "# SRE Chaos Engineering Lab" > README.md
echo "Testing deployment resilience under controlled failure conditions" >> README.md

git add README.md
git commit -m "Initial commit: chaos engineering lab setup"
git push -u origin main
```

-----

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
        </style>
    </head>
    <body>
        <h1>Chaos Engineering Target Application</h1>
        <div class="status">Status: STABLE</div>
        <p>Timestamp: <span id="time"></span></p>
        <script>document.getElementById('time').textContent = new Date().toLocaleString();</script>
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
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
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
    </head>
    <body>
        <h1>Chaos Engineering Target - BROKEN</h1>
    </body>
    </html>
EOF
```

### Step 3: Deploy and Verify Stable Application

```bash
# Deploy stable version
kubectl apply -f manifests/stable/
kubectl rollout status deployment/chaos-target-app
```

-----

## Phase 2: Install and Configure LitmusChaos

In this phase, you'll install LitmusChaos, a popular open-source Chaos Engineering framework for Kubernetes. Unlike manual scripting, Litmus allows you to manage chaos using Kubernetes manifests.

### Step 1: Install LitmusChaos Operator

```bash
# Create dedicated namespace
kubectl create namespace litmus

# Install LitmusChaos operator
kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v3.0.0.yaml -n litmus

# Wait for installation to complete
echo "Waiting for LitmusChaos operator to be ready..."
kubectl wait --for=condition=Ready pods --all -n litmus --timeout=300s
```

### Step 2: Setup Chaos Permissions (RBAC)

Litmus needs permission to modify your application pods (delete them, stress them, etc.). We will create a ServiceAccount for this.

```bash
cat > manifests/chaos/rbac.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pod-delete-sa
  namespace: default
  labels:
    name: pod-delete-sa
    app.kubernetes.io/part-of: litmus
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-delete-sa
  namespace: default
  labels:
    name: pod-delete-sa
    app.kubernetes.io/part-of: litmus
rules:
- apiGroups: ["", "apps", "batch", "litmuschaos.io"]
  resources: ["pods", "deployments", "pods/log", "events", "jobs", "chaosengines", "chaosexperiments", "chaosresults"]
  verbs: ["create", "list", "get", "patch", "update", "delete", "deletecollection"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-delete-sa
  namespace: default
  labels:
    name: pod-delete-sa
    app.kubernetes.io/part-of: litmus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-delete-sa
subjects:
- kind: ServiceAccount
  name: pod-delete-sa
  namespace: default
EOF

kubectl apply -f manifests/chaos/rbac.yaml
```

-----

## Phase 3: Basic Chaos Experiments (Cloud-Native)

Instead of running manual scripts, we will use **Litmus Custom Resource Definitions (CRDs)**. You will define the chaos you want as YAML, and the operator will execute it.

### Step 1: Install the Experiment Definition

We need to pull the logic for "Pod Deletion" from the public ChaosHub.

```bash
kubectl apply -f https://hub.litmuschaos.io/api/chaos/master?file=charts/generic/pod-delete/experiment.yaml
```

### Step 2: Define the Chaos Engine

The `ChaosEngine` connects the experiment to your specific application.

```bash
cat > manifests/chaos/engine-pod-delete.yaml <<EOF
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: nginx-chaos
  namespace: default
spec:
  appinfo:
    appns: 'default'
    applabel: 'app=chaos-target-app'
    appkind: 'deployment'
  jobCleanUpPolicy: 'delete'
  engineState: 'active'
  chaosServiceAccount: pod-delete-sa
  experiments:
    - name: pod-delete
      spec:
        components:
          env:
            # Kill one pod every 10 seconds for 60 seconds
            - name: TOTAL_CHAOS_DURATION
              value: '60'
            - name: CHAOS_INTERVAL
              value: '10'
            - name: FORCE
              value: 'true'
EOF
```

### Step 3: Execute and Observe

Open two terminals to see Cloud-Native chaos in action.

**Terminal 1 (Observation):**

```bash
watch kubectl get pods
```

**Terminal 2 (Action):**

```bash
kubectl apply -f manifests/chaos/engine-pod-delete.yaml
```

**What to observe:**

1.  A `nginx-chaos-runner` pod appears.
2.  Every 10 seconds, one of your application pods is deleted.
3.  Kubernetes automatically recreates the pod (Self-Healing).

When finished observing, stop the experiment:

```bash
kubectl delete -f manifests/chaos/engine-pod-delete.yaml
```

### 💡 SRE Analysis: What just happened?

**The Technical Event:**
You didn't write a script to delete pods. You created a Kubernetes Object (a `ChaosEngine`) that *declared* your intent: "I want pods to die every 10 seconds." The Litmus Operator saw this request and spun up a runner pod to execute that logic for you.

**The Learning Outcome:**
This teaches you **Declarative Chaos**. In the past, sysadmins would SSH into servers and run commands to break things (Imperative). In Modern SRE, we manage chaos exactly like we manage deployments: using YAML manifests. This makes chaos reproducible, version-controlled, and auditable.

**Real Production Value:**
In a real company, you wouldn't run this manually. You would commit this YAML to a Git repository. A CI/CD pipeline could then automatically apply this "Chaos Configuration" to a staging environment every Tuesday, ensuring your system is *continuously* tested for resilience without human intervention.

-----

## Phase 4: Rollback Under Chaos

In this phase, you'll simulate a failed deployment and measure how long it takes to recover — **Mean Time to Recovery (MTTR)**. You'll use a Python script that deploys an unstable application version, triggers the Litmus ChaosEngine to attack the cluster, and measures how long it takes to successfully rollback.

### Step 1: Create the Automated MTTR Script

```bash
cat > scripts/measure-rollback-mttr.py <<'EOF'
#!/usr/bin/env python3
import subprocess
import time
import argparse
import sys
import json
import os

RESULTS_FILE = "chaos_results.json"

def run_command(cmd, timeout=300):
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", "Command timed out"

def deploy_broken_version():
    print(">> Deploying unstable version...")
    success, _, stderr = run_command("kubectl apply -f manifests/unstable/")
    if not success:
        print(f"Failed to deploy unstable version: {stderr}")
        return False
    print(">> Waiting for bad deployment to stabilize...")
    time.sleep(10) 
    return True

def trigger_litmus_chaos(chaos_file):
    if not chaos_file:
        print(">> No chaos selected (Baseline test).")
        return True
    print(f">> Injecting Chaos using manifest: {chaos_file}")
    run_command("kubectl delete chaosengine nginx-chaos --ignore-not-found")
    success, _, stderr = run_command(f"kubectl apply -f {chaos_file}")
    if not success:
        print(f"Failed to inject chaos: {stderr}")
        return False
    print(">> Chaos Engine started.")
    return True

def execute_rollback():
    print(">> Executing rollback command...")
    start_time = time.time()
    success, _, stderr = run_command("kubectl rollout undo deployment/chaos-target-app")
    if not success:
        print(f"Rollback command failed: {stderr}")
        return None
    print(">> Waiting for rollout to succeed...")
    success, _, stderr = run_command("kubectl rollout status deployment/chaos-target-app --timeout=300s")
    end_time = time.time()
    if success:
        return end_time - start_time
    return None

def cleanup_chaos():
    print(">> Cleaning up chaos artifacts...")
    run_command("kubectl delete chaosengine nginx-chaos --ignore-not-found")

def save_result(chaos_type, duration):
    data = {}
    if os.path.exists(RESULTS_FILE):
        try:
            with open(RESULTS_FILE, 'r') as f:
                data = json.load(f)
        except:
            pass
    
    if chaos_type not in data:
        data[chaos_type] = []
    data[chaos_type].append(duration)
    
    with open(RESULTS_FILE, 'w') as f:
        json.dump(data, f, indent=4)
    print(f">> Result saved to {RESULTS_FILE}")

def measure_rollback_mttr(chaos_type=None):
    label = chaos_type if chaos_type else "baseline"
    print(f"\nMEASURING MTTR: {label.upper()}")
    print("=" * 60)
    
    if not deploy_broken_version(): return None

    chaos_manifest = ""
    if chaos_type == "pod-delete":
        chaos_manifest = "manifests/chaos/engine-pod-delete.yaml"
    
    if not trigger_litmus_chaos(chaos_manifest): return None

    mttr = execute_rollback()
    cleanup_chaos()
    
    if mttr:
        print(f">> SUCCESS: Rollback took {mttr:.2f} seconds")
        save_result(label, mttr)
        return mttr
    else:
        print(">> FAILED: Rollback did not complete")
        return None

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--chaos", choices=["pod-delete"], help="Chaos type")
    parser.add_argument("--baseline", action="store_true", help="Run baseline without chaos")
    args = parser.parse_args()
    
    if not args.chaos and not args.baseline:
        print("Specify --baseline or --chaos pod-delete")
        sys.exit(1)

    chaos = None if args.baseline else args.chaos
    measure_rollback_mttr(chaos)
EOF

chmod +x scripts/measure-rollback-mttr.py
```

### 💡 SRE Analysis: What just happened?

**The Technical Event:**
You created a Python script that acts as a "Test Runner." It programmatically breaks your application (bad deploy), optionally breaks your infrastructure (ChaosEngine), and then attempts to fix it (Rollback), recording the exact time taken to succeed.

**The Learning Outcome:**
This introduces the concept of **Test Harnesses**. Chaos Engineering isn't just about breaking things randomly; it's about scientific measurement. You learned how to isolate variables:

1.  Variable A: Bad Code (Unstable Manifest)
2.  Variable B: Bad Infrastructure (Litmus Chaos)
3.  Constant: The Rollback Command

**Real Production Value:**
SREs use scripts like this to validate **Runbooks**. If your "Emergency Rollback" runbook says "Run command X," you need to know if command X actually works when pods are crashing. This script proves that your rollback procedure is valid even when the cluster is on fire.

-----

## Phase 5: Automated Stress Testing

Now that we have our automated tool, we will generate the data needed for our final report. We will run the **Baseline** test (no chaos) and the **Chaos** test (Pod Deletion) multiple times to get an average.

### Step 1: Reset Environment

Ensure you are starting with a healthy cluster.

```bash
kubectl apply -f manifests/stable/
kubectl rollout status deployment/chaos-target-app
```

### Step 2: Run the Test Suite

Run the following commands one by one. Watch `kubectl get pods` in a second terminal to see the difference in behavior.

1.  **Establish Baseline (Run 3 times for accuracy):**

    ```bash
    python3 scripts/measure-rollback-mttr.py --baseline
    python3 scripts/measure-rollback-mttr.py --baseline
    python3 scripts/measure-rollback-mttr.py --baseline
    ```

2.  **Test Under Chaos (Run 3 times):**

    ```bash
    python3 scripts/measure-rollback-mttr.py --chaos pod-delete
    python3 scripts/measure-rollback-mttr.py --chaos pod-delete
    python3 scripts/measure-rollback-mttr.py --chaos pod-delete
    ```

By running these, you are populating the `chaos_results.json` file which we will analyze in the next phase.

### 💡 SRE Analysis: What just happened?

**The Technical Event:**
You collected a dataset. You ran the same test multiple times to generate a statistical average (Mean) rather than relying on a single lucky (or unlucky) run.

**The Learning Outcome:**
This teaches **Statistical Significance**. In distributed systems (like Kubernetes), network flukes happen. One slow test might be a fluke; three slow tests indicate a pattern. SREs deal in trends, not anecdotes.

**Real Production Value:**
This data is what you show to your boss or the CTO. You cannot ask for budget to improve infrastructure based on "It felt slow." You ask for budget based on: "Our tests show that pod instability increases recovery time by 90%." Data drives architectural decisions.

-----

## Phase 6: Measuring Chaos Impact

In this final phase, you’ll **analyze the results** generated in Phase 5 and **generate a professional-grade report**.

### Step 1: Create the Analysis Script

This script reads your *actual* test data from `chaos_results.json` and calculates the impact of chaos on your specific cluster.

```bash
cat > scripts/analyze-chaos-impact.py <<'EOF'
#!/usr/bin/env python3
import json
import os
import statistics

RESULTS_FILE = "chaos_results.json"

def analyze_mttr_results():
    if not os.path.exists(RESULTS_FILE):
        print(f"No results found in {RESULTS_FILE}. Run Phase 5 first.")
        return

    with open(RESULTS_FILE, 'r') as f:
        results = json.load(f)

    print("Chaos Engineering Impact Analysis")
    print("=" * 50)

    if "baseline" not in results:
        print("Error: No baseline data found.")
        return

    baseline_avg = statistics.mean(results["baseline"])

    for scenario, times in results.items():
        avg_time = statistics.mean(times)
        impact = ((avg_time - baseline_avg) / baseline_avg) * 100 if scenario != "baseline" else 0.0
        print(f"{scenario:15}: {avg_time:6.1f}s (avg) | Impact: {impact:+5.1f}%")

    print("\nKey Insights:")
    print(f"- Baseline rollback time is {baseline_avg:.1f} seconds.")
    if "pod-delete" in results:
        print("- Active pod deletion destabilizes deployment, increasing MTTR.")
    
    print("\nSRE Recommendations:")
    print("- Set rollback SLA targets based on the 'Chaos' MTTR, not the Baseline.")
    print("- Ensure LivenessProbes are tuned so Kubernetes detects failures quickly.")

if __name__ == "__main__":
    analyze_mttr_results()
EOF

chmod +x scripts/analyze-chaos-impact.py
```

### Step 2: Generate the Report

Run the analysis script to see your final metrics:

```bash
python3 scripts/analyze-chaos-impact.py
```

**Example Output:**

```text
Chaos Engineering Impact Analysis
==================================================
baseline       :   38.2s (avg) | Impact:  +0.0%
pod-delete     :   72.5s (avg) | Impact: +89.8%
```

### 💡 SRE Analysis: What just happened?

**The Technical Event:**
You processed raw timing data to calculate the "Chaos Tax"—the percentage increase in recovery time caused by the failure.

**The Learning Outcome:**
You learned to quantify **Resilience**. Resilience isn't a "yes/no" checkbox; it is a spectrum. By knowing that pod deletion adds \~90% to your recovery time, you understand the "cost" of that specific failure mode.

**Real Production Value:**
This informs your **Service Level Agreements (SLAs)**.
If you promise your customers "We will fix any bad deployment in 1 minute," your baseline test (38s) says you are safe. But your chaos test (72s) says **you will break your promise** if the cluster is unstable.
A smart SRE uses this data to say: "We cannot promise 1 minute recovery. We can safely promise 2 minutes to account for potential instability." This prevents legal and contractual breaches.

-----

## Cleanup

Once you’ve finished the experiment, clean up the environment.

```bash
# Remove all versions of the application
kubectl delete -f manifests/stable/ --ignore-not-found
kubectl delete -f manifests/unstable/ --ignore-not-found

# Remove Chaos Engines and Permissions
kubectl delete -f manifests/chaos/ --ignore-not-found

# Optionally remove LitmusChaos
kubectl delete namespace litmus --ignore-not-found

echo "Cleanup completed"
```

-----

## Commit Your Work

```bash
git add .
git commit -m "Complete chaos engineering lab with Litmus"
git push origin main
```

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
