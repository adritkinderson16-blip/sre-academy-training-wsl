# Prerequisites and System Setup

This document explains how to prepare your local environment to run the exercises from this repository, including Kubernetes-based labs using Minikube.

---

## Supported Operating Systems

- macOS
- Windows 10/11

---

## Required Tools

| Tool | macOS | Windows (via WSL2) |
|---|---|---|
| Minikube | `brew install minikube` | Install inside WSL |
| QEMU | `brew install qemu` | Installed via apt in WSL |
| kubectl | `brew install kubectl` | Install inside WSL |

---

## Setup on macOS

1. **Install Minikube**
   ```bash
   brew install minikube
   ```

2.  **Install QEMU (virtualization engine)**

    ```bash
    brew install qemu
    ```

3.  **Install kubectl**

    ```bash
    brew install kubectl
    ```

4.  **Start Minikube with QEMU**

    ```bash
    minikube start --driver=qemu
    ```

5.  **Enable recommended addons**

    ```bash
    minikube addons enable ingress
    minikube addons enable metrics-server
    minikube addons enable dashboard
    ```

-----

## Setup on Windows

### Option 1: Using WSL2 (Recommended)

> ⚠️ **Note:** Windows support has not been officially tested for this repository.
> These instructions are provided based on equivalent setups from macOS and Linux.
> Use with caution, and feel free to contribute improvements if you encounter issues.

> Avoids Docker Desktop
> Works well with Minikube + QEMU inside Linux

1.  **Enable WSL2 (Windows Subsystem for Linux)**

    ```powershell
    wsl --install
    ```

2.  **Install Ubuntu from Microsoft Store**
    Recommended: Ubuntu 22.04

3.  **Inside Ubuntu (WSL Terminal):**

    ```bash
    sudo apt update && sudo apt upgrade
    sudo apt install -y curl qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
    ```

4.  **Install Minikube**

    ```bash
    curl -LO [https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64](https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64)
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    ```

5.  **Install kubectl**

    ```bash
    curl -LO "[https://dl.k8s.io/release/$(curl](https://dl.k8s.io/release/$(curl) -s [https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl](https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl)"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    ```

6.  **Start Minikube using KVM (QEMU backend)**

    ```bash
    minikube start --driver=kvm2
    ```

-----

## Verifying Installation

  * Check cluster status:

    ```bash
    minikube status
    ```

  * Validate node is ready:

    ```bash
    kubectl get nodes
    ```

-----

## Troubleshooting

  * If Minikube fails to start with QEMU:

      * Try `--force` option
      * Delete and restart: `minikube delete && minikube start --driver=qemu`

  * If using WSL and KVM is unavailable, try VirtualBox as fallback:

    ```bash
    minikube start --driver=virtualbox
    ```

-----

## See Also

  * [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
  * [Kubernetes CLI (kubectl)](https://kubernetes.io/docs/tasks/tools/)
  * [WSL2 Setup Guide (Microsoft)](https://learn.microsoft.com/en-us/windows/wsl/install)

-----