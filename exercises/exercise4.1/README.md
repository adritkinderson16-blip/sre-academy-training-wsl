# Infrastructure as Code (IaC) with Ansible

## Table of Contents

* [What is Infrastructure as Code (IaC)?](#what-is-infrastructure-as-code-iac)

  * [Why is IaC Important?](#why-is-iac-important)
* [What is Ansible?](#what-is-ansible)

  * [Key Features of Ansible](#key-features-of-ansible)
* [Navigate to the Exercise Directory](#navigate-to-the-exercise-directory)
* [Getting Started with Ansible](#getting-started-with-ansible)
* [Step 1: Setting Up an Inventory File](#step-1-setting-up-an-inventory-file)

  * [Test Inventory File](#test-inventory-file)
* [Step 2: Running a Basic Ansible Playbook](#step-2-running-a-basic-ansible-playbook)

  * [Verify the Output](#verify-the-output)
* [Step 3: Automating Infrastructure Setup with IaC Playbook](#step-3-automating-infrastructure-setup-with-iac-playbook)

  * [Review the IaC Playbook](#review-the-iac-playbook)
  * [Run the IaC Playbook](#run-the-iac-playbook)
  * [Verify Infrastructure Setup](#verify-infrastructure-setup)
* [Final Objective](#final-objective)
* [Next Steps](#next-steps)


---

## What is Infrastructure as Code (IaC)?

Infrastructure as Code (IaC) is the practice of defining infrastructure—like servers, packages, clusters, and services—in machine-readable configuration files. This allows engineers to automate environment setup, enforce consistency across systems, and apply the same rigor of versioning and testing to infrastructure as they do to software development.

### Why is IaC Important?

* **Consistency**: Prevents "configuration drift" between environments.
* **Speed**: Automates repetitive tasks and reduces human error.
* **Scalability**: Makes it easier to scale systems up or down on demand.
* **Traceability**: All changes can be tracked using Git or other version control systems.

---

## What is Ansible?

Ansible is a simple, agentless automation engine that lets you define and enforce system configurations using plain-text YAML files called playbooks. It connects to remote or local machines over SSH or locally and executes the desired changes in a repeatable, idempotent way.

### Key Features of Ansible

* **Agentless**: No need to install anything on the managed systems.
* **Idempotent**: Running the same playbook multiple times won’t cause unexpected results.
* **Human-Readable**: Uses YAML for easy-to-read and write automation tasks.

---

## Navigate to the Exercise Directory

Before you begin, navigate to the correct directory for this exercise:

```bash
cd sre-academy-training/exercises/exercise4.1
```

This folder contains:

* `inventory.ini` – your inventory file for Ansible
* `playbook.yaml` – a simple example playbook
* `iac_playbook.yaml` – a more advanced Infrastructure-as-Code playbook

---

## Getting Started with Ansible

Ansible should already be installed using `pipx` as described in the [Tool Installation Guide](../exercise4/installation.md).

You can confirm it is working by checking the version:

```bash
ansible --version
```

If Ansible is not recognized, revisit the installation guide before proceeding.

---

## Step 1: Setting Up an Inventory File

An inventory file tells Ansible what hosts to manage. In this case, we’ll use `localhost` for local testing and provisioning.

The provided `inventory.ini` looks like this:

```ini
[allhosts]
127.0.0.1 ansible_connection=local
```

This means:

* The host is your local machine.
* Ansible will connect without SSH, using the `local` method.

### Test Inventory File

Run this command to validate that Ansible recognizes the host:

```bash
ansible-inventory -i inventory.ini --list
```

Expected result (formatted JSON):

```json
{
  "_meta": { "hostvars": {} },
  "all": {
    "children": [ "ungrouped", "allhosts" ]
  },
  "allhosts": {
    "hosts": [ "127.0.0.1" ]
  }
}
```

Also test the connection with:

```bash
ansible allhosts -m ping -i inventory.ini
```

You should see:

```bash
127.0.0.1 | SUCCESS => {
  "changed": false,
  "ping": "pong"
}
```

---

## Step 2: Running a Basic Ansible Playbook

Let’s run a simple playbook to verify Ansible works on your machine.

Run the following:

```bash
ansible-playbook -i inventory.ini playbook.yaml --ask-become-pass
```

> This playbook:
>
> * Gathers facts about the system
> * Pings the local machine
> * Prints a "Hello World" message

### Verify the Output

If successful, the output will include:

* ✅ Facts gathered
* ✅ Ping task succeeded
* ✅ Message printed

Sample output:

```
TASK [Ping my hosts]
ok: [127.0.0.1]

TASK [Print message]
ok: [127.0.0.1] => {
    "msg": "Hello world"
}
```

---

## Step 3: Automating Infrastructure Setup with IaC Playbook

Now you’ll use `iac_playbook.yaml` to automate a full infrastructure setup using Ansible.

This includes:

* Installing required packages (like Minikube or Podman)
* Starting background services
* Handling both macOS and Linux setups

### Review the IaC Playbook

Open `iac_playbook.yaml` and observe:

* Conditional logic for operating systems:

  ```yaml
  when: ansible_os_family == "Debian"
  ```
* Modules used:

  * `apt` (Linux)
  * `homebrew` (macOS)
  * `get_url` for downloading
  * `command` for CLI-based operations

### Run the IaC Playbook

Make sure you're in the `exercise4.1` folder, then run:

```bash
ansible-playbook -i inventory.ini iac_playbook.yaml --ask-become-pass
```

> **Note:** When prompted, enter your system password. This is required to elevate privileges for certain tasks.

### Verify Infrastructure Setup

Check that services were set up correctly:

```bash
minikube status
minikube dashboard
```

Both commands should return valid output if the installation worked.

---

## Final Objective

By completing this exercise, you should be able to:

* Use **Ansible** to run simple and complex playbooks.
* Define and test an **inventory file**.
* Automate infrastructure provisioning using **Infrastructure as Code**.
* Understand how to extend playbooks for different platforms and requirements.

You’re now ready to expand this foundation into more advanced automation workflows.

---

## Next Steps

In [Exercise 5](../exercise5), we’ll deploy a basic Prometheus setup inside your local Kubernetes cluster to start collecting system-level metrics. This will mark the beginning of your journey into **observability** and monitoring, laying the foundation for future integrations with Grafana, Alertmanager, and OpenTelemetry.

You should now be confident with:

* Installing and running Ansible playbooks locally.
* Defining inventory files to manage hosts.
* Using Infrastructure as Code (IaC) to provision and configure local environments like Minikube and Podman.

---
