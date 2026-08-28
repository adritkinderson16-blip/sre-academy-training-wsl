# Tool Installation Guide for SRE Academy

## Table of Contents

- [Overview](#overview)
- [Tools You Will Install](#tools-you-will-install)
- [macOS Users](#macos-users)
  - [Step 1 – Install Homebrew](#step-1--install-homebrew)
  - [Step 2 – Install Required Tools](#step-2--install-required-tools)
  - [Step 3 – Start Colima](#step-3--start-colima)
- [Windows Users (WSL2 + Ubuntu)](#windows-users-wsl2--ubuntu)
  - [Step 1 – Enable WSL2](#step-1--enable-wsl2)
  - [Step 2 – Enable systemd in WSL2](#step-2--enable-systemd-in-wsl2)
  - [Step 3 – Install Docker Engine (Official Repo)](#step-3--install-docker-engine-official-repo)
  - [Step 4 – Install kubectl (Official Repo)](#step-4--install-kubectl-official-repo)
  - [Step 5 – Install Minikube (Official Binary)](#step-5--install-minikube-official-binary)
  - [Step 6 – Install Python, pip, venv, pipx, and Ansible](#step-6--install-python-pip-venv-pipx-and-ansible)
  - [Step 7 – Install Git](#step-7--install-git)
- [Starting Minikube](#starting-minikube)
- [Verification](#verification)
- [Final Notes](#final-notes)

## Overview

This guide will walk you through installing all the required tools for **Exercises 1–19** in the SRE Academy.
Setup steps differ depending on your operating system.

---

## Tools You Will Install

| Tool                    | Purpose                                       |
| ----------------------- | --------------------------------------------- |
| Python 3                | Runs the initial Flask application            |
| pip / venv              | Manages Python packages                       |
| Docker (Colima or WSL2) | Builds and runs containers                    |
| Minikube                | Runs a local Kubernetes cluster               |
| kubectl                 | Manages Kubernetes resources                  |
| Homebrew (macOS only)   | Installs CLI tools                            |
| pipx + Ansible          | Infrastructure as Code (Exercise 4.1 onwards) |

---

## macOS Users

All macOS users (especially IBM-managed devices) **must use Colima** instead of Docker Desktop.

### Step 1 – Install Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew --version
```

### Step 2 – Install Required Tools

```bash
brew install python
brew install ansible
brew install colima
brew install docker
brew install minikube
brew install kubectl
brew install git
```

### Step 3 – Start Colima

```bash
colima start --cpu 4 --memory 6 --disk 60
docker version
```

---

## Windows Users (WSL2 + Ubuntu)

You must install **WSL2** and use **Ubuntu** as your Linux distribution.
We will install **Docker Engine** (official repo), **Minikube**, and **kubectl**.

### Step 1 – Enable WSL2

Open **PowerShell as Administrator** and run:

```powershell
wsl --install
```

Restart your computer.

---

### Step 2 – Enable systemd in WSL2

This is required for Docker to run as a service inside WSL2.

In Ubuntu:

```bash
sudo nano /etc/wsl.conf
```

Add:

```
[boot]
systemd=true
```

Back in PowerShell (Windows):

```powershell
wsl --shutdown
```

Reopen Ubuntu.

---

### Step 3 – Install Docker Engine (Official Repo)

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER
newgrp docker
sudo systemctl enable --now docker
docker version
```

---

### Step 4 – Install kubectl (Official Repo)

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
  | sudo gpg --dearmor --yes \
      -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubectl=1.35.1-1.1
kubectl version --client
```

---

### Step 5 – Install Minikube (Official Binary)

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
minikube version
```

---

### Step 6 – Install Python, pip, venv, pipx, and Ansible

```bash
sudo apt-get install -y python3 python3-pip python3-venv pipx
pipx ensurepath
pipx install --include-deps ansible
ansible --version
```

---

### Step 7 – Install Git

```bash
sudo apt install git
```

---

## Starting Minikube

On both macOS and Windows/WSL2:

```bash
minikube start --driver=docker
kubectl get nodes
```

---

## Verification

Run these commands to ensure all tools are working:

```bash
python3 --version
pip3 --version
docker --version
minikube version
kubectl version --client
ansible --version
git --version
```

---

## Final Notes

* **macOS users** use `colima` to simulate a Docker environment.
* **Windows users** use `WSL2 + Ubuntu + Docker Engine`.
* All Minikube commands use the **Docker driver** (`--driver=docker`).

---
