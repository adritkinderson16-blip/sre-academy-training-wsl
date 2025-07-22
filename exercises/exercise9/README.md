
# Generating Trace-Based Metrics Using OpenTelemetry and Prometheus

## **Table of Contents**

- [Overview](#overview)
- [Navigate to the Directory](#navigate-to-the-directory)
- [Deploy the Environment](#deploy-the-environment)
- [Understanding the Configuration](#understanding-the-configuration)
  - [SpanMetrics Connector](#spanmetrics-connector)
  - [OpenTelemetry Collector Example](#opentelemetry-collector-example)
  - [Prometheus Configuration Example](#prometheus-configuration-example)
- [Accessing Prometheus and Grafana](#accessing-prometheus-and-grafana)
  - [Prometheus](#prometheus)
  - [Grafana](#grafana)
- [Final Objective](#final-objective)

---

## **Overview**

In this exercise, we configure the **OpenTelemetry Collector** to generate trace-based metrics from a Python application and send them to **Prometheus**. These metrics will then be visualized using **Grafana** to monitor request count, error count, and request duration.

Key components involved:
- **OpenTelemetry Collector**
- **SpanMetrics Connector**
- **Prometheus**
- **Grafana**

![Infra](Infra.png)

---

## **Navigate to the Directory**

```bash
cd sre-academy-training/exercises/exercise9
```

---

## **Deploy the Environment**

Use the provided shell script to deploy the Python app, OpenTelemetry Collector, Jaeger, Prometheus, and Grafana:

```bash
chmod +x cluster.sh
./cluster.sh
```

> ℹ️ **Note:**  
> This script **automates the entire setup**, including:
> - Cleaning previous deployments
> - Creating the necessary namespaces
> - Applying all required manifests (`otel-collector.yaml`, `prometheus.yaml`, `grafana.yaml`, etc.)
> 
> You **do not need to modify or apply YAML files manually** unless you are debugging or customizing.

After running the script, wait 30–60 seconds and confirm all pods are running:

```bash
kubectl get pods -A
```

---

## **Understanding the Configuration**

Below are example configurations used in the exercise. You **don’t need to edit these files** — they are deployed automatically by the script. These are here to help you understand what’s happening under the hood.

---

### **SpanMetrics Connector**

The `spanmetricsconnector` converts span (trace) data into useful metrics:
- **Request Count**
- **Error Count**
- **Request Duration**

---

### **OpenTelemetry Collector Example**

File: `otel-collector.yaml`

```yaml
exporters:
  prometheus:
    endpoint: "0.0.0.0:9464"
    namespace: "otel_collector"

connectors:
  spanmetrics:
    namespace: span.metrics

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/jaeger, spanmetrics]
    metrics:
      receivers: [otlp, spanmetrics]
      exporters: [prometheus]
```

---

### **Prometheus Configuration Example**

File: `prometheus.yaml`

```yaml
- job_name: 'otel-collector'
  scrape_interval: 15s
  static_configs:
    - targets: ['otel-collector.opentelemetry.svc.cluster.local:9464']
```

Prometheus will scrape metrics exposed by the OpenTelemetry Collector using this job.

---

## **Accessing Prometheus and Grafana**

### **Prometheus**

Open the Prometheus UI using:

```bash
minikube service prometheus-service -n monitoring
```

In the UI, search for metrics with the prefix:

```
otel_collector_span_metrics_calls_total
```

These are automatically generated from the application traces.

---

### **View the Dashboard in Grafana**

Once the deployment is complete and all pods are in the Running state, open Grafana:

```bash
minikube service grafana-service -n monitoring
```

Log in (default is usually `admin` / `admin`).

Navigate to Dashboards → Example Dashboard

You’ll be able to visualize metrics like request count, errors, and latency, including a panel showing errors in the goo function.

![Grafana-dashboard](Grafana-dashboard.png)

---

## **Final Objective**

You should now be able to:
- View trace-derived metrics in **Prometheus**
- Build a **Grafana dashboard** using OpenTelemetry metrics
- Analyze application health and error rates using span-based telemetry

---
