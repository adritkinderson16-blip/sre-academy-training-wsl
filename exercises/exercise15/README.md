# **Infrastructure Automation with Terraform**

## **Table of Contents**

- [Introduction](#introduction)
- [Why Use Terraform in SRE?](#why-use-terraform-in-sre)
- [Lab Objectives](#lab-objectives)
- [Prerequisites](#prerequisites)
- [Navigate to the Directory](#navigate-to-the-directory)
- [Module 1: The Basics - Deploying a Simple Application](#module-1-the-basics---deploying-a-simple-application)
- [Module 2: Expanding Your Infrastructure - A Multi-Tier Application](#module-2-expanding-your-infrastructure---a-multi-tier-application)
- [Module 3: Advanced Concepts and Troubleshooting](#module-3-advanced-concepts-and-troubleshooting)
- [Cleanup](#cleanup)
- [Final Objective](#final-objective)
- [Next Steps](#next-steps)

---

## **Introduction**

In previous exercises, we used Helm Charts, YAML manifests, and Ansible to manage Kubernetes resources. In this expanded practice, we will explore **Terraform**, a powerful and flexible **Infrastructure as Code (IaC)** tool that allows engineers to describe, provision, and manage infrastructure declaratively.

This lab takes you from basic to advanced Terraform usage within the context of Kubernetes. You’ll learn not only how to use Terraform, but why it’s a valuable tool in the SRE toolkit.

---

## **Why Use Terraform in SRE?**

Terraform is widely used by Site Reliability Engineers (SREs) because it enables automation, repeatability, and visibility into infrastructure changes. Its key benefits include:

- **Declarative Configuration**: You define what you want (the *desired state*), and Terraform figures out how to reach that state.
- **Version Control**: Infrastructure becomes code. You can review, track, and roll back changes.
- **State Management**: Terraform keeps track of what it deployed, helping to detect drift and avoid redeploying unchanged resources.
- **Multi-Cloud and Platform Agnostic**: Use the same tool to manage AWS, Azure, GCP, Kubernetes, and more.
- **Automation-Friendly**: Integrates well with CI/CD pipelines, GitOps workflows, and monitoring systems.

---

## **Lab Objectives**

By the end of this lab, you will:

- Understand Terraform’s core components: providers, resources, variables, outputs, and state.
- Use Terraform to deploy and manage Kubernetes applications.
- Work with real-world patterns like ConfigMaps, environment variables, and multi-tier apps.
- Implement workspace isolation for environments (e.g., dev vs. prod).
- Learn troubleshooting techniques for failed deployments and state management.

---

## **Prerequisites**

You need the following tools installed and configured:

- Terraform CLI
- A Kubernetes cluster (Minikube)

---

## **Navigate to the Directory**

This exercise is located in the following path:

```bash
cd sre-academy-training/exercises/exercise15
````

Make sure you’re in this directory before executing any Terraform commands.

---

## **Module 1: The Basics – Deploying a Simple Application**

We will start by deploying a basic “Hello, World!” Python web application into a Kubernetes cluster using Terraform.

---

### **Step 1: Understand the Terraform Configuration**

This exercise includes several `.tf` files:

* `main.tf`: Defines the Kubernetes resources (namespace, deployment, service)
* `variables.tf`: Contains parameterized values like app name, image, port, and replicas
* `outputs.tf`: Defines what to show after deployment (namespace, deployment name, etc.)

Open these files in your editor and review their structure and content.

---

### **Step 2: Configure the Terraform Provider**

Terraform uses **providers** to interact with infrastructure platforms. For this exercise, we’ll use the `kubernetes` provider.

Create a new file named `provider.tf` with the following:

```hcl
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}
```

* `required_providers`: Specifies the plugins Terraform needs.
* `config_path`: Tells Terraform how to authenticate with your Kubernetes cluster (usually via `kubectl` config).

---

### **Step 3: Initialize Terraform**

```bash
terraform init
```

This command:

* Downloads the required provider plugins (e.g., Kubernetes).
* Sets up the local working directory.
* Prepares the backend for storing Terraform’s state.

You must run this the **first time** or any time you add new provider blocks.

---

### **Step 4: Review the Execution Plan**

```bash
terraform plan
```

This command performs a dry run:

* It checks what Terraform *would* create based on your `.tf` files.
* No actual resources are created at this stage.
* It shows the exact set of changes to be applied.

Review the output to understand what Terraform is about to do.

---

### **Step 5: Apply the Configuration**

```bash
terraform apply
```

When prompted:

```text
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

Terraform will:

* Create a new Kubernetes namespace
* Deploy the Python app (with 3 replicas)
* Create a NodePort service to expose it

---

### **Step 6: Verify the Deployment**

Check that everything is running in the Kubernetes cluster:

```bash
kubectl get all -n application
```

You should see:

* A deployment
* 3 running pods
* A service

To access the app locally in your browser:

```bash
minikube service sre-abc-training-app-service -n application
```

Terraform has successfully deployed your application using code.

---

### **Step 7: Modify and Reapply**

Let’s update the number of replicas:

1. Edit `variables.tf`:

```hcl
variable "replicas" {
  default = 5
}
```

2. Preview the change:

```bash
terraform plan
```

3. Apply the change:

```bash
terraform apply
```

Terraform will only update the replica count in the deployment — no other resources will be changed.

---

## **Module 2: Expanding Your Infrastructure – A Multi-Tier Application**

### **Hands-on Challenge 1: Add a ConfigMap**

A ConfigMap lets you inject configuration into your app without changing code.

1. Create `config.tf`:

```hcl
resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "app-config"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }
  data = {
    "MESSAGE_TEXT" = "Hello from the SRE Academy!"
  }
}
```

2. Modify the container spec in `main.tf` to use the ConfigMap:

```hcl
env {
  name  = "MESSAGE_TEXT"
  value = kubernetes_config_map.app_config.data.MESSAGE_TEXT
}
```

3. Apply the changes:

```bash
terraform apply
```

Your app will now use the environment variable defined in the ConfigMap.

---

### **Hands-on Challenge 2: Add a Redis Database**

Redis will act as a second-tier backend for our application.

Tasks:

* Deploy a Redis pod using the `redis:alpine` image.
* Create a `ClusterIP` service for Redis.
* Expose its host and port to the Python app as environment variables.

Hints:

* Redis listens on port `6379`.
* Use a second deployment and service in a new file: `redis.tf`.
* Reference `kubernetes_service.redis.metadata[0].name` for the hostname.

This simulates a **multi-tier app**, common in microservices architectures.

---

## **Module 3: Advanced Concepts and Troubleshooting**

### **Hands-on Challenge 3: Using Workspaces for Environments**

Workspaces allow you to maintain separate state for different environments.

1. Destroy resources in default workspace:

```bash
terraform workspace select default
terraform destroy
```

2. Create a new workspace:

```bash
terraform workspace new dev
```

3. Reapply the configuration:

```bash
terraform apply
```

4. Modify the app (e.g., change `replicas`) and reapply.

5. Switch between workspaces to compare state:

```bash
terraform workspace select default
terraform plan
```

Each workspace is isolated — no shared state.

---

## **Cleanup**

To delete resources:

```bash
terraform destroy
```

To clean up workspaces:

```bash
terraform workspace select default
terraform workspace delete dev
```

Always clean up after completing an exercise to avoid conflicts or quota issues.

---

## **Final Objective**

You now have hands-on experience with:

* Writing and applying Terraform configurations
* Managing Kubernetes infrastructure as code
* Using Terraform features like state, variables, outputs, and workspaces
* Deploying multi-tier apps in Kubernetes
* Troubleshooting drift and changes safely

These practices are foundational for modern Site Reliability Engineers working in cloud-native and DevOps environments.

---

## **Next Steps**

In [Exercise 16](../exercise16), you will automate this workflow using GitHub Actions. You’ll build a CI/CD pipeline that deploys infrastructure with Terraform on every code push or pull request.

---