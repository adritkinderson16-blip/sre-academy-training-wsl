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

**What we're building:** A three-replica nginx deployment that will serve as our "production application." We need something to break during chaos experiments.

**Why two versions?** We're creating both a stable version (works correctly) and an unstable version (intentionally broken) so we can practice rollback procedures under stress.

### Step 1: Create Application Namespace

**What this does:** Creates an isolated namespace called `chaos-app` where our application will live. This separation mirrors production practices where applications run in dedicated namespaces rather than the default namespace.

```bash
# Create dedicated namespace for the target application
kubectl create namespace chaos-app

# Verify namespace creation
kubectl get namespace chaos-app
```

**Expected output:**
```
namespace/chaos-app created
NAME        STATUS   AGE
chaos-app   Active   1s
```

**What just happened:** Kubernetes created a new namespace. Think of it as a separate "room" in your cluster where resources are isolated from other namespaces.

---

### Step 2: Create Stable Application Manifests

**What this does:** Creates three YAML files that define your application: deployment (the pods), service (networking), and configmap (web content). These files don't deploy anything yet—they're just text files on your computer.

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

**What you just created:**
- `deployment.yaml` - Defines 3 nginx pods with health checks and resource limits
- `service.yaml` - Creates a network endpoint to access the pods
- `configmap.yaml` - Contains the HTML content the nginx pods will serve

**Key details to notice:**
- `replicas: 3` means we'll have 3 copies of the application running
- `namespace: chaos-app` places everything in our dedicated namespace
- `livenessProbe` and `readinessProbe` help Kubernetes detect if pods are healthy
- The label `app: chaos-target-app` is how chaos experiments will find these pods

---

### Step 3: Create Unstable Application (For Rollback Testing)

**What this does:** Creates manifests for a broken version of your application. The image tag `nonexistent-tag` doesn't exist, so pods will fail with `ImagePullBackOff`. This simulates a bad production deployment.

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
  strategy:
    type: Recreate  # ← Changed from RollingUpdate to force all pods down
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

**Why create a broken version?** In Phase 4, we'll deploy this broken version and measure how long it takes to roll back to the stable version—both with and without chaos attacking the cluster.

---

### Step 4: Deploy and Verify Stable Application

**What this does:** Actually deploys your application to Kubernetes. Until now, you've just been creating files. This command sends those files to the Kubernetes API server.

**Important:** Open TWO terminal windows for this section. Keep both visible.

**Terminal 1 - Observation:**
```bash
# Watch pods being created in real-time
watch kubectl get pods -n chaos-app
```

**Terminal 2 - Action:**
```bash
# Deploy stable version
kubectl apply -f manifests/stable/

# Wait for deployment to complete
kubectl rollout status deployment/chaos-target-app -n chaos-app
```

**What you'll see in Terminal 1:**
```
NAME                               READY   STATUS              RESTARTS   AGE
chaos-target-app-7d9f8c5b4-abc12   0/1     ContainerCreating   0          2s
chaos-target-app-7d9f8c5b4-def34   0/1     ContainerCreating   0          2s
chaos-target-app-7d9f8c5b4-ghi56   0/1     ContainerCreating   0          2s
```

Then after ~10 seconds:
```
NAME                               READY   STATUS    RESTARTS   AGE
chaos-target-app-7d9f8c5b4-abc12   1/1     Running   0          15s
chaos-target-app-7d9f8c5b4-def34   1/1     Running   0          15s
chaos-target-app-7d9f8c5b4-ghi56   1/1     Running   0          15s
```

**What you'll see in Terminal 2:**
```
configmap/app-content created
deployment.apps/chaos-target-app created
service/chaos-target-service created
deployment "chaos-target-app" successfully rolled out
```

**What just happened:**
1. Kubernetes created the ConfigMap with your HTML content
2. Kubernetes created the Deployment, which created a ReplicaSet, which created 3 Pods
3. Each pod pulled the nginx:1.21-alpine image from Docker Hub
4. Kubernetes started the containers and ran health checks
5. Once healthy, the pods were marked as "Ready"
6. Kubernetes created a Service to route traffic to the pods

**Verify everything is working:**
```bash
# See all resources in chaos-app namespace
kubectl get all -n chaos-app

# Test the application
kubectl get svc chaos-target-service -n chaos-app
minikube service chaos-target-service -n chaos-app --url
```

Visit the URL in your browser. You should see: "Status: STABLE"

**Press Ctrl+C in Terminal 1 to stop watching pods.**

---

## Phase 2: Install Argo Workflows and LitmusChaos

**What we're installing:** Two systems that work together:
1. **Argo Workflows** - Orchestrates multi-step chaos experiments (like a conductor leading an orchestra)
2. **LitmusChaos** - Actually executes the chaos (the musicians playing the instruments)

**Why both?** Modern chaos engineering doesn't just "break stuff randomly." It follows a workflow: install experiment → execute chaos → collect results → cleanup. Argo manages this workflow; Litmus executes the chaos.

### Step 1: Install Argo Workflows

**What this does:** Installs Argo Workflows, which will orchestrate our chaos experiments. This is similar to installing a CI/CD system like Jenkins or GitHub Actions.

**Terminal 1 - Observation:**
```bash
# Watch Argo pods being created
watch kubectl get pods -n argo
```

**Terminal 2 - Action:**
```bash
# Create namespace for Argo
kubectl create namespace argo

# Install Argo Workflows
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.5.11/install.yaml

# Wait for Argo to be ready (this may take 1-2 minutes)
echo "Waiting for Argo Workflows to be ready..."
kubectl wait --for=condition=Ready pods --all -n argo --timeout=300s
```

**What you'll see in Terminal 1:**

Initially:
```
NAME                                   READY   STATUS              RESTARTS   AGE
argo-server-667f6fdf45-xxxxx           0/1     ContainerCreating   0          5s
workflow-controller-5d5c84f6c8-xxxxx   0/1     ContainerCreating   0          5s
```

After 30-60 seconds:
```
NAME                                   READY   STATUS    RESTARTS   AGE
argo-server-667f6fdf45-xxxxx           1/1     Running   0          45s
workflow-controller-5d5c84f6c8-xxxxx   1/1     Running   0          45s
```

**What you'll see in Terminal 2:**
```
namespace/argo created
customresourcedefinition.apiextensions.k8s.io/clusterworkflowtemplates.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/cronworkflows.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/workfloweventbindings.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/workflows.argoproj.io created
...
pod/argo-server-667f6fdf45-xxxxx condition met
pod/workflow-controller-5d5c84f6c8-xxxxx condition met
```

**What just happened:**
1. Created `argo` namespace
2. Installed Custom Resource Definitions (CRDs) for Workflow, CronWorkflow, etc.
3. Deployed two pods: `argo-server` (web UI) and `workflow-controller` (executes workflows)
4. Argo is now watching for Workflow resources in your cluster

**Press Ctrl+C in Terminal 1 to stop watching.**

---

### Step 2: Install LitmusChaos Operator

**What this does:** Installs the LitmusChaos operator, which watches for ChaosEngine resources and executes chaos experiments.

**Terminal 1 - Observation:**
```bash
# Watch Litmus pods being created
watch kubectl get pods -n litmus
```

**Terminal 2 - Action:**
```bash
# Create dedicated namespace
kubectl create namespace litmus

# Install LitmusChaos operator
kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v3.0.0.yaml -n litmus

# Wait for installation to complete
echo "Waiting for LitmusChaos operator to be ready..."
kubectl wait --for=condition=Ready pods --all -n litmus --timeout=300s
```

**What you'll see in Terminal 1:**
```
NAME                                 READY   STATUS    RESTARTS   AGE
chaos-operator-ce-75767d49b7-xxxxx   1/1     Running   0          30s
```

**What you'll see in Terminal 2:**
```
namespace/litmus created
customresourcedefinition.apiextensions.k8s.io/chaosengines.litmuschaos.io created
customresourcedefinition.apiextensions.k8s.io/chaosexperiments.litmuschaos.io created
customresourcedefinition.apiextensions.k8s.io/chaosresults.litmuschaos.io created
...
pod/chaos-operator-ce-75767d49b7-xxxxx condition met
```

**What just happened:**
1. Created `litmus` namespace
2. Installed CRDs for ChaosEngine, ChaosExperiment, and ChaosResult
3. Deployed the chaos operator pod
4. The operator is now watching for ChaosEngine resources

**Press Ctrl+C in Terminal 1.**

---

### Step 3: Setup Chaos Permissions (RBAC)

**What this does:** Gives Argo Workflows permission to create chaos experiments in the litmus namespace, and gives chaos experiments permission to delete pods in the chaos-app namespace. Without these permissions, chaos experiments would fail with "Forbidden" errors.

**Think of it like:** Creating access badges for employees. Argo gets a badge to enter the "litmus" building, and chaos experiments get badges to enter the "chaos-app" building.

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
    resources: ["deployments", "statefulsets", "daemonsets", "replicasets"]
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

# Apply the RBAC
kubectl apply -f manifests/chaos/argo-chaos-rbac.yaml
```

**Expected output:**
```
serviceaccount/argo-chaos created
role.rbac.authorization.k8s.io/argo-chaos-role created
rolebinding.rbac.authorization.k8s.io/argo-chaos-rolebinding created
role.rbac.authorization.k8s.io/argo-chaos-target-role created
rolebinding.rbac.authorization.k8s.io/argo-chaos-target-rolebinding created
```

**What you just created:**
- **ServiceAccount**: An identity for Argo workflows to use
- **Role in litmus namespace**: Permissions to create chaos experiments
- **Role in chaos-app namespace**: Permissions to delete your application pods
- **RoleBindings**: Connects the service account to the roles

**Why cross-namespace permissions?** Chaos infrastructure (litmus) needs to affect your application (chaos-app). This is like giving a security tester permission to test your application even though they're in a different department.

---

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
Notice we're using separate namespaces: `chaos-app` for your target application, `litmus` for chaos infrastructure, and `argo` for workflow orchestration. This mirrors production practices where applications run in dedicated namespaces (dev, staging, prod) while infrastructure tools run separately. The cross-namespace RBAC you configured allows chaos experiments to safely target applications without granting excessive cluster-wide permissions.

---

## Phase 3: Basic Chaos Experiments (Workflow-Based)

**What we're doing:** Creating an Argo Workflow that orchestrates a pod-delete chaos experiment. Instead of manually running commands, we'll define the entire chaos experiment as a workflow that Argo executes automatically.

**Why workflows?** This is how chaos engineering works in production. Experiments are defined as code, version-controlled in Git, and executed automatically by CI/CD systems or scheduled to run during maintenance windows.

### Step 1: Create the Pod-Delete Chaos Workflow

**What this creates:** A Workflow resource that defines a 3-step process: install the experiment definition, execute chaos, and cleanup. This is NOT running chaos yet—we're just creating the "recipe."

**Think of it like:** Writing a recipe in a cookbook. The recipe exists, but no food is being cooked yet.

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
            echo "ChaosEngine created. Waiting for chaos runner to start..."
            sleep 5
            
            echo "Monitoring ChaosResult status..."
            # Wait up to 90 seconds for chaos to complete
            for i in $(seq 1 90); do
              PHASE=$(kubectl get chaosresult pod-delete-engine-pod-delete -n {{workflow.parameters.adminModeNamespace}} -o jsonpath='{.status.experimentStatus.phase}' 2>/dev/null || echo "NotFound")
              VERDICT=$(kubectl get chaosresult pod-delete-engine-pod-delete -n {{workflow.parameters.adminModeNamespace}} -o jsonpath='{.status.experimentStatus.verdict}' 2>/dev/null || echo "Unknown")
              
              echo "[$i/90] Phase: $PHASE | Verdict: $VERDICT"
              
              # Exit when chaos reaches a final state
              if [ "$PHASE" = "Completed" ]; then
                echo "✅ Chaos experiment completed successfully!"
                break
              elif [ "$PHASE" = "Stopped" ] || [ "$PHASE" = "Error" ]; then
                echo "⚠️  Chaos experiment ended with phase: $PHASE"
                break
              fi
              
              sleep 1
            done
            
            echo ""
            echo "=== Final ChaosResult ==="
            kubectl get chaosresult -n {{workflow.parameters.adminModeNamespace}}
            echo ""
            kubectl describe chaosresult pod-delete-engine-pod-delete -n {{workflow.parameters.adminModeNamespace}} | grep -A 10 "Status:"

    # Step 3: Cleanup
    - name: revert-chaos
      container:
        image: bitnami/kubectl:latest
        command: [sh, -c]
        args:
          - |
            echo "Cleaning up chaos resources..."
            kubectl delete chaosengine pod-delete-engine -n {{workflow.parameters.adminModeNamespace}} --ignore-not-found=true
            kubectl delete chaosexperiment pod-delete -n {{workflow.parameters.adminModeNamespace}} --ignore-not-found=true
            echo "Cleanup completed"
EOF
```

**What you just created:** A workflow with 3 templates (steps):

1. **install-chaos-experiments**: Creates a ChaosExperiment definition (the template for how to delete pods)
2. **pod-delete-chaos**: Creates a ChaosEngine (triggers the actual chaos)
3. **revert-chaos**: Cleans up by deleting the ChaosEngine and ChaosExperiment

**Key parameters to notice:**
- `TOTAL_CHAOS_DURATION: "30"` - Run chaos for 30 seconds
- `CHAOS_INTERVAL: "10"` - Delete pods every 10 seconds
- `PODS_AFFECTED_PERC: "50"` - Delete 50% of pods each time
- `appns: chaos-app` - Target the chaos-app namespace
- `applabel: 'app=chaos-target-app'` - Find pods with this label

---

### Step 2: Execute and Observe

**What we're doing:** Running the workflow to see chaos in action while simultaneously proving that the application remains available to users. This is when pods start getting deleted, but the service stays up.

**Important:** You need **FIVE terminal windows** open for this section, plus a web browser. Arrange them so you can see everything at once.

---

**Terminal 1 - Get Service URL:**
```bash
# Get the URL for your application
minikube service chaos-target-service -n chaos-app --url
```

**Expected output:**
```
http://127.0.0.1:55741
```

**Copy this URL** - you'll need it for Terminal 2 and your browser.

---

**Terminal 2 - Continuous Availability Monitoring (User Simulation):**

This simulates a user constantly accessing your application. It will prove the service stays up during chaos.
```bash
# Replace with YOUR actual URL from Terminal 1
URL="http://127.0.0.1:55741"

# Hit the service every 0.5 seconds and show timestamp + HTTP status
while true; do
  TIMESTAMP=$(date '+%H:%M:%S')
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$URL" --max-time 2)
  if [ "$RESPONSE" = "200" ]; then
    echo "[$TIMESTAMP] ✅ Service UP - HTTP $RESPONSE"
  else
    echo "[$TIMESTAMP] ❌ Service DOWN - HTTP $RESPONSE"
  fi
  sleep 0.5
done
```

**What you'll see:** A continuous stream of timestamps showing the service is responding:
```
[10:35:53] ✅ Service UP - HTTP 200
[10:35:54] ✅ Service UP - HTTP 200
[10:35:55] ✅ Service UP - HTTP 200
```

This will keep running throughout the chaos experiment. **Watch for any ❌ symbols** - those indicate brief moments when the service was unavailable.

---

**Terminal 3 - Application Pods (chaos-app namespace):**
```bash
# Watch your application pods (these will be deleted by chaos)
watch -n 0.5 kubectl get pods -n chaos-app -l app=chaos-target-app
```

**What you'll see:** Your three application pods running normally, then every 10 seconds some will be deleted and recreated.

---

**Terminal 4 - Chaos Infrastructure (litmus namespace):**
```bash
# Watch chaos-related pods (these execute the chaos)
watch -n 0.5 kubectl get pods -n litmus
```

**What you'll see:** Workflow pods being created to execute each step, and a chaos-runner pod that actually deletes your application pods.

---

**Terminal 5 - Execute the Workflow:**
```bash
# Submit the workflow to Argo
kubectl create -f manifests/chaos/pod-delete-workflow.yaml

# Watch workflow progress
kubectl get workflows -n litmus -w
```

**What you'll see:**
```
NAME                          STATUS    AGE   MESSAGE
pod-delete-chaos-experiment   Pending   1s    
pod-delete-chaos-experiment   Running   5s    
pod-delete-chaos-experiment   Running   50s   
pod-delete-chaos-experiment   Succeeded 60s
```

---

**Web Browser - Visual Confirmation:**

1. **Open the URL** from Terminal 1 in your web browser: `http://127.0.0.1:xxxxx`
2. **Keep the browser window visible** alongside your terminals
3. **Manually refresh** the page every few seconds during chaos (or use a browser auto-refresh extension)

**What you'll see:** The webpage continues to load successfully, displaying "Status: STABLE" throughout the chaos experiment. This is visual proof that end users experience zero downtime.

---

### What Happens (Step by Step)

**T=0s - You run kubectl create:**
- Workflow resource is created in Kubernetes
- Argo Workflow Controller sees the new workflow
- **Terminal 2 continues showing ✅ Service UP**

**T=1s - Step 1 begins:**
- Argo creates a pod named `pod-delete-chaos-experiment-install-xyz`
- **In Terminal 4**, you'll see this pod appear
- This pod runs `kubectl apply -f /tmp/pod-delete.yaml`
- A ChaosExperiment resource is created
- **Terminal 2 still shows ✅ Service UP**

**T=5s - Step 1 completes, Step 2 begins:**
- Argo creates a pod named `pod-delete-chaos-experiment-run-xyz`
- **In Terminal 4**, you'll see this pod appear
- This pod runs `kubectl apply -f /tmp/chaosengine.yaml`
- A ChaosEngine resource is created

**T=10s - LitmusChaos Operator springs into action:**
- The operator sees the new ChaosEngine
- It creates a chaos-runner pod: `pod-delete-engine-runner-xyz`
- **In Terminal 4**, you'll see the runner pod appear
- **In Terminal 3**, you'll see your application pods start getting deleted!
- **In Terminal 2**, you'll notice it **still shows ✅ Service UP** - this is the critical observation!

**T=10s-40s - Active chaos period:**
Every 10 seconds, the chaos-runner:
- Finds all pods with label `app=chaos-target-app` in namespace `chaos-app`
- Deletes 50% of them (about 1-2 pods)
- **In Terminal 3**, you'll see:
  - Pods transition from Running → Terminating → (disappear)
  - New pods appear with status ContainerCreating → Running
  - This happens multiple times (every 10 seconds for 30 seconds = 3 times)
- **In Terminal 2**, you'll see mostly ✅ (maybe 1-2 brief ❌ during transitions)
- **In your browser**, the page keeps loading successfully

**T=50s - Step 2 completes, Step 3 begins:**
- Argo creates a cleanup pod
- This pod deletes the ChaosEngine and ChaosExperiment
- **In Terminal 4**, you'll see the runner pod disappear
- **Terminal 2 never stopped showing ✅**

**T=60s - Workflow completes:**
- **Terminal 5** shows workflow status: Succeeded
- **Terminal 3** shows your application pods all running normally again
- **Terminal 4** shows only the chaos-operator-ce pod remaining
- **Terminal 2 shows uninterrupted ✅ Service UP** throughout the entire experiment

---

### The Critical Observation

**Look at Terminal 2 during the entire experiment.** Even while chaos was forcefully deleting pods in Terminal 3, Terminal 2 should show continuous availability:
```
[10:35:53] ✅ Service UP - HTTP 200
[10:35:54] ✅ Service UP - HTTP 200
[10:35:55] ✅ Service UP - HTTP 200  ← Chaos starts deleting pods
[10:35:56] ✅ Service UP - HTTP 200  ← Pods being terminated
[10:35:57] ✅ Service UP - HTTP 200  ← New pods being created
[10:35:58] ✅ Service UP - HTTP 200  ← More deletions happening
[10:36:00] ✅ Service UP - HTTP 200  ← Chaos still active
[10:36:03] ✅ Service UP - HTTP 200  ← Chaos completes
```

**This proves:** Individual pods can fail catastrophically, yet the service remains available to users. This is the fundamental principle of chaos engineering and cloud-native resilience.

---

### Verify Results

**Press Ctrl+C in Terminals 2, 3, 4, and 5 to stop watching.**

Now let's examine what happened:
```bash
# Check if ChaosEngine still exists (it should be deleted)
kubectl get chaosengine -n litmus
```

**Expected output:**
```
No resources found in litmus namespace.
```

**What this means:** The cleanup step successfully deleted the ChaosEngine.

---
```bash
# Check ChaosResult (this persists for audit trail)
kubectl get chaosresult -n litmus
```

**Expected output:**
```
NAME                            AGE
pod-delete-engine-pod-delete    2m
```

**What this means:** A ChaosResult was created to record what happened during the experiment.

---
```bash
# View detailed results
kubectl describe chaosresult pod-delete-engine-pod-delete -n litmus
```

**Look for:**
- `Verdict: Pass` or `Verdict: Fail` (did the experiment complete successfully?)
- `Probe Success Percentage` (how many pods were actually deleted?)
- `Total Chaos Duration` (how long chaos ran)

---
```bash
# View events showing pod deletions
kubectl get events -n chaos-app --sort-by='.lastTimestamp' | grep -i "delete"
```

**Expected output:** You'll see multiple events like:
```
Normal  Killing  pod/chaos-target-app-xxx  Stopping container app
```

**What this means:** Kubernetes recorded each time a pod was deleted.

---

### 💡 SRE Analysis: Understanding Declarative Chaos

**The Technical Event:**
You didn't write a bash script to delete pods or manually execute commands. You created an Argo Workflow that declared your chaos intent: "Install this experiment, execute pod deletion for 30 seconds, then clean up." The workflow orchestrator handled all execution details.

**What Really Happened Under the Hood:**

1. **You created a Workflow CRD** - Just YAML stored in Kubernetes, not running yet
2. **Argo Workflow Controller saw it** - Started executing the workflow
3. **Step 1 pod created** - Installed the ChaosExperiment definition (the template)
4. **Step 2 pod created** - Created the ChaosEngine (the trigger)
5. **LitmusChaos Operator reacted** - Saw ChaosEngine, created runner pod
6. **Runner pod executed chaos** - Actually deleted your application pods
7. **Kubernetes self-healed** - Automatically recreated deleted pods
8. **Step 3 pod created** - Cleaned up ChaosEngine and ChaosExperiment
9. **Workflow marked complete** - All temporary pods deleted, only audit trail remains

**The Learning Outcome:**
This demonstrates **Declarative Chaos Engineering**. Traditional chaos engineering involved imperative scripts (bash loops deleting pods). Modern chaos engineering uses declarative workflows that specify what should happen, not how. This makes chaos experiments:
- **Version controllable**: Commit workflows to Git, track changes
- **Reproducible**: Same YAML produces same results every time
- **Auditable**: Workflow history shows who ran what chaos and when
- **Schedulable**: Convert to CronWorkflow for automated testing
- **Composable**: Chain multiple experiments (pod-delete → network-latency → cpu-stress)

**Real Production Value:**
In production environments, these workflows aren't triggered manually. They're either:
1. **Scheduled**: Run as CronWorkflows during maintenance windows (every Tuesday at 2 AM)
2. **CI/CD Integrated**: Executed automatically in staging before production deployments
3. **Game Day Exercises**: Used during quarterly chaos engineering drills

The workflow approach means your chaos practices scale from a single engineer's experiment to organization-wide resilience testing.

**Why Argo Workflows Instead of Alternatives:**
- **Bash scripts**: Hard to maintain, no observability, not schedulable
- **Direct ChaosEngine**: No multi-step orchestration, manual cleanup
- **CI/CD tools**: Not Kubernetes-native, less flexible for complex workflows
- **LitmusChaos Portal**: Heavy installation, overkill for learning

Argo Workflows is the production standard for orchestrating Kubernetes-based workflows, not just for chaos engineering but also for ML pipelines, data processing, and complex deployments.

**Zero-Downtime Validation:**
The continuous availability monitoring (Terminal 2) proved that even while chaos forcefully deleted 67% of your pods over 30 seconds, your application remained accessible to users. This validates that your deployment configuration (replicas: 3, health probes, resource limits) is production-ready and can survive infrastructure failures without service interruption.

---

# Phase 4: Rollback Under Chaos

**What we're doing:** Measuring how long it takes to recover from a bad deployment when the cluster is under stress. This simulates a real production incident where you need to rollback during an outage.

**Why this matters:** Your rollback procedures might work perfectly in a quiet test environment, but will they work when production is on fire? This phase finds out.

**Time required:** Each test takes approximately 1 minute (baseline) or 2 minutes (with chaos). The complete test suite in Phase 5 takes about 11 minutes.

---

## Step 1: Create the Automated MTTR Script

**What this creates:** A Python script that automates the entire test scenario:
1. Deploy a broken version of your application
2. (Optionally) Trigger chaos to stress the cluster
3. Execute rollback command and measure time to completion
4. Save results to a JSON file for analysis

**Think of it like:** An automated lab assistant that runs experiments for you and records the results.

```bash
# Create scripts directory if it doesn't exist
mkdir -p scripts

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
    
    print(">> Waiting for chaos workflow to initialize...")
    time.sleep(10)
    
    # Wait for chaos runner pod to appear and become active
    print(">> Waiting for chaos runner to start actively deleting pods...")
    for i in range(30):
        # Check if chaos runner pod exists and is running
        success, stdout, _ = run_command("kubectl get pods -n litmus -l job-name --no-headers 2>/dev/null | grep -i running")
        if success and "Running" in stdout:
            print(f">> Chaos runner detected! Waiting 5 more seconds for active deletion to begin...")
            time.sleep(5)
            return True
        time.sleep(1)
    
    print(">> Warning: Chaos runner not detected, proceeding anyway...")
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

**What you just created:** A test automation script with five key functions:
- `deploy_broken_version()` - Applies the unstable manifests
- `trigger_chaos_workflow()` - Starts the Argo Workflow
- `execute_rollback()` - Runs rollback and times it
- `cleanup_chaos()` - Removes all chaos artifacts
- `save_result()` - Stores timing data to JSON

---

## Step 2: Understanding What You'll Monitor

**Important:** Open THREE terminal windows for this test. Each terminal shows a different aspect of the rollback under stress.

**Terminal 1** shows you the application's struggle to recover (pods failing, being deleted, recovering).

**Terminal 2** runs the automated test and shows you the final MTTR measurement.

**Terminal 3** shows you live events explaining WHY things are happening (image pull failures, pod deletions, container starts).

---

## Step 3: Run a Baseline Test (No Chaos)

This establishes your "best case" recovery time under ideal conditions.

**Terminal 1 - Application Pod States:**
```bash
# Start watching BEFORE running the script
watch -n 0.5 kubectl get pods -n chaos-app -l app=chaos-target-app
```

**Initial state (before running script):**
```
NAME                                READY   STATUS    RESTARTS   AGE
chaos-target-app-xxx-stable1        1/1     Running   0          5m
chaos-target-app-xxx-stable2        1/1     Running   0          5m
chaos-target-app-xxx-stable3        1/1     Running   0          5m
```

---

**Terminal 2 - Execute Test:**
```bash
# Now run the baseline test
python3 scripts/measure-rollback-mttr.py --baseline
```

**What you'll see:**
```
MEASURING MTTR: BASELINE
============================================================
>> Deploying unstable version...
>> Waiting for bad deployment to stabilize...
>> Executing rollback command...
deployment.apps/chaos-target-app rolled back
>> Waiting for rollout to succeed...
deployment "chaos-target-app" successfully rolled out
>> Cleaning up chaos artifacts...
>> SUCCESS: Rollback took 8.29 seconds
>> Result saved to chaos_results.json
```

**What this tells you:** The 8.29 seconds is ONLY the rollback time (from executing `kubectl rollout undo` to all pods healthy). This is your baseline recovery time.

---

**Terminal 3 - Live Events Log:**
```bash
# Watch events as they happen
kubectl get events -n chaos-app --watch
```

**What you'll see happen in real-time:**

**Step 1: Script deploys broken version**
```
0s    Normal   ScalingReplicaSet   deployment/chaos-target-app   Scaled down replica set ...f567f from 3 to 0
0s    Normal   SuccessfulDelete    replicaset/...                Deleted pod: chaos-target-app-xxx-stable1
0s    Normal   Killing             pod/...stable1                Stopping container app
2s    Normal   ScalingReplicaSet   deployment/chaos-target-app   Scaled up replica set ...d6d79 from 0 to 3
2s    Normal   SuccessfulCreate    replicaset/...                Created pod: chaos-target-app-xxx-broken1
2s    Normal   Scheduled           pod/...broken1                Successfully assigned chaos-app/...
```

**Step 2: Broken pods fail to start**
```
5s    Normal   Pulling             pod/...broken1                Pulling image "nginx:nonexistent-tag"
7s    Warning  Failed              pod/...broken1                Failed to pull image "nginx:nonexistent-tag"
7s    Warning  Failed              pod/...broken1                Error: ErrImagePull
10s   Normal   BackOff             pod/...broken1                Back-off pulling image "nginx:nonexistent-tag"
10s   Warning  Failed              pod/...broken1                Error: ImagePullBackOff
```

**Step 3: Script executes rollback**
```
15s   Normal   ScalingReplicaSet   deployment/chaos-target-app   Scaled down replica set ...d6d79 from 3 to 0
15s   Normal   SuccessfulDelete    replicaset/...                Deleted pod: chaos-target-app-xxx-broken1
15s   Normal   Killing             pod/...broken1                Stopping container app
16s   Normal   ScalingReplicaSet   deployment/chaos-target-app   Scaled up replica set ...f567f from 0 to 3
16s   Normal   SuccessfulCreate    replicaset/...                Created pod: chaos-target-app-xxx-new1
16s   Normal   Scheduled           pod/...new1                   Successfully assigned chaos-app/...
```

**Step 4: Recovery completes**
```
17s   Normal   Pulled              pod/...new1                   Container image "nginx:1.21-alpine" already present
17s   Normal   Created             pod/...new1                   Created container app
17s   Normal   Started             pod/...new1                   Started container app
```

---

**Back to Terminal 1 - What you saw happen:**

```
# Before script runs
NAME                                READY   STATUS    RESTARTS   AGE
chaos-target-app-xxx-stable1        1/1     Running   0          5m
chaos-target-app-xxx-stable2        1/1     Running   0          5m
chaos-target-app-xxx-stable3        1/1     Running   0          5m

# Script deploys broken version (Recreate strategy kills all first)
chaos-target-app-xxx-stable1        1/1     Terminating         0     5m
chaos-target-app-xxx-stable2        1/1     Terminating         0     5m
chaos-target-app-xxx-stable3        1/1     Terminating         0     5m

# All old pods gone, new broken pods appear
chaos-target-app-xxx-broken1        0/1     ContainerCreating   0     3s
chaos-target-app-xxx-broken2        0/1     ContainerCreating   0     3s
chaos-target-app-xxx-broken3        0/1     ContainerCreating   0     3s

# Broken pods fail to start
chaos-target-app-xxx-broken1        0/1     ImagePullBackOff    0     15s
chaos-target-app-xxx-broken2        0/1     ImagePullBackOff    0     15s
chaos-target-app-xxx-broken3        0/1     ErrImagePull        0     13s

# Script executes rollback
chaos-target-app-xxx-broken1        0/1     Terminating         0     18s
chaos-target-app-xxx-new1           0/1     ContainerCreating   0     2s
chaos-target-app-xxx-new2           0/1     ContainerCreating   0     2s
chaos-target-app-xxx-new3           0/1     Pending             0     1s

# Recovery complete
chaos-target-app-xxx-new1           1/1     Running   0          8s
chaos-target-app-xxx-new2           1/1     Running   0          8s
chaos-target-app-xxx-new3           1/1     Running   0          8s
```

**What to notice:** 
- Started with 3 healthy pods
- Script deployed broken version → all pods terminated (Recreate strategy)
- New pods failed with ImagePullBackOff
- Script executed rollback → new healthy pods created
- Total recovery time: ~8 seconds

---

## Step 5: Run a Chaos Test (With Active Pod Deletion)

Now measure rollback time while chaos actively deletes pods.

**Keep all three terminals open from Step 4.**

**Terminal 2 - Execute Chaos Test:**
```bash
# Run chaos-enabled test
python3 scripts/measure-rollback-mttr.py --chaos
```

**What you'll see:**
```
MEASURING MTTR: WITH-CHAOS
============================================================
>> Deploying unstable version...
>> Waiting for bad deployment to stabilize...
>> Triggering chaos workflow...
workflow.argoproj.io "pod-delete-chaos-experiment" deleted
workflow.argoproj.io/pod-delete-chaos-experiment created
>> Chaos workflow started. Waiting for chaos to begin...
>> Executing rollback command...
deployment.apps/chaos-target-app rolled back
>> Waiting for rollout to succeed...
deployment "chaos-target-app" successfully rolled out
>> Cleaning up chaos artifacts...
>> SUCCESS: Rollback took 45.7 seconds
>> Result saved to chaos_results.json
```

**What this tells you:** With chaos active, rollback takes ~45 seconds—significantly longer than the 8-second baseline!

---

**Terminal 1 - Application Pod States (During Chaos):**

**What you'll see (this is dramatic):**
```
# Broken pods failing
NAME                                READY   STATUS              RESTARTS   AGE
chaos-target-app-xxx-broken1        0/1     ImagePullBackOff    0          15s
chaos-target-app-xxx-broken2        0/1     Terminating         0          15s  ← Chaos deleting!
chaos-target-app-xxx-broken3        0/1     ImagePullBackOff    0          15s

# Rollback starts creating healthy pods, but chaos interferes...
chaos-target-app-xxx-new1           1/1     Running             0          10s
chaos-target-app-xxx-new2           0/1     ContainerCreating   0          3s
chaos-target-app-xxx-new3           0/1     Pending             0          1s
chaos-target-app-xxx-new1           1/1     Terminating         0          12s  ← New pod deleted by chaos!

# More chaos deletions during recovery...
chaos-target-app-xxx-new2           1/1     Running             0          15s
chaos-target-app-xxx-new3           1/1     Running             0          13s
chaos-target-app-xxx-new4           0/1     ContainerCreating   0          2s
chaos-target-app-xxx-new2           1/1     Terminating         0          18s  ← Deleted again!

# Eventually chaos stops (after 30s), system stabilizes...
chaos-target-app-xxx-new4           1/1     Running   0          45s  ← Finally stable!
chaos-target-app-xxx-new5           1/1     Running   0          43s
chaos-target-app-xxx-new6           1/1     Running   0          40s
```

**What to notice:** 
- Pods keep getting deleted even after rollback starts
- Recovery takes much longer because chaos keeps interfering
- Notice the AGE differences—pods are constantly being recreated
- The system eventually stabilizes once chaos stops (after its 30-second duration)

---

**Terminal 3 - Live Events (During Chaos):**

**Additional events you'll see:**
```
20s   Normal   Killing             pod/...new1                   Stopping container app  ← Chaos!
20s   Normal   SuccessfulCreate    replicaset/...                Created pod: ...new4
25s   Normal   Killing             pod/...new2                   Stopping container app  ← More chaos!
30s   Normal   SuccessfulCreate    replicaset/...                Created pod: ...new5
```

**What this shows:** Chaos is actively deleting healthy pods during the rollback attempt, forcing Kubernetes to keep creating replacements.

You can also check workflow status:
```bash
# In a separate terminal (or after test completes)
kubectl get workflows -n litmus
```

**Expected output:**
```
NAME                          STATUS      AGE
pod-delete-chaos-experiment   Succeeded   2m
```

**What this confirms:** The chaos workflow completed its 30-second cycle during your rollback attempt.

---

## Understanding the Test Results

**What you just proved:**

### Baseline Test (~8 seconds):
- Broken deployment detected
- Rollback executed
- All pods recovered to healthy state
- No interference from infrastructure

### Chaos Test (~45 seconds):
- Broken deployment detected
- Rollback executed **while chaos actively deletes pods**
- System fights to recover against active interference
- Takes 5-6x longer due to chaos

**The Key Insight:** Your rollback command works in both scenarios, but recovery time increases dramatically when infrastructure is unstable. This is critical data for:
- Setting realistic SLA targets (don't promise 1-minute recovery if it takes 45 seconds under stress)
- Capacity planning (need extra replicas to absorb chaos during incidents)
- Incident response procedures (expect longer recovery during cascading failures)

---

## What Each Terminal Taught You

**Terminal 1 (Pod States):**
- Shows the actual struggle: pods failing, being deleted, recovering
- Visualizes why chaos increases MTTR
- Proves Kubernetes self-healing works even under stress

**Terminal 2 (MTTR Measurement):**
- Gives you the hard numbers: 8s baseline vs 45s with chaos
- Automates the entire test process
- Saves results for statistical analysis

**Terminal 3 (Live Events):**
- Explains WHY things are happening (image pull failures, chaos deletions)
- Provides audit trail for incident reports
- Helps debug unexpected behavior

---

## Verify Your Results

```bash
# View saved results
cat chaos_results.json
```

**Expected output:**
```json
{
    "baseline": [
        8.29
    ],
    "with-chaos": [
        45.7
    ]
}
```

**What this data means:** You now have empirical evidence that chaos increases recovery time by ~5-6x. This isn't theoretical—it's measured data from your actual cluster.

---

## 💡 SRE Analysis: Understanding Test Automation

**The Technical Event:**
You created a comprehensive test harness that automates the entire chaos experiment lifecycle. This script acts as a "chaos orchestrator" that controls both your application state (broken deploy) and your infrastructure state (chaos injection), then measures recovery performance.

**What Really Happened:**

1. **Isolated Variables**: The script ensures only one thing changes between tests (chaos on/off)
2. **Repeatable Experiments**: Same rollback command, same cluster, same application
3. **Quantifiable Results**: Not "it felt slower"—actual seconds measured
4. **Audit Trail**: JSON file proves results, events log shows causation

**The Learning Outcome:**

This introduces **Scientific Chaos Engineering**. Chaos isn't about randomly breaking things—it's about controlled experiments with measurable outcomes. Your script follows the scientific method:

- **Hypothesis**: "Chaos will increase MTTR"
- **Independent Variable**: Presence or absence of pod deletion chaos
- **Dependent Variable**: Time to complete rollback (MTTR)
- **Controlled Variables**: Same rollback command, same cluster state, same broken deployment
- **Results**: 8s baseline vs 45s with chaos
- **Conclusion**: Hypothesis confirmed—chaos increases MTTR by 5-6x

**Real Production Value:**

Production SREs use automation like this to validate disaster recovery procedures. Your "Emergency Rollback Runbook" might say "Execute kubectl rollout undo," but does that command work when:
- Pods are crashing unexpectedly?
- The control plane is under load?
- Multiple deployments are failing simultaneously?
- Network partitions are occurring?

This script proves your runbook works under stress, not just in ideal conditions. That validation is what separates theoretical runbooks from battle-tested procedures that work during real incidents at 3 AM.

**Why This Matters:**

In production, you'll have SLAs (Service Level Agreements) that promise things like:
- "99.9% uptime" (43 minutes downtime per month allowed)
- "15-minute recovery time for critical incidents"
- "Zero data loss during rollbacks"

Your chaos testing data lets you make these commitments confidently. You're not guessing—you've measured it. When leadership asks "Can we hit 99.9% uptime?", you respond with "Yes, our rollback takes 45 seconds even under chaos, well within our 15-minute recovery SLA."

**Time Investment:**

Yes, each test takes 1-2 minutes. But in production, you'd schedule these tests to run automatically during off-hours (nightly or weekly). The infrastructure team doesn't need to be present—the script runs, collects data, and saves results. Over time, you build a dataset showing how MTTR trends as you improve your systems.

**Next Evolution:**

Professional SRE teams extend this approach to test:
- Database rollbacks under chaos
- Multi-region failover during network partitions
- Rollback success rate (does it work 100% of the time or only 80%?)
- Rollback under different chaos types (CPU starvation, memory pressure, disk I/O saturation)

You've built the foundation. The methodology scales to any recovery procedure you need to validate.

---

## Phase 5: Automated Stress Testing

**What we're doing:** Running multiple test iterations to collect statistically significant data. We'll measure rollback time both with and without chaos to quantify the impact of instability.

**Why multiple runs?** One test could be affected by random factors (network hiccup, scheduler delay). Three tests reveal patterns.

### Step 1: Reset Environment

**What this does:** Ensures you're starting from a known-good state. If previous tests left broken deployments or chaos artifacts, this cleans them up.

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

**Expected output:**
```
# From rollout status:
deployment "chaos-target-app" successfully rolled out

# From get pods:
NAME                               READY   STATUS    RESTARTS   AGE
chaos-target-app-7d9f8c5b4-abc12   1/1     Running   0          1m
chaos-target-app-7d9f8c5b4-def34   1/1     Running   0          1m
chaos-target-app-7d9f8c5b4-ghi56   1/1     Running   0          1m

# From checking chaos artifacts:
No resources found in litmus namespace.
```

**What to do if something's wrong:**
```bash
# If pods are stuck in bad state:
kubectl delete deployment chaos-target-app -n chaos-app
kubectl apply -f manifests/stable/

# If chaos artifacts exist:
kubectl delete workflow --all -n litmus
kubectl delete chaosengine --all -n litmus
```

---

### Step 2: Run Baseline Tests (No Chaos)

**What this does:** Measures how long rollback takes under perfect conditions. This establishes your "best case" performance.

**Important:** Open TWO terminal windows.

**Terminal 1 - Observation:**
```bash
# Watch what happens to your pods during each test
watch kubectl get pods -n chaos-app -l app=chaos-target-app
```

**Terminal 2 - Execute Tests:**
```bash
# Run baseline test 1
python3 scripts/measure-rollback-mttr.py --baseline
```

**What you'll see in Terminal 1:**

Initially (stable version running):
```
NAME                               READY   STATUS    RESTARTS   AGE
chaos-target-app-7d9f8c5b4-abc12   1/1     Running   0          2m
chaos-target-app-7d9f8c5b4-def34   1/1     Running   0          2m
chaos-target-app-7d9f8c5b4-ghi56   1/1     Running   0          2m
```

After script deploys unstable version:
```
NAME                               READY   STATUS             RESTARTS   AGE
chaos-target-app-8a2b3c4d5-xyz11   0/1     ImagePullBackOff   0          10s
chaos-target-app-8a2b3c4d5-xyz22   0/1     ImagePullBackOff   0          10s
chaos-target-app-8a2b3c4d5-xyz33   0/1     ErrImagePull       0          8s
```

After script executes rollback:
```
NAME                               READY   STATUS              RESTARTS   AGE
chaos-target-app-7d9f8c5b4-new11   0/1     ContainerCreating   0          2s
chaos-target-app-7d9f8c5b4-new22   0/1     ContainerCreating   0          2s
chaos-target-app-7d9f8c5b4-new33   0/1     ContainerCreating   0          2s
```

Finally (rollback complete):
```
NAME                               READY   STATUS    RESTARTS   AGE
chaos-target-app-7d9f8c5b4-new11   1/1     Running   0          25s
chaos-target-app-7d9f8c5b4-new22   1/1     Running   0          25s
chaos-target-app-7d9f8c5b4-new33   1/1     Running   0          25s
```

**What you'll see in Terminal 2:**
```
MEASURING MTTR: BASELINE
============================================================
>> Deploying unstable version...
>> Waiting for bad deployment to stabilize...
>> Executing rollback command...
>> Waiting for rollout to succeed...
>> Cleaning up chaos artifacts...
>> SUCCESS: Rollback took 38.2 seconds
>> Result saved to chaos_results.json
```

**What just happened:** The script deployed the broken version, immediately rolled it back, and measured that it took 38.2 seconds to recover. This is your baseline.

---

**Wait 30 seconds for cluster to fully stabilize, then run test 2:**

```bash
sleep 30
python3 scripts/measure-rollback-mttr.py --baseline
```

**Expected output (Terminal 2):**
```
MEASURING MTTR: BASELINE
============================================================
>> SUCCESS: Rollback took 39.1 seconds
>> Result saved to chaos_results.json
```

---

**Wait and run test 3:**

```bash
sleep 30
python3 scripts/measure-rollback-mttr.py --baseline
```

**Expected output (Terminal 2):**
```
MEASURING MTTR: BASELINE
============================================================
>> SUCCESS: Rollback took 37.8 seconds
>> Result saved to chaos_results.json
```

**What you just collected:** Three baseline measurements. The average will be around 38 seconds, with slight variation.

---

### Step 3: Run Chaos Tests (With Active Pod Deletion)

**What this does:** Measures how long rollback takes when pods are being actively deleted by chaos. This simulates a production incident where infrastructure is unstable.

**Terminal 1 should still be running with the watch command.**

**Terminal 2 - Execute Chaos Tests:**

```bash
# Run chaos test 1
python3 scripts/measure-rollback-mttr.py --chaos
```

**What you'll see in Terminal 1 (this is dramatic):**

Initial stable state:
```
NAME                               READY   STATUS    RESTARTS   AGE
chaos-target-app-7d9f8c5b4-abc12   1/1     Running   0          1m
chaos-target-app-7d9f8c5b4-def34   1/1     Running   0          1m
chaos-target-app-7d9f8c5b4-ghi56   1/1     Running   0          1m
```

Script deploys unstable version:
```
NAME                               READY   STATUS             RESTARTS   AGE
chaos-target-app-8a2b3c4d5-xyz11   0/1     ImagePullBackOff   0          10s
chaos-target-app-8a2b3c4d5-xyz22   0/1     ImagePullBackOff   0          10s
chaos-target-app-8a2b3c4d5-xyz33   0/1     ErrImagePull       0          8s
```

Chaos workflow starts, begins deleting pods:
```
NAME                               READY   STATUS        RESTARTS   AGE
chaos-target-app-8a2b3c4d5-xyz11   0/1     Terminating   0          20s
chaos-target-app-8a2b3c4d5-xyz22   0/1     ErrImagePull  0          20s
chaos-target-app-8a2b3c4d5-xyz33   0/1     ErrImagePull  0          18s
chaos-target-app-8a2b3c4d5-new44   0/1     Pending       0          1s
```

Rollback executes WHILE chaos is still running:
```
NAME                               READY   STATUS              RESTARTS   AGE
chaos-target-app-7d9f8c5b4-new11   0/1     ContainerCreating   0          2s
chaos-target-app-8a2b3c4d5-xyz22   0/1     Terminating         0          25s
chaos-target-app-7d9f8c5b4-new22   0/1     ContainerCreating   0          2s
```

Chaos continues deleting, even new pods:
```
NAME                               READY   STATUS        RESTARTS   AGE
chaos-target-app-7d9f8c5b4-new11   1/1     Terminating   0          15s
chaos-target-app-7d9f8c5b4-new22   1/1     Running       0          15s
chaos-target-app-7d9f8c5b4-new33   0/1     Pending       0          1s
```

Finally, chaos stops and system stabilizes:
```
NAME                               READY   STATUS    RESTARTS   AGE
chaos-target-app-7d9f8c5b4-new11   1/1     Running   0          55s
chaos-target-app-7d9f8c5b4-new22   1/1     Running   0          55s
chaos-target-app-7d9f8c5b4-new33   1/1     Running   0          40s
```

**What you'll see in Terminal 2:**
```
MEASURING MTTR: WITH-CHAOS
============================================================
>> Deploying unstable version...
>> Waiting for bad deployment to stabilize...
>> Triggering chaos workflow...
>> Chaos workflow started. Waiting for chaos to begin...
>> Executing rollback command...
>> Waiting for rollout to succeed...
>> Cleaning up chaos artifacts...
>> SUCCESS: Rollback took 72.5 seconds
>> Result saved to chaos_results.json
```

**Notice:** 72.5 seconds vs 38 seconds baseline! Recovery took almost twice as long under chaos.

**What just happened:** The script deployed the broken version, started chaos (which began deleting pods), then tried to rollback. The rollback command succeeded, but Kubernetes struggled to get all pods healthy because chaos kept deleting them. Eventually chaos stopped and the system recovered.

---

**Wait and run test 2:**

```bash
sleep 30
python3 scripts/measure-rollback-mttr.py --chaos
```

**Expected output:**
```
MEASURING MTTR: WITH-CHAOS
============================================================
>> SUCCESS: Rollback took 68.9 seconds
>> Result saved to chaos_results.json
```

---

**Wait and run test 3:**

```bash
sleep 30
python3 scripts/measure-rollback-mttr.py --chaos
```

**Expected output:**
```
MEASURING MTTR: WITH-CHAOS
============================================================
>> SUCCESS: Rollback took 75.2 seconds
>> Result saved to chaos_results.json
```

**Press Ctrl+C in Terminal 1 to stop watching pods.**

---

### Step 4: Verify Data Collection

```bash
# View collected results
cat chaos_results.json
```

**Expected output:**
```json
{
    "baseline": [
        38.2,
        39.1,
        37.8
    ],
    "with-chaos": [
        72.5,
        68.9,
        75.2
    ]
}
```

**What this data shows:**
- **Baseline average**: ~38 seconds (best case scenario)
- **Chaos average**: ~72 seconds (realistic failure scenario)
- **Impact**: Chaos increases recovery time by ~90%

---

### 💡 SRE Analysis: Statistical Significance

**The Technical Event:**
You executed controlled experiments multiple times to generate a dataset. Running tests three times produces an average (mean) that's more reliable than a single measurement.

**The Learning Outcome:**
This demonstrates **Statistical Rigor** in chaos engineering. Distributed systems exhibit variance—network latency fluctuates, scheduling decisions vary, API server response times change. One slow test might be a fluke caused by background processes. Three slow tests indicate a systematic problem.

The data reveals that chaos isn't just "slightly annoying"—it nearly doubles your recovery time. This is the difference between meeting and violating your SLA.

**Real Production Value:**
When presenting chaos engineering findings to leadership, data quality matters. You cannot justify infrastructure investments by saying "It felt slower during chaos." You justify investments with: "Our tests show that pod instability increases recovery time by 90% (72s vs 38s), which exceeds our 60-second SLA. We need improved health checks and faster pod startup times."

Data-driven recommendations get approved. Anecdotal complaints get ignored.

---

## Phase 6: Measuring Chaos Impact

**What we're doing:** Analyzing the test results to generate a professional report quantifying the impact of chaos on system resilience.

**Why this matters:** Raw data (38s, 72s) tells you numbers. Analysis tells you what those numbers mean for your business, your SLAs, and your infrastructure investments.

### Step 1: Create the Analysis Script

**What this creates:** A script that reads your test data, calculates statistical metrics (mean, standard deviation), and generates actionable recommendations.

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
    print("   - Consider PodDisruptionBudgets to limit chaos impact")
    
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

**What you just created:** An analysis script that:
- Calculates average (mean) recovery time for each scenario
- Calculates standard deviation (variability)
- Computes percentage impact of chaos
- Generates actionable recommendations based on your data

---

### Step 2: Generate the Report

**What this does:** Processes your test data and displays a professional analysis report.

```bash
python3 scripts/analyze-chaos-impact.py
```

**Expected output:**

```
Chaos Engineering Impact Analysis
============================================================

Test Scenario          Avg MTTR    Std Dev    Impact
------------------------------------------------------------
baseline                 38.4s     ±0.7s      +0.0%
with-chaos               72.2s     ±3.2s     +88.0%

Key Insights:
- Baseline rollback time: 38.4s (±0.7s)
- Active pod deletion increases MTTR by 88.0%
- Recovery takes an additional 33.8s under chaos

SRE Recommendations:

1. Set SLA Targets Based on Chaos Conditions
   - Do NOT promise recovery times based on baseline tests
   - Account for real-world instability in SLA commitments
   - Recommend SLA: 87s (chaos MTTR + 20% buffer)

2. Improve System Resilience
   - Tune livenessProbe/readinessProbe for faster failure detection
   - Optimize container startup time to reduce MTTR
   - Consider PodDisruptionBudgets to limit chaos impact

3. Automate Chaos Testing
   - Schedule these workflows weekly in staging environments
   - Block production deployments if chaos tests fail
   - Track MTTR trends over time to validate improvements

4. Document Findings
   - Add these metrics to your incident response runbooks
   - Use this data during post-incident reviews
   - Present findings to leadership for infrastructure investments
```

---

### Understanding the Report

**Test Scenario Table:**
- **baseline**: Tests without chaos (perfect conditions)
- **with-chaos**: Tests with active pod deletion
- **Avg MTTR**: Average recovery time across 3 tests
- **Std Dev**: Variability (±0.7s means tests were very consistent, ±3.2s means more variation under chaos)
- **Impact**: Percentage increase compared to baseline

**Key Insights:**
- Your baseline is 38.4 seconds—this is what you'd promise if you ignored chaos
- Chaos increases recovery time by 88%—nearly double
- You lose 33.8 extra seconds when infrastructure is unstable

**SRE Recommendations:**
These aren't generic advice—they're based on YOUR actual test results.

**Recommendation 1** says: Don't promise 60-second SLA based on 38s baseline. Your chaos tests show you need 72s, so promise 87s (with buffer).

**Recommendation 2** points to specific improvements that would reduce MTTR.

**Recommendation 3** explains how to operationalize this testing.

**Recommendation 4** shows how to use this data in your organization.

---

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
You want to implement PodDisruptionBudgets to limit chaos impact, but leadership questions the value. You present this data: "Pod instability increases our recovery time by 88%. PodDisruptionBudgets will reduce that to 30%, keeping us within our SLA commitments." Data-backed proposals get approved.

**Scenario C: Continuous Improvement**
After implementing improvements (better health checks, faster startup), you re-run these tests and prove recovery time decreased from 72s to 55s. You've quantified the value of your engineering work.

**Scenario D: Post-Incident Reviews**
During a real production incident, rollback took 65 seconds. Is that good or bad? Your chaos test data shows: "That's actually better than our 72s chaos test average, meaning our runbook performed well under realistic pressure."

**The Bottom Line:**
This isn't just an academic exercise. This is how production SREs validate their disaster recovery procedures and prove to leadership that their systems are ready for real incidents.

---

## Cleanup

**What this does:** Removes all resources created during this lab to return your cluster to its original state.

```bash
# Remove application deployments
kubectl delete -f manifests/stable/ --ignore-not-found
kubectl delete -f manifests/unstable/ --ignore-not-found

# Remove chaos artifacts
kubectl delete -f manifests/chaos/ --ignore-not-found
kubectl delete workflow --all -n litmus
kubectl delete chaosengine --all -n litmus
kubectl delete chaosexperiment --all -n litmus
kubectl delete chaosresult --all -n litmus

# Remove application namespace
kubectl delete namespace chaos-app

# Optional: Remove entire chaos engineering stack
kubectl delete namespace litmus
kubectl delete namespace argo

echo "Cleanup completed successfully"
```

**Expected output:**
```
configmap "app-content" deleted
deployment.apps "chaos-target-app" deleted
service "chaos-target-service" deleted
...
namespace "chaos-app" deleted
namespace "litmus" deleted
namespace "argo" deleted
Cleanup completed successfully
```

**Verify cleanup:**
```bash
# Should show no pods in these namespaces
kubectl get pods -n chaos-app
kubectl get pods -n litmus
kubectl get pods -n argo
```

---

## Commit Your Work

**What this does:** Saves all your work to Git so you can share it, revisit it, or use it as a reference for future chaos engineering work.

```bash
# Stage all files
git add .

# Commit with descriptive message
git commit -m "Complete chaos engineering lab with LitmusChaos 3.x and Argo Workflows

- Implemented workflow-based chaos experiments using modern architecture
- Used dedicated namespaces (chaos-app for application, litmus for infrastructure)
- Configured cross-namespace RBAC for secure chaos execution
- Measured MTTR under baseline and chaos conditions
- Generated quantitative resilience metrics with statistical analysis
- Documented production-ready patterns and SRE recommendations"

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