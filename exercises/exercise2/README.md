# Python Application with Podman

## Table of Contents

  - [Introduction](https://www.google.com/search?q=%23introduction)
  - [What is Docker?](https://www.google.com/search?q=%23what-is-docker)
  - [What is Podman?](https://www.google.com/search?q=%23what-is-podman)
  - [Dockerfile Explanation](https://www.google.com/search?q=%23dockerfile-explanation)
  - [Prerequisites](https://www.google.com/search?q=%23prerequisites)
  - [Building the Container Image](https://www.google.com/search?q=%23building-the-container-image)
  - [Running the Container](https://www.google.com/search?q=%23running-the-container)
  - [Conclusion](https://www.google.com/search?q=%23conclusion)
  - [Final Objective](https://www.google.com/search?q=%23final-objective)

-----

## Introduction

This exercise focuses on containerizing a Python application and running it using **Podman**, a modern container management tool. You will learn how to build a container image and run it locally, enabling you to work with containerized environments in a secure and rootless manner.

-----

## What is Docker?

**Docker** is a popular platform used for developing, shipping, and running applications inside containers. Containers allow developers to package an application with all its dependencies and run it in a consistent environment across different systems. Docker provides:

  - Simplified container management.
  - Compatibility across multiple platforms.
  - A daemon-based approach to container orchestration.

-----

## What is Podman?

**Podman** is an open-source container engine similar to Docker but without requiring a background daemon. Key features include:

  - **Daemonless and rootless operation** for enhanced security.
  - Full compatibility with Dockerfiles.
  - Support for running containers in environments where Docker is not available or needed.

Unlike Docker, Podman does not require root access and provides improved security for managing containers.

-----

## Dockerfile Explanation

The `Dockerfile` is a script that contains a series of instructions to automate the creation of a container image. Here is what each instruction in the provided `Dockerfile` does:

```dockerfile
FROM python:3.10
EXPOSE 5000
WORKDIR /app
RUN pip install flask
COPY . .
CMD ["flask", "run", "--host", "0.0.0.0"]
```

**Explanation:**

1.  `FROM python:3.10`: Specifies the **base image** (Python 3.10) for the container. This means your container will start with a clean Python 3.10 environment.
2.  `EXPOSE 5000`: Informs Docker/Podman that the container is designed to **listen on port `5000`** at runtime. This is a declaration, not a firewall rule.
3.  `WORKDIR /app`: Sets the **working directory** inside the container to `/app`. All subsequent commands (like `COPY`, `RUN`, `CMD`) will be executed relative to this directory.
4.  `RUN pip install flask`: Executes the command to **install the `flask` package** inside the container. This ensures the application's dependencies are met.
5.  `COPY . .`: **Copies all files** from the host's current directory (where the `Dockerfile` is located) into the container's working directory (`/app`). This includes `app.py`.
6.  `CMD ["flask", "run", "--host", "0.0.0.0"]`: Defines the **command to run the Python application** when the container starts. It explicitly tells Flask to run and listen on all network interfaces (`0.0.0.0`).

-----

## Prerequisites

Before you start, ensure the following:

  - **Podman installed** on macOS. Follow the [Podman installation guide](https://podman.io/getting-started/installation) or use:
    ```bash
    brew install podman
    ```
  - Basic understanding of Python and containerization concepts.
  - Completion of Exercise \#1.

For macOS users new to Podman, initialize and start the Podman machine:

```bash
podman machine init
podman machine start
```

Verify that Podman is working with:

```bash
podman info
```

-----

## Building the Container Image

1.  Navigate to the `exercise2` directory:

    ```bash
    cd sre-academy-training/exercises/exercise2
    ```

2.  Build the container image:

    ```bash
    podman build -t my-python-app .
    ```

      - `-t my-python-app`: Assigns the **tag `my-python-app`** to the image, making it easy to reference later.
      - `.`: Specifies the **current directory** containing the `Dockerfile`, indicating where Podman should look for the build context.

-----

## Running the Container

Run the container using Podman:

```bash
podman run --rm -it -p 5000:5000 my-python-app
```

Explanation of flags:

  - `--rm`: **Removes the container** automatically once it stops, keeping your environment clean.
  - `-it`: Runs the container in **interactive mode** and allocates a pseudo-TTY, allowing you to see logs and interact (e.g., Ctrl+C to stop).
  - `-p 5000:5000`: **Maps port 5000** on the container to port 5000 on your host machine, making the application accessible from your browser.

Access the application by visiting:

```bash
http://127.0.0.1:5000/
```

---

## Conclusion

You have now successfully containerized and run a Python application using Podman. This exercise demonstrates the basics of containerization and prepares you for more advanced deployment scenarios.

-----

## Final Objective

At the end of this exercise, you should accomplish the following:

> **[!IMPORTANT]**
> Once the container is running, open your web browser and go to `http://127.0.0.1:5000/`. You should see the text **"Hello, World!"** displayed.
>
> ![app](app.png)

---