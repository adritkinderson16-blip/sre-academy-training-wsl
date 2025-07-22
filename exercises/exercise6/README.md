# Deploying Grafana in Minikube

## Table of Contents

- [Navigate to the Application Directory](#navigate-to-the-application-directory)
- [Overview](#overview)
- [Key Features of Grafana](#key-features-of-grafana)
- [Architecture](#architecture)
- [Use Cases](#use-cases)
- [Traditional Installation](#traditional-installation)
- [Grafana Installation Steps](#grafana-installation-steps)
  - [Step 1: Namespace Creation](#step-1-namespace-creation)
  - [Step 2: Grafana Deployment and Service](#step-2-grafana-deployment-and-service)
  - [Step 3: Configuring Prometheus as a Data Source](#step-3-configuring-prometheus-as-a-data-source)
  - [Step 4: Provisioning Dashboards](#step-4-provisioning-dashboards)
  - [Step 5: Verifying the Configuration](#step-5-verifying-the-configuration)
- [Running the Playbook](#running-the-playbook)
- [Final Objective](#final-objective)

-----

## Navigate to the Application Directory

To begin, navigate to the directory for Exercise 6:

```bash
cd sre-academy-training/exercises/exercise6
```

> **Note**: This directory contains the necessary YAML files for the deployment and service configuration.

-----

## Overview

Grafana is an open-source platform for monitoring and observability that provides powerful visualization and analysis capabilities. This exercise focuses on deploying Grafana in a Minikube cluster and integrating it with Prometheus (set up in Exercise 5).

> **Important**: Before proceeding, ensure that both Minikube and Podman are running. These were set up in previous exercises.

-----

## Key Features of Grafana

  - Customizable Dashboards with interactive visualizations.
  - Integration with multiple data sources such as Prometheus, InfluxDB, and Elasticsearch.
  - Advanced alerting and notification capabilities.
  - User management and role-based access control.

-----

## Architecture

Grafana's key components:

  - **Dashboard**: Provides data visualization and analysis.
  - **Data Sources**: Supports multiple data backends for metrics and logs.
  - **Alerting**: Generates alerts based on configured rules and thresholds.

-----

## Use Cases

  - Real-time application monitoring.
  - Infrastructure performance tracking.
  - System health alerts and notifications.
  - Metrics visualization from multiple data sources.

-----

## Traditional Installation

This section provides the traditional steps to install Grafana on macOS using Homebrew:

1.  **Install Grafana via Homebrew**:
    ```bash
    brew install grafana
    ```
    Homebrew will download and install the latest stable version of Grafana, along with its dependencies.
2.  **Start Grafana Service**:
    ```bash
    brew services start grafana
    ```
    This command starts Grafana as a background service that will also restart automatically at login. If you prefer to run it once without backgrounding, you can typically find the executable at `/opt/homebrew/opt/grafana/bin/grafana-server` (adjust path based on your Homebrew installation, especially for Intel Macs).
3.  **Access Grafana**:
    Open your web browser and navigate to `http://localhost:3000`. This is the default port Grafana listens on.
4.  **Login**:
    The default login credentials are **username: `admin`** and **password: `admin`**. You'll be prompted to change the password on your first login for security.

In this exercise, we’ll focus on deploying Grafana within a Minikube cluster using Kubernetes YAML configurations, which offers a cloud-native approach to monitoring.

-----

## Grafana Installation Steps

### Step 1: Namespace Creation

To isolate monitoring tools, the `grafana.yaml` file includes a namespace definition:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring # Namespace for monitoring tools.
```

-----

### Step 2: Grafana Deployment and Service

The `grafana.yaml` file also defines the Grafana deployment and service:

  - **Deployment**:

<!-- end list -->

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana-deployment
  namespace: monitoring
  labels:
    app: grafana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
        - name: grafana
          image: grafana/grafana:latest
          ports:
            - containerPort: 3000
```

  - **Service**:

<!-- end list -->

```yaml
apiVersion: v1
kind: Service
metadata:
  name: grafana-service
  namespace: monitoring
  labels:
    app: grafana
spec:
  selector:
    app: grafana
  ports:
    - protocol: TCP
      port: 3000
      targetPort: 3000
  type: NodePort
```

-----

### Step 3: Configuring Prometheus as a Data Source

The `grafana.yaml` file configures Prometheus as a data source via a `ConfigMap` called `grafana-datasources-config`. This allows Grafana to automatically discover and connect to your Prometheus instance running within the `monitoring` namespace.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources-config
  namespace: monitoring
  labels:
    app: grafana
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-service.monitoring.svc.cluster.local:9090
        access: proxy
        isDefault: true
```

-----

### Step 4: Provisioning Dashboards

In addition to data sources, Grafana can automatically provision dashboards. The `grafana.yaml` file includes another `ConfigMap` called `grafana-dashboards-config`. This ConfigMap defines a dashboard provider and includes an `example-dashboard.json` directly. When Grafana starts, it will automatically load this dashboard.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards-config
  namespace: monitoring
  labels:
    app: grafana
data:
  dashboards.yaml: |
    apiVersion: 1
    providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: false
        options:
          path: /etc/grafana/provisioning/dashboards
  example-dashboard.json: |
    {
      "id": null,
      "uid": "example-dashboard",
      "title": "Example Dashboard",
      "tags": [],
      "style": "dark",
      "timezone": "browser",
      "editable": true,
      "panels": [
        {
          "datasource": "Prometheus",
          "id": 1,
          "targets": [
            {
              "expr": "sum by(job) (rate(process_cpu_seconds_total[1m]))",
              "refId": "A"
            }
          ],
          "title": "CPU Usage",
          "type": "graph"
        }
      ],
      "schemaVersion": 16,
      "version": 1
    }
```

-----

### Step 5: Verifying the Configuration

Deploy the Grafana resources by applying the `grafana.yaml` file to your Minikube cluster:

```bash
kubectl apply -f grafana.yaml
```

Verify the status of the Grafana pods in the `monitoring` namespace:

```bash
kubectl get pods -n monitoring
```

Access Grafana in your browser using the Minikube service command:

```bash
minikube service grafana-service -n monitoring
```

> **Expected Outcome**: After logging in with `admin/admin` (default password is also `admin`), you should see the default Grafana interface. Navigate to **Configuration \> Data Sources** to verify Prometheus is listed and correctly configured. You should also find the "Example Dashboard" automatically available under the Dashboards section.

-----

## Running the Playbook

While the previous steps guided you through applying Kubernetes configurations manually with `kubectl`, this section demonstrates a more **automated and scalable approach** using Ansible. This is where the principles of **Infrastructure as Code (IaC)** come into play, allowing you to define and manage your infrastructure (in this case, Grafana on Kubernetes) through code.

Ansible acts as an **orchestration tool**, taking the defined state in your YAML files (`grafana.yaml` and `infra.yaml`) and applying it to your target environment. This ensures **repeatability and consistency**, meaning you can deploy Grafana to any similar Minikube cluster with the same configuration simply by running this playbook. It also integrates seamlessly with version control, making your infrastructure deployments traceable and auditable.

To deploy Grafana using Ansible:

1.  **Clarify the Dependency**
    Ensure you have completed Exercise 4.1, as this exercise requires the `inventory.ini` file from the `exercise4.1/ansible_quickstart` directory. This `inventory.ini` file tells Ansible to target your local machine.

2.  **Run the Playbook**
    Execute the following command:

    ```bash
    ansible-playbook -i ../exercise4.1/ansible_quickstart/inventory.ini infra.yaml
    ```

    This command tells Ansible to use the specified inventory file and execute the `infra.yaml` playbook, which in turn applies your Grafana Kubernetes configurations.

3.  **Verify Access**
    Confirm that Grafana is accessible:

    ```bash
    minikube service grafana-service -n monitoring
    ```

-----

## Final Objective

At the end of this exercise, you should accomplish the following:

> **Important**
> Log in to Grafana using the default credentials (`admin/admin`) and verify:
>
>   - Prometheus is configured as a data source (under **Configuration \> Data Sources**).
>   - The automatically provisioned "Example Dashboard" is visible and functional (under **Dashboards**).
>   - The "CPU Usage" panel within the example dashboard displays metrics from the Prometheus server.
>
> **Note:** The "CPU Usage" graph will likely display metrics only for the Prometheus server's own process (`process_cpu_seconds_total`) because, in Exercise 5, Prometheus was configured to scrape only itself. To monitor general system CPU/memory metrics from your Minikube node or other applications, additional Prometheus exporters (like Node Exporter) and corresponding scrape configurations would be required in Prometheus, which are beyond the scope of this exercise.

Example Dashboard:
![Grafana Dashboard](image.png)

-----