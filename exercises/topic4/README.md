# **GitHub Fundamentals**

## **Table of Contents**

* [Overview](#overview)
* [Prerequisites & Setup](#prerequisites--setup)
* [What is GitHub?](#what-is-github)
* [Key Concepts](#key-concepts)

  * [Repositories](#repositories)
  * [Commits and Version History](#commits-and-version-history)
  * [Branches](#branches)
  * [Pull Requests](#pull-requests)
  * [Issues](#issues)
  * [Forks and Cloning](#forks-and-cloning)
* [Getting Started: Basic Workflow](#getting-started-basic-workflow)
* [Best Practices for GitHub Collaboration](#best-practices-for-github-collaboration)
* [Branching Strategies](#branching-strategies)
* [Essential GitHub Commands](#essential-github-commands)
* [Exercise: Practice the Fundamentals](#exercise-practice-the-fundamentals)
* [Summary](#summary)

---

## **Overview**

**GitHub** is the most widely used platform for collaborative software development. It builds on Git and enables teams to manage code, track changes, and collaborate efficiently. In this topic, you’ll learn core concepts and workflows to use GitHub effectively in both personal and professional projects.

---

## **Prerequisites & Setup**

Before we begin, make sure the following tools are installed and configured:

### 1. Git

* **Install:** [https://git-scm.com/downloads](https://git-scm.com/downloads)
* **Verify:**

  ```bash
  git --version
  ```

### 2. GitHub Account

* Create a personal account at: [https://github.com/join](https://github.com/join)
* ⚠️ **Use a personal email** (not your IBM email) to ensure future access to your account.

### 3. Visual Studio Code (VSC)

* **Install:** [https://code.visualstudio.com/download](https://code.visualstudio.com/download)
* **Verify:** Open a terminal and run:

  ```bash
  code .
  ```

### 4. Git Configuration

Run the following to set up your identity in Git:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

---

## **What is GitHub?**

GitHub is a cloud-based hosting service for Git repositories. It enables collaboration, version control, code reviews, and project management in a shared space.

Use GitHub to:

* Collaborate with others
* Track issues and features
* Review and merge code changes
* Maintain documentation and history

---

## **Key Concepts**

### **Repositories**

* A repo is the main container for your project code.
* Can be public or private.
* Typically includes a `README.md`, `LICENSE`, and `.gitignore`.

### **Commits and Version History**

* A **commit** is a snapshot of your files at a point in time.
* Use meaningful messages (e.g., `Fix broken link on homepage`).
* Track and revert changes using Git’s history.

### **Branches**

* **Branching** allows for isolated development.
* Common types: `main`, `feature/*`, `bugfix/*`, `hotfix/*`.
* Merge changes via pull requests.

### **Pull Requests (PRs)**

* Propose changes from one branch to another.
* Enables **code review** and **discussion** before merging.
* PRs can include issue references (e.g., `Fixes #21`).

### **Issues**

* Use to track bugs, features, questions, or tasks.
* Organize with **labels**, assign **owners**, and use **milestones**.

### **Forks and Cloning**

* **Fork**: Make your own copy of a repo to contribute to someone else’s project.
* **Clone**: Download a repo to work locally.

---

## **Getting Started: Basic Workflow**

1. **Clone a repository**

   ```bash
   git clone https://github.com/yourname/repo.git
   ```

2. **Create a new branch**

   ```bash
   git checkout -b feature/my-feature
   ```

3. **Make changes and commit**

   ```bash
   git add .
   git commit -m "Add my new feature"
   ```

4. **Push to GitHub**

   ```bash
   git push origin feature/my-feature
   ```

5. **Open a pull request** from GitHub UI

6. **Review and merge** the PR once approved

---

## **Best Practices for GitHub Collaboration**

### **Commit Best Practices**

* Write meaningful messages
* Keep changes atomic
* Avoid committing secrets or credentials
* Link commits to issues (e.g., `Closes #45`)

### **Pull Request Best Practices**

* One feature or fix per PR
* Include a clear description
* Request reviews from relevant teammates
* Resolve comments and keep conversation focused

### **Issue Management Best Practices**

* Create issues for all bugs or enhancements
* Use templates when available
* Assign and label issues clearly
* Close issues after resolution

---

## **Branching Strategies**

### **Main Only**

* Simple projects where changes go directly to `main`
* Risky for collaboration

### **Feature Branching**

* Create branches per task (e.g., `feature/login`)
* Merge into `main` via PR
* Ideal for small/medium projects

### **Git Flow**

* Formal structure with branches for `develop`, `release/*`, `hotfix/*`
* Best for large projects with scheduled releases

### **Trunk-Based Development**

* Frequent merges to `main` from short-lived branches
* Works well with strong CI/CD pipelines

### **Choosing a Strategy**

* Use **Feature Branching** for most teams
* Use **Git Flow** for formal releases
* Use **Trunk-Based** for fast, CI-driven teams

---

## **Essential GitHub Commands**

```bash
# Clone a repository
git clone <repo-url>

# Check repo status
git status

# Stage changes
git add .

# Commit changes
git commit -m "Meaningful message"

# Create a branch
git checkout -b feature/my-change

# Push branch to GitHub
git push origin feature/my-change

# Pull changes
git pull origin main

# View commit history
git log --oneline --graph --all
```

---

## **Exercise: Practice the Fundamentals**

1. Create a new GitHub repository
2. Clone it locally
3. Create a branch `feature/hello-world`
4. Add a file `hello.txt` with:

   ```
   Hello, GitHub!
   ```
5. Commit and push
6. Open and merge a PR
7. Create an issue labeled `enhancement`
8. Try a branching strategy for future changes

---

## **Summary**

Mastering GitHub fundamentals allows you to collaborate, manage code, and build software more effectively. By following best practices and adopting a consistent workflow, your team can move faster while keeping quality and traceability high.

---