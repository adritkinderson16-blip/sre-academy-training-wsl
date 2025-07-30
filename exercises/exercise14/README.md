# Installation and Configuration Using Helm Charts

## Table of Contents

- [Introduction to Helm](#introduction-to-helm)  
  - [What is Helm and Why Does It Matter?](#what-is-helm-and-why-does-it-matter)  
- [Installing Helm](#installing-helm)  
  - [Why We Install Helm Locally](#why-we-install-helm-locally)  
  - [Installation Methods](#installation-methods)  
  - [Verify Installation](#verify-installation)  
- [Creating Your First Helm Chart](#creating-your-first-helm-chart)  
  - [Navigate to the Exercise Directory](#navigate-to-the-exercise-directory)  
  - [Create a New Helm Chart](#create-a-new-helm-chart)  
  - [Clean Up the Default Templates](#clean-up-the-default-templates)  
  - [Add Required Manifests to the Chart](#add-required-manifests-to-the-chart)  
- [Installing and Running the Helm Chart](#installing-and-running-the-helm-chart)  
  - [Understanding the Deployment Process](#understanding-the-deployment-process)  
  - [Step 1: Install the Helm Chart](#step-1-install-the-helm-chart)  
  - [Step 2: Verify the Installation](#step-2-verify-the-installation)  
  - [Step 3: Understanding Helm Release Management](#step-3-understanding-helm-release-management)  
- [Expose Services](#expose-services)  
  - [Understanding Service Exposure in Different Environments](#understanding-service-exposure-in-different-environments)  
  - [Access the Application](#access-the-application)  
  - [Access Grafana](#access-grafana)  
  - [Accessing Additional Services](#accessing-additional-services)  
- [Publishing a Helm Chart to a Public Repository (Optional)](#publishing-a-helm-chart-to-a-public-repository-optional)  
  - [Background and Context](#background-and-context)  
  - [Step-by-Step Publication Guide](#step-by-step-publication-guide)  
- [Final Objective](#final-objective)  
  - [Learning Outcomes Verification](#learning-outcomes-verification)  
  - [Verify Your Deployment](#verify-your-deployment)  
  - [Test Application Functionality](#test-application-functionality)  
- [Next Steps](#next-steps)  

-----

## Introduction to Helm

In previous exercises, we deployed Kubernetes resources manually using YAML files. While this approach taught us the fundamentals of Kubernetes manifests, it also revealed several practical limitations in real-world scenarios:

  - **Strict order of execution**: You had to apply each manifest in a specific sequence, often waiting between deployments to ensure dependencies were met. This manual orchestration is error-prone and time-consuming.
  - **Redundant configuration**: Many values like image names, labels, resource limits, and environment variables were repeated across multiple files, violating the **DRY (Don't Repeat Yourself)** principle.
  - **No rollback mechanism**: If something went wrong during deployment, reverting changes required manually tracking and undoing each applied manifest—a risky and complex process.
  - **Poor modularity**: Updating individual components meant modifying multiple interconnected files, making maintenance difficult and increasing the risk of breaking dependencies.
  - **Environment inconsistency**: Deploying the same application across different environments (development, staging, production) required maintaining separate sets of manifests with slight variations.

To solve these problems, we now introduce **Helm**, a powerful tool that revolutionizes how we manage Kubernetes applications through **charts**.

> **Understanding the Architecture**: This diagram represents the evolved architecture of our SRE Academy lab environment. With Helm's introduction, we've transformed from managing individual YAML files to orchestrating comprehensive **charts** that bundle related components together. Notice how Helm acts as an abstraction layer above Kubernetes, managing the lifecycle of interconnected services like our application, monitoring stack (Prometheus, Grafana), observability tools (Jaeger, Loki), and data collection (OpenTelemetry). This architectural shift mirrors real-world enterprise practices where complex distributed systems require sophisticated deployment orchestration.

### What is Helm and Why Does It Matter?

**Helm is the package manager for Kubernetes**—think of it as the "npm for Node.js" or "pip for Python" but specifically designed for Kubernetes applications. Just as these package managers simplify software dependency management, Helm simplifies the deployment and management of complex Kubernetes applications.

#### Core Concepts Explained:

**Helm Charts** are packages that contain:

  - **Chart.yaml**: A metadata file defining the chart's name, version, description, and dependencies. This is like a `package.json` file that tells Helm what your application is and how it relates to other components.
  - **values.yaml**: A configuration file containing default values for template variables. This allows the same chart to be customized for different environments without changing the underlying templates.
  - **templates/ directory**: Contains Kubernetes manifest templates with placeholders that get replaced with actual values during deployment. This enables dynamic configuration based on environment or user preferences.
  - **charts/ directory**: Contains dependency charts, allowing you to build complex applications from smaller, reusable components.

#### Why Helm Revolutionizes Kubernetes Deployments:

1.  **Templating Power**: Instead of static YAML files, Helm uses Go templates that allow dynamic value substitution. This means one chart can deploy to development with 1 replica and minimal resources, then to production with 10 replicas and high resource limits—all from the same source.
2.  **Dependency Management**: Helm charts can declare dependencies on other charts, automatically ensuring that required services (like databases) are deployed before applications that need them.
3.  **Release Management**: Helm tracks every deployment as a "release" with a unique revision number, making rollbacks as simple as `helm rollback myapp 1`.
4.  **Atomic Operations**: Helm deployments are atomic—either everything deploys successfully, or nothing changes. This prevents partially deployed applications that can cause system instability.
5.  **Ecosystem Integration**: The Helm community maintains thousands of pre-built charts for popular applications, allowing you to deploy complex software like PostgreSQL, Redis, or Kafka with a single command.

-----

## Installing Helm

Before using Helm, you need to install it on your local machine. Helm is a client-side tool that communicates with your Kubernetes cluster through the Kubernetes API, just like `kubectl`.

### Why We Install Helm Locally

Unlike older versions (Helm v2), Helm v3 doesn't require a server-side component (Tiller) in your cluster. This design is more secure and simpler to manage, as Helm now uses your existing Kubernetes credentials and permissions.

### Installation Methods:

#### macOS (Homebrew) - Recommended:

```bash
brew install helm
```

**Why Homebrew?** Homebrew automatically handles dependency management, PATH configuration, and provides easy updates through `brew upgrade helm`.

### Verify Installation:

```bash
helm version
```

**Expected Output:**

```
version.BuildInfo{Version:"v3.x.x", GitCommit:"...", GitTreeState:"clean", GoVersion:"go1.x.x"}
```

**Understanding the Output:**

  - **Version**: Shows the Helm version installed.
  - **GitCommit**: The specific code commit this build was created from.
  - **GitTreeState**: "clean" indicates this is an official release.
  - **GoVersion**: The Go language version used to compile Helm.

If you see an error, check that:

1.  The Helm binary is in your PATH.
2.  Your Kubernetes cluster is accessible (`kubectl cluster-info` should work).
3.  You have proper permissions to access the cluster.

-----

## Creating Your First Helm Chart

Creating a Helm chart is like setting up a new software project—you're establishing the structure and configuration that will govern how your application deploys across different environments.

### Navigate to the Exercise Directory

```bash
cd sre-academy-training/exercises/exercise14
```

### Create a New Helm Chart

```bash
helm create my-sre-app-chart
```

**What This Command Does:**

1.  **Creates Directory Structure**: Helm generates a complete chart skeleton with all necessary files and folders.
2.  **Generates Templates**: Provides sample Kubernetes manifests that demonstrate best practices.
3.  **Sets Up Configuration**: Creates a `values.yaml` with common configuration options.
4.  **Establishes Metadata**: Generates `Chart.yaml` with basic project information.

**Generated Structure Explained:**

```
my-sre-app-chart/
├── Chart.yaml          # Chart metadata and version info
├── values.yaml         # Default configuration values
├── charts/             # Directory for chart dependencies
└── templates/          # Kubernetes manifest templates
    ├── deployment.yaml # Sample application deployment
    ├── service.yaml    # Sample service configuration
    ├── ingress.yaml    # Sample ingress rules
    ├── _helpers.tpl    # Template helper functions
    └── tests/          # Chart testing configurations
```

### Clean Up the Default Templates

**Why We Remove Default Templates:**
Helm generates generic templates suitable for a basic web application, but we're building a comprehensive SRE stack with specific requirements. Rather than modifying these templates, it's cleaner to start with our proven manifests from previous exercises.

```bash
rm -rf my-sre-app-chart/templates/*
```

> **[\!NOTE]**
> **Shell Confirmation Prompt**: Your shell may prompt you with a safety warning like:
>
> ```
> zsh: sure you want to delete all the files in /path/to/my-sre-app-chart/templates [yn]?
> ```
>
> This is a built-in protection against accidental deletions. Type `y` to proceed—this is expected and safe in our training context.

**What We're Doing:** We're clearing the templates directory to make room for our carefully crafted manifests that have been tested in previous exercises. This approach ensures we're building on proven configurations rather than generic examples.

### Add Required Manifests to the Chart

**The Philosophy Behind This Step:**
Instead of recreating manifests from scratch, we're reusing and organizing the battle-tested configurations you've developed in earlier exercises. This demonstrates a key SRE principle: **reusability and iteration** rather than constant reinvention.

```bash
cp ../exercise10/storage.yaml ../exercise10/deployment.yaml ../exercise10/otel-collector.yaml \
   ../exercise8/jaeger.yaml ../exercise9/prometheus.yaml ../exercise12/grafana-loki.yaml \
   ../exercise12/grafana.yaml my-sre-app-chart/templates/
```

**Understanding Each Component's Role:**

| **File** | **Purpose** | **Why It's Critical** |
| :----------------- | :------------------------------------ | :---------------------------------------------------------------------------------------------------------------------- |
| `deployment.yaml`  | Deploys your main SRE application     | The core service that everything else supports; without this, you have monitoring infrastructure but nothing to monitor. |
| `storage.yaml`     | Sets up persistent volumes and claims | Provides durable storage for databases and logs; losing this means losing historical data when pods restart.             |
| `otel-collector.yaml` | Deploys OpenTelemetry collector       | Acts as the central hub for collecting traces, metrics, and logs from your application; the "data pipeline" of observability. |
| `jaeger.yaml`      | Enables distributed tracing           | Allows you to track requests across multiple services; essential for debugging microservices architectures.             |
| `prometheus.yaml`  | Collects and stores metrics           | The time-series database that powers your monitoring; stores numerical data about system performance.                   |
| `grafana.yaml`     | Visualizes metrics and logs           | The dashboard that makes your data actionable; transforms raw metrics into meaningful insights.                         |
| `grafana-loki.yaml` | Enables log aggregation               | Centralizes log collection and search; crucial for debugging and audit trails.                                          |

**The SRE Stack Integration:**
These components work together to create a comprehensive observability platform:

1.  **Your application** generates logs, metrics, and traces.
2.  **OpenTelemetry collector** gathers this telemetry data.
3.  **Prometheus** stores metrics for performance monitoring.
4.  **Loki** aggregates logs for debugging and analysis.
5.  **Jaeger** traces requests across service boundaries.
6.  **Grafana** provides unified dashboards for all data sources.
7.  **Persistent storage** ensures data survives pod restarts.

**Why This Approach Works:**
By adding these manifests to the chart's `templates/` folder, Helm now manages their entire lifecycle as a cohesive unit. This means:

  - **Coordinated Deployment**: All components deploy together in the correct order.
  - **Unified Configuration**: Shared values can be used across all components.
  - **Atomic Operations**: Success or failure affects the entire stack, not individual pieces.
  - **Version Control**: The entire stack evolves together as a single versioned unit.

-----

## Installing and Running the Helm Chart

Now that your chart is prepared with all necessary components, you're ready to deploy your complete SRE stack to your Kubernetes cluster. This single deployment will orchestrate the creation of multiple interconnected services that would have required careful manual sequencing in previous exercises.

### Understanding the Deployment Process

**What Happens During Helm Install:**

1.  **Template Rendering**: Helm processes your template files, substituting variables with values from `values.yaml`.
2.  **Dependency Resolution**: Helm ensures all required resources are defined and available.
3.  **Resource Ordering**: Helm applies resources in an order that respects Kubernetes dependencies.
4.  **Health Checking**: With the `--wait` flag, Helm monitors deployment progress and reports success/failure.
5.  **Release Tracking**: Helm creates a release record for future management operations.

### Step 1: Install the Helm Chart

```bash
helm install sre-app ./my-sre-app-chart --wait --timeout=5m
```

**Command Breakdown:**

  - **`helm install`**: The primary command for deploying a chart.
  - **`sre-app`**: The release name—a unique identifier for this deployment instance. You could deploy the same chart multiple times with different names (e.g., `sre-app-staging`, `sre-app-prod`).
  - **`./my-sre-app-chart`**: Path to your local chart directory. This could also be a chart from a repository (e.g., `stable/mysql`).
  - **`--wait`**: Crucial flag that makes Helm wait until all resources are healthy before returning success. Without this, Helm would return immediately after submitting manifests to Kubernetes, potentially before services are actually ready.
  - **`--timeout=5m`**: Maximum time Helm should wait before declaring the deployment failed. 5 minutes is reasonable for our stack size—enough time for images to download and services to start, but not so long that you wait indefinitely for a failed deployment.

**Why These Flags Matter:**

  - **Without `--wait`**: Your script would continue immediately, potentially trying to access services before they're ready.
  - **Without `--timeout`**: A failed deployment could hang indefinitely, requiring manual intervention.
  - **Together**: They provide predictable, reliable deployment behavior suitable for automation.

### Step 2: Verify the Installation

**Check What Helm Actually Deployed:**

```bash
helm get manifest sre-app
```

**What This Shows You:**
This command displays the actual Kubernetes manifests that Helm sent to your cluster—after template processing and value substitution. It's invaluable for:

  - **Debugging**: See exactly what resources were created.
  - **Learning**: Understand how your templates became actual Kubernetes resources.
  - **Auditing**: Verify that the deployed configuration matches your expectations.

**Monitor Your Pods:**

```bash
kubectl get pods -A
```

**Understanding Pod States:**

  - **Pending**: Pod is waiting for resources (CPU, memory, storage) or scheduling.
  - **ContainerCreating**: Kubernetes is downloading images and starting containers.
  - **Running**: Pod is operational (but individual containers might still be starting).
  - **CrashLoopBackOff**: Container is failing to start and Kubernetes is retrying.
  - **ImagePullBackOff**: Cannot download the specified container image.

**Normal Startup Sequence:**

1.  Storage-related pods (PVC, PV) get created first.
2.  Database-like services (if any) start next.
3.  Applications and collectors start once storage is ready.
4.  Dashboard and UI services start last.

**If Pods Are Stuck in Pending:**
This usually indicates resource constraints. Your Minikube cluster might need more memory or CPU:

```bash
# Check resource usage
kubectl top nodes
kubectl describe nodes

# If needed, restart Minikube with more resources
minikube delete
minikube start --memory=4096 --cpus=4
```

### Step 3: Understanding Helm Release Management

**Check Release Status:**

```bash
helm status sre-app
```

This shows:

  - **Release information**: Name, namespace, status, revision.
  - **Resource summary**: What Kubernetes objects were created.
  - **Notes**: Any custom instructions or access information from the chart.

**View Release History:**

```bash
helm history sre-app
```

This displays all revisions of your release, enabling you to:

  - Track changes over time.
  - Identify when problems were introduced.
  - Enable precise rollbacks to known-good states.

-----

## Expose Services

Your application and observability tools expose web interfaces that need to be accessible from your local machine. In a cloud environment, you'd typically use LoadBalancers or Ingress controllers, but in Minikube, we use port forwarding to access services.

### Understanding Service Exposure in Different Environments

**Why Service Exposure Matters:**

  - **Development (Minikube)**: Services run inside a VM and need port forwarding to your local machine.
  - **Cloud Environments**: Services get public IPs or load balancers automatically.
  - **Production**: Services typically sit behind ingress controllers with proper DNS and SSL.

**Minikube's Role:**
Minikube creates a virtual machine that runs your Kubernetes cluster. The `minikube service` command creates a tunnel from your local machine to services inside this VM, automatically handling port forwarding and opening your browser.

### Access the Application

```bash
minikube service sre-abc-training-service -n application
```

**What This Command Does:**

1.  **Identifies the Service**: Finds the `sre-abc-training-service` in the `application` namespace.
2.  **Creates Port Forward**: Maps a local port to the service's port inside Minikube.
3.  **Opens Browser**: Automatically launches your default browser to the correct URL.
4.  **Maintains Tunnel**: Keeps the connection open as long as the terminal remains active.

**Critical Usage Notes:**

  - **Keep Terminal Open**: Closing this terminal window stops the port forwarding.
  - **Unique Ports**: Minikube assigns random local ports to avoid conflicts.
  - **Process Management**: Each service requires its own terminal window for concurrent access.

**Expected Behavior:**
Your browser should open to a URL like `http://127.0.0.1:12345` (port number will vary) showing your SRE application interface. If the page doesn't load immediately, wait 30-60 seconds for the application to fully initialize.

### Access Grafana

**Open a New Terminal Window:**
This is crucial—you need separate terminals for each service to maintain concurrent access.

```bash
minikube service grafana-service -n monitoring
```

**Grafana Login Process:**

1.  **Default Credentials**: Username: `admin`, Password: `admin` (unless you've customized this in your manifests).
2.  **First Login**: Grafana will prompt you to change the password.
3.  **Dashboard Access**: Once logged in, explore the pre-configured dashboards for your application metrics.

**Understanding Grafana's Role:**
Grafana serves as your observability command center, providing:

  - **Application Metrics**: Performance data from Prometheus.
  - **Log Analysis**: Search and visualization of logs from Loki.
  - **Distributed Traces**: Request flow analysis from Jaeger.
  - **Custom Dashboards**: Tailored views of your system's health.

### Accessing Additional Services

**For Prometheus (metrics database):**

```bash
minikube service prometheus-service -n monitoring
```

**For Jaeger (tracing UI):**

```bash
minikube service jaeger-service -n opentelemetry
```

**Service Discovery Commands:**
If you're unsure about service names or namespaces:

```bash
# List all services across namespaces
kubectl get svc -A

# List services in specific namespace
kubectl get svc -n monitoring
kubectl get svc -n application
kubectl get svc -n opentelemetry
```

> **[\!TIP]**
> **Professional Tip**: In production environments, you'd typically set up an ingress controller (like nginx-ingress) with proper DNS names instead of using port forwarding. This exercise uses Minikube's built-in service exposure for simplicity, but the underlying Kubernetes service concepts remain the same.

-----

## Publishing a Helm Chart to a Public Repository (Optional)

This section teaches you how to share your Helm charts with others and consume charts from remote repositories—a crucial skill for collaborative development and open-source contribution.

### Background and Context

**Repository Restrictions:**
You **cannot publish charts to the restricted IBM training repository** because:

  - It's read-only for students.
  - Corporate security policies prevent external contributions.
  - It's designed for consumption, not publication.

**Why Learn Chart Publishing?**
In real-world scenarios, you'll need to:

  - Share charts across teams and projects.
  - Contribute to open-source projects.
  - Maintain private chart repositories for your organization.
  - Version and distribute infrastructure as code.

**Learning Approach:**
We'll use **GitHub Pages** as a free, public Helm repository to practice these skills.

### Step-by-Step Publication Guide

#### Prerequisites: Setting Up Your Repository

**Create a New Public Repository:**

1.  Go to your personal GitHub account.

2.  Create a new repository (e.g., `my-sre-training-charts`).

3.  Make it **public** (required for GitHub Pages).

4.  Clone it locally:

    ```bash
    git clone https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
    cd YOUR_REPO_NAME
    ```

**Why GitHub Pages?**
GitHub Pages provides free static website hosting, perfect for Helm repositories since they're just static files (chart packages and an index).

#### 1\. Package the Chart

```bash
helm package ./my-sre-app-chart
```

**What This Creates:**

  - A compressed archive file: `my-sre-app-chart-0.1.0.tgz`.
  - Contains all chart files, templates, and metadata.
  - Version number comes from `Chart.yaml`.
  - This is the distributable format for Helm charts.

**Understanding Versioning:**

```yaml
# In Chart.yaml
version: 0.1.0    # Chart version (your packaging version)
appVersion: "1.0" # Application version (the software being deployed)
```

  - **Chart Version**: Changes when you modify the chart itself (templates, values, etc.).
  - **App Version**: Changes when you update the application being deployed.

#### 2\. Create a Helm Repository Index

```bash
helm repo index . --url https://YOUR_USERNAME.github.io/YOUR_REPO_NAME/
```

**Replace Placeholders:**

  - `YOUR_USERNAME`: Your actual GitHub username.
  - `YOUR_REPO_NAME`: Your repository name.

**What This Command Does:**

1.  **Scans Directory**: Looks for all `.tgz` chart packages.
2.  **Generates Metadata**: Creates an `index.yaml` file with chart information.
3.  **Sets Base URL**: Configures where charts will be downloaded from.
4.  **Creates Repository**: Makes the directory a valid Helm repository.

**Understanding `index.yaml`:**

```yaml
apiVersion: v1
entries:
  my-sre-app-chart:
  - apiVersion: v2
    created: "2023-xx-xxT00:00:00.000000000Z"
    description: A Helm chart for SRE training
    digest: sha256:abc123...  # Integrity checksum
    name: my-sre-app-chart
    urls:
    - https://YOUR_USERNAME.github.io/YOUR_REPO_NAME/my-sre-app-chart-0.1.0.tgz
    version: 0.1.0
```

#### 3\. Organize Files for GitHub Pages

```bash
mkdir -p ./docs/
mv my-sre-app-chart-0.1.0.tgz ./docs/
cd ./docs
helm repo index . --url https://YOUR_USERNAME.github.io/YOUR_REPO_NAME/
```

**Why the `docs/` Directory?**
GitHub Pages can serve from:

  - Root directory of `main` branch.
  - `docs/` directory of `main` branch (our choice).
  - `gh-pages` branch.

Using `docs/` keeps your repository organized and separates source code from published artifacts.

#### 4\. Push to GitHub and Enable Pages

```bash
git add ./docs/index.yaml
git add ./docs/my-sre-app-chart-0.1.0.tgz
git commit -m "Add Helm chart to GitHub Pages"
git push origin main
```

**Enable GitHub Pages:**

1.  Navigate to your repository on GitHub.
2.  Go to **Settings** → **Pages**.
3.  Under **Source**, select:
      - **Branch**: `main`
      - **Folder**: `/docs`
4.  Click **Save**.

**Wait for Deployment:**
GitHub Pages takes a few minutes to build and deploy. You'll see a green checkmark and URL when ready.

#### 5\. Add and Use Your Repository

```bash
helm repo add my-sre-lab https://YOUR_USERNAME.github.io/YOUR_REPO_NAME/
helm repo update
helm repo list
```

**Verify Repository Access:**

```bash
helm search repo my-sre-lab
```

**Expected Output:**

```
NAME                    CHART VERSION   APP VERSION    DESCRIPTION
my-sre-lab/my-sre-app-chart 0.1.0           1.0            A Helm chart for SRE training
```

#### 6\. Install from Your Published Repository

```bash
# Remove local installation
helm uninstall sre-app

# Install from your published repository
helm install sre-app my-sre-lab/my-sre-app-chart
```

**What This Demonstrates:**

  - **Chart Portability**: Your chart works from any location.
  - **Version Control**: Specific versions can be installed.
  - **Distribution**: Others can now use your chart.
  - **Reproducibility**: Same chart works across different environments.

#### Optional Cleanup

```bash
rm -rf ./docs
```

**When to Clean Up:**
Remove the local `docs/` folder after publishing to avoid confusion between local development files and published artifacts.

### Real-World Repository Management

**Professional Practices:**

1.  **Versioning Strategy**: Use semantic versioning (major.minor.patch).
2.  **Chart Testing**: Implement automated testing before publishing.
3.  **Documentation**: Include comprehensive README and CHANGELOG.
4.  **Security Scanning**: Check for vulnerabilities in dependencies.
5.  **Access Control**: Use private repositories for sensitive charts.

**Enterprise Alternatives:**

  - **ChartMuseum**: Self-hosted Helm repository.
  - **Harbor**: Container registry with Helm chart support.
  - **AWS S3**: Static hosting for Helm repositories.
  - **Google Cloud Storage**: Alternative static hosting.
  - **Azure Blob Storage**: Microsoft's static hosting option.

-----

## Final Objective

By completing this exercise, you should have gained practical experience with the core concepts that make Helm the industry standard for Kubernetes application management.

### Learning Outcomes Verification

**You should now be able to:**

  - **Deploy Complex Applications**: Use Helm to orchestrate multi-component deployments with a single command.
  - **Understand Chart Structure**: Know how templates, values, and metadata work together to create flexible deployments.
  - **Manage Application Lifecycle**: Install, upgrade, rollback, and uninstall applications using Helm releases.
  - **Share and Distribute Charts**: Package and publish charts to repositories for team collaboration.
  - **Troubleshoot Deployments**: Use Helm and `kubectl` commands to diagnose and resolve deployment issues.

### Verify Your Deployment

**Check cluster status:**

```bash
kubectl get pods -A
```

**Expected output:**

```
NAMESPACE       NAME                            READY   STATUS    RESTARTS   AGE
application     sre-abc-training-app-xxxxxx     1/1     Running   0          5m
monitoring      grafana-deployment-xxxxxx       1/1     Running   0          5m
monitoring      prometheus-deployment-xxxxxx    1/1     Running   0          5m
opentelemetry   jaeger-xxxxxx                   1/1     Running   0          5m
opentelemetry   loki-xxxxxx                     1/1     Running   0          5m
opentelemetry   otel-collector-xxxxxx           1/1     Running   0          5m
```

**What Each Status Means:**

  - **Running**: Pod is operational and serving traffic.
  - **Ready 1/1**: All containers in the pod are healthy.
  - **Restarts 0**: No container crashes (restarts \> 0 might indicate issues).
  - **Age**: How long the pod has been running.

### Test Application Functionality

**Verify Application Access:**

```bash
minikube service sre-abc-training-service -n application
```

Your application should load in the browser and respond to requests.

**Verify Monitoring Stack:**

```bash
minikube service grafana-service -n monitoring
```

Grafana should display dashboards with metrics from your application.

**Test Helm Management:**

```bash
# View your release
helm status sre-app

# Check release history
helm history sre-app

# Test rollback capability (rolls back to previous revision)
helm rollback sre-app 1

# Verify rollback worked
helm history sre-app
```

**From Manual to Automated:**
You've transformed from manually applying individual YAML files in sequence to deploying entire application stacks with a single Helm command. This represents a fundamental shift from imperative (step-by-step instructions) to declarative (desired state) infrastructure management.

**Production-Ready Skills:**
The techniques you've learned mirror exactly how enterprise teams manage applications:

  - **GitOps Workflows**: Charts stored in Git, deployed via CI/CD pipelines.
  - **Environment Promotion**: Same charts deployed across dev/staging/prod with different values.
  - **Disaster Recovery**: Quick restoration using Helm charts and backups.
  - **Scaling Operations**: Managing hundreds of applications across multiple clusters.

-----

## Next Steps

In [Exercise 15](https://www.google.com/search?q=../exercise15), you will shift focus from application-level automation to **infrastructure-level automation using Terraform**.

You should now be confident with:

  - Structuring Helm charts.
  - Installing and managing releases.
  - Publishing charts for reuse.
  - Using templated Kubernetes deployments.

-----