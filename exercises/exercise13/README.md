# Automating Incident Response with AWX and Grafana

## Table of Contents

- [Learning Objectives](#learning-objectives)
- [Navigate to the Directory](#navigate-to-the-directory)
- [Part 1: Deploy Infrastructure (10 minutes)](#part-1-deploy-infrastructure-10-minutes)
- [Part 2: Configure AWX Project and Runbook](#part-2-configure-awx-project-and-runbook)
- [Part 3: API Integration Setup (10 minutes)](#part-3-api-integration-setup-10-minutes)
- [Part 4: Configure Grafana Alerting (15 minutes)](#part-4-configure-grafana-alerting-15-minutes)
- [Part 5: Test End-to-End Automation (10 minutes)](#part-5-test-end-to-end-automation-10-minutes)
- [Troubleshooting](#troubleshooting)
- [Final Objective](#final-objective)
- [Next Steps](#next-steps)

---

## Learning Objectives

By the end of this exercise, you will:

- Understand automated runbook execution concepts
- Deploy AWX in a Kubernetes environment
- Create and execute Ansible runbooks via AWX
- Configure Grafana alerts to trigger AWX jobs automatically
- Implement end-to-end automated incident response

---

## Navigate to the Directory

Before proceeding, navigate to the correct directory:

```bash
cd sre-academy-training/exercises/exercise13
```

---

## Part 1: Deploy Infrastructure

### Step 1: Automated Deployment

Run the provided script to deploy the complete infrastructure:

```bash
./cluster.sh
```

**What this does:**

- Starts fresh Minikube cluster with increased resources
- Deploys AWX operator and instance
- Installs complete observability stack (Prometheus, Grafana, Jaeger, Loki)
- Deploys sample application for monitoring

### Step 2: Verify Deployment

Wait for the script to complete, then verify all services are running:

```bash
# Check all pods are running (should see ~20+ pods across multiple namespaces)
kubectl get pods -A

# Expected output should show pods like:
# awx              awx-demo-web-xxx                    3/3     Running
# awx              awx-demo-task-xxx                   4/4     Running  
# monitoring       grafana-deployment-xxx              1/1     Running
# monitoring       prometheus-deployment-xxx           1/1     Running
```

### Step 3: Extract AWX Credentials

```bash
# Get AWX admin password (SAVE THIS - you'll need it!)
kubectl get secret awx-demo-admin-password -o jsonpath="{.data.password}" -n awx | base64 --decode ; echo

# Example output: SmLs6RC0VN9aMKXxPrIpSpD3ujmaBCzp
```

### Step 4: Access The AWX UI

```bash
# Get AWX URL (note this IP:port for later)
minikube service awx-demo-service -n awx --url
# Example output: http://127.0.0.1:53331
```

> ⚠️ **Common Issues:**
> - If pods are stuck in `Pending`, wait 2-3 minutes for resources to allocate
> - If services don't respond, check pod status: `kubectl describe pod <pod-name> -n <namespace>`

---

## Part 2: Configure AWX Project and Runbook

### Step 5: Create AWX Project

1. **Access AWX Web UI** using the URL from Step 4
2. **Login** with username `admin` and the password from Step 3
3. **Navigate to Projects** → Click **"+ Add"**
4. **Configure Project:**
   - **Name**: `SRE Project`
   - **Organization**: `Default`
   - **Source Control Type**: `Git`
   - **Source Control URL**:
     ```
     https://github.com/cguillencr/sre-abc-training.git
     ```
   - **Source Control Branch/Tag/Commit**: leave blank (default = `main`)
   - Leave the rest of the fields unchanged and click **Save**

> **Note:** This repository is public and read-only. You will **not push any changes** to it. It's used only so AWX can load the playbook `collect-status-application.yaml` during the lab.

#### 🔐 Why Not Use the IBM Internal Repo?

Because:

- Students not on VPN or without access would break the exercise
- It may require authentication setup in AWX (SSH keys or GitHub App token)
- The repo content is static during the exercise, so the public fork is sufficient

> **Example:** This is how your AWX project should look after saving:
>
> ![AWX SRE Project Configuration](./images/awx-sre-project.png)

### Step 6: Create Runbook (Job Template)

1. **Navigate to Templates** → Click **"+ Add" → Job Template**
2. **Configure Template:**
   - **Name**: `Collect System Status`
   - **Job Type**: `Run`
   - **Inventory**: `Demo Inventory`
   - **Project**: `SRE Project` (from Step 5)
   - **Playbook**: `exercises/exercise13/collect-status-application.yaml`
   - **Credential**: `Demo Credential`
   - Click **Save**

> **Example:** Your Job Template setup in AWX should look similar to this:
>
> ![AWX Job Template Setup](./images/awx-template-setup.png)

### Step 7: Test Manual Execution

1. **Find your job template** in the Templates list
2. **Click the rocket icon** (🚀) to launch
3. **Verify successful execution** (should show green checkmark)

**Expected Result:** Job should complete successfully and show system information in the output logs.

> **Example:** After clicking the rocket icon, your job should appear like this in the Jobs list:
>
> ![AWX Jobs List](./images/awx-jobs.png)

> **Note:** If the job shows a green checkmark but no output appears, try refreshing the page. AWX sometimes delays the display of job logs in the UI until you reload.

### Deep Dive: Understanding the Runbook

Let's examine what our runbook actually does:

```yaml
# Content of collect-status-application.yaml
---
- name: Collect System Diagnostics for Incident Response
  hosts: localhost
  gather_facts: yes
  tasks:
    - name: Get system uptime
      command: uptime
      register: system_uptime
      
    - name: Check disk usage
      command: df -h
      register: disk_usage
      
    - name: Get running processes
      command: ps aux --sort=-%cpu | head -20
      register: top_processes
      
    - name: Check Kubernetes pod status
      command: kubectl get pods -A
      register: k8s_pods
      ignore_errors: yes
      
    - name: Display collected information
      debug:
        msg: |
          === INCIDENT RESPONSE DIAGNOSTICS ===
          System Uptime: {{ system_uptime.stdout }}
          
          Top CPU Processes:
          {{ top_processes.stdout }}
          
          Kubernetes Status:
          {{ k8s_pods.stdout }}
```

**Why this matters in SRE:**

- **Standardized response**: Every incident gets the same diagnostic information
- **Time savings**: No manual command execution during incidents
- **Documentation**: All actions are logged automatically
- **Consistency**: Eliminates human error in diagnostic collection

---

## Part 3: API Integration Setup

### Step 8: Create API Application

1. **Navigate to Applications** (under Administration)
2. **Click "+ Add"**
3. **Configure Application:**
   - **Name**: `Grafana Integration`
   - **Organization**: `Default`
   - **Authorization Grant Type**: `Resource owner password-based`
   - **Client Type**: `Confidential`
   - Click **Save**
4. **Copy the Client ID and Secret** (you'll need these later)

> ℹ️ **Important:** This is the only time the API token will be shown. Make sure to copy and save it securely — you won't be able to retrieve it later.

### Step 9: Generate a Personal API Token

1. **Go to Users** (under Access) → Click on admin → **Tokens** → **"+ Add"**
2. **Configure Token:**
   - **Application**: `Grafana Integration`
   - **Scope**: `Write`
   - Click **Save**
3. **Copy the Token** (you'll need this for Grafana)

> ℹ️ **Important:** This is the only time the **token value** and associated **refresh token** will be shown. Make sure to copy and store them securely. You won't be able to retrieve them again from the UI.

### Step 10: Test API Access

> **Open a new terminal window** for this step. You'll be using `curl` to interact with the AWX API directly.  
> Keep your current Minikube terminal open if it's running port forwarding or watching pods.

```bash
# Replace with your actual values
export AWX_TOKEN="your_token_here"
export AWX_URL="http://127.0.0.1:<random-port>"
```

> **Note:** The AWX URL will always start with `http://127.0.0.1:<random-port>`  
> This value comes from the output of:
>
> ```bash
> minikube service awx-demo-service -n awx --url
> ```
>
> The port number is dynamically assigned and will be different for each student or environment. Be sure to use the full output as-is.

#### Test API connectivity

```bash
curl -s -H "Authorization: Bearer $AWX_TOKEN" \
     -H "Content-Type: application/json" \
     $AWX_URL/api/v2/me/ | jq '.results[] | {id, username, is_superuser}'
```

You should receive a JSON response with your user info:

```json
{
  "id": 1,
  "username": "admin",
  "is_superuser": true,
  ...
}
```

### Deep Dive: AWX REST API

Understanding the API calls that power automation.

#### 1. List all job templates

```bash
curl -s -H "Authorization: Bearer $AWX_TOKEN" \
     $AWX_URL/api/v2/job_templates/ | jq '.results[] | {id, name}'
```

This will return something like:

```json
{
  "id": 9,
  "name": "Collect System Status"
}
{
  "id": 7,
  "name": "Demo Job Template"
}
```

> **Note:** Job Template IDs vary. Use the correct `id` from your own environment in the next step.

#### 2. Launch a job (THIS IS WHAT GRAFANA WILL DO)

```bash
curl -s -X POST \
     -H "Authorization: Bearer $AWX_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{}' \
     $AWX_URL/api/v2/job_templates/9/launch/ | jq '{job, status}'
```

> Replace `9` with the ID of your own `Collect System Status` job template.

The response will look like:

```json
{
  "job": 5,
  "status": "pending"
}
```

#### 3. Monitor job status

```bash
curl -s -H "Authorization: Bearer $AWX_TOKEN" \
     $AWX_URL/api/v2/jobs/3/ | jq '.status'
```

> Status will progress through:
>
> - "pending"
> - "running"
> - "successful"

**Why API automation matters:**

- **Integration**: Any system can trigger runbooks (Grafana, PagerDuty, custom scripts)
- **Programmatic control**: No human needed to click buttons during incidents
- **Scalability**: Handle hundreds of concurrent runbook executions

> **Why this step is important:**
>
> These API calls demonstrate how Grafana will trigger AWX jobs automatically when an alert fires.
>
> By testing the API manually, you're confirming:
>
> - The runbook can be launched without any human intervention
> - AWX is reachable and properly secured via token-based access
> - Your setup supports real-time automation from monitoring systems like Grafana
>
> This is the core of an automated incident response system: when something goes wrong, your monitoring tools don't just send a notification — they can trigger diagnostic or remediation actions automatically through AWX.
>
> This manual API test ensures the pieces are working *before* connecting them together with alerting logic.

---

## Part 4: Configure Grafana Alerting

### Step 11: Access Grafana

> **Open a new terminal window** if your current one is running a port-forward or watching AWX logs.  
> You'll need this terminal to retrieve the Grafana URL and access the web interface.

```bash
# Get Grafana URL
minikube service grafana-service -n monitoring
```

Use the URL output (typically `http://127.0.0.1:<port>`) to open Grafana in your browser.

**Default login:**

- **Username**: `admin`
- **Password**: `admin`

### Step 12: Create Contact Point

1. **Navigate to** `Alerting → Contact Points → + Add Contact Point`

2. **Configure the Webhook Contact Point:**
   - **Name**: `AWX Runbook Trigger`
   - **Integration**: `Webhook`
   - **URL**:
     ```
     http://127.0.0.1:30100/api/v2/job_templates/9/launch/
     ```
   - **HTTP Method**: `POST`

3. **Authorization Header:**
   - **Scheme**: `Bearer`
   - **Credentials**: `<YOUR_API_TOKEN>` (e.g., `MZRXFg1SN1xQPzMhzRyV2csm5Phxe`)

4. **Extra Headers:**
   - Add:
     - **Key**: `Content-Type`
     - **Value**: `application/json`

5. **Save** the contact point

**Explanation:**

This sets up a webhook that triggers an AWX job template (ID `9`) whenever an alert fires. It includes:

- A Bearer token for authorization
- A `Content-Type: application/json` header
- POST request to AWX job template launch URL

> **Example:** Configuration for the AWX Runbook Trigger contact point using the Webhook integration in Grafana's latest UI.
>
> ![AWX Runbook Trigger Contact Point](./images/grafana-contact-point-awx.png)

### Step 13: Create Alert Rule

> **Note:** Grafana's alerting UI can vary slightly between versions. These steps apply to the unified alerting system.

1. In Grafana, go to **Alerting** → **Alert Rules**
2. Click **"+ New alert rule"**

#### 1. Enter alert rule name

- **Name**: `High Application Latency`

#### 2. Define query and alert condition

- Click the **"Code"** tab inside the query box (or type directly if you're in "Builder")
- Paste this PromQL query:
  ```promql
  sum(rate(otel_collector_span_metrics_duration_milliseconds_bucket[5m])) by (span_name)
  ```

- Set the **evaluation interval** (click Options) to `1m`
- Below, in **Alert condition**, set:
  - **WHEN** Query
  - **IS ABOVE**
  - `1`

![High Application Latency Alert Rule](./images/grafana-alert-high-latency.png)

#### 3. Add folder and labels (optional but recommended)

- **Folder**: You must select or create a folder to store your alert rule (e.g., alerts)
- **Labels**: Two custom labels were added—severity and warning. These labels are essential for alert routing and filtering in contact points or silences

#### 4. Set Evaluation Behavior

- **Evaluation group**: Set to latency-group, indicating alerts are grouped and evaluated together every 1 minute
- **Pending period**: 1 minute. The alert must breach its condition continuously for this duration before firing
- **Keep firing**: Set to 0s, so the alert clears as soon as the condition returns to normal

![Grafana Alert Folder and Evaluation Behavior](./images/grafana-alert-folder-evaluation.png)

#### 5. Configure notifications

This step defines who receives alerts when a rule fires.

- **Recipient system**: Alertmanager (Grafana-managed)
- **Contact point selected**: AWX Runbook Trigger
  - This is a custom contact point you previously created to trigger an AWX job (runbook) when an alert fires
- **Link option available**: You can view or create other contact points using the View or create contact points link

Optional sections like muting, grouping, and timing are collapsed but can be configured for advanced control over how alerts behave when triggered repeatedly or simultaneously.

![Grafana Alert Notification Settings](./images/grafana-alert-notification-settings.png)

Click **Save**

![Grafana Alert Result – High Latency](./images/grafana-alert-result-high-latency.png)

### Deep Dive: Understanding the Alert Query

Let's break down what this PromQL query does:

```promql
# Our alert query explained:
sum(rate(otel_collector_span_metrics_duration_milliseconds_bucket[5m])) by (span_name)

# Breaking it down:
# 1. otel_collector_span_metrics_duration_milliseconds_bucket
#    ↳ OpenTelemetry histogram buckets measuring request duration

# 2. rate(...[5m])
#    ↳ Calculate per-second rate over 5-minute window

# 3. sum(...) by (span_name)
#    ↳ Aggregate all buckets, grouped by operation name

# This effectively measures: "requests per second" for each operation
# When this goes ABOVE 1 req/sec, it indicates high traffic/latency
```

**Why this metric matters:**

- **Leading indicator**: Rate increase often precedes latency issues
- **Actionable**: Clear threshold that indicates when intervention is needed
- **Observable**: Based on actual user request patterns

### Deep Dive: Webhook Integration

Here's what happens when Grafana sends the webhook:

```bash
# This is the EXACT HTTP call Grafana makes when alert fires:
curl -X POST \
  -H "Authorization: Bearer wpSCyIlK1j8Dy8zM7wTmZ7bbkdgQVE" \
  -H "Content-Type: application/json" \
  -d '{
    "receiver": "AWX Runbook Trigger",
    "status": "firing",
    "alerts": [
      {
        "status": "firing",
        "labels": {
          "alertname": "High Application Latency",
          "span_name": "http_request"
        },
        "annotations": {
          "summary": "Application latency is above threshold"
        },
        "startsAt": "2025-07-29T19:45:00Z"
      }
    ],
    "groupLabels": {},
    "commonLabels": {
      "alertname": "High Application Latency"
    },
    "commonAnnotations": {},
    "externalURL": "http://192.168.49.2:32000"
  }' \
  http://192.168.49.2:30100/api/v2/job_templates/13/launch/
```

**The automation chain:**

1. **Application** experiences high latency
2. **OpenTelemetry** captures metrics
3. **Prometheus** stores time-series data
4. **Grafana** evaluates alert rule
5. **Webhook** triggers AWX job automatically
6. **AWX** executes diagnostic runbook
7. **Results** logged for incident responders

---

### Deep Dive: Observing the Full Pipeline

This section helps you **watch the full alerting and automation pipeline** in real time — from metrics spikes to alert triggers and AWX runbook execution.

#### What You'll Observe:

When the app degrades or traffic spikes:

1. **Latency increases** → Prometheus metrics reflect it
2. **Grafana alert fires** → Visual red status on alert panel
3. **Alert triggers webhook** → AWX job is created automatically
4. **AWX job runs a playbook** → You’ll see a short-lived pod
5. **Pod completes** → Job logs contain diagnostics; pod gets cleaned up

---

### Suggested Terminal Setup

Run these in **four parallel terminals** for best visibility:

#### **Terminal 1: Watch AWX Job Creation**

```bash
# Continuously watch for AWX job creations
while true; do clear; kubectl get jobs -n awx; sleep 2; done
```

> Look for new `automation-job-*` jobs being created when alerts fire.

---

#### **Terminal 2: View AWX Job Logs**

```bash
# Wait for the job pod to appear (check Terminal 1 output)
kubectl get pods -n awx | grep automation-job

# Once the pod appears, stream its logs:
kubectl logs -n awx <pod-name> -f
```

> These pods are short-lived. If the job finishes fast, the pod might be gone — check Terminal 1 again and be quick!

---

#### **Terminal 3: View Prometheus Metrics**

```bash
kubectl port-forward -n monitoring svc/prometheus-service 9090:9090
```

Then open your browser:
[http://localhost:9090](http://localhost:9090)
Run the following query:

```promql
sum(rate(otel_collector_span_metrics_duration_milliseconds_bucket[5m])) by (span_name)
```

> You should see a spike in latency when degradation is triggered.

> ![Prometheus Latency Query – Span Names](./images/prometheus-latency-query-span-names.png)

---

#### **Terminal 4: Watch for Job Pods**

```bash
# Watch for the automation-job pod itself
while true; do clear; kubectl get pods -n awx | grep automation-job; sleep 2; done
```

> The pod will be `Running`, then switch to `Completed`, and finally disappear.

---

### Testing It End-to-End

Trigger the alert using:

```bash
kubectl exec -n application deployment/sre-abc-training-app -- curl -X POST http://localhost:8080/degrade
```

Or simulate load with:

```bash
for i in {1..100}; do
  kubectl exec -n application deployment/sre-abc-training-app -- curl http://localhost:8080/api/data &
done
```

---

### Success Criteria

| Event                 | What to Look For                                |
| --------------------- | ----------------------------------------------- |
| **Metric spike**      | Latency increase in Prometheus                  |
| **Alert fired**       | Alert panel turns red in Grafana                |
| **AWX job triggered** | New `automation-job-*` appears in AWX namespace |
| **Logs available**    | `kubectl logs` shows Ansible playbook execution |
| **Pod cleanup**       | Pod auto-deletes after successful run           |

---

## Troubleshooting

### Common Issues

#### AWX not accessible

```bash
# Get the correct service URL
minikube service awx-demo-service -n awx --url

# If still not working, check pod status
kubectl get pods -n awx
kubectl describe pod -n awx -l app.kubernetes.io/name=awx-demo

# Check logs for errors
kubectl logs -n awx -l app.kubernetes.io/component=web
```

#### API calls failing

```bash
# Test API connectivity step by step
export AWX_URL="http://192.168.49.2:30100"
export AWX_TOKEN="your_token_here"

# 1. Test basic connectivity
curl -v $AWX_URL/api/v2/

# 2. Test authentication
curl -H "Authorization: Bearer $AWX_TOKEN" $AWX_URL/api/v2/me/

# 3. Find your job template ID
curl -H "Authorization: Bearer $AWX_TOKEN" \
     $AWX_URL/api/v2/job_templates/ | jq '.results[] | {id, name}'

# 4. Test job launch
curl -X POST \
     -H "Authorization: Bearer $AWX_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{}' \
     $AWX_URL/api/v2/job_templates/YOUR_ID/launch/
```

#### Alerts not triggering AWX

```bash
# Check Grafana can reach AWX
kubectl exec -n monitoring deployment/grafana-deployment -- \
  curl -v http://192.168.49.2:30100/api/v2/

# Test webhook manually
kubectl exec -n monitoring deployment/grafana-deployment -- \
  curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}' \
  http://192.168.49.2:30100/api/v2/job_templates/13/launch/

# Check Grafana notification logs
kubectl logs -n monitoring deployment/grafana-deployment | grep -i webhook
```

#### Prometheus metrics missing

```bash
# Check OpenTelemetry collector is running
kubectl get pods -n opentelemetry

# Test metrics endpoint
kubectl exec -n opentelemetry deployment/otel-collector -- \
  curl http://localhost:8889/metrics | grep otel_collector_span

# Verify application is generating traces
kubectl logs -n application deployment/sre-abc-training-app
```

---

## Final Objective

By completing this exercise, you should have implemented an automated incident response workflow triggered by Grafana alerts.

### Goal

Each time an alert is fired in Grafana, a diagnostic runbook should be executed automatically via AWX. This setup enhances incident response by:

- Collecting real-time system diagnostics
- Reducing manual intervention and response time
- Ensuring consistent and repeatable incident handling

### Alert Integration Example

As the application degrades due to simulated conditions, alerts will be triggered:

![grafana-error-triggering](./images/grafana-error-triggering.png)

Each alert should automatically execute your runbook in AWX:

![awx-template-job-executions](./images/awx-template-job-executions.png)

---

## Next Steps

In [Exercise 14](../exercise14), we will conduct an **Operational Readiness Review (ORR)** to ensure your system meets production-level expectations.

You should now be confident with:

- Deploying AWX and configuring job templates through the UI and API
- Integrating alerting systems (Grafana) with automation tools (AWX)
- Writing diagnostic Ansible runbooks for incident response
- Testing and validating alert-triggered automation in a Kubernetes environment

---