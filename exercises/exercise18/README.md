# **Rolling Updates & Rollbacks in Kubernetes**

## **Table of Contents**

- [Scenario: A Bad Release in Production](#scenario-a-bad-release-in-production)
- [Why Rollbacks Matter for SRE](#why-rollbacks-matter-for-sre)
- [Learning Objectives](#learning-objectives)
- [Prerequisites and GitHub Repo Preparation](#prerequisites-and-github-repo-preparation)
- [Cleanup](#cleanup)
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

In a production environment, every second of downtime directly impacts your users and your business's bottom line. When a new release introduces an unexpected regression—or worse, a total outage—your first priority is to restore service as quickly as possible. Rollbacks provide a proven safety valve: instead of scrambling to diagnose and patch on the fly, you can revert to the last known-good configuration with a single command.

By automating rollbacks through Kubernetes' native `rollout undo` or through a GitOps control plane like ArgoCD, you eliminate error-prone manual steps, enforce consistency, and reduce human intervention to near zero. This not only speeds up recovery but also ensures that every change—and every reversion—is recorded in your cluster's deployment history and in Git. Together, those audit trails offer complete visibility into who changed what, when, and why.

From an SRE metrics perspective, fast and reliable rollbacks drive down **Mean Time To Recovery (MTTR)**—an SRE golden metric—helping you meet aggressive SLAs (for many teams, MTTR targets are under five minutes). Quick reversion also protects your **error budget** by minimizing how much downtime eats into your allotted margin of failure. And by bounding the impact of a bad release (your "blast radius"), rollbacks preserve user trust and keep postmortems focused and data-driven: you can pinpoint exactly when and how the system diverged from its healthy state.

---

## Learning Objectives

In this exercise you will author and manage two distinct application versions—a stable v1 release and an intentionally broken v2—to practice full rollback workflows. You'll begin by writing versioned Kubernetes manifests and deploying the stable release, verifying its health both at the pod level and through service endpoints. Next, you will introduce a failure by rolling out the broken version, then gather diagnostic data from pod logs, events, and rollout status.

With a clear understanding of the failure, you will execute a native Kubernetes rollback using `kubectl rollout undo`, observing how the cluster automatically restores the previous deployment. You will then repeat that recovery through ArgoCD's GitOps model—rolling back declaratively in the UI and via the `argocd` CLI—reinforcing the differences between imperative and declarative incident response.

Throughout the lab, you will inspect rollout history, monitor events and logs, and watch your service return to a healthy state in real time. By the end, you'll not only have hands-on experience with both manual and automated rollback techniques, but also an intuitive grasp of how these patterns drive down MTTR, preserve error budgets, and underpin resilient SRE practices.

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
kubectl version          # you'll see both Client and Server versions
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

## Cleanup

Before you start this exercise, remove any leftover demo resources:

```bash
# Remove ArgoCD applications (ignore if they don't exist)
kubectl delete application sre-app sre-app-dev sre-app-staging sre-app-prod \
  -n argocd --ignore-not-found

# Delete demo namespaces
kubectl delete namespace application dev staging production \
  --ignore-not-found

# Wipe any orphaned sre-demo deployments/services
for ns in application dev staging production; do
  kubectl delete deployment,service -n "$ns" --all --ignore-not-found
done

# Confirm no leftover sre-demo pods or services
kubectl get pods -A | grep sre-demo
```

---

## Phase 1: Prepare Versioned Manifests

We'll create two folders—`v1/` (stable) and `v2/` (faulty)—each with a Deployment, Service, and ConfigMap. This simulates how teams manage different versions of their applications using reliable public container images.

### **Create Stable Version (v1)**

```bash
# Create directory structure
mkdir -p v1
```

```bash
# Stable v1 deployment using nginx
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
        image: nginx:1.21-alpine  # Stable, reliable image
        ports: 
        - containerPort: 80
        # Health checks for safer deployments
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
        # Mount custom content to differentiate versions
        volumeMounts:
        - name: html-content
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
      volumes:
      - name: html-content
        configMap:
          name: v1-content
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
  - port: 80
    targetPort: 80
  type: NodePort
EOF

# ConfigMap with v1 content
cat > v1/configmap.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: v1-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>SRE Rollback Demo v1</title>
        <style>
            body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #f0f8ff; }
            .version { color: #28a745; font-size: 2em; margin: 20px 0; }
            .status { color: #155724; background: #d4edda; padding: 15px; border-radius: 5px; display: inline-block; }
        </style>
    </head>
    <body>
        <h1>SRE Rollback Demo</h1>
        <div class="version">✅ Version 1.0 - Stable Release</div>
        <div class="status">
            <strong>Status:</strong> Healthy and Running<br>
            <strong>Deployed:</strong> <span id="timestamp"></span>
        </div>
        <p>This is the stable version that works correctly and passes all health checks.</p>
        <script>
            document.getElementById('timestamp').textContent = new Date().toLocaleString();
        </script>
    </body>
    </html>
EOF
```

### **Create Faulty Version (v2)**

```bash
# Create directory for faulty version
mkdir -p v2
```

```bash
# Faulty v2 deployment (intentionally broken with non-existent image)
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
        image: nginx:broken-v2-tag  # This image tag doesn't exist - causes ImagePullBackOff
        ports: 
        - containerPort: 80
        # Same health checks as v1 (but won't work due to broken image)
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
        - name: html-content
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
      volumes:
      - name: html-content
        configMap:
          name: v2-content
EOF

# Same service configuration for v2
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
  - port: 80
    targetPort: 80
  type: NodePort
EOF

# ConfigMap for v2 (won't be used due to broken image, but shows intent)
cat > v2/configmap.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: v2-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>SRE Rollback Demo v2</title>
        <style>
            body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #ffe6e6; }
            .version { color: #dc3545; font-size: 2em; margin: 20px 0; }
            .status { color: #721c24; background: #f8d7da; padding: 15px; border-radius: 5px; display: inline-block; }
        </style>
    </head>
    <body>
        <h1>SRE Rollback Demo</h1>
        <div class="version">❌ Version 2.0 - Broken Release</div>
        <div class="status">
            <strong>Status:</strong> Unhealthy - Critical Issues Detected<br>
            <strong>Deployed:</strong> <span id="timestamp"></span>
        </div>
        <p>This version has critical issues and should be rolled back immediately!</p>
        <script>
            document.getElementById('timestamp').textContent = new Date().toLocaleString();
        </script>
    </body>
    </html>
EOF
```

```bash
# Stage your new version folders
git add v1 v2

# Commit with a clear, descriptive message
git commit -m "feat: add v1 (stable nginx) and v2 (broken image) manifests for rollback demo"

# Push to your GitHub remote
git push origin main
```

---

## Phase 2: Deploy & Verify v1 (Stable)

**Why?** Establish a known-good baseline before simulating failure.

### **Deploy the Stable Version**

```bash
# Apply v1 manifests (includes deployment, service, and configmap)
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

# Verify ConfigMap was created
kubectl get configmap v1-content
```

### **Test Service Accessibility**

```bash
# Get service URL
SERVICE_URL=$(minikube service sre-rollback-service --url)
echo "Service URL: $SERVICE_URL"

# Test the application
curl -s $SERVICE_URL
# Expected output: HTML page showing "Version 1.0 - Stable Release"

# Test with browser-friendly output
curl -s $SERVICE_URL | grep -E "(Version|Status)" || echo "Service is responding with HTML content"

# Or open in browser (macOS/Linux)
open $SERVICE_URL  # macOS
# or
xdg-open $SERVICE_URL  # Linux
```

### **Verification Checklist**

✅ Pod is in "Running" state  
✅ Service responds with v1 HTML content  
✅ ConfigMap is properly mounted  
✅ No error events in cluster  

```bash
# Check for any error events
kubectl get events --sort-by='.metadata.creationTimestamp' | tail -5

# Verify nginx is serving the custom content
curl -s $SERVICE_URL | head -10
```

---

## Phase 3: Simulate Faulty v2 Release

**Why?** Introduce a realistic production failure to practice incident response.

### **Deploy the Broken Version**

```bash
# Apply v2 manifests (includes the broken image)
kubectl apply -f v2/

# Try to monitor deployment (this will likely hang or show errors)
echo "Monitoring deployment progress (this will fail due to broken image)..."
kubectl rollout status deployment/sre-rollback-app --timeout=60s || echo "❌ Deployment failed or timed out as expected"
```

### **Analyze the Failure**

Open multiple terminal windows to monitor the failure:

**Terminal 1 - Watch pods:**
```bash
# Watch pod status in real-time
watch -n 2 'kubectl get pods -l app=sre-rollback-app'
# You should see pods in "ImagePullBackOff" or "ErrImagePull" state
```

**Terminal 2 - Check pod details:**
```bash
# Get the failing pod name
FAILING_POD=$(kubectl get pods -l app=sre-rollback-app --sort-by='.metadata.creationTimestamp' -o jsonpath='{.items[-1].metadata.name}')
echo "Checking details for pod: $FAILING_POD"

# Describe the failing pod to see image pull errors
kubectl describe pod $FAILING_POD

# Check events for this specific pod
kubectl get events --field-selector involvedObject.name=$FAILING_POD --sort-by='.metadata.creationTimestamp'
```

**Terminal 3 - Service status:**
```bash
# Test service availability (should still work from old pods if any exist)
while true; do
  response_code=$(curl -s -o /dev/null -w "%{http_code}" $SERVICE_URL 2>/dev/null || echo "000")
  timestamp=$(date '+%H:%M:%S')
  if [ "$response_code" = "200" ]; then
    echo "[$timestamp] ✅ Service responding (HTTP $response_code)"
  else
    echo "[$timestamp] ❌ Service unavailable (HTTP $response_code)"
  fi
  sleep 3
done
```

### **Gather Diagnostic Information**

```bash
# Check deployment status and conditions
kubectl describe deployment sre-rollback-app

# View recent events
kubectl get events --sort-by='.metadata.creationTimestamp' | tail -10

# Check ReplicaSet history (you should see old and new ReplicaSets)
kubectl get rs -l app=sre-rollback-app -o wide

# Check rollout status
kubectl rollout status deployment/sre-rollback-app --timeout=10s || echo "Rollout is stuck"

# See the problematic image that's causing the failure
kubectl get deployment sre-rollback-app -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""
```

**Expected Failure Symptoms:**
- Pods in `ImagePullBackOff` or `ErrImagePull` state
- Error events showing "Failed to pull image" or "repository does not exist"
- Service may still respond if old pods haven't been terminated yet
- Deployment shows "1 unavailable" replica

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
# Monitor deployment status in real-time
watch -n 2 'kubectl get pods -l app=sre-rollback-app'
# Should see new pods starting and old broken pods terminating
```

**Terminal 2 - Service availability:**
```bash
# Monitor service recovery
echo "Monitoring service recovery..."
for i in {1..10}; do
  response=$(curl -s $SERVICE_URL 2>/dev/null | grep -o "Version [0-9.]*" || echo "Service unavailable")
  timestamp=$(date '+%H:%M:%S')
  echo "[$timestamp] Test $i: $response"
  sleep 2
done
```

### **Verify Successful Recovery**

```bash
# Check pod status
kubectl get pods -l app=sre-rollback-app -o wide
# Should show healthy pods running nginx:1.21-alpine

# Verify service response
curl -s $SERVICE_URL | grep -E "(Version|Status)" || echo "HTML content restored"

# Test direct health check (nginx root path)
curl -I $SERVICE_URL
# Should return HTTP 200

# Check deployment health
kubectl describe deployment sre-rollback-app | grep -A 5 "Conditions"

# Verify we're back to the working image
kubectl get deployment sre-rollback-app -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""
```

### **Review Rollback History**

```bash
# View rollout history
kubectl rollout history deployment/sre-rollback-app
# Shows: revision 1 (v1), revision 2 (broken v2), revision 3 (rollback to v1)

# Get details about current revision
kubectl rollout history deployment/sre-rollback-app --revision=3

# Check which ConfigMap is active
kubectl get deployment sre-rollback-app -o yaml | grep -A 5 "configMap"

# Verify ConfigMap cleanup (v2-content might still exist but not be used)
kubectl get configmaps
```

---

## Phase 5: ArgoCD-Driven Rollback

**Why?** Practice GitOps-based recovery for declarative infrastructure management.

### **Create ArgoCD Application**

First, let's create an ArgoCD application that syncs with our GitHub repository:

```bash
# Create ArgoCD application manifest
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
    syncOptions:
    - CreateNamespace=true
EOF

# Replace YOUR-USERNAME with your actual GitHub username
sed -i.bak 's/YOUR-USERNAME/your-actual-github-username/g' argocd-app.yaml

# Apply the ArgoCD application
kubectl apply -f argocd-app.yaml

# Wait for ArgoCD to sync
echo "Waiting for ArgoCD to sync the application..."
sleep 10
argocd app get sre-rollback-app
```

### **Simulate Failure via GitOps**

```bash
# Update ArgoCD app to point to v2 (faulty version)
kubectl patch application sre-rollback-app -n argocd --type='merge' -p='{"spec":{"source":{"path":"v2"}}}'

# Watch ArgoCD sync the broken version
echo "ArgoCD will now sync the broken v2 version..."
argocd app sync sre-rollback-app

# Monitor the deployment failure
echo "Monitoring pods during GitOps deployment..."
kubectl get pods -l app=sre-rollback-app -w &
WATCH_PID=$!

# Let it run for 30 seconds then stop the watch
sleep 30
kill $WATCH_PID 2>/dev/null || true
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
LAST_GOOD_REVISION=$(argocd app history sre-rollback-app | grep "v1" | tail -1 | awk '{print $1}')
echo "Rolling back to revision: $LAST_GOOD_REVISION"
argocd app rollback sre-rollback-app $LAST_GOOD_REVISION

# Verify rollback
argocd app get sre-rollback-app
# Should show: SyncStatus=Synced, HealthStatus=Healthy
```

#### **Method 3: Git-Based Rollback (Most GitOps Way)**

```bash
# Update the ArgoCD app to point back to v1 via kubectl patch
kubectl patch application sre-rollback-app -n argocd --type='merge' -p='{"spec":{"source":{"path":"v1"}}}'

# Sync the application
argocd app sync sre-rollback-app

# Watch the rollback
argocd app wait sre-rollback-app --health --timeout 180
```

### **Verify ArgoCD Rollback**

```bash
# Check application status in ArgoCD
argocd app get sre-rollback-app

# Verify pods are healthy
kubectl get pods -l app=sre-rollback-app

# Test service
curl -s $SERVICE_URL | grep -E "(Version|Status)" || echo "Service restored"

# Check sync status
argocd app list | grep sre-rollback-app

# Verify the image is back to the working version
kubectl get deployment sre-rollback-app -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""

# Clean up the background port-forward if running
pkill -f "kubectl port-forward svc/argocd-server" 2>/dev/null || true
```

---

## Expected Outcome

**Congratulations!** You have successfully:

* **Deployed & validated** a stable v1 release using nginx with custom content and comprehensive health checks
* **Simulated a realistic production failure** with v2 using a non-existent image tag and analyzed failure symptoms  
* **Recovered instantly** using `kubectl rollout undo` with real-time monitoring of the recovery process
* **Performed GitOps-based rollback** via ArgoCD using multiple methods (UI, CLI, and declarative patching)
* **Explored rollout history** and gained audit trail visibility across both imperative and declarative approaches
* **Monitored service availability** throughout the incident lifecycle without requiring custom Docker images

### **Key Skills Developed:**

- **Incident Response**: Quick diagnosis and recovery under pressure using standard container images
- **Tool Proficiency**: Both imperative (kubectl) and declarative (ArgoCD) approaches to rollback management
- **Monitoring**: Real-time observability during deployment operations and failure scenarios
- **GitOps Workflows**: Version-controlled infrastructure management with proper audit trails
- **Troubleshooting**: Image pull error analysis, event inspection, and systematic failure diagnosis
- **Production Readiness**: Using reliable, public images to simulate real-world deployment scenarios

### **What You Learned About Rollback Patterns:**

- **ImagePullBackOff errors** are common production failures that require immediate rollback
- **Multiple recovery paths** provide flexibility during incidents (kubectl vs ArgoCD vs Git-based)
- **Health checks and monitoring** are essential for detecting and validating recovery
- **Rollout history** provides complete audit trails for post-incident analysis
- **GitOps patterns** ensure all changes are tracked and recoverable through Git

---

## Next Steps

In **[Exercise 19](../exercise19)**, you'll take your rollback skills to the next level by:

- **Introducing controlled failures** with Chaos Engineering tools like Chaos Monkey and Litmus
- **Validating rollback procedures** under various stress conditions including network partitions and resource exhaustion
- **Testing system resilience** with pod kills, network latency, CPU spikes, and memory pressure
- **Building confidence** that your recovery workflows handle real-world disruptions beyond simple image failures
- **Automating chaos experiments** to continuously validate system reliability and rollback effectiveness
- **Measuring MTTR improvements** through systematic chaos testing and rollback optimization

The rollback skills you've mastered here will be essential when chaos engineering exposes weaknesses in your systems - you'll know exactly how to recover quickly and safely from any type of failure!

---

**Ready to break things safely and build antifragile systems? Continue to Exercise 19: Chaos Engineering!**