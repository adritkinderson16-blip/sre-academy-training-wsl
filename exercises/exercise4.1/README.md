# Infrastructure as Code (IaC) with Ansible

## Table of Contents

- [What is Infrastructure as Code (IaC)?](#what-is-infrastructure-as-code-iac)
  - [Why is IaC Important?](#why-is-iac-important)
- [What is Ansible?](#what-is-ansible)
  - [Key Features of Ansible](#key-features-of-ansible)
- [Navigate to the Exercise Directory](#navigate-to-the-exercise-directory)
- [Step 1: Install pipx](#step-1-install-pipx)
- [Step 2: Install Ansible with pipx](#step-2-install-ansible-with-pipx)
- [Step 3: Getting Started with Ansible](#step-3-getting-started-with-ansible)
- [Step 4: Setting Up an Inventory File](#step-4-setting-up-an-inventory-file)
  - [Testing the Inventory File](#testing-the-inventory-file)
- [Step 5: Running a Basic Ansible Playbook](#step-5-running-a-basic-ansible-playbook)
  - [Verify the Output](#verify-the-output)
- [Step 6: Automating Infrastructure Setup with IaC Playbook](#step-6-automating-infrastructure-setup-with-iac-playbook)
  - [Review the IaC Playbook](#review-the-iac-playbook)
  - [Run the IaC Playbook](#run-the-iac-playbook)
  - [Verify Infrastructure Setup](#verify-infrastructure-setup)
- [Final Objective](#final-objective)

-----

## What is Infrastructure as Code (IaC)?

Infrastructure as Code (IaC) is a modern approach to managing and provisioning computing infrastructure through code, rather than manual processes. With IaC, infrastructure configuration and deployment are defined in machine-readable scripts, allowing infrastructure to be versioned, tested, and reproduced just like software code.

### Why is IaC Important?

  - **Consistency**: IaC helps eliminate configuration drift and ensures that environments are consistent across development, testing, and production.
  - **Efficiency**: Manual infrastructure management is time-consuming. IaC automates repetitive tasks, making setup faster and reducing human error.
  - **Scalability**: With IaC, scaling infrastructure up or down is much easier, especially in environments like cloud computing where resources can be dynamically adjusted.
  - **Version Control**: Since infrastructure is managed as code, all changes can be tracked through version control, enabling rollback if an issue arises.

-----

## What is Ansible?

Ansible is an open-source automation tool primarily used for configuration management, application deployment, and task automation. With its simple YAML syntax, Ansible allows developers and operators to describe the desired state of systems without needing to write complex code.

### Key Features of Ansible

  - **Agentless**: No need to install additional software on the target machines.
  - **Idempotency**: Ensures that applying the same configuration multiple times yields the same result.
  - **Flexibility**: Supports a wide range of modules for different environments.

-----

## Navigate to the Exercise Directory

To begin, navigate to the directory for Exercise 4.1:

```bash
cd sre-academy-training/exercises/exercise4.1
```

This directory contains the necessary files for the exercise, including `inventory.ini`, `playbook.yaml`, and `iac_paybook.yaml`.

-----

## Step 1: Install pipx

`pipx` is a tool to install and run Python applications in isolated environments. To install `pipx` on macOS:

```bash
brew install pipx
pipx ensurepath
```

-----

## Step 2: Install Ansible with pipx

Once `pipx` is installed, use it to install Ansible. This approach ensures Ansible and its dependencies are managed in a virtual environment.

```bash
pipx install --include-deps ansible
pipx upgrade --include-injected ansible
pipx inject --include-apps ansible argcomplete
```

Verify the installation:

```bash
ansible --version
```

-----

## Step 3: Getting Started with Ansible

To prepare the environment, create a new directory for your Ansible project and navigate into it. Although this directory is already part of the cloned repository, the following command illustrates the structure:

```bash
cd ansible_quickstart
```

The `ansible_quickstart` directory contains:

  - `inventory.ini`: Defines the systems Ansible will manage.
  - `playbook.yaml`: A simple playbook to test Ansible functionality.
  - `iac_paybook.yaml`: A more complex playbook to automate Minikube and Podman setup.

-----

## Step 4: Setting Up an Inventory File

An inventory file is used to define the systems Ansible will manage. The provided file, `inventory.ini`, contains the following content:

```ini
[allhosts]
127.0.0.1 ansible_connection=local
```

This file tells Ansible to connect to 127.0.0.1 (localhost) using the local connection method, which is useful for testing and development.

### Testing the Inventory File

To confirm that the inventory file is correctly configured, run:

```bash
ansible-inventory -i inventory.ini --list
```

Expected output:

```json
{
    "_meta": {
        "hostvars": {}
    },
    "all": {
        "children": [
            "ungrouped",
            "allhosts"
        ]
    },
    "allhosts": {
        "hosts": [
            "127.0.0.1"
        ]
    }
}
```

To verify connectivity, use the following command:

```bash
ansible allhosts -m ping -i inventory.ini
```

Expected output:

```bash
127.0.0.1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/local/bin/python3.12"
    },
    "changed": false,
    "ping": "pong"
}
```

-----

## Step 5: Running a Basic Ansible Playbook

To test your Ansible setup and run the provided basic playbook, execute the following command:

```bash
ansible-playbook -i inventory.ini playbook.yaml --ask-become-pass
```

> **Note:** When prompted, enter your system password. This is required to elevate privileges for certain tasks.

### Verify the Output

The output should look like this if everything worked as expected:

```bash
BECOME password:

PLAY [My first play] *************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************
[WARNING]: Platform darwin on host 127.0.0.1 is using the discovered Python interpreter at /opt/homebrew/bin/python3.13, but future installation of another Python interpreter could change the
meaning of that path. See [https://docs.ansible.com/ansible-core/2.18/reference_appendices/interpreter_discovery.html](https://docs.ansible.com/ansible-core/2.18/reference_appendices/interpreter_discovery.html) for more information.
ok: [127.0.0.1]

TASK [Ping my hosts] *************************************************************************************************************
ok: [127.0.0.1]

TASK [Print message] *************************************************************************************************************
ok: [127.0.0.1] => {
    "msg": "Hello world"
}

PLAY RECAP ***********************************************************************************************************************
127.0.0.1                  : ok=3    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

-----

## Step 6: Automating Infrastructure Setup with IaC Playbook

Now, let's explore a more practical application of IaC by running a playbook designed to set up Minikube and Podman on your machine. This demonstrates how you can automate complex environment configurations.

### Review the IaC Playbook

Before running it, take a moment to review the `iac_paybook.yaml` file in your `ansible_quickstart` directory. Notice how it uses conditional tasks (`when:`) for different operating systems (macOS, Debian/Ubuntu) and various modules (`homebrew`, `apt`, `get_url`, `command`) to install software and start services.

### Run the IaC Playbook

> **[\!WARNING]**
> If you already have Minikube and Podman set up from previous exercises, running this playbook might attempt to reinstall or restart them. This is generally **idempotent** (meaning it will achieve the desired state without breaking existing installations), but be aware of the actions it performs.
> If you wish to test a fresh setup, you might consider running `minikube delete` and cleaning up Podman installations before this step (refer to previous exercise clean-up instructions).

Execute the `iac_paybook.yaml`:

```bash
ansible-playbook -i inventory.ini iac_paybook.yaml --ask-become-pass
```

> **Note:** You will be prompted for your system password as this playbook performs installations that require elevated privileges. The playbook may take a few minutes to complete, especially if it needs to download and install packages.

### Verify Infrastructure Setup

After the playbook completes, you can verify that Minikube is running using the same commands from Exercise 4:

```bash
minikube status
minikube dashboard
```

You should see that Minikube is running and the dashboard launches successfully, demonstrating that the playbook effectively provisioned your local Kubernetes environment.

-----

## Final Objective

At the end of this exercise, you should be able to:

  * **Successfully use Ansible** to execute basic tasks defined in a playbook.
  * **Understand and demonstrate the principles of Infrastructure as Code** by running an Ansible playbook (`iac_paybook.yaml`) that automates the setup of tools like Minikube and Podman, ensuring a reproducible environment.

-----