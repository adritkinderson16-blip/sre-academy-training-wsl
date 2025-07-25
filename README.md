# SRE (Site Reliability Engineering) Process

---

## Introduction

This repository is part of IBM’s internal SRE Academy initiative. It applies software engineering principles to operations, enabling learners to build scalable and highly reliable systems. The goal is to ensure system availability, reduce toil, and drive continuous improvement—striking a balance between innovation velocity and risk management.

---

## Getting Started

Before working on any exercise or topic, make sure to set up the required tools. We've prepared a step-by-step installation guide for both macOS and Windows (WSL2).

👉 **[Start with the Tool Installation Guide](./installation.md)**

You’ll find instructions to install Python, Docker, Colima, Minikube, kubectl, and other essentials depending on your operating system.

Once your environment is ready, get the repository onto your machine using one of the following options:

### Option 1: Download as a ZIP File (Recommended for Students)

This is the simplest method and does not require Git configuration or tokens.

1. Navigate to the repository: `https://github.ibm.com/SRE-Academy/sre-academy-training.git`
2. Click the green "**Code**" button.
3. Select "**Download ZIP**".
4. Extract the ZIP to your preferred location.
5. Open your terminal and navigate to the extracted folder:

   ```bash
   cd /path/to/extracted/sre-academy-training-main
   ```

> ⚠️ The folder name may include `-main` or a commit hash.

### Option 2: Clone the Repository (Requires Git Setup & Token/SSH)

```bash
git clone https://github.ibm.com/SRE-Academy/sre-academy-training.git
cd sre-academy-training
```

> 🔐 You must be logged into [https://github.ibm.com](https://github.ibm.com) with your IBM w3id to access the repository.

---

## Table of Contents

* [Topics](#topics)
* [Exercises](#exercises)
* [Learning Path](#learning-path)
* [Final Objectives](#final-objectives)
* [Contributing](CONTRIBUTING.md)
* [License](LICENSE.md)
* [Notes](#notes)

---

## Topics

* [Topic 0 – SLIs, SLOs, SLAs, and Error Budgets](./exercises/topic0/)
* [Topic 1 – Time to Detect, Acknowledge, and Resolve](./exercises/topic1/)
* [Topic 2 – Synthetic Monitoring](./exercises/topic2/)
* [Topic 3 – Operational Readiness Review (ORR)](./exercises/topic3/)
* [Topic 4 – GitHub Fundamentals](./exercises/topic4/)
* [Topic 5 – Managing Tasks with GitHub Projects](./exercises/topic5/)
* [Topic 6 – Incident Management](./exercises/topic6/)

---

## Exercises

| Exercise #                                | Title                                | Description                                       |
| ----------------------------------------- | ------------------------------------ | ------------------------------------------------- |
| [Exercise #1](./exercises/exercise1/)     | Python app                           | Build and run a simple Python Flask application.  |
| [Exercise #2](./exercises/exercise2/)     | App packaged as image                | Package the Python app as a Docker image.         |
| [Exercise #3](./exercises/exercise3/)     | App image pushed to a registry       | Push the Docker image to a container registry.    |
| [Exercise #4](./exercises/exercise4/)     | Running the app as a service         | Deploy the Docker image as a service.             |
| [Exercise #4.1](./exercises/exercise4.1/) | IaC with Ansible                     | Use Ansible for Infrastructure as Code (IaC).     |
| [Exercise #5](./exercises/exercise5/)     | Include Prometheus                   | Integrate Prometheus for monitoring.              |
| [Exercise #6](./exercises/exercise6/)     | Include Grafana                      | Integrate Grafana for visualization.              |
| [Exercise #7](./exercises/exercise7/)     | Share node metrics                   | Collect and share node metrics.                   |
| [Exercise #8](./exercises/exercise8/)     | Share app traces                     | Collect and share application traces.             |
| [Exercise #9](./exercises/exercise9/)     | Create metrics from traces           | Create metrics based on application traces.       |
| [Exercise #10](./exercises/exercise10/)   | Share app logs                       | Set up log sharing and observability.             |
| [Exercise #11](./exercises/exercise11/)   | Golden Signals Dashboard             | Create a dashboard for golden signals monitoring. |
| [Exercise #12](./exercises/exercise12/)   | Define alerts                        | Define and configure alerts.                      |
| [Exercise #13](./exercises/exercise13/)   | Automate runbooks with Ansible + AWX | Automate runbooks using Ansible and AWX.          |
| [Exercise #14](./exercises/exercise14/)   | Helm Charts                          | Use Helm charts for application deployment.       |
| [Exercise #15](./exercises/exercise15/)   | Terraform                            | Manage infrastructure with Terraform.             |
| [Exercise #16](./exercises/exercise16/)   | CI/CD with GitHub Actions            | Implement CI/CD pipelines with GitHub Actions.    |
| [Exercise #17](./exercises/exercise17/)   | GitOps with ArgoCD                   | Practice GitOps using ArgoCD.                     |
| [Exercise #18](./exercises/exercise18/)   | Kubernetes Rollback                  | Perform rollbacks in Kubernetes.                  |
| [Exercise #19](./exercises/exercise19/)   | Chaos Engineering                    | Conduct chaos engineering experiments.            |

---

## Learning Path

1. **Start with the Topics (Topic 0 to Topic 6)**
   These foundational concepts are essential for understanding SRE principles before diving into practical labs.

2. **Proceed Through the Exercises Sequentially (Exercise 1 to Exercise 19)**
   Each exercise builds upon the previous one, gradually introducing new tools and concepts related to monitoring, automation, resiliency, and GitOps.

---

## Final Objectives

By completing all topics and exercises, you will:

* Learn and apply key SRE concepts in real-world labs.
* Deploy a containerized application and set up monitoring and alerting.
* Automate infrastructure using tools like Ansible, Helm, and Terraform.
* Practice GitOps with ArgoCD and CI/CD with GitHub Actions.
* Run chaos experiments to enhance system resilience.
* Manage tasks using GitHub Projects with a production-oriented mindset.

---

## Notes

* This repository is part of a practical training series developed for SRE onboarding and the IBM SRE Academy.
* Minikube (with Docker) is used to simulate Kubernetes environments; Colima and WSL2 are supported as local Docker runtimes.
* Please follow the [installation instructions](./installation.md) **before the first class** to avoid setup issues during live sessions.

Happy learning and implementing SRE best practices!

![SRE Academy](https://img.shields.io/badge/SRE-Academy-blue)

---