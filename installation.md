# Tool Installation Guide for SRE Academy

## Overview

This guide will help you install the required tools to complete all exercises in the SRE Academy (Exercises 1–19).
The setup is different depending on your operating system.

---

## What You Will Install

| Tool                        | Purpose                                   |
| --------------------------- | ----------------------------------------- |
| Python 3                    | Used to run the initial Flask application |
| pip / venv                  | To manage Python packages                 |
| Docker (via Colima or WSL2) | To build and run containers               |
| Minikube                    | To run a local Kubernetes cluster         |
| kubectl                     | To manage Kubernetes resources            |
| Homebrew (macOS)            | To install CLI tools                      |
| pipx + Ansible              | For Infrastructure as Code (Exercise 4.1) |

---

## For macOS Users

All macOS users (especially IBM-managed devices) must use **Colima** instead of Docker Desktop.

### Step 1: Install Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Verify installation:

```bash
brew --version
```

### Step 2: Install Required Tools

```bash
brew install python
brew install colima
brew install docker
brew install minikube
brew install kubectl
```

---

## For Windows Users

You must install **WSL2 (Windows Subsystem for Linux)** and use **Ubuntu** as your Linux distribution.

### Step 1: Enable WSL2

Open PowerShell **as Administrator** and run:

```powershell
wsl --install
```

Then restart your computer. This installs:

* WSL2
* Ubuntu (default distribution)
* Required kernel updates

> If needed: [WSL Official Setup Guide](https://learn.microsoft.com/en-us/windows/wsl/install)

---

### Step 2: Open Ubuntu and Update System

After reboot, open Ubuntu and run:

```bash
sudo apt update && sudo apt upgrade -y
```

---

### Step 3: Install Required Tools in Ubuntu

```bash
sudo apt install -y python3 python3-pip python3-venv
sudo apt install -y docker.io
sudo apt install -y minikube
sudo apt install -y kubectl
```

---

### Step 4: Add Your User to Docker Group

To avoid `sudo` when using Docker:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

---

## Install pipx and Ansible

> Starting from Exercise 4.1, we will use `pipx` to install Ansible in an isolated environment.

### On macOS

```bash
brew install pipx
pipx ensurepath

pipx install --include-deps ansible
pipx upgrade --include-injected ansible
pipx inject --include-apps ansible argcomplete
```

### On WSL2 (Ubuntu)

```bash
sudo apt update
sudo apt install -y pipx python3-venv
pipx ensurepath

pipx install --include-deps ansible
pipx upgrade --include-injected ansible
pipx inject --include-apps ansible argcomplete
```

Verify installation:

```bash
ansible --version
```

---

## After Installation

Once all tools are installed, verify:

```bash
python3 --version
pip3 --version
docker --version
minikube version
kubectl version --client
ansible --version
```

If any command fails, resolve it **before** attending the first class.

---

## Final Notes

* **macOS users** will use `colima` to simulate a Docker environment.
* **Windows users** will use `WSL2 + Ubuntu + Docker` to follow the same instructions.
* All commands in this academy assume the **Docker runtime** (`--driver=docker`) for Minikube.
* You are now ready to begin **Exercise 1**.

---
