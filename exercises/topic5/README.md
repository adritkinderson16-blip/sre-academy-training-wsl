# **GitHub Projects**

## **Table of Contents**

- [Why Use GitHub Projects in SRE?](#why-use-github-projects-in-sre)
- [Key Features of GitHub Projects](#key-features-of-github-projects)
- [Exploring GitHub Projects in Your Own Repositories](#exploring-github-projects-in-your-own-repositories)
  - [Step-by-Step Guide](#step-by-step-guide)
- [Summary](#summary)

---

## **Overview**

GitHub Projects is a flexible and powerful tool that enables teams to manage tasks, track progress, and coordinate work directly from their GitHub repositories. In the context of Site Reliability Engineering (SRE), GitHub Projects helps streamline operational workflows, organize incident response efforts, and improve overall project visibility.

This topic covers:
- The core concepts behind GitHub Projects.
- How to structure project boards to reflect SRE priorities.
- Integrating GitHub Projects with issues and pull requests.
- An overview of automation possibilities with GitHub Actions.

---

## **Why Use GitHub Projects in SRE?**

SRE teams use GitHub Projects to address operational and collaborative needs, including:

- **Task Organization**  
  Create and manage cards representing incidents, alerts, infrastructure changes, or improvement tasks.

- **Workflow Visibility**  
  Track the status of issues and pull requests through defined columns (e.g., To Do, In Progress, Review, Done).

- **Collaboration**  
  Integrate work items from issues, pull requests, and discussions to promote shared ownership and alignment across teams.

- **Automation Opportunities**  
  Leverage GitHub Actions to automatically move project cards, assign labels, or update issue statuses based on repository events.

- **Practical Use Case**  
  During an incident response, SREs can log issues in a GitHub Project and assign them to team members—tracking progress on tasks such as mitigation, root cause analysis, documentation, and follow-ups.

---

## **Key Features of GitHub Projects**

- **Project Boards**  
  Visualize your workflow with Kanban-style boards that allow you to manage tasks efficiently.

- **Custom Columns**  
  Tailor columns (e.g., “Backlog”, “In Progress”, “Done”) to match your team’s lifecycle and workflow priorities.

- **Issue and Pull Request Integration**  
  Link GitHub Issues and Pull Requests directly to project cards for enhanced traceability.

- **Automation with GitHub Actions**  
  Create workflows that react to GitHub events by automatically updating your project board.

- **Reporting and Insights**  
  Access built-in dashboards to track metrics such as cycle time, bottlenecks, and overall throughput—crucial for data-driven teams.

---

## **Exploring GitHub Projects in Your Own Repositories**

Although this topic is not a structured lab, you can gain hands-on experience by exploring GitHub Projects within your own repositories or team organization. Here’s a simple step-by-step guide:

### Step-by-Step Guide

1. **Access the Projects Tab**  
   - Navigate to any repository on GitHub.
   - Click on the **Projects** tab.

2. **Create a New Project**  
   - Choose between Classic Projects or the new Projects experience (based on GitHub Issues).
   - Define columns such as **To Do**, **In Progress**, and **Done** to reflect your workflow.

3. **Add Issues and Pull Requests**  
   - Open or create an issue or pull request in your repository.
   - Use the repository sidebar to associate the item with your GitHub Project.

4. **Try Automation (Optional)**  
   - Set up GitHub Actions to automatically update project boards.  
   - For example, create a workflow that moves a card to the **Done** column when a pull request is merged.

   ```yaml name=.github/workflows/auto-update-project.yml
   name: "Auto Update Project Board"
   
   on:
     pull_request:
       types: [closed]
   
   jobs:
     update_project:
       runs-on: ubuntu-latest
       steps:
         - name: Move Project Card (Simulation)
           run: |
             echo "Simulated action: A pull request was merged, moving the associated project card to Done."
   ```

---

## **Summary**

GitHub Projects offers a scalable and transparent way to manage work within SRE teams. Whether it's organizing incident resolution, tracking observability improvements, or automating workflows, GitHub Projects unifies tracking and collaboration directly within your GitHub repository.

**Key Takeaways:**
- **Structure Your Own Project Board:** Learn how to set up and customize columns to reflect your SRE workflow.
- **Organize Team Workflows:** Integrate issues, pull requests, and other work items to promote collaboration.
- **Explore Automation:** Use GitHub Actions to reduce manual overhead and streamline board updates.

> 🎯 **Pro Tip:** If your team uses GitHub Enterprise or Codespaces, consider preconfiguring GitHub Projects in your training environments to simulate real-world collaboration at scale.

Happy exploring and organizing your work with GitHub Projects!
