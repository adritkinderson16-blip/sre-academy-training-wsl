# **Implementing CI/CD with GitHub Actions**

## **Table of Contents**

* [Scenario: The Production Outage Problem](#scenario-the-production-outage-problem)
* [Learning Objectives](#learning-objectives)
* [Prerequisites](#prerequisites)
* [Understanding CI/CD in SRE Context](#understanding-cicd-in-sre-context)
* [Getting Started: Setup and Repository Initialization](#getting-started-setup-and-repository-initialization)
* [Phase 1: Basic Pipeline Foundation](#phase-1-basic-pipeline-foundation)
* [Phase 2: Security and Quality Gates](#phase-2-security-and-quality-gates)
* [Phase 3: Multi-Environment Deployment](#phase-3-multi-environment-deployment)
* [Phase 4: Observability and Monitoring](#phase-4-observability-and-monitoring)
* [Phase 5: Failure Simulation and Recovery](#phase-5-failure-simulation-and-recovery)
* [Real-World Extensions and SRE Metrics](#real-world-extensions-and-sre-metrics)
* [Reflection Questions](#reflection-questions)
* [Next Steps](#next-steps)

---

## Scenario: The Production Outage Problem

You’re a Site Reliability Engineer at **TechCorp**, a fast-growing startup. Over the past quarter, your team has experienced:

* **8 production outages** caused by manual deployment errors
* **45 minutes average** time to detect deployment issues
* **2.5 hours average** time to rollback failed deployments
* **Developer frustration** with inconsistent environments
* **Customer complaints** about service reliability

### **Your Mission**

Design and implement a production-ready CI/CD pipeline that eliminates manual deployment errors, reduces time-to-detection, and improves overall system reliability.

### **Success Metrics**

* Zero deployment-related outages
* Sub-5-minute detection of deployment issues
* Automated rollback capability
* 99.9% deployment success rate

---

## Learning Objectives

By completing this exercise, you will:

* Design resilient CI/CD pipelines that prevent production incidents
* Implement security scanning and quality gates in deployment workflows
* Create multi-environment deployment strategies with automated promotion
* Build observability into CI/CD processes for faster incident detection
* Understand failure modes and implement automated recovery mechanisms
* Apply SRE principles of error budgets, SLOs, and toil reduction to CI/CD
* Simulate and handle pipeline failures like a production environment

---

## Prerequisites

To follow this exercise successfully, you should have:

* Basic understanding of Python, Git, and Docker
* Familiarity with YAML syntax
* Understanding of HTTP APIs and web services
* Basic knowledge of monitoring concepts (metrics, logs, alerts)
* A **new, empty public GitHub repository** for this exercise

---

## Understanding CI/CD in SRE Context

### What is Continuous Integration (CI)?

CI is the practice of automatically building, testing, and validating code changes multiple times per day. For SREs, CI is about reducing risk through automation.

**SRE Benefits:**

* Early detection of issues before they reach production
* Consistent environments across development and production
* Reduced toil from manual testing and integration
* Faster feedback loops for developers

### What is Continuous Deployment (CD)?

CD extends CI by automatically deploying validated changes to production. For SREs, CD is about reliability and repeatability.

**SRE Benefits:**

* Reduced MTTR through automated rollbacks
* Smaller, safer changes deployed more frequently
* Elimination of deployment drift between environments
* Improved observability of deployment impact

### Why GitHub Actions?

* **Infrastructure as Code**: Pipeline definitions are stored in version control
* **Event-driven automation**: Triggers based on code changes, schedules, or external events
* **Integrated security**: Built-in secret management and vulnerability scanning
* **Scalable compute**: Serverless runners eliminate infrastructure overhead
* **Rich ecosystem**: Thousands of reusable actions for common DevOps tasks

---

## Getting Started: Setup and Repository Initialization

In this phase, you will prepare your local environment and initialize your new GitHub repository with the necessary files.

### **Step 1: Prepare Your Repository**

### Create a New Repository on GitHub

1. Go to [https://github.com/new](https://github.com/new)
2. **Repository name**: `sre-cicd-pipeline`
3. **Visibility**: Public (recommended for this exercise)
4. Leave **“Initialize this repository with a README”** **unchecked**
5. Click **Create repository**

### Prepare Your Local Directory

In your terminal:

```bash
# Create a clean destination folder
mkdir -p ~/Projects/sre-cicd-pipeline

# Copy only the contents of exercise16 into it
cp -r ~/Downloads/sre-academy-training-main/exercises/exercise16/* ~/Projects/sre-cicd-pipeline/

> NOTE: Your source path may vary depending on where you downloaded the repository.
> Replace ~/Downloads/... with the actual path to your local copy of the SRE Academy repo.

# Navigate to your new working directory
cd ~/Projects/sre-cicd-pipeline
```

### Initialize Git and Commit Locally

```bash
git init
git add .
git commit -m "Initial commit - standalone CI/CD pipeline"
```

### Link to GitHub and Push

Replace `YOUR-USERNAME` with your actual GitHub username if needed:

```bash
git remote add origin https://github.com/YOUR-USERNAME/sre-cicd-pipeline.git
git branch -M main
git push -u origin main
```

> ❗ If you see an error like “rejected: fetch first,” it means the GitHub repo already has a README or commit. In that case, force the push:

```bash
git push --force origin main
```

### **Step 2: Update Application Code and Dependencies**

Now that your repository is initialized, let’s update the application and prepare it for testing.

### Update `app/app.py`

Replace the default content with a production-friendly version that includes two endpoints (`/health` and `/api/data`) and prints clear instructions to the terminal when running locally.

Run the following command to overwrite `app.py`:

```bash
cat <<EOF > app/app.py
from flask import Flask, jsonify
import os
import time

app = Flask(__name__)

@app.route('/health')
def health_check():
    return jsonify({
        "status": "healthy",
        "timestamp": int(time.time()),
        "version": os.getenv("APP_VERSION", "unknown")
    })

@app.route('/api/data')
def get_data():
    return jsonify({
        "message": "Hello from TechCorp API",
        "environment": os.getenv("ENVIRONMENT", "development"),
        "version": os.getenv("APP_VERSION", "1.0.0")
    })

if __name__ == "__main__":
    print("Flask app initialized.")
    print("To test the app, run the following commands in a separate terminal:")
    print("  curl http://localhost:8080/health")
    print("  curl http://localhost:8080/api/data")
    print("Then press Ctrl+C to exit.")
    app.run(host='0.0.0.0', port=8080)
EOF
```

#### Update `app/requirements.txt`

Next, create the file that lists your Python dependencies:

```bash
cat <<EOF > app/requirements.txt
flask==2.3.3
pytest==7.4.0
pytest-cov==4.1.0
black==23.7.0
flake8==6.0.0
requests==2.31.0
EOF
```

#### Create `app/test_app.py`

Now add a Python test file to validate the app behavior:

```bash
cat <<EOF > app/test_app.py
import pytest
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_health_check(client):
    response = client.get('/health')
    assert response.status_code == 200
    data = response.get_json()
    assert data['status'] == 'healthy'
    assert 'timestamp' in data

def test_get_data(client):
    response = client.get('/api/data')
    assert response.status_code == 200
    data = response.get_json()
    assert 'message' in data
    assert 'environment' in data
EOF
```

#### Test the Application Locally

Ensure your application works before adding CI:

```bash
cd app
pip install -r requirements.txt
python -m pytest
python app.py
```

> This app doesn't serve a homepage (`/`) or favicon, so you should not open it in a browser.
> You should **run the curl commands** manually to test the API.
> Example:

  ```bash
  curl http://localhost:8080/health
  curl http://localhost:8080/api/data
  ```

You should receive a JSON response indicating the app is healthy.

### **Step 3: Commit Your Changes**

Once verified, commit and push everything:

```bash
git add .
git commit -m "Complete setup for exercise"
git push origin main
```

---

## Phase 1: Basic Pipeline Foundation

In this phase, you will create the core CI pipeline that runs **unit tests** and **code quality checks** every time code is pushed. This is your first reliability gate — it ensures that broken or non-compliant code **never reaches your main branch**.

This early automation step helps you:

* Catch issues as soon as they happen (shift-left testing)
* Enforce consistent style and clean code practices across teams
* Prevent bugs from progressing to more expensive stages (e.g., staging or production)
* Build trust in every commit as part of a healthy software delivery lifecycle

As an SRE, these gates are the first signal that your system is behaving as expected before deployment even begins.

### **Step 1: Create the GitHub Actions Workflow File**

Start by creating the directory structure and a new workflow file:

```bash
mkdir -p .github/workflows
```

Then create a file named `.github/workflows/ci-cd.yml` with the following content:

```yaml
name: SRE Production Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    name: Run Tests and Quality Checks
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Set up Python
      uses: actions/setup-python@v5
      with:
        python-version: '3.11'

    - name: Install dependencies
      run: |
        cd app
        pip install -r requirements.txt
        pip install pytest-cov black flake8

    - name: Code formatting check
      run: |
        cd app
        black --check .

    - name: Linting
      run: |
        cd app
        flake8 . --max-line-length=100

    - name: Run unit tests
      run: |
        cd app
        pytest --cov=. --cov-report=xml --cov-report=term
```

This workflow defines a single job called `test` which:

* Checks out the code
* Installs Python and dependencies
* Verifies code formatting with `black`
* Lints the code with `flake8`
* Runs unit tests with coverage

### **Step 2: Commit and Test the Pipeline**

Once the workflow file is ready, commit and push the changes:

```bash
git add .github/workflows/ci-cd.yml
git commit -m "Add basic CI pipeline with tests"
git push origin main
```

Go to the **Actions** tab in your GitHub repository to verify that the workflow is triggered.

### Intentional First Failure: Code Formatting

> 🔥 The first time you push, the pipeline will likely **fail on the `black --check .` step**.

This is intentional.

The purpose of this check is to prevent non-compliant code from entering `main`. It teaches you to:

* Observe CI feedback
* Fix issues locally
* Re-commit clean code

You’ll likely see a message like:

```bash
would reformat app.py
would reformat test_app.py

Oh no! 💥 💔 💥
2 files would be reformatted.
```

To fix it:

```bash
cd app
black .
```

This command runs [**Black**](https://black.readthedocs.io/en/stable/), a Python code formatter that automatically rewrites your code to follow a strict style guide.

* `black` is the tool
* `.` tells it to format **all Python files in the current directory**
* It modifies your code in place to make it compliant

After running the command, your files will be updated automatically.

Then re-commit and push the changes:

```bash
git add .
git commit -m "Fix formatting to pass Black check"
git push origin main
```

Once pushed, the pipeline should now pass.

---

## Phase 2: Security and Quality Gates

Security and quality checks are critical SRE responsibilities. You will now extend your pipeline by adding steps to scan for vulnerabilities and enforce security policies.

These quality gates ensure that code changes are secure and meet best practices before progressing to deployment.

### **Step 1: Create a Helper Script for Security Evaluation**

This script evaluates the results of `safety` and `bandit`, which check for known vulnerabilities and insecure coding patterns. If any critical issues are found, the script will fail the pipeline.

```bash
# Step 1: Create the scripts directory
mkdir scripts

# Step 2: Write the security evaluation script
cat <<EOF > scripts/evaluate-security.py
#!/usr/bin/env python3
import json
import sys
import os

def evaluate_security_results():
    """Evaluate security scan results and fail if critical issues found"""
    critical_issues = 0

    # Check Safety results
    if os.path.exists('app/safety-report.json'):
        with open('app/safety-report.json', 'r') as f:
            try:
                safety_data = json.load(f)
                if isinstance(safety_data, list):
                    critical_issues += len([v for v in safety_data if 'vulnerability' in str(v).lower()])
            except:
                pass

    # Check Bandit results
    if os.path.exists('app/bandit-report.json'):
        with open('app/bandit-report.json', 'r') as f:
            try:
                bandit_data = json.load(f)
                if 'results' in bandit_data:
                    high_issues = [r for r in bandit_data['results'] if r.get('issue_severity') == 'HIGH']
                    critical_issues += len(high_issues)
            except:
                pass

    print(f"Found {critical_issues} critical security issues")

    if critical_issues > 0:
        print("❌ Security scan failed - critical vulnerabilities found")
        sys.exit(1)
    else:
        print("✅ Security scan passed")
        sys.exit(0)

if __name__ == "__main__":
    evaluate_security_results()
EOF

# Step 3: Make the script executable
chmod +x scripts/evaluate-security.py
```

### **Step 2: Add the Security Scan Job to Your Workflow**

Now that you’ve established a baseline for testing and code quality, it's time to integrate **security scanning** into your CI/CD pipeline.

In this step, you'll add a new job named `security-scan` to your GitHub Actions workflow. This job will run **only if the `test` job passes**, ensuring that only tested and syntactically valid code is scanned for security issues.

---

#### Why is this important?

As an SRE or DevSecOps engineer, your responsibility doesn't end at passing tests — you also need to prevent insecure code from reaching production. This security job helps you:

* **Catch known vulnerabilities** in your Python dependencies using [Safety](https://github.com/pyupio/safety)
* **Perform static analysis** on your code using [Bandit](https://bandit.readthedocs.io/) to find insecure coding practices (e.g., use of `eval`, hardcoded passwords, etc.)
* **Fail the pipeline automatically** if critical issues are found

Adding this stage ensures that **security becomes a default part of your development lifecycle**, not an afterthought.

---

### What you'll do:

* Add a new `security-scan` job to your pipeline
* Ensure it depends on the successful completion of the `test` job
* Automate security evaluations with `safety` and `bandit`
* Use a helper script to fail the job if critical vulnerabilities are detected

---

### Next step:

Update the `.github/workflows/ci-cd.yml` file to include the `security-scan` job. Replace the entire file with the updated version provided below.

> 🔒 Security should never be optional in a modern pipeline — this job enforces that principle automatically.

```yaml
name: SRE Production Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    name: Run Tests and Quality Checks
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          cd app
          pip install -r requirements.txt
          pip install pytest-cov black flake8

      - name: Code formatting check
        run: |
          cd app
          black --check .

      - name: Linting
        run: |
          cd app
          flake8 . --max-line-length=100

      - name: Run unit tests
        run: |
          cd app
          pytest --cov=. --cov-report=xml --cov-report=term

  security-scan:
    name: Security Analysis
    runs-on: ubuntu-latest
    needs: test

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install security tools
        run: |
          pip install safety bandit

      - name: Check for known vulnerabilities
        run: |
          cd app
          safety check -r requirements.txt --json > safety-report.json || true

      - name: Static security analysis
        run: |
          cd app
          bandit -r . -f json -o bandit-report.json || true

      - name: Evaluate security results
        run: |
          python scripts/evaluate-security.py
```

### **Step 3: Commit and Test the Security Pipeline**

```bash
git add scripts/evaluate-security.py .github/workflows/ci-cd.yml
git commit -m "Add security scanning to pipeline"
git push origin main
```

Go to the **Actions** tab in GitHub to ensure the workflow now runs two jobs sequentially:

1. `test`
2. `security-scan`

Both should pass, unless a critical vulnerability is detected.

---

## Phase 3: Multi-Environment Deployment

A production-grade pipeline doesn’t stop after running tests and scanning for security issues. It must support **progressive delivery** through multiple environments (like `staging` and `production`), ensuring reliability at every stage.

In this phase, we’ll simulate this using three additional jobs in the pipeline:

* `build`: Generates a container image (simulated)
* `deploy-staging`: Deploys the app to a staging environment and runs verification tests
* `deploy-production`: Deploys the app to a production environment if staging passes

But before we can automate these deployments, we need test scripts to verify that each environment is healthy. That’s where our work begins.

---

### **Step 1: Create Helper Scripts for Validation**

In this step, you’ll generate two Python scripts:

* `smoke-tests.py`: Simulates verifying the application's health and basic functionality after a deployment.
* `performance-test.py`: Simulates performance testing by generating random latency metrics for a specified duration.

These scripts will later be executed automatically as part of the `deploy-staging` and `deploy-production` jobs in the pipeline.

> You’ll use the `cat <<EOF > filename.py` method to write each script to disk. This technique ensures proper formatting and avoids manual indentation errors.

#### `scripts/smoke-tests.py`

This script simulates basic health checks and API verification.

```bash
cat <<EOF > scripts/smoke-tests.py
#!/usr/bin/env python3
import requests
import sys
import argparse
import time

def run_smoke_tests(environment):
    print(f"🧪 Running smoke tests against {environment} environment...")
    tests = [
        {"name": "Health Check", "endpoint": "/health"},
        {"name": "API Data", "endpoint": "/api/data"},
    ]
    passed = 0
    total = len(tests)
    for test in tests:
        print(f"  Testing {test['name']}...")
        time.sleep(2)
        print(f"  ✅ {test['name']} passed")
        passed += 1
    print(f"\n📊 Smoke test results: {passed}/{total} tests passed")
    if passed == total:
        print("✅ All smoke tests passed!")
        return True
    else:
        print("❌ Some smoke tests failed!")
        return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--environment", required=True)
    args = parser.parse_args()
    success = run_smoke_tests(args.environment)
    sys.exit(0 if success else 1)
EOF
```

---

#### `scripts/performance-test.py`

This script simulates a performance test by printing randomized latency numbers for a given duration.

```bash
cat <<EOF > scripts/performance-test.py
#!/usr/bin/env python3
import argparse
import time
import random

def run_performance_test(duration, environment):
    print(f"🚀 Running performance test for {duration}s against {environment}")
    for i in range(duration // 10):
        latency = random.uniform(50, 200)
        print(f"  Average latency: {latency:.1f}ms")
        time.sleep(10)
    print("✅ Performance test completed - within acceptable limits")
    return True

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--duration", type=int, required=True)
    parser.add_argument("--environment", required=True)
    args = parser.parse_args()
    run_performance_test(args.duration, args.environment)
EOF
```

---

### Make the scripts executable

Once both scripts have been created, make sure they are executable by the CI runner:

```bash
chmod +x scripts/*.py
```

This step is required so that GitHub Actions can run the scripts without permission errors during the `deploy-staging` and `deploy-production` jobs.

---

### **Step 2: Add Build and Deployment Jobs to the Pipeline**

Now that your validation scripts are in place, it’s time to expand your `.github/workflows/ci-cd.yml` file to simulate:

* Building the application (with metadata and digests)
* Deploying to a `staging` environment
* Running smoke and performance tests in staging
* Promoting to a `production` environment once staging passes

Each of these jobs is gated by the previous one using the `needs:` keyword — this creates a reliable, test-driven release flow.

By chaining these jobs together, you’re simulating a **progressive delivery model**, where code must pass increasing levels of scrutiny before reaching production.

---

#### Add the pipeline jobs using this command:

```bash
cat <<EOF > .github/workflows/ci-cd.yml
name: SRE Production Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: \${{ github.repository }}

jobs:
  test:
    name: Run Tests and Quality Checks
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          cd app
          pip install -r requirements.txt
          pip install pytest-cov black flake8

      - name: Code formatting check
        run: |
          cd app
          black --check .

      - name: Linting
        run: |
          cd app
          flake8 . --max-line-length=100

      - name: Run unit tests
        run: |
          cd app
          pytest --cov=. --cov-report=xml --cov-report=term

  security-scan:
    name: Security Analysis
    runs-on: ubuntu-latest
    needs: test

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install security tools
        run: |
          pip install safety bandit

      - name: Check for known vulnerabilities
        run: |
          cd app
          safety check -r requirements.txt --json > safety-report.json || true

      - name: Static security analysis
        run: |
          cd app
          bandit -r . -f json -o bandit-report.json || true

      - name: Evaluate security results
        run: |
          python scripts/evaluate-security.py

  build:
    name: Build and Push Image
    runs-on: ubuntu-latest
    needs: [test, security-scan]
    if: github.ref == 'refs/heads/main'

    outputs:
      image-digest: \${{ steps.build.outputs.digest }}
      image-tag: \${{ steps.meta.outputs.tags }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: \${{ env.REGISTRY }}/\${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=sha,prefix={{branch}}-

      - name: Build and push image (simulated)
        id: build
        run: |
          echo "Building image for commit: \${{ github.sha }}"
          echo "Image would be tagged as: \${{ steps.meta.outputs.tags }}"
          echo "digest=sha256:\$(date +%s | sha256sum | cut -d' ' -f1)" >> \$GITHUB_OUTPUT

  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: build
    environment: staging

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy to staging cluster (simulated)
        run: |
          echo "🚀 Deploying to staging environment"
          echo "Image: \${{ needs.build.outputs.image-tag }}"
          sleep 10
          echo "✅ Deployment to staging completed"

      - name: Run smoke tests
        run: |
          python scripts/smoke-tests.py --environment=staging

      - name: Performance baseline test
        run: |
          python scripts/performance-test.py --duration=30 --environment=staging

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: [build, deploy-staging]
    environment: production

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy to production cluster (simulated)
        run: |
          echo "🚀 Deploying to production environment"
          echo "Image: \${{ needs.build.outputs.image-tag }}"
          sleep 15
          echo "✅ Production deployment completed"

      - name: Post-deployment verification
        run: |
          echo "🔍 Running post-deployment verification..."
          sleep 5
          echo "✅ All systems healthy"
EOF
```

### **Step 3: Commit and Run the Full Pipeline**

Now that you’ve written the test scripts and defined the new deployment jobs, commit and push your changes:

```bash
git add scripts/smoke-tests.py scripts/performance-test.py .github/workflows/ci-cd.yml
git commit -m "Add multi-environment deployment pipeline"
git push origin main
```

Once your pipeline runs:

1. Code is tested and scanned for security
2. A container image is simulated and metadata is generated
3. The app is deployed to a staging environment, where smoke and performance tests are run
4. If staging passes, it’s promoted to production for final verification

This structure mirrors how modern SRE teams validate releases safely and reliably.

---

## Phase 4: Observability and Monitoring

Even after a successful production deployment, your job as an SRE isn’t done. You must ensure that the service remains **healthy and performant**. That’s where observability practices come in.

In this phase, you’ll simulate an **SLO (Service Level Objective)** check — a critical component of post-deployment validation that helps determine whether the service is meeting user expectations.

---

### **Step 1: Create the SLO Monitoring Script**

You will now create a Python script called `slo-check.py` that simulates measuring **availability** and **latency** of the service against pre-defined thresholds.

This script will be executed by the pipeline **after production deployment**, and if SLOs are not met, it will return a non-zero exit code (causing the job to fail).

> Like before, we’ll use `cat <<EOF >` to generate the script, ensuring correct formatting.

```bash
cat <<EOF > scripts/slo-check.py
#!/usr/bin/env python3
import argparse
import time
import random

def check_slo(environment, window, availability_target, latency_target):
    print(f"🎯 Checking SLOs for {environment} environment")
    print(f"   Window: {window}")
    print(f"   Availability target: {availability_target}%")
    print(f"   Latency target: {latency_target}ms")

    # Simulate real-world delay and random metrics
    time.sleep(5)
    current_availability = random.uniform(99.5, 99.99)
    current_latency = random.uniform(100, 300)

    print(f"\n📊 Current metrics:")
    print(f"   Availability: {current_availability:.2f}%")
    print(f"   Average latency: {current_latency:.1f}ms")

    slo_met = (current_availability >= availability_target and 
               current_latency <= latency_target)

    if slo_met:
        print("✅ All SLOs are being met")
        return True
    else:
        print("❌ SLO violation detected!")
        return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--environment", required=True)
    parser.add_argument("--window", required=True)
    parser.add_argument("--availability-target", type=float, required=True)
    parser.add_argument("--latency-target", type=int, required=True)
    args = parser.parse_args()

    success = check_slo(args.environment, args.window, 
                        args.availability_target, args.latency_target)

    if not success:
        exit(1)
EOF
```

Then make the script executable:

```bash
chmod +x scripts/slo-check.py
```

---

### **Step 2: Add the SLO Check Job to Your Pipeline**

Now that you have the script ready, the next step is to **add a new job** to your GitHub Actions workflow.

This job, named `slo-check`, runs **after `deploy-production`**. It verifies that the deployed service still meets your SLOs for **availability** and **late

```bash
cat <<EOF > .github/workflows/ci-cd.yml
name: SRE Production Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: \${{ github.repository }}

jobs:
  test:
    name: Run Tests and Quality Checks
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          cd app
          pip install -r requirements.txt
          pip install pytest-cov black flake8

      - name: Code formatting check
        run: |
          cd app
          black --check .

      - name: Linting
        run: |
          cd app
          flake8 . --max-line-length=100

      - name: Run unit tests
        run: |
          cd app
          pytest --cov=. --cov-report=xml --cov-report=term

  security-scan:
    name: Security Analysis
    runs-on: ubuntu-latest
    needs: test

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install security tools
        run: |
          pip install safety bandit

      - name: Check for known vulnerabilities
        run: |
          cd app
          safety check -r requirements.txt --json > safety-report.json || true

      - name: Static security analysis
        run: |
          cd app
          bandit -r . -f json -o bandit-report.json || true

      - name: Evaluate security results
        run: |
          python scripts/evaluate-security.py

  build:
    name: Build and Push Image
    runs-on: ubuntu-latest
    needs: [test, security-scan]
    if: github.ref == 'refs/heads/main'

    outputs:
      image-digest: \${{ steps.build.outputs.digest }}
      image-tag: \${{ steps.meta.outputs.tags }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: \${{ env.REGISTRY }}/\${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=sha,prefix={{branch}}-

      - name: Build and push image (simulated)
        id: build
        run: |
          echo "Building image for commit: \${{ github.sha }}"
          echo "Image would be tagged as: \${{ steps.meta.outputs.tags }}"
          echo "digest=sha256:\$(date +%s | sha256sum | cut -d' ' -f1)" >> \$GITHUB_OUTPUT

  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: build
    environment: staging

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy to staging cluster (simulated)
        run: |
          echo "🚀 Deploying to staging environment"
          echo "Image: \${{ needs.build.outputs.image-tag }}"
          sleep 10
          echo "✅ Deployment to staging completed"

      - name: Run smoke tests
        run: |
          python scripts/smoke-tests.py --environment=staging

      - name: Performance baseline test
        run: |
          python scripts/performance-test.py --duration=30 --environment=staging

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: [build, deploy-staging]
    environment: production

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy to production cluster (simulated)
        run: |
          echo "🚀 Deploying to production environment"
          echo "Image: \${{ needs.build.outputs.image-tag }}"
          sleep 15
          echo "✅ Production deployment completed"

      - name: Post-deployment verification
        run: |
          echo "🔍 Running post-deployment verification..."
          sleep 5
          echo "✅ All systems healthy"

  slo-check:
    name: Verify SLOs
    runs-on: ubuntu-latest
    needs: deploy-production
    if: always()

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Check Service Level Objectives
        run: |
          python scripts/slo-check.py \
            --environment=production \
            --window=15min \
            --availability-target=99.9 \
            --latency-target=200
EOF
```
---

### **Step 3: Commit and Push the Changes**

Run the following commands to add the script and update your pipeline definition:

```bash
git add scripts/slo-check.py .github/workflows/ci-cd.yml
git commit -m "Add SLO monitoring to pipeline after production deployment"
git push origin main
```

---

### What You’ve Accomplished

Your pipeline now includes a **post-deployment observability phase** — just like in real-world SRE practice. It validates not only that the app was deployed, but also that it meets performance and reliability expectations before it’s declared stable.

You’ve introduced the foundation for:

* Automated reliability enforcement
* Progressive delivery with measurable quality gates
* Real SRE culture in CI/CD automation

---

## Phase 5: Failure Simulation and Recovery

Failure is inevitable. As an SRE, your job is to plan for it and recover gracefully.

In this phase, you’ll simulate a **production failure** and implement an **automated rollback mechanism**. If the production deployment job (`deploy-production`) fails, a new job (`automated-rollback`) will trigger and restore a previous version.

This is the final phase that completes a reliable, resilient CI/CD pipeline.

---

### **Step 1: Create the Rollback Script**

You’ll begin by creating a script called `rollback.py`. This simulates identifying the last known good version of the application and rolling back to it.

Like before, we’ll use a `cat <<EOF` block to avoid indentation errors.

```bash
cat <<EOF > scripts/rollback.py
#!/usr/bin/env python3
import argparse

def rollback_deployment(environment, reason):
    """Simulate rollback to previous version"""
    print(f"🔄 Initiating rollback for {environment} environment")
    print(f"   Reason: {reason}")

    print("   Finding previous successful deployment...")
    print("   Rolling back to previous version...")
    print("   Verifying rollback...")

    print("✅ Rollback completed successfully")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--environment", required=True)
    parser.add_argument("--reason", required=True)
    args = parser.parse_args()

    rollback_deployment(args.environment, args.reason)
EOF

chmod +x scripts/rollback.py
```

This script will later be invoked automatically by GitHub Actions if your production deployment fails.

---

### **Step 2: Add the Rollback Job to Your Workflow**

Now you’ll add a job to `.github/workflows/ci-cd.yml` called `automated-rollback`. This job runs only when `deploy-production` fails. It simulates an emergency recovery procedure.

To avoid YAML indentation errors, use this command to regenerate the full workflow file (with rollback logic included):

```bash
cat <<EOF > .github/workflows/ci-cd.yml
name: SRE Production Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: \${{ github.repository }}

jobs:
  test:
    name: Run Tests and Quality Checks
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          cd app
          pip install -r requirements.txt
          pip install pytest-cov black flake8

      - name: Code formatting check
        run: |
          cd app
          black --check .

      - name: Linting
        run: |
          cd app
          flake8 . --max-line-length=100

      - name: Run unit tests
        run: |
          cd app
          pytest --cov=. --cov-report=xml --cov-report=term

  security-scan:
    name: Security Analysis
    runs-on: ubuntu-latest
    needs: test

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install security tools
        run: |
          pip install safety bandit

      - name: Check for known vulnerabilities
        run: |
          cd app
          safety check -r requirements.txt --json > safety-report.json || true

      - name: Static security analysis
        run: |
          cd app
          bandit -r . -f json -o bandit-report.json || true

      - name: Evaluate security results
        run: |
          python scripts/evaluate-security.py

  build:
    name: Build and Push Image
    runs-on: ubuntu-latest
    needs: [test, security-scan]
    if: github.ref == 'refs/heads/main'

    outputs:
      image-digest: \${{ steps.build.outputs.digest }}
      image-tag: \${{ steps.meta.outputs.tags }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: \${{ env.REGISTRY }}/\${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=sha,prefix={{branch}}-

      - name: Build and push image (simulated)
        id: build
        run: |
          echo "Building image for commit: \${{ github.sha }}"
          echo "Image would be tagged as: \${{ steps.meta.outputs.tags }}"
          echo "digest=sha256:\$(date +%s | sha256sum | cut -d' ' -f1)" >> \$GITHUB_OUTPUT

  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: build
    environment: staging

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy to staging cluster (simulated)
        run: |
          echo "🚀 Deploying to staging environment"
          echo "Image: \${{ needs.build.outputs.image-tag }}"
          sleep 10
          echo "✅ Deployment to staging completed"

      - name: Run smoke tests
        run: |
          python scripts/smoke-tests.py --environment=staging

      - name: Performance baseline test
        run: |
          python scripts/performance-test.py --duration=30 --environment=staging

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: [build, deploy-staging]
    environment: production

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy to production cluster (simulated)
        run: |
          echo "🚀 Deploying to production environment"
          echo "Image: \${{ needs.build.outputs.image-tag }}"
          sleep 15
          echo "✅ Production deployment completed"

      - name: Post-deployment verification
        run: |
          echo "🔍 Running post-deployment verification..."
          sleep 5
          echo "✅ All systems healthy"

  slo-check:
    name: Verify SLOs
    runs-on: ubuntu-latest
    needs: deploy-production
    if: always()

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Check Service Level Objectives
        run: |
          python scripts/slo-check.py \
            --environment=production \
            --window=15min \
            --availability-target=99.9 \
            --latency-target=200

  automated-rollback:
    name: Automated Rollback
    runs-on: ubuntu-latest
    needs: deploy-production
    if: failure()

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Trigger rollback
        run: |
          echo "❌ Production deployment failed, initiating rollback"
          python scripts/rollback.py \
            --environment=production \
            --reason="Failed deployment: \${{ github.sha }}"

      - name: Verify rollback success
        run: |
          echo "🔍 Verifying rollback success..."
          sleep 5
          echo "✅ Rollback verification completed"
EOF
```

This ensures that rollbacks only run when a production release is broken — a best practice in real-world CI/CD systems.

---

### **Step 3: Simulate a Failure to Trigger Rollback**

To confirm that your automated rollback mechanism works as intended, you’ll now simulate a production deployment failure.

However, it's important to understand how GitHub Actions workflows are structured:

* Jobs like `test` and `security-scan` run first to ensure that only valid, secure code proceeds through the pipeline.
* If you inject a syntax error or break the application code early, the pipeline will stop in the **test phase**, and **the deployment jobs will never be reached**.
* As a result, the `automated-rollback` job will not be triggered because it only runs **if `deploy-production` fails** — and that job will be skipped if earlier checks fail.

To accurately test rollback, we need to **allow the code to pass initial stages** and **fail specifically at the production deployment step**.

---

#### **Option: Simulate the Failure in the Production Deployment Step**

Open `.github/workflows/ci-cd.yml` and temporarily modify the `deploy-production` job to include a forced failure.

Replace this block:

```yaml
- name: Deploy to production cluster (simulated)
  run: |
    echo "Deploying to production environment"
    echo "Image: ${{ needs.build.outputs.image-tag }}"
    sleep 15
    echo "Production deployment completed"
```

With this:

```yaml
- name: Deploy to production cluster (simulated failure)
  run: |
    echo "Deploying to production environment"
    echo "Image: ${{ needs.build.outputs.image-tag }}"
    exit 1  # Force failure to trigger rollback
```

This simulates a real deployment error, such as a failed Helm release, infrastructure issue, or crash during rollout.

---

#### **Step-by-Step: Test the Rollback Logic**

1. Edit the file as described and commit the change:

```bash
git add .github/workflows/ci-cd.yml
git commit -m "Simulate production failure to trigger rollback"
git push origin main
```

2. Open the **Actions** tab on your GitHub repository.

You should observe the following:

* The `test`, `security-scan`, `build`, and `deploy-staging` jobs run successfully.
* The `deploy-production` job fails due to the forced `exit 1` command.
* The `automated-rollback` job is triggered automatically as a result of the failure.

This allows you to verify the recovery logic in a controlled and intentional way, without needing to break earlier pipeline functionality.

---

### **Step 4: Revert and Fix the Code**

Although the rollback job ran successfully, it did **not** actually fix the broken code. You need to manually restore the application to a working state so future pipeline runs can succeed.

> **Note:** The rollback job only simulates recovery — it does not revert files in your Git repository. Real pipelines would require integration with deployment tools or GitOps workflows to perform automatic rollbacks.

#### Revert the entire commit

To undo everything added in the previous commit (including a broken pipeline):

```bash
git revert HEAD
git push origin main
```

This creates a new commit that reverses the last one.

---

### What You’ve Achieved

Your pipeline now includes:

* Resilient multi-environment delivery
* Observability and SLO-based validation
* Failure handling with automatic rollback

This is the **final piece** in your CI/CD puzzle — a safety net that helps teams release confidently, detect failures quickly, and recover fast.

---

🎉 **Done!** You've implemented a robust, automated, SRE-grade CI/CD pipeline.

---

## Real-World Extensions and SRE Metrics

Now that you’ve built a fully functional pipeline, here are a few ways Site Reliability Engineers extend and evolve this system in production environments:

### **Key Metrics to Track**

Tracking these indicators helps ensure your CI/CD process aligns with organizational goals:

* **Deployment Frequency** — How often do you deploy new changes to production?
* **Lead Time for Changes** — How long does it take from code commit to deployment?
* **Mean Time to Recovery (MTTR)** — How fast can you recover from failure?
* **Change Failure Rate** — What percentage of deployments cause incidents?

### **Advanced SRE Practices**

* **SLO-Based Deployment Decisions**
  Integrate monitoring tools like Prometheus to halt deployment if your SLOs are being violated in real-time.

* **Canary Deployments**
  Gradually roll out new versions to a small subset of users, validate performance, and then scale up.

* **Cost Optimization**
  Use self-hosted runners or optimize job timing to reduce compute costs across CI/CD workflows.

* **Drift Detection with GitOps**
  Implement tools like ArgoCD or FluxCD to automatically detect and fix configuration drift in production environments.

These enhancements make your pipeline smarter, more cost-effective, and more reliable.

---

## Reflection Questions

Use these questions for self-assessment or discussion in a team retrospective:

* **Risk Assessment:** How does this pipeline reduce production risk compared to manual deployments?
* **Incident Response:** How would you modify this pipeline after a production incident caused by a deployment?
* **Scaling Considerations:** What changes would be needed to support 100+ developers using this pipeline?
* **Security Posture:** Are there additional security gates you would add for production pipelines?
* **Observability Maturity:** How would you integrate real telemetry and alerts for deeper visibility?

---

## Next Steps

In [Exercise 17](../exercise17), you’ll extend this foundation by implementing **GitOps with ArgoCD**, where you'll:

* Implement declarative deployment management
* Set up automated drift detection and correction
* Build multi-cluster deployment strategies
* Create disaster recovery automation

This exercise has given you the foundation of **reliability through automation**. The next exercise will focus on **consistency through declarative infrastructure** — a core principle of modern SRE and DevOps practices.

Keep building. Keep breaking. Keep improving.

---
