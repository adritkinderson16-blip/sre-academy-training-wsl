# SRE (Site Reliability Engineering) Process

---

## Introduction

Site Reliability Engineering (SRE) applies software engineering principles to operations to build scalable and highly reliable systems. SRE ensures system availability, reduces toil, and drives continuous improvement—striking a balance between innovation velocity and risk management.

This repository offers a step-by-step learning path with hands-on exercises and supporting topics that introduce core SRE concepts, practices, and tooling. Each section contains clear objectives along with real-world examples for both aspiring and experienced SRE professionals.

---

## Getting Started

Before beginning any exercise or topic, clone the repository to your local machine:

```bash
git clone https://github.ibm.com/SRE-Academy/sre-academy-training.git
cd sre-academy-training
```

This will give you access to all the exercises (located in the `exercises/` folder) and topics (located in the `topicX/` folders).

---

## Table of Contents

- [Topics](#topics)
- [Exercises](#exercises)
- [Learning Path](#learning-path)
- [Final Objectives](#final-objectives)
- [Notes](#notes)

---

## Topics

- [Topic 0 – SLIs, SLOs, SLAs, and Error Budgets](./exercises/topic0/)
- [Topic 1 – Time to Detect, Acknowledge, and Resolve](./exercises/topic1/)
- [Topic 2 – Synthetic Monitoring](./exercises/topic2/)
- [Topic 3 – Operational Readiness Review (ORR)](./exercises/topic3/)
- [Topic 4 – GitHub Fundamentals](./exercises/topic4/)
- [Topic 5 – Managing Tasks with GitHub Projects](./exercises/topic5/)
- [Topic 6 – Incident Management](./exercises/topic6/)

---

## Exercises

| Exercise #                                | Title                                  | Description                                      |
|-------------------------------------------|----------------------------------------|--------------------------------------------------|
| [Exercise #1](./exercises/exercise1/)     | Python app                             | Build and run a simple Python Flask application. |
| [Exercise #2](./exercises/exercise2/)     | App packaged as image                  | Package the Python app as a Docker image.        |
| [Exercise #3](./exercises/exercise3/)     | App image pushed to a registry         | Push the Docker image to a container registry.   |
| [Exercise #4](./exercises/exercise4/)     | Running the app as a service           | Deploy the Docker image as a service.            |
| [Exercise #4.1](./exercises/exercise4.1/) | IaC with Ansible                       | Use Ansible for Infrastructure as Code (IaC).    |
| [Exercise #5](./exercises/exercise5/)     | Include Prometheus                     | Integrate Prometheus for monitoring.             |
| [Exercise #6](./exercises/exercise6/)     | Include Grafana                        | Integrate Grafana for visualization.             |
| [Exercise #7](./exercises/exercise7/)     | Share node metrics                     | Collect and share node metrics.                  |
| [Exercise #8](./exercises/exercise8/)     | Share app traces                       | Collect and share application traces.            |
| [Exercise #9](./exercises/exercise9/)     | Create metrics from traces             | Create metrics based on application traces.      |
| [Exercise #10](./exercises/exercise10/)   | Share app logs                         | Set up log sharing and observability.            |
| [Exercise #11](./exercises/exercise11/)   | Golden Signals Dashboard               | Create a dashboard for golden signals monitoring.|
| [Exercise #12](./exercises/exercise12/)   | Define alerts                          | Define and configure alerts.                     |
| [Exercise #13](./exercises/exercise13/)   | Automate runbooks with Ansible + AWX   | Automate runbooks using Ansible and AWX.         |
| [Exercise #14](./exercises/exercise14/)   | Helm Charts                            | Use Helm charts for application deployment.      |
| [Exercise #15](./exercises/exercise15/)   | Terraform                              | Manage infrastructure with Terraform.            |
| [Exercise #16](./exercises/exercise16/)   | CI/CD with GitHub Actions              | Implement CI/CD pipelines with GitHub Actions.   |
| [Exercise #17](./exercises/exercise17/)   | GitOps with ArgoCD                     | Practice GitOps using ArgoCD.                    |
| [Exercise #18](./exercises/exercise18/)   | Kubernetes Rollback                    | Perform rollbacks in Kubernetes.                 |
| [Exercise #19](./exercises/exercise19/)   | Chaos Engineering                      | Conduct chaos engineering experiments.           |

---

## Learning Path

1. **Start with the Topics (Topic 0 to Topic 6):**  
   These foundational concepts are essential for understanding SRE principles before diving into practical labs.

2. **Proceed Through the Exercises Sequentially (Exercise 1 to Exercise 19):**  
   The exercises build upon each other, guiding you from application creation and packaging to comprehensive monitoring, automation, and resilience engineering.

---

## Final Objectives

By completing all topics and exercises, you will:
- Learn and apply key SRE concepts in real-world labs.
- Deploy a containerized application and set up monitoring and alerting.
- Automate infrastructure management using tools like Ansible, Helm, and Terraform.
- Practice GitOps with ArgoCD and CI/CD with GitHub Actions.
- Run chaos experiments to enhance system resilience.
- Manage tasks using GitHub Projects with a production-oriented mindset.

---

## Notes

- This repository is part of a practical training series developed for SRE bootcamps and team onboarding.
- It is optimized for environments like Minikube but can be adapted to other Kubernetes setups.
- Contributions and improvements are welcome. If you encounter issues or have suggestions, please open a pull request or GitHub issue.

Happy learning and implementing SRE best practices!

![SRE Bootcamp](https://img.shields.io/badge/SRE-Bootcamp-blue)