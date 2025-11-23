# Chaos Engineering - Testing System Resilience

## Table of Contents

- [Scenario: Production Under Stress](#scenario-production-under-stress)
- [Why Chaos Engineering Matters for SRE](#why-chaos-engineering-matters-for-sre)
- [Learning Objectives](#learning-objectives)
- [Prerequisites and GitHub Repo Setup](#prerequisites-and-github-repo-setup)
- [Phase 1: Deploy Target Application](#phase-1-deploy-target-application)
- [Phase 2: Install Argo Workflows and LitmusChaos](#phase-2-install-argo-workflows-and-litmuschaos)
- [Phase 3: Basic Chaos Experiments (Workflow-Based)](#phase-3-basic-chaos-experiments-workflow-based)
- [Phase 4: Rollback Under Chaos](#phase-4-rollback-under-chaos)
- [Phase 5: Automated Stress Testing](#phase-5-automated-stress-testing)
- [Phase 6: Measuring Chaos Impact](#phase-6-measuring-chaos-impact)
- [Cleanup](#cleanup)
- [Final Thoughts](#final-thoughts)

---

## Scenario: Production Under Stress

It's Black Friday, and your e-commerce platform is under immense pressure, with traffic ten times higher than normal. To make matters worse, you need to deploy a critical security patch right in the middle of this surge. However, your production environment isn't behaving as expected. You're seeing network latency spikes disrupting service communication and pods unexpectedly restarting.

As the SRE on call, you have a critical mission. First, you must **deploy the security patch** despite the unstable environment. You also need to be prepared to **safely roll back** if the deployment fails, all while **maintaining service availability** for your customers. Throughout this process, you must also **measure the impact** of these challenging conditions on your recovery procedures. The ultimate question is this: Will your deployment and rollback procedures work when production is already under so much stress?

---

## Why Chaos Engineering Matters for SRE

In previous exercises, you mastered deployment automation and rollback procedures under **controlled and ideal conditions**. But real-world production environments are rarely ideal. This is where **Chaos Engineering** comes in. By intentionally injecting controlled failures, Chaos Engineering helps SREs validate their assumptions about how a system behaves under pressure. It's a proactive way to discover weaknesses before they lead to real outages. This practice builds confidence in your recovery procedures, allowing you to measure the true Mean Time to Recovery (MTTR) under realistic failure conditions.

---

## Learning Objectives

By completing this exercise, you will gain practical experience with modern Cloud-Native Chaos Engineering using LitmusChaos 3.x and Argo Workflows. You'll begin by **installing the complete chaos engineering stack** in your Kubernetes environment. From there, you will **define chaos experiments as workflow orchestrations** using Argo Workflows—the production standard for automated chaos testing. You will then **execute automated rollbacks** while chaos experiments actively stress your cluster. Finally, you will **measure MTTR** to quantify how instability affects your ability to recover.

**Key Technical Skills:**
- Install and configure Argo Workflows for chaos orchestration
- Deploy LitmusChaos operator and chaos experiments
- Create declarative chaos workflows using Argo CRDs
- Implement RBAC for chaos experiment execution
- Measure and analyze Mean Time to Recovery (MTTR) under failure conditions
- Version control chaos experiments as infrastructure-as-code

---

## Prerequisites and GitHub Repo Setup

### Prerequisites

- A running Kubernetes cluster (Minikube, kind, or cloud-based)
- `kubectl` configured and working
- Python 3 installed
- Basic understanding of Kubernetes deployments
- Familiarity with YAML manifests

### Create Your GitHub Repository

1. **Create a new repository:**
   - Visit https://github.com/new
   - Repository name: `sre-chaos-engineering`
   - Visibility: Public
   - Leave "Initialize with README" unchecked
   - Click **Create repository**

2. **Initialize locally:**

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

4. **Create initial structure:**

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

---

## Phase 1: Deploy Target Application

We'll create a simple but realistic web application in a dedicated namespace that we can stress test and practice rollbacks with.

### Step 1: Create Application Namespace

```bash
# Create dedicated namespace for the target application
kubectl create namespace chaos-app

# Verify namespace creation
kubectl get namespace chaos-app
```

### Step 2: Create Stable Application Manifests

```bash
# Create stable deployment
cat > manifests/stable/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chaos-target-app
  namespace: chaos-app
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
  namespace: chaos-app
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
  namespace: chaos-app
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
  namespace: chaos-app
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
  namespace: chaos-app
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
kubectl rollout status deployment/chaos-target-app -n chaos-app

# Verify pods are running
kubectl get pods -n chaos-app -l app=chaos-target-app

# Test the application
kubectl get svc chaos-target-service -n chaos-app
minikube service chaos-target-service -n chaos-app --url
```

---

## Phase 2: Install Argo Workflows and LitmusChaos

Modern chaos engineering relies on workflow orchestration. LitmusChaos 3.x uses Argo Workflows to manage the complete chaos experiment lifecycle: install experiments, execute chaos, collect results, and cleanup.

### Step 1: Install Argo Workflows

```bash
# Create namespace for Argo
kubectl create namespace argo

# Install Argo Workflows
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.5.11/install.yaml

# Wait for Argo to be ready
echo "Waiting for Argo Workflows to be ready..."
kubectl wait --for=condition=Ready pods --all -n argo --timeout=300s

# Verify installation
kubectl get pods -n argo
```

### Step 2: Install LitmusChaos Operator

```bash
# Create dedicated namespace
kubectl create namespace litmus

# Install LitmusChaos operator
kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v3.0.0.yaml -n litmus

# Wait for installation to complete
echo "Waiting for LitmusChaos operator to be ready..."
kubectl wait --for=condition=Ready pods --all -n litmus --timeout=300s

# Verify operator is running
kubectl get pods -n litmus
```

### Step 3: Setup Chaos Permissions (RBAC)

Argo Workflows needs permissions to orchestrate chaos experiments, and chaos experiments need permissions to affect target applications.

```bash
# Create RBAC directory if it doesn't exist
mkdir -p manifests/chaos

# Create Argo service account with chaos permissions
cat > manifests/chaos/argo-chaos-rbac.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argo-chaos
  namespace: litmus
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: argo-chaos-role
  namespace: litmus
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "pods/exec", "services", "events"]
    verbs: ["create", "get", "list", "watch", "update", "patch", "delete"]
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets", "daemonsets", "replicasets"]
    verbs: ["get", "list", "watch", "update", "patch"]
  - apiGroups: ["batch"]
    resources: ["jobs"]
    verbs: ["create", "get", "list", "watch", "delete", "deletecollection"]
  - apiGroups: ["litmuschaos.io"]
    resources: ["chaosengines", "chaosexperiments", "chaosresults"]
    verbs: ["create", "get", "list", "watch", "update", "patch", "delete"]
  - apiGroups: ["argoproj.io"]
    resources: ["workflows", "workflows/finalizers"]
    verbs: ["get", "list", "watch", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argo-chaos-rolebinding
  namespace: litmus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: argo-chaos-role
subjects:
  - kind: ServiceAccount
    name: argo-chaos
    namespace: litmus
---
# Cross-namespace permissions for chaos to affect chaos-app namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: argo-chaos-target-role
  namespace: chaos-app
rules:
  - apiGroups: [""]
    resources: ["pods", "events"]
    verbs: ["create", "list", "get", "patch", "update", "delete", "deletecollection"]
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets", "daemonsets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs"]
    verbs: ["create", "list", "get", "delete", "deletecollection"]
  - apiGroups: ["litmuschaos.io"]
    resources: ["chaosengines", "chaosexperiments", "chaosresults"]
    verbs: ["create", "list", "get", "patch", "update", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argo-chaos-target-rolebinding
  namespace: chaos-app
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: argo-chaos-target-role
subjects:
  - kind: ServiceAccount
    name: argo-chaos
    namespace: litmus
EOF

kubectl apply -f manifests/chaos/argo-chaos-rbac.yaml
```

### 💡 SRE Analysis: Understanding the Architecture

**The Technical Stack:**
You've installed a complete chaos engineering platform consisting of two major components:

1. **Argo Workflows** - The orchestration engine that manages multi-step chaos experiments as declarative workflows
2. **LitmusChaos Operator** - The chaos execution engine that watches for ChaosEngine CRDs and executes experiments

**The Learning Outcome:**
This architecture demonstrates **Separation of Concerns**. Argo handles the "what happens when" (orchestration), while Litmus handles the "how to break things" (chaos execution). This separation allows you to compose complex chaos scenarios by chaining multiple experiments together.

**Real Production Value:**
In production environments, chaos experiments aren't run manually. They're scheduled using Argo CronWorkflows to run automatically during off-peak hours. The workflow-based approach means your chaos experiments become version-controlled, auditable, and CI/CD-ready—just like your application code.

**Namespace Isolation:**
Notice we're using separate namespaces: `chaos-app` for your target application and `litmus` for chaos infrastructure. This mirrors production practices where applications run in dedicated namespaces (dev, staging, prod) while chaos tooling runs in infrastructure namespaces. The cross-namespace RBAC you configured allows chaos experiments to safely target applications without granting excessive cluster-wide permissions.

---

## Phase 3: Basic Chaos Experiments (Workflow-Based)

Instead of running chaos experiments directly, we'll use Argo Workflows to orchestrate the complete chaos lifecycle. This approach mirrors production practices where chaos experiments are automated and repeatable.

### Step 1: Create the Pod-Delete Chaos Workflow

This workflow demonstrates the complete chaos experiment pattern: install the experiment definition, execute chaos against your application, and cleanup afterward.

```bash
cat > manifests/chaos/pod-delete-workflow.yaml <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: pod-delete-chaos-experiment
  namespace: litmus
  labels:
    subject: pod-delete-chaos
spec:
  entrypoint: chaos-experiment
  serviceAccountName: argo-chaos
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  arguments:
    parameters:
      - name: adminModeNamespace
        value: litmus
  templates:
    # Main experiment flow
    - name: chaos-experiment
      steps:
        - - name: install-chaos-experiments
            template: install-chaos-experiments
        - - name: run-pod-delete
            template: pod-delete-chaos
        - - name: cleanup
            template: revert-chaos

    # Step 1: Install the ChaosExperiment CRD
    - name: install-chaos-experiments
      inputs:
        artifacts:
          - name: pod-delete
            path: /tmp/pod-delete.yaml
            raw:
              data: |
                apiVersion: litmuschaos.io/v1alpha1
                kind: ChaosExperiment
                metadata:
                  name: pod-delete
                  namespace: {{workflow.parameters.adminModeNamespace}}
                  labels:
                    name: pod-delete
                    app.kubernetes.io/part-of: litmus
                    app.kubernetes.io/component: chaosexperiment
                    app.kubernetes.io/version: 3.0.0
                spec:
                  definition:
                    scope: Namespaced
                    permissions:
                      - apiGroups: [""]
                        resources: ["pods", "events"]
                        verbs: ["create", "list", "get", "patch", "update", "delete", "deletecollection"]
                      - apiGroups: [""]
                        resources: ["pods/log"]
                        verbs: ["get", "list", "watch"]
                      - apiGroups: ["batch"]
                        resources: ["jobs"]
                        verbs: ["create", "list", "get", "delete", "deletecollection"]
                      - apiGroups: ["litmuschaos.io"]
                        resources: ["chaosengines", "chaosexperiments", "chaosresults"]
                        verbs: ["create", "list", "get", "patch", "update", "delete"]
                    image: "litmuschaos/go-runner:latest"
                    imagePullPolicy: Always
                    args:
                      - -c
                      - ./experiments -name pod-delete
                    command:
                      - /bin/bash
                    env:
                      - name: TOTAL_CHAOS_DURATION
                        value: "30"
                      - name: RAMP_TIME
                        value: "0"
                      - name: FORCE
                        value: "true"
                      - name: CHAOS_INTERVAL
                        value: "10"
                      - name: PODS_AFFECTED_PERC
                        value: ""
                      - name: LIB
                        value: "litmus"
                      - name: TARGET_PODS
                        value: ""
                      - name: SEQUENCE
                        value: "parallel"
                    labels:
                      name: pod-delete
                      app.kubernetes.io/part-of: litmus
                      app.kubernetes.io/component: experiment-job
      container:
        image: bitnami/kubectl:latest
        command: [sh, -c]
        args: 
          - kubectl apply -f /tmp/pod-delete.yaml -n {{workflow.parameters.adminModeNamespace}}

    # Step 2: Run the actual chaos experiment via ChaosEngine
    - name: pod-delete-chaos
      inputs:
        artifacts:
          - name: chaosengine
            path: /tmp/chaosengine.yaml
            raw:
              data: |
                apiVersion: litmuschaos.io/v1alpha1
                kind: ChaosEngine
                metadata:
                  name: pod-delete-engine
                  namespace: {{workflow.parameters.adminModeNamespace}}
                spec:
                  appinfo:
                    appns: chaos-app
                    applabel: 'app=chaos-target-app'
                    appkind: deployment
                  engineState: active
                  chaosServiceAccount: argo-chaos
                  experiments:
                    - name: pod-delete
                      spec:
                        components:
                          env:
                            - name: TOTAL_CHAOS_DURATION
                              value: "30"
                            - name: CHAOS_INTERVAL
                              value: "10"
                            - name: FORCE
                              value: "false"
                            - name: PODS_AFFECTED_PERC
                              value: "50"
      container:
        image: bitnami/kubectl:latest
        command: [sh, -c]
        args:
          - |
            kubectl apply -f /tmp/chaosengine.yaml -n {{workflow.parameters.adminModeNamespace}}
            echo "Waiting for chaos to complete..."
            sleep 40
            kubectl get chaosresult -n {{workflow.parameters.adminModeNamespace}}

    # Step 3: Cleanup
    - name: revert-chaos
      container:
        image: bitnami/kubectl:latest
        command: [sh, -c]
        args:
          - |
            kubectl delete chaosengine pod-delete-engine -n {{workflow.parameters.adminModeNamespace}} --ignore-not-found=true
            kubectl delete chaosexperiment pod-delete -n {{workflow.parameters.adminModeNamespace}} --ignore-not-found=true
EOF
```

### Step 2: Execute and Observe

Open two terminals to see workflow-orchestrated chaos in action.

**Terminal 1 (Observation):**

```bash
# Watch your application pods
watch kubectl get pods -n chaos-app -l app=chaos-target-app
```

**Terminal 2 (Action):**

```bash
# Submit the workflow
kubectl create -f manifests/chaos/pod-delete-workflow.yaml

# Watch workflow progress
kubectl get workflows -n litmus -w

# In another terminal, view detailed workflow status
kubectl describe workflow pod-delete-chaos-experiment -n litmus

# View workflow logs
kubectl logs -n litmus -l workflows.argoproj.io/workflow=pod-delete-chaos-experiment --follow
```

**What to observe:**

1. The workflow creates a series of pods to execute each step
2. First, it installs the ChaosExperiment definition
3. Then it creates a ChaosEngine that spawns a chaos-runner pod
4. Every 10 seconds, one of your application pods is deleted
5. Kubernetes automatically recreates the deleted pods (Self-Healing)
6. After 30 seconds, chaos stops and cleanup occurs

### Step 3: Verify Results

```bash
# Check ChaosEngine status
kubectl get chaosengine -n litmus

# Check ChaosResult for detailed verdict
kubectl get chaosresult -n litmus
kubectl describe chaosresult pod-delete-engine-pod-delete -n litmus

# View events showing pod deletions
kubectl get events -n chaos-app --sort-by='.lastTimestamp' | grep -i "delete"
```

### 💡 SRE Analysis: Understanding Declarative Chaos

**The Technical Event:**
You didn't write a script to delete pods or manually execute commands. You created an Argo Workflow that declared your chaos intent: "Install this experiment, execute pod deletion for 30 seconds, then clean up." The workflow orchestrator handled all execution details.

**The Learning Outcome:**
This demonstrates **Declarative Chaos Engineering**. Traditional chaos engineering involved imperative scripts (bash loops deleting pods). Modern chaos engineering uses declarative workflows that specify what should happen, not how. This makes chaos experiments:
- Version controllable (commit workflows to Git)
- Reproducible (same YAML produces same results)
- Auditable (workflow history shows who ran what chaos)
- Schedulable (convert to CronWorkflow for automated testing)

**Real Production Value:**
In production environments, these workflows aren't triggered manually. They're either:
1. **Scheduled**: Run as CronWorkflows during maintenance windows
2. **CI/CD Integrated**: Executed automatically in staging before production deployments
3. **Game Day Exercises**: Used during quarterly chaos engineering drills

The workflow approach means your chaos practices scale from a single engineer's experiment to organization-wide resilience testing.

---

## Phase 4: Rollback Under Chaos

In this phase, you'll simulate a failed deployment and measure how long it takes to recover while chaos actively stresses your cluster—measuring true **Mean Time to Recovery (MTTR)** under degraded conditions.

### Step 1: Create the Automated MTTR Script

This Python script orchestrates the complete test scenario: deploy broken code, trigger chaos, execute rollback, and measure recovery time.

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
    """Execute shell command with timeout and return success status"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", "Command timed out"

def deploy_broken_version():
    """Deploy unstable application version that will fail"""
    print(">> Deploying unstable version...")
    success, _, stderr = run_command("kubectl apply -f manifests/unstable/")
    if not success:
        print(f"Failed to deploy unstable version: {stderr}")
        return False
    print(">> Waiting for bad deployment to stabilize...")
    time.sleep(10) 
    return True

def trigger_chaos_workflow():
    """Launch Argo Workflow to execute chaos experiment"""
    print(">> Triggering chaos workflow...")
    # Clean up any existing workflow
    run_command("kubectl delete workflow pod-delete-chaos-experiment -n litmus --ignore-not-found=true")
    time.sleep(2)
    
    success, _, stderr = run_command("kubectl create -f manifests/chaos/pod-delete-workflow.yaml")
    if not success:
        print(f"Failed to trigger chaos workflow: {stderr}")
        return False
    
    print(">> Chaos workflow started. Waiting for chaos to begin...")
    time.sleep(15)  # Give workflow time to start chaos injection
    return True

def execute_rollback():
    """Execute rollback and measure time to successful recovery"""
    print(">> Executing rollback command...")
    start_time = time.time()
    success, _, stderr = run_command("kubectl rollout undo deployment/chaos-target-app -n chaos-app")
    if not success:
        print(f"Rollback command failed: {stderr}")
        return None
    
    print(">> Waiting for rollout to succeed...")
    success, _, stderr = run_command("kubectl rollout status deployment/chaos-target-app -n chaos-app --timeout=300s")
    end_time = time.time()
    
    if success:
        return end_time - start_time
    return None

def cleanup_chaos():
    """Clean up all chaos artifacts"""
    print(">> Cleaning up chaos artifacts...")
    run_command("kubectl delete workflow pod-delete-chaos-experiment -n litmus --ignore-not-found=true")
    run_command("kubectl delete chaosengine pod-delete-engine -n litmus --ignore-not-found=true")
    run_command("kubectl delete chaosexperiment pod-delete -n litmus --ignore-not-found=true")
    time.sleep(5)

def save_result(test_type, duration):
    """Save test result to JSON file for analysis"""
    data = {}
    if os.path.exists(RESULTS_FILE):
        try:
            with open(RESULTS_FILE, 'r') as f:
                data = json.load(f)
        except:
            pass
    
    if test_type not in data:
        data[test_type] = []
    data[test_type].append(duration)
    
    with open(RESULTS_FILE, 'w') as f:
        json.dump(data, f, indent=4)
    print(f">> Result saved to {RESULTS_FILE}")

def measure_rollback_mttr(chaos_enabled=False):
    """Execute complete test scenario and measure MTTR"""
    label = "with-chaos" if chaos_enabled else "baseline"
    print(f"\nMEASURING MTTR: {label.upper()}")
    print("=" * 60)
    
    if not deploy_broken_version():
        return None

    if chaos_enabled:
        if not trigger_chaos_workflow():
            return None

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
    parser = argparse.ArgumentParser(description="Measure MTTR for rollback procedures")
    parser.add_argument("--chaos", action="store_true", help="Enable chaos during rollback")
    parser.add_argument("--baseline", action="store_true", help="Run baseline test without chaos")
    args = parser.parse_args()
    
    if not args.chaos and not args.baseline:
        print("ERROR: Specify either --baseline or --chaos")
        print("Usage:")
        print("  Baseline test:  python3 scripts/measure-rollback-mttr.py --baseline")
        print("  Chaos test:     python3 scripts/measure-rollback-mttr.py --chaos")
        sys.exit(1)

    chaos = args.chaos
    measure_rollback_mttr(chaos)
EOF

chmod +x scripts/measure-rollback-mttr.py
```

### 💡 SRE Analysis: Understanding Test Automation

**The Technical Event:**
You created a comprehensive test harness that automates the entire chaos experiment lifecycle. This script acts as a "chaos orchestrator" that controls both your application state (broken deploy) and your infrastructure state (chaos injection), then measures recovery performance.

**The Learning Outcome:**
This introduces **Scientific Chaos Engineering**. Chaos isn't about randomly breaking things—it's about controlled experiments with measurable outcomes. Your script isolates variables:
- **Independent Variable**: Presence or absence of chaos
- **Dependent Variable**: Time to recover (MTTR)
- **Controlled Variables**: Same rollback command, same cluster, same application

**Real Production Value:**
Production SREs use automation like this to validate disaster recovery procedures. Your "Emergency Rollback Runbook" might say "Execute kubectl rollout undo," but does that command work when:
- Pods are crashing unexpectedly?
- The API server is under load?
- Multiple deployments are failing simultaneously?

This script proves your runbook works under stress, not just in ideal conditions. That validation is what separates theoretical runbooks from battle-tested procedures.

---

## Phase 5: Automated Stress Testing

Now that we have automated testing tools, we'll generate statistically significant data by running multiple test iterations. This provides reliable metrics rather than anecdotal evidence.

### Step 1: Reset Environment

Ensure you're starting with a clean, healthy cluster.

```bash
# Apply stable version
kubectl apply -f manifests/stable/
kubectl rollout status deployment/chaos-target-app -n chaos-app

# Verify all pods are healthy
kubectl get pods -n chaos-app -l app=chaos-target-app

# Confirm no chaos artifacts exist
kubectl get chaosengine -n litmus
kubectl get workflows -n litmus
```

### Step 2: Run Baseline Tests (No Chaos)

Establish your baseline performance by measuring rollback time under ideal conditions.

```bash
# Run baseline test 3 times for statistical accuracy
python3 scripts/measure-rollback-mttr.py --baseline
sleep 30  # Allow cluster to stabilize

python3 scripts/measure-rollback-mttr.py --baseline
sleep 30

python3 scripts/measure-rollback-mttr.py --baseline
sleep 30
```

**What to observe in Terminal 2:**
- Deployment switches to unstable version (ImagePullBackOff)
- Rollback command executes
- Pods transition back to stable version
- All pods become Ready

The baseline establishes your "best case" recovery time.

### Step 3: Run Chaos Tests (With Active Pod Deletion)

Now measure rollback time while chaos actively deletes pods.

```bash
# Run chaos test 3 times
python3 scripts/measure-rollback-mttr.py --chaos
sleep 30

python3 scripts/measure-rollback-mttr.py --chaos
sleep 30

python3 scripts/measure-rollback-mttr.py --chaos
```

**What to observe in Terminal 2:**
- Deployment switches to unstable version
- Argo Workflow launches and begins deleting pods
- Pods are repeatedly terminated and recreated
- Rollback command executes during this chaos
- System fights to stabilize while under attack
- Eventually reaches stable state despite chaos

### Step 4: Verify Data Collection

```bash
# Check collected results
cat chaos_results.json

# Example output:
# {
#     "baseline": [38.2, 39.1, 37.8],
#     "with-chaos": [72.5, 68.9, 75.2]
# }
```

### 💡 SRE Analysis: Statistical Significance

**The Technical Event:**
You executed controlled experiments multiple times to generate a dataset. Running tests three times produces an average (mean) that's more reliable than a single measurement.

**The Learning Outcome:**
This demonstrates **Statistical Rigor** in chaos engineering. Distributed systems exhibit variance—network latency fluctuates, scheduling decisions vary, API server response times change. One slow test might be a fluke caused by background processes. Three slow tests indicate a systematic problem.

**Real Production Value:**
When presenting chaos engineering findings to leadership, data quality matters. You cannot justify infrastructure investments by saying "It felt slower during chaos." You justify investments with: "Our tests show that pod instability increases recovery time by 90% (72s vs 38s), which exceeds our 60-second SLA. We need improved health checks and faster pod startup times."

Data-driven recommendations get approved. Anecdotal complaints get ignored.

---

## Phase 6: Measuring Chaos Impact

In this final phase, you'll analyze the results from your controlled experiments and generate a professional report quantifying chaos impact on system resilience.

### Step 1: Create the Analysis Script

This script processes your test data and calculates key metrics.

```bash
cat > scripts/analyze-chaos-impact.py <<'EOF'
#!/usr/bin/env python3
import json
import os
import statistics

RESULTS_FILE = "chaos_results.json"

def analyze_mttr_results():
    """Analyze test results and generate impact report"""
    if not os.path.exists(RESULTS_FILE):
        print(f"ERROR: No results found in {RESULTS_FILE}")
        print("Run Phase 5 tests first to generate data.")
        return

    with open(RESULTS_FILE, 'r') as f:
        results = json.load(f)

    print("\nChaos Engineering Impact Analysis")
    print("=" * 60)
    print()

    if "baseline" not in results:
        print("ERROR: No baseline data found.")
        print("Run baseline tests with: python3 scripts/measure-rollback-mttr.py --baseline")
        return

    baseline_avg = statistics.mean(results["baseline"])
    baseline_stdev = statistics.stdev(results["baseline"]) if len(results["baseline"]) > 1 else 0

    print(f"Test Scenario          Avg MTTR    Std Dev    Impact")
    print("-" * 60)

    for scenario, times in sorted(results.items()):
        avg_time = statistics.mean(times)
        stdev = statistics.stdev(times) if len(times) > 1 else 0
        
        if scenario == "baseline":
            impact = 0.0
        else:
            impact = ((avg_time - baseline_avg) / baseline_avg) * 100
        
        print(f"{scenario:20} {avg_time:6.1f}s    ±{stdev:4.1f}s    {impact:+6.1f}%")

    print()
    print("Key Insights:")
    print(f"- Baseline rollback time: {baseline_avg:.1f}s (±{baseline_stdev:.1f}s)")
    
    if "with-chaos" in results:
        chaos_avg = statistics.mean(results["with-chaos"])
        impact_pct = ((chaos_avg - baseline_avg) / baseline_avg) * 100
        print(f"- Active pod deletion increases MTTR by {impact_pct:.1f}%")
        print(f"- Recovery takes an additional {chaos_avg - baseline_avg:.1f}s under chaos")
    
    print()
    print("SRE Recommendations:")
    print()
    print("1. Set SLA Targets Based on Chaos Conditions")
    print("   - Do NOT promise recovery times based on baseline tests")
    print("   - Account for real-world instability in SLA commitments")
    
    if "with-chaos" in results:
        chaos_avg = statistics.mean(results["with-chaos"])
        sla_target = chaos_avg * 1.2  # 20% buffer
        print(f"   - Recommend SLA: {sla_target:.0f}s (chaos MTTR + 20% buffer)")
    
    print()
    print("2. Improve System Resilience")
    print("   - Tune livenessProbe/readinessProbe for faster failure detection")
    print("   - Optimize container startup time to reduce MTTR")
    print("   - Consider pod disruption budgets to limit chaos impact")
    
    print()
    print("3. Automate Chaos Testing")
    print("   - Schedule these workflows weekly in staging environments")
    print("   - Block production deployments if chaos tests fail")
    print("   - Track MTTR trends over time to validate improvements")
    
    print()
    print("4. Document Findings")
    print("   - Add these metrics to your incident response runbooks")
    print("   - Use this data during post-incident reviews")
    print("   - Present findings to leadership for infrastructure investments")
    print()

if __name__ == "__main__":
    analyze_mttr_results()
EOF

chmod +x scripts/analyze-chaos-impact.py
```

### Step 2: Generate the Report

Execute the analysis to see your final metrics:

```bash
python3 scripts/analyze-chaos-impact.py
```

**Example Output:**

```
Chaos Engineering Impact Analysis
============================================================

Test Scenario          Avg MTTR    Std Dev    Impact
------------------------------------------------------------
baseline                 38.1s     ±1.2s      +0.0%
with-chaos               72.4s     ±3.1s     +90.0%

Key Insights:
- Baseline rollback time: 38.1s (±1.2s)
- Active pod deletion increases MTTR by 90.0%
- Recovery takes an additional 34.3s under chaos

SRE Recommendations:

1. Set SLA Targets Based on Chaos Conditions
   - Do NOT promise recovery times based on baseline tests
   - Account for real-world instability in SLA commitments
   - Recommend SLA: 87s (chaos MTTR + 20% buffer)

2. Improve System Resilience
   - Tune livenessProbe/readinessProbe for faster failure detection
   - Optimize container startup time to reduce MTTR
   - Consider pod disruption budgets to limit chaos impact

3. Automate Chaos Testing
   - Schedule these workflows weekly in staging environments
   - Block production deployments if chaos tests fail
   - Track MTTR trends over time to validate improvements

4. Document Findings
   - Add these metrics to your incident response runbooks
   - Use this data during post-incident reviews
   - Present findings to leadership for infrastructure investments
```

### 💡 SRE Analysis: From Data to Action

**The Technical Event:**
You transformed raw timing data into actionable intelligence. The script calculated not just averages, but also standard deviation (variance) and percentage impact—metrics that communicate the magnitude of chaos effects.

**The Learning Outcome:**
This teaches **Quantitative Risk Assessment**. Resilience isn't binary—it's measured on a spectrum. By quantifying the "chaos tax" (how much longer recovery takes under stress), you understand the cost of specific failure modes. This data answers critical questions:
- How much buffer should we include in our SLAs?
- Are our health checks tuned correctly?
- Should we invest in faster pod startup times?

**Real Production Value:**
This analysis directly informs business decisions. Consider these scenarios:

**Scenario A: Overpromising Recovery Time**
Your contract promises customers "Recovery within 60 seconds for any bad deployment." Your baseline test (38s) suggests this is safe. But your chaos test (72s) proves you'll violate that SLA during real incidents. This analysis prevents costly contract violations.

**Scenario B: Justifying Infrastructure Investment**
You want to implement PodDisruptionBudgets to limit chaos impact, but leadership questions the value. You present this data: "Pod instability increases our recovery time by 90%. PodDisruptionBudgets will reduce that to 30%, keeping us within our SLA commitments." Data-backed proposals get approved.

**Scenario C: Continuous Improvement**
After implementing improvements (better health checks, faster startup), you re-run these tests and prove recovery time decreased from 72s to 55s. You've quantified the value of your engineering work.

---

## Cleanup

Once you've completed the experiment and collected your data, clean up all resources.

```bash
# Remove application deployments
kubectl delete -f manifests/stable/ --ignore-not-found
kubectl delete -f manifests/unstable/ --ignore-not-found

# Remove chaos artifacts
kubectl delete -f manifests/chaos/ --ignore-not-found
kubectl delete workflow --all -n litmus
kubectl delete chaosengine --all -n litmus
kubectl delete chaosexperiment --all -n litmus

# Remove application namespace
kubectl delete namespace chaos-app

# Optional: Remove entire chaos engineering stack
kubectl delete namespace litmus
kubectl delete namespace argo

echo "Cleanup completed successfully"
```

---

## Commit Your Work

Document your complete chaos engineering implementation in Git.

```bash
# Stage all files
git add .

# Commit with descriptive message
git commit -m "Complete chaos engineering lab with LitmusChaos 3.x and Argo Workflows

- Implemented workflow-based chaos experiments
- Measured MTTR under baseline and chaos conditions
- Generated quantitative resilience metrics
- Documented findings and SRE recommendations"

# Push to remote
git push origin main
```

---

## Final Thoughts

You've just completed a comprehensive **Chaos Engineering exercise** using production-grade tools and methodologies. More importantly, you approached chaos engineering with the scientific rigor that distinguishes professional SRE practice from random destruction.

**What You Accomplished:**

You built a realistic application with multiple deployment states (stable and unstable). You installed a complete chaos engineering platform using modern cloud-native tools (Argo Workflows and LitmusChaos 3.x). You created declarative, version-controlled chaos experiments as workflow orchestrations. You measured Mean Time to Recovery (MTTR) under both ideal and degraded conditions. You validated your rollback procedures under active stress, proving they work when production is already failing. You generated quantitative metrics that transform chaos engineering from an art into a science.

**The SRE Mindset You Developed:**

Throughout this exercise, you learned to think like a production SRE. You didn't just break things randomly—you designed controlled experiments with measurable outcomes. You didn't rely on anecdotes—you collected statistical data across multiple test runs. You didn't assume your procedures work—you proved they work under stress. You didn't keep findings to yourself—you generated reports suitable for leadership presentations.

**From Lab to Production:**

This exercise provides a foundation for real-world chaos engineering practices. In production environments, you would:

**Schedule Regular Chaos**: Convert your workflows to CronWorkflows that run automatically during maintenance windows, continuously validating system resilience.

**Integrate with CI/CD**: Block production deployments unless chaos tests pass in staging, preventing the deployment of code that fails under stress.

**Expand Experiment Coverage**: Add network latency experiments, CPU stress tests, and node failure simulations to validate resilience across multiple failure modes.

**Track Trends Over Time**: Maintain historical MTTR data to measure whether system improvements actually improve resilience or just add complexity.

**Game Day Exercises**: Use these workflows during quarterly chaos engineering drills where entire teams practice incident response under controlled failure conditions.

**The Bottom Line:**

Chaos engineering isn't about breaking production—it's about building confidence that your systems can survive when production breaks itself. By systematically injecting controlled failures and measuring recovery performance, you discover weaknesses before they cause customer-impacting outages.

You've moved beyond hoping your systems are resilient to proving they are. That's the difference between good intentions and reliable systems.

---

## Final Note: You've Completed the SRE Academy

This was the final exercise of the SRE Academy—and arguably the most demanding one. You didn't just build deployment pipelines or configure monitoring dashboards. You **put your entire stack under controlled stress**, validated how it behaves under failure, and measured how fast it recovers. That's what Site Reliability Engineering is fundamentally about: designing for failure, observing failure in controlled conditions, and continuously improving resilience.

Throughout this journey, you've learned to:

- Build and containerize applications with Docker
- Deploy and orchestrate them in Kubernetes
- Monitor system health with Prometheus and Grafana
- Automate deployments through CI/CD pipelines
- Implement GitOps workflows for declarative infrastructure
- Create incident response runbooks and rollback procedures
- Apply Chaos Engineering to validate system resilience under realistic failure conditions

Each exercise built systematically on the last. What started as basic `kubectl` commands evolved into production-grade workflows. What began as manual deployments matured into automated, tested, and validated procedures. What was once hope that "it should work" became proof that "it does work, even under stress."

**You've reached the point where your systems aren't just functional—they're battle-tested.**

The skills you've developed here—automation, observability, resilience testing, and systematic problem-solving—are the foundation of production SRE work. You're now equipped to build systems that don't just work in demos but survive real-world chaos.

**Congratulations. You've completed the full SRE Academy.**

> Your deployments are resilient. Your monitoring is comprehensive. Your procedures are validated.
> You're ready for production.