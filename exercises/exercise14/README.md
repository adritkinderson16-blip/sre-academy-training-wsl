# Installation and Configuration Using Helm Charts

## Table of Contents

1. [Introduction to Helm](#introduction-to-helm)  
2. [Installing Helm](#installing-helm)  
3. [Creating the First Helm Chart](#creating-the-first-helm-chart)  
4. [Installing and Running the Helm Chart](#installing-and-running-the-helm-chart)  
5. [Expose Services](#expose-services)  
6. [Publishing a Helm Chart to a Public Repository (Optional)](#publishing-a-helm-chart-to-a-public-repository-optional)  
7. [Final Objective](#final-objective)  
8. [Useful Helm & Kubernetes Commands](#useful-helm--kubernetes-commands)  
9. [Cleanup](#cleanup)  
10. [Next Steps](#next-steps)

---

## Introduction to Helm

In previous exercises, we deployed Kubernetes resources manually using YAML files. While this worked, the approach has limitations:

- **Strict order of execution**: You had to apply each manifest in sequence.
- **Redundant configuration**: Many values like image names or labels were repeated.
- **No rollback**: If something went wrong, reverting changes was not trivial.
- **Poor modularity**: Updating or managing individual parts of the stack was error-prone.

To solve these problems, we now introduce **Helm**, a powerful tool for managing Kubernetes applications through **charts**.

![Infrastructure Overview](Infra.png)

> This diagram represents the updated architecture of our SRE Academy lab environment. With the introduction of **Helm**, we now manage application and observability stack deployments as modular, reusable charts. Helm simplifies the orchestration of components like:

### What is Helm?

Helm is the **package manager for Kubernetes**. It simplifies deployment by bundling all Kubernetes manifests and configurations into reusable packages called **Helm charts**.

Each Helm chart contains:

- A `Chart.yaml` file that defines metadata (name, version, description)
- A `values.yaml` file that holds configurable values
- A `templates/` directory with the actual Kubernetes manifests

Helm lets you:

- Install, upgrade, or rollback applications with a single command
- Use variables and templates to avoid duplication
- Version-control your infrastructure as code

---

## Installing Helm

Before using Helm, install it via your package manager.

### macOS (Homebrew):
```bash
brew install helm
````

### Verify Installation:

```bash
helm version
```

This should return the installed version of Helm. If you see an error, double-check your PATH settings.

---

## Creating the First Helm Chart

### Navigate to the Exercise Directory

All work for this exercise will be done in the correct subdirectory:

```bash
cd sre-abc-training/exercises/exercise14
```

### Create a New Helm Chart

```bash
helm create my-sre-app-chart
```

This creates a folder named `my-sre-app-chart` with a standard Helm structure.

### Clean Up the Default Templates

Helm generates default manifests like a sample service and deployment. Since we're replacing those with our own custom manifests, remove them:

```bash
rm -rf my-sre-app-chart/templates/*
```

> Note: Your shell may prompt you with a warning (e.g., `zsh: sure you want to delete...`). This is normal. Type `y` to proceed.

### Add Required Manifests to the Chart

We will now reuse and organize the manifests you've written in earlier exercises.

```bash
cp ../exercise10/storage.yaml ../exercise10/deployment.yaml ../exercise10/otel-collector.yaml \
   ../exercise8/jaeger.yaml ../exercise9/prometheus.yaml ../exercise12/grafana-loki.yaml \
   ../exercise12/grafana.yaml my-sre-app-chart/templates/
```

Each file serves a distinct role:

* `deployment.yaml`: Deploys your main app
* `storage.yaml`: Sets up persistent volumes
* `otel-collector.yaml`: Collects traces and metrics
* `jaeger.yaml`: Adds distributed tracing
* `prometheus.yaml`: Collects and stores metrics
* `grafana.yaml`: Visualizes metrics
* `grafana-loki.yaml`: Enables log aggregation

By adding them into the chart’s `templates/` folder, Helm now manages their lifecycle.

---

## Installing and Running the Helm Chart

With your chart prepared, you're ready to install it into your Kubernetes cluster.

### Step 1: Install the Helm Chart

```bash
helm install sre-app ./my-sre-app-chart --wait --timeout=5m
```

* `sre-app`: This is the release name. You can pick any name you want.
* `--wait`: Helm will wait until all Kubernetes resources are healthy.
* `--timeout`: Defines how long Helm should wait before failing.

### Step 2: Verify the Installation

Check what manifests Helm deployed:

```bash
helm get manifest sre-app
```

See if your pods are running:

```bash
kubectl get pods -A
```

If any pods are `Pending`, it may be due to resource limits. Wait a few minutes and check again.

---

## Expose Services

Your application and observability tools expose web interfaces. Use `minikube service` to access them.

### Access the Application

```bash
minikube service sre-abc-training-service -n application
```

This command opens the application in a browser. Keep this terminal window open; closing it will stop the forwarding.

### Access Grafana

In a new terminal:

```bash
minikube service grafana-service -n monitoring
```

Log in to Grafana using the default credentials (`admin/admin` unless changed).

> Tip: If these commands don’t work, make sure `minikube tunnel` is running in a separate terminal.

---

## Publishing a Helm Chart to a Public Repository (Optional)

### Background

You **cannot publish charts to the restricted IBM training repository**. However, you are encouraged to practice publishing by using a **public repository on your personal GitHub account**.

### Step-by-Step Guide

#### 1. Package the Chart

```bash
helm package ./my-sre-app-chart
```

This creates a file like `my-sre-app-chart-0.1.0.tgz`.

#### 2. Create a Helm Repo Index

```bash
helm repo index . --url https://YOUR_USERNAME.github.io/YOUR_REPO_NAME/
```

#### 3. Move Files to a `docs/` Directory

```bash
mkdir -p ./docs/
mv my-sre-app-chart-0.1.0.tgz ./docs/
cd ./docs
helm repo index . --url https://YOUR_USERNAME.github.io/YOUR_REPO_NAME/
```

#### 4. Push to GitHub

```bash
git add ./docs/index.yaml
git add ./docs/my-sre-app-chart-0.1.0.tgz
git commit -m "Add Helm chart to GitHub Pages"
git push origin main
```

#### 5. Enable GitHub Pages

* On GitHub, go to your repo settings
* Under **Pages**, set source to `main` branch and `/docs` folder

#### 6. Add and Use the Repo Locally

```bash
helm repo add my-sre-lab https://YOUR_USERNAME.github.io/YOUR_REPO_NAME/
helm repo update
helm search repo my-sre-lab
```

#### 7. Install the Chart from GitHub

```bash
helm uninstall sre-app
helm install sre-app my-sre-lab/my-sre-app-chart
```

#### Optional Cleanup

Once you've published to your personal GitHub, you can remove the `docs/` folder locally to avoid confusion:

```bash
rm -rf ./docs
```

---

## Final Objective

You should now:

* Be able to deploy your application and observability stack using Helm
* Understand how Helm organizes Kubernetes resources into charts
* Optionally, publish a Helm chart and use it from a remote repo

Check your cluster status:

```bash
kubectl get pods -A
```

Expected output:

```
NAMESPACE       NAME                                      READY   STATUS    RESTARTS   AGE
application     sre-abc-training-app-xxxxxx              1/1     Running   0          5m
monitoring      grafana-deployment-xxxxxx                1/1     Running   0          5m
monitoring      prometheus-deployment-xxxxxx             1/1     Running   0          5m
opentelemetry   jaeger-xxxxxx                            1/1     Running   0          5m
opentelemetry   loki-xxxxxx                              1/1     Running   0          5m
opentelemetry   otel-collector-xxxxxx                    1/1     Running   0          5m
```

---

## Useful Helm & Kubernetes Commands

```bash
# Helm
helm list -A
helm status sre-app
helm get all sre-app
helm history sre-app
helm rollback sre-app <revision>

# Kubernetes
kubectl get pods -A
kubectl top pods -A
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

---

## Cleanup

To fully reset your environment:

```bash
# Uninstall the Helm release
helm uninstall sre-app

# Remove other Helm-managed tools (if present)
helm uninstall my-awx-operator -n awx || true

# Delete namespaces
kubectl delete ns application --ignore-not-found
kubectl delete ns monitoring --ignore-not-found
kubectl delete ns opentelemetry --ignore-not-found
kubectl delete ns awx --ignore-not-found

# Delete persistent volumes
kubectl delete pvc --all --all-namespaces --ignore-not-found
kubectl delete pv --all --ignore-not-found
```

---

## Next Steps

In the [Exercise15](../exercise15), you will shift focus from application-level automation to **infrastructure-level automation using Terraform**.

You should now be confident with:

* Structuring Helm charts
* Installing and managing releases
* Publishing charts for reuse
* Using templated Kubernetes deployments

---
