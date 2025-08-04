# **Rolling Updates & Rollbacks in Kubernetes**

## **Table of Contents**

- [Scenario: A Bad Release in Production](#scenario-a-bad-release-in-production)
- [Why Rollbacks Matter for SRE](#why-rollbacks-matter-for-sre)
- [Learning Objectives](#learning-objectives)
- [Prerequisites and GitHub Repo Preparation](#prerequisites-and-github-repo-preparation)
- [Phase 1: Prepare Versioned Manifests](#phase-1-prepare-versioned-manifests)
- [Phase 2: Deploy & Verify v1 (Stable)](#phase-2-deploy--verify-v1-stable)
- [Phase 3: Simulate Faulty v2 Release](#phase-3-simulate-faulty-v2-release)
- [Phase 4: Kubernetes Native Rollback](#phase-4-kubernetes-native-rollback)
- [Phase 5: ArgoCD-Driven Rollback](#phase-5-argocd-driven-rollback)
- [Expected Outcome](#expected-outcome)
- [Next Steps](#next-steps)

---

## Scenario: A Bad Release in Production

Your team has just pushed v2.0 of the "sre-rollback-app" into production. Shortly after, alerts flood in: pods crash, the service returns errors, and users can't reach your app. As the on-call SRE, you need to revert to the last known-good version (v1.0) as quickly as possible.

**🚨 The clock is ticking: every minute of downtime costs your company money and damages user trust!**

---

## Why Rollbacks Matter for SRE

- **Minimize downtime**: Restore service health before SLA breaches occur  
- **Automate recovery**: Reduce manual intervention and human error during incidents  
- **Audit & traceability**: Kubernetes rollout history and Git commits document every change  
- **Safe iteration**: Confidently push frequent updates knowing you can revert instantly  

### **SRE Metrics Impact**
- **MTTR** (Mean Time To Recovery): Target < 5 minutes
- **Error Budget**: Each minute of downtime consumes your monthly availability budget
- **Blast Radius**: Minimize impact through quick, reliable rollbacks
- **Postmortem Data**: Rollout history provides precise timeline for incident analysis

---

## Learning Objectives

By the end of this exercise you will:

1. **Create** versioned Kubernetes manifests for v1 (stable) and v2 (faulty)  
2. **Deploy** v1 and validate service health using multiple verification methods  
3. **Simulate** a broken release with v2 and analyze the failure  
4. **Perform** an imperative rollback using `kubectl rollout undo`  
5. **Execute** a declarative rollback via ArgoCD's history and CLI  
6. **Inspect** rollout history, events, logs, and service responses at each step  
7. **Monitor** rollback progress in real-time to ensure successful recovery

---

## Prerequisites and GitHub Repo Preparation

**Make sure you've completed Exercise 17** (ArgoCD) and have:

- A running Minikube/Colima cluster  
- `kubectl` pointing at that cluster  
- ArgoCD installed, with `kubectl port-forward svc/argocd-server -n argocd 8080:443 &` running  
- `argocd` CLI installed and logged in:  

  ```bash
  argocd login localhost:8080 \
    --username admin \
    --password "$(kubectl -n argocd get secret argocd-initial-admin-secret \
      -o jsonpath="{.data.password}" | base64 --decode)" \
    --insecure
  ```

### **Verify Your Prerequisites**

```bash
# Check kubectl client version
kubectl version --client

# Check cluster connectivity by listing nodes
kubectl version          # you’ll see both Client and Server versions
kubectl get nodes

# Verify ArgoCD server pod is running
kubectl get pods -n argocd | grep argocd-server

# Test ArgoCD CLI connection
argocd version --client   # checks your CLI version
argocd version            # shows both CLI and server versions
```

### 1. Create Your Personal GitHub Repo

1. Visit [https://github.com/new](https://github.com/new)
2. **Name:** `sre-rollback-deployments`
3. **Visibility:** Public
4. **Leave "Initialize this repository with a README" unchecked**
5. Click **Create repository**

### 2. Bootstrap Locally

Create & enter your workspace:

```bash
mkdir -p ~/Projects/sre-rollback-deployments
cd ~/Projects/sre-rollback-deployments

# Initialize Git repository
git init
git branch -M main
```

Link to your remote:

```bash
git remote add origin https://github.com/YOUR-USERNAME/sre-rollback-deployments.git
```

*Replace `YOUR-USERNAME` with your GitHub username.*

Create initial commit and push:

```bash
# Create initial README
echo "# SRE Rollback Deployments Lab" > README.md
git add README.md
git commit -m "feat: initial commit with lab setup"
git push -u origin main
```

*Sets upstream so future pushes/pulls are simple.*

> ❗ **If you see `rejected: fetch first`**, then the remote already has commits; integrate with:
>
> ```bash
> git pull --rebase origin main
> git push origin main
> ```

---

## Phase 1: Prepare Versioned Manifests

We'll create two folders—`v1/` (stable) and `v2/` (faulty)—each with a Deployment + Service. This simulates how teams manage different versions of their applications.

### **Create Stable Version (v1)**

```bash
# Create directory structure
mkdir -p v1
```

> **⚠️ Remember:**
>
> * Replace `<YOUR-USERNAME>` with your actual DockerHub username (or the registry path you’re using).
> * If you forget, Kubernetes won’t be able to pull the container images and your rollout will fail.

```bash
# Stable v1 deployment
cat > v1/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-rollback-app
  labels:
    app: sre-rollback-app
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels: 
      app: sre-rollback-app
  template:
    metadata: 
      labels: 
        app: sre-rollback-app
        version: v1
    spec:
      containers:
      - name: app
        image: <YOUR-USERNAME>/sre-rollback-demo:v1
        ports: 
        - containerPort: 5000
        # Health checks for safer deployments
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 5
          periodSeconds: 5
EOF

# Stable v1 service
cat > v1/service.yaml <<EOF
apiVersion: v1
kind: Service
metadata: 
  name: sre-rollback-service
  labels:
    app: sre-rollback-app
spec:
  selector: 
    app: sre-rollback-app
  ports: 
  - port: 5000
    targetPort: 5000
  type: NodePort
EOF
```

### **Create Faulty Version (v2)**

```bash
# Create directory for faulty version
mkdir -p v2
```

> **⚠️ Remember:**
>
> * Replace `<YOUR-USERNAME>` with your actual DockerHub username (or the registry path you’re using).
> * If you forget, Kubernetes won’t be able to pull the container images and your rollout will fail.

```bash
# Faulty v2 deployment (intentionally broken)
cat > v2/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-rollback-app
  labels:
    app: sre-rollback-app
    version: v2
spec:
  replicas: 1
  selector:
    matchLabels: 
      app: sre-rollback-app
  template:
    metadata: 
      labels: 
        app: sre-rollback-app
        version: v2
    spec:
      containers:
      - name: app
        image: <YOUR-USERNAME>/sre-rollback-demo:v2  # This version is broken!
        ports: 
        - containerPort: 5000
        # Same health checks as v1
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 5
          periodSeconds: 5
EOF

# Same service configuration
cat > v2/service.yaml <<EOF
apiVersion: v1
kind: Service
metadata: 
  name: sre-rollback-service
  labels:
    app: sre-rollback-app
spec:
  selector: 
    app: sre-rollback-app
  ports: 
  - port: 5000
    targetPort: 5000
  type: NodePort
EOF
```

### **Commit Manifests to GitHub**

```bash
# Add files to Git
git add v1 v2

# Commit with descriptive message
git commit -m "feat: add v1 (stable) and v2 (faulty) manifests for rollback demo"

# Push to GitHub
git push origin main

# Verify the push was successful
echo "Manifests pushed to GitHub successfully!"
```

---

## Phase 2: Deploy & Verify v1 (Stable)

**Why?** Establish a known-good baseline before simulating failure.

### **Deploy the Stable Version**

```bash
# Apply v1 manifests
kubectl apply -f v1/

# Monitor deployment progress
kubectl rollout status deployment/sre-rollback-app
# Expected output: "deployment "sre-rollback-app" successfully rolled out"
```

### **Verify Deployment Health**

```bash
# Check pod status
kubectl get pods -l app=sre-rollback-app
# Should show 1 pod in "Running" state

# Get detailed pod information
kubectl get pods -l app=sre-rollback-app -o wide

# Check deployment details
kubectl describe deployment sre-rollback-app
```

### **Test Service Accessibility**

```bash
# Get service URL
SERVICE_URL=$(minikube service sre-rollback-service --url)
echo "Service URL: $SERVICE_URL"

# Test the application
curl -s $SERVICE_URL
# Expected output: "Version 1 - Stable release"

# Test health endpoint
curl -s $SERVICE_URL/health
# Should return health status

# Or open in browser (macOS/Linux)
open $SERVICE_URL  # macOS
# or
xdg-open $SERVICE_URL  # Linux
```

### **Verification Checklist**

✅ Pod is in "Running" state  
✅ Service responds with "Version 1 - Stable release"  
✅ Health endpoint returns success  
✅ No error events in cluster  

```bash
# Check for any error events
kubectl get events --sort-by='.metadata.creationTimestamp' | tail -5
```

---

## Phase 3: Simulate Faulty v2 Release

**Why?** Introduce a realistic production failure to practice incident response.

### **Deploy the Broken Version**

```bash
# Apply v2 manifests (the broken version)
kubectl apply -f v2/

# Try to monitor deployment (this will likely hang or show errors)
echo "Monitoring deployment progress (this may take a while due to failures)..."
kubectl rollout status deployment/sre-rollback-app --timeout=60s || echo "❌ Deployment failed or timed out"
```

### **Analyze the Failure**

Open multiple terminal windows to monitor the failure:

**Terminal 1 - Watch pods:**
```bash
# Watch pod status in real-time
watch -n 2 'kubectl get pods -l app=sre-rollback-app'
# You should see pods failing to start or crashing
```

**Terminal 2 - Check logs:**
```bash
# Get the failing pod name
FAILING_POD=$(kubectl get pods -l app=sre-rollback-app -o jsonpath='{.items[0].metadata.name}')
echo "Checking logs for pod: $FAILING_POD"

# View pod logs
kubectl logs $FAILING_POD || echo "Pod not ready for logs yet"

# Follow logs in real-time
kubectl logs -f $FAILING_POD
```

**Terminal 3 - Service status:**
```bash
# Test service availability
while true; do
  response=$(curl -s -o /dev/null -w "%{http_code}" $SERVICE_URL 2>/dev/null || echo "000")
  timestamp=$(date '+%H:%M:%S')
  if [ "$response" = "200" ]; then
    echo "[$timestamp] ✅ Service responding (HTTP $response)"
  else
    echo "[$timestamp] ❌ Service unavailable (HTTP $response)"
  fi
  sleep 3
done
```

### **Gather Diagnostic Information**

```bash
# Check deployment status
kubectl describe deployment sre-rollback-app

# View recent events
kubectl get events --sort-by='.metadata.creationTimestamp' | tail -10

# Check ReplicaSet history
kubectl get rs -l app=sre-rollback-app
# You should see old and new ReplicaSets

# Get detailed pod information
kubectl describe pod -l app=sre-rollback-app
```

**Expected Failure Symptoms:**
- Pods in `CrashLoopBackOff` or `Error` state
- Service returns HTTP 502/503 errors or timeouts
- Pod logs show application startup failures
- Health check failures in pod events

---

## Phase 4: Kubernetes Native Rollback

**Why?** Use Kubernetes built-in recovery mechanisms for immediate response.

### **Execute Emergency Rollback**

```bash
# EMERGENCY ROLLBACK - Execute immediately!
echo "EXECUTING EMERGENCY ROLLBACK"

# Rollback to previous revision
kubectl rollout undo deployment/sre-rollback-app

# Monitor rollback progress
kubectl rollout status deployment/sre-rollback-app --timeout=180s
# Expected output: "deployment "sre-rollback-app" successfully rolled out"
```

### **Monitor Rollback Progress**

**Terminal 1 - Watch rollback:**
```bash
# Monitor deployment status
kubectl rollout status deployment/sre-rollback-app --watch
```

**Terminal 2 - Service availability:**
```bash
# Monitor service recovery
echo "Monitoring service recovery..."
for i in {1..10}; do
  response=$(curl -s $SERVICE_URL 2>/dev/null || echo "Service unavailable")
  timestamp=$(date '+%H:%M:%S')
  echo "[$timestamp] Test $i: $response"
  sleep 2
done
```

### **Verify Successful Recovery**

```bash
# Check pod status
kubectl get pods -l app=sre-rollback-app -o wide
# Should show healthy v1 pods

# Verify service response
curl -s $SERVICE_URL
# Expected: "Version 1 - Stable release"

# Test health endpoint
curl -I $SERVICE_URL/health
# Should return HTTP 200

# Check deployment health
kubectl describe deployment sre-rollback-app | grep -A 5 "Conditions"
```

### **Review Rollback History**

```bash
# View rollout history
kubectl rollout history deployment/sre-rollback-app
# Shows: revision 1 (v1), revision 2 (v2), revision 3 (rollback to v1)

# Get details about current revision
kubectl rollout history deployment/sre-rollback-app --revision=3

# Verify we're back to v1 image
kubectl get deployment sre-rollback-app -o jsonpath='{.spec.template.spec.containers[0].image}'
# Should show: <YOUR-USERNAME>/sre-rollback-demo:v1
```

---

## Phase 5: ArgoCD-Driven Rollback

**Why?** Practice GitOps-based recovery for declarative infrastructure management.

### **Create ArgoCD Application**

First, let's create an ArgoCD application that syncs with our GitHub repository:

```bash
# Create ArgoCD application
cat > argocd-app.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sre-rollback-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR-USERNAME/sre-rollback-deployments.git
    targetRevision: HEAD
    path: v1  # Start with stable version
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# Replace YOUR-USERNAME with your actual GitHub username
sed -i '' 's/YOUR-USERNAME/your-actual-username/g' argocd-app.yaml

# Apply the ArgoCD application
kubectl apply -f argocd-app.yaml
```

### **Simulate Failure via GitOps**

```bash
# Update ArgoCD app to point to v2 (faulty version)
kubectl patch application sre-rollback-app -n argocd --type='merge' -p='{"spec":{"source":{"path":"v2"}}}'

# Watch ArgoCD sync the broken version
argocd app get sre-rollback-app
argocd app sync sre-rollback-app

# Monitor the deployment failure
kubectl get pods -l app=sre-rollback-app -w
```

### **ArgoCD Rollback Methods**

#### **Method 1: Web UI Rollback**

1. **Open ArgoCD Dashboard:**
   ```bash
   # Ensure port-forward is running
   kubectl port-forward svc/argocd-server -n argocd 8080:443 &
   
   # Open browser
   open http://localhost:8080  # macOS
   # or
   xdg-open http://localhost:8080  # Linux
   ```

2. **Navigate to Application:**
   - Click on `sre-rollback-app`
   - Go to **History** tab
   - Find the last successful revision (should be v1)
   - Click **Rollback** button
   - Confirm the rollback

#### **Method 2: CLI Rollback**

```bash
# List application history
argocd app history sre-rollback-app

# Rollback to previous revision (adjust revision number as needed)
argocd app rollback sre-rollback-app 1

# Verify rollback
argocd app get sre-rollback-app
# Should show: SyncStatus=Synced, HealthStatus=Healthy
```

#### **Method 3: Git-Based Rollback (Most GitOps Way)**

```bash
# Update the ArgoCD app to point back to v1
kubectl patch application sre-rollback-app -n argocd --type='merge' -p='{"spec":{"source":{"path":"v1"}}}'

# Sync the application
argocd app sync sre-rollback-app

# Watch the rollback
argocd app wait sre-rollback-app --health
```

### **Verify ArgoCD Rollback**

```bash
# Check application status
argocd app get sre-rollback-app

# Verify pods are healthy
kubectl get pods -l app=sre-rollback-app

# Test service
curl -s $SERVICE_URL
# Expected: "Version 1 - Stable release"

# Check sync status
argocd app list | grep sre-rollback-app
```

---

## Expected Outcome

**Congratulations!** You have successfully:

* **Deployed & validated** a stable v1 release with comprehensive health checks
* **Simulated a realistic production failure** with v2 and analyzed failure symptoms  
* **Recovered instantly** using `kubectl rollout undo` with real-time monitoring
* **Performed GitOps-based rollback** via ArgoCD with multiple methods
* **Explored rollout history** and gained audit trail visibility
* **Monitored service availability** throughout the incident lifecycle

### **Key Skills Developed:**

- **Incident Response**: Quick diagnosis and recovery under pressure
- **Tool Proficiency**: Both imperative (kubectl) and declarative (ArgoCD) approaches
- **Monitoring**: Real-time observability during deployment operations
- **GitOps Workflows**: Version-controlled infrastructure management
- **Troubleshooting**: Log analysis, event inspection, and failure diagnosis

---

## Next Steps

In **[Exercise 19: Chaos Engineering](../exercise19)**, you'll take your rollback skills to the next level by:

- **Introducing controlled failures** with Chaos Engineering tools
- **Validating rollback procedures** under various stress conditions
- **Testing system resilience** with pod kills, network latency, and resource constraints
- **Building confidence** that your recovery workflows handle real-world disruptions
- **Automating chaos experiments** to continuously validate system reliability

The rollback skills you've mastered here will be essential when chaos engineering exposes weaknesses in your systems - you'll know exactly how to recover quickly and safely!

---

**Ready to break things safely? Continue to Exercise 19: Chaos Engineering!**