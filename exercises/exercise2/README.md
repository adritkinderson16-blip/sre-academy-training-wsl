# Python App Packaged as a Docker Image

## Table of Contents

- [Navigate to the Exercise Directory](#navigate-to-the-exercise-directory)
- [Overview](#overview)
- [What is Docker?](#what-is-docker)
- [What is Colima?](#what-is-colima)
- [Why This Exercise Matters](#why-this-exercise-matters)
- [Dockerfile Explanation](#dockerfile-explanation)
- [Prerequisites](#prerequisites)
- [Build the Docker Image](#build-the-docker-image)
- [Run the Docker Container](#run-the-docker-container)
- [Final Objective](#final-objective)
- [Next Steps](#next-steps)

---

## Navigate to the Exercise Directory

```bash
cd sre-academy-training/exercises/exercise2
````

---

## Overview

This exercise focuses on **containerizing a simple Python Flask application** using Docker. You'll create a Docker image from your application code and run it in a consistent and isolated environment. This is a key step in enabling reproducibility, portability, and fast deployment across different systems.

---

## What is Docker?

**Docker** is a platform for building, running, and managing containers. Containers are lightweight, standalone, and executable units that include everything needed to run a piece of software: code, runtime, libraries, and configuration.

Key benefits:

* Ensures consistent environments across development, testing, and production.
* Eliminates “it works on my machine” problems.
* Makes deployments faster and more reliable.

---

## What is Colima?

**Colima** (short for **Container On Lima**) is a tool that runs Docker and Kubernetes containers on macOS using a lightweight Linux virtual machine. It is an alternative to Docker Desktop and is often used on corporate laptops where Docker Desktop is restricted or not allowed.

Colima uses the `docker` CLI and works seamlessly with the Docker ecosystem:

* On **macOS**, it enables Docker-style workflows without requiring Docker Desktop.
* On **Windows**, users typically use **WSL2 with Ubuntu** and install Docker CLI inside that Linux environment.

---

## Why This Exercise Matters

In real-world production environments, applications run inside containers. Understanding how to:

* Build an image,
* Package your code,
* Run it consistently anywhere,

...is foundational for any SRE or DevOps role. This exercise introduces:

* The `Dockerfile`: a reproducible recipe for building containers.
* `docker build`: how to turn your source code into a reusable image.
* `docker run`: how to run and test your container locally.

These are the first steps toward automation, CI/CD pipelines, and deployment into Kubernetes.

---

## Dockerfile Explanation

Here’s the breakdown of the provided `Dockerfile`:

```Dockerfile
FROM python:3.10
EXPOSE 5000
WORKDIR /app
RUN pip install flask
COPY . .
CMD ["flask", "run", "--host", "0.0.0.0"]
```

* `FROM python:3.10`: Uses Python 3.10 as the base image.
* `EXPOSE 5000`: Documents the port the app will use.
* `WORKDIR /app`: Sets the working directory inside the container.
* `RUN pip install flask`: Installs Flask inside the container.
* `COPY . .`: Copies your local code to the container.
* `CMD [...]`: Runs the Flask app, listening on all network interfaces.

---

## Prerequisites

Before proceeding:

* Make sure you have **Colima running with Docker**:

  ```bash
  colima start --runtime docker
  ```

* Verify Docker is working:

  ```bash
  docker version
  ```

---

## Build the Docker Image

Run the following command inside the exercise directory:

```bash
docker build -t my-python-app .
```

What this does:

* Uses the `Dockerfile` to build a container image from your source code.
* `-t my-python-app` tags the image so you can reference it easily.
* `.` means the current directory is used as the build context (where to find the Dockerfile and app code).

---

## Run the Docker Container

Start your container:

```bash
docker run --rm -it -p 5000:5000 my-python-app
```

Flags explained:

* `--rm`: Deletes the container after it stops (keeps your system clean).
* `-it`: Runs interactively and shows logs in your terminal.
* `-p 5000:5000`: Maps container port 5000 to host port 5000 so you can access the app in your browser.

Visit:

```bash
http://127.0.0.1:5000/
```

You should see:

```
Hello, World!
```

---

## Final Objective

Your goal is to:

* Successfully build a Docker image from the Python app.
* Run the container using Docker.
* Validate that the application runs correctly in the container.

> ![app](app.png)

---

## Next Steps

After verifying everything works, continue with [Exercise 3](../exercise3/), where you’ll push your image to a container registry to prepare it for sharing and deployment.

---