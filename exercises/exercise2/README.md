# Python Application with Podman

## Table of Contents
- [Introduction](#introduction)
- [What is Docker?](#what-is-docker)
- [What is Podman?](#what-is-podman)
- [Project Structure](#project-structure)
- [Dockerfile Explanation](#dockerfile-explanation)
- [Prerequisites](#prerequisites)
- [Building the Container Image](#building-the-container-image)
- [Running the Container](#running-the-container)
- [Conclusion](#conclusion)
- [Final Objective](#final-objective)

---

## Introduction

This exercise focuses on containerizing a Python application and running it using **Podman**, a modern container management tool. You will learn how to build a container image and run it locally, enabling you to work with containerized environments in a secure and rootless manner.

---

## What is Docker?

**Docker** is a popular platform used for developing, shipping, and running applications inside containers. Containers allow developers to package an application with all its dependencies and run it in a consistent environment across different systems. Docker provides:
- Simplified container management.
- Compatibility across multiple platforms.
- A daemon-based approach to container orchestration.

---

## What is Podman?

**Podman** is an open-source container engine similar to Docker but without requiring a background daemon. Key features include:
- Daemonless and rootless operation for enhanced security.
- Full compatibility with Dockerfiles.
- Support for running containers in environments where Docker is not available or needed.

Unlike Docker, Podman does not require root access and provides improved security for managing containers.

---

## Project Structure

Here is the project structure for this exercise:

```
exercises/exercise2/
├── Dockerfile
├── Infra.png
├── README.md
├── app.png
└── app.py
```

- **Dockerfile**: Contains the instructions for building the container image.
- **Infra.png**: Diagram or visualization of the application's infrastructure.
- **README.md**: This file contains instructions for the exercise.
- **app.png**: Screenshot of the application running.
- **app.py**: Python script for the application.

---

## Dockerfile Explanation

The `Dockerfile` is a script that contains a series of instructions to automate the creation of a container image. Here is what each instruction in the provided `Dockerfile` does:

```Dockerfile
# Use the official Python image from Docker Hub
FROM python:3.9-slim

# Set the working directory inside the container
WORKDIR /app

# Copy the application code into the container
COPY app.py .

# Install the Python dependencies (if any)
RUN pip install flask

# Specify the command to run the application
CMD ["python", "app.py"]
```

**Explanation:**
1. `FROM`: Specifies the base image (Python 3.9 slim version) for the container.
2. `WORKDIR`: Sets the working directory inside the container to `/app`.
3. `COPY`: Copies the `app.py` file from the host to the container's working directory.
4. `RUN`: Installs the `flask` package inside the container.
5. `CMD`: Defines the command to run the Python application when the container starts.

---

## Prerequisites

Before you start, ensure the following:
- **Podman installed** on macOS. Follow the [Podman installation guide](https://podman.io/getting-started/installation) or use:
  ```bash
  brew install podman
  ```
- Basic understanding of Python and containerization concepts.
- Completion of Exercise #1.

For macOS users new to Podman, initialize and start the Podman machine:
```bash
podman machine init
podman machine start
```

Verify that Podman is working with:
```bash
podman info
```

---

## Building the Container Image

1. Navigate to the `exercise2` directory:
   ```bash
   cd sre-academy-training/exercises/exercise2
   ```

2. Build the container image:
   ```bash
   podman build -t my-python-app .
   ```

   - `-t my-python-app`: Assigns the tag `my-python-app` to the image.
   - `.`: Specifies the current directory containing the `Dockerfile`.

---

## Running the Container

Run the container using Podman:
```bash
podman run --rm -it -p 5000:5000 my-python-app
```

Explanation of flags:
- `--rm`: Removes the container after it stops.
- `-it`: Runs the container interactively.
- `-p 5000:5000`: Maps port 5000 on the container to port 5000 on the host.

Access the application by visiting:
```bash
http://127.0.0.1:5000/
```

---

## Conclusion

You have now successfully containerized and run a Python application using Podman. This exercise demonstrates the basics of containerization and prepares you for more advanced deployment scenarios.

---

## Final Objective

At the end of this exercise, you should accomplish the following:

> **[!IMPORTANT]**
> Once the container is running, open your web browser and go to `http://127.0.0.1:5000/`. You should see the text **"Hello, World!"** displayed.
>
> ![app](app.png)

---