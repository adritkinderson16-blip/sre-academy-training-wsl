# Clone the Repository (Requires Git Setup and Token/SSH)

## Table of Contents

- [Step 1 - Prerequisites](#step-1---prerequisites)
- [Step 2 - Create SSH Keys](#step-2---create-ssh-keys)
- [Step 3 - Configure the SSH Key in GitHub](#step-3---configure-the-ssh-key-in-github)
- [Step 4 - Clone the Repository](#step-4---clone-the-repository)
- [Step 5 - IDE Integration](#step-5---ide-integration)
- [Final Notes](#final-notes)

---

By following these steps, the student will get access to the repository by using SSH keys (IBM recommended).

macOS users will run the steps in their native Terminal application.

Windows users will run the steps in their Ubuntu (WSL) terminal.

## Step 1 - Prerequisites

1. Open a browser and open the [sre-academy-training](https://github.ibm.com/SRE-Academy/sre-academy-training) repository with your IBM account.

   If you don't have access to it, reach out to the PM or Academy Director to grant you access.

2. Open the terminal application.

   - a. **macOS** users: Open the Terminal application.

   - b. **Windows** users:

     1. Open the Ubuntu (WSL) application. It will open a new terminal.

        To verify that you are inside Ubuntu, run:

        ~~~bash
        grep PRETTY /etc/os-release
        ~~~

        It should print an output similar to:

        ~~~bash
        PRETTY_NAME="Ubuntu 24.04.4 LTS"
        ~~~

## Step 2 - Create SSH Keys

SSH keys are the IBM-recommended method to authenticate against `github.ibm.com`. These instructions are the same for both macOS and Windows users.

Once in your terminal:

1. Create a new pair of SSH keys.

   Important: Press Enter for all questions to leave the default location and no passphrase.

   ~~~bash
   ssh-keygen -t ed25519 -C "youremail@ibm.com"
   ~~~

2. Verify and print the public key.

   ~~~bash
   cat ~/.ssh/id_ed25519.pub
   ~~~

## Step 3 - Configure the SSH Key in GitHub

To allow authentication over SSH, GitHub must know the contents of the public key.

1. Copy the output of the public key obtained in Step 2.2.

2. Open the [sre-academy-training](https://github.ibm.com/SRE-Academy/sre-academy-training) repository with your IBM account.

3. In the **top-right corner**, click on your **username**, then **Settings**.

4. In the left pane, click on **SSH and GPG keys**.

5. In the **SSH keys** menu, click on **New SSH key**.

6. Give the key a descriptive name, e.g., `username-wsl-ubuntu`.

7. In **Key type**, select `Authentication Key`.

8. In the **Key** text box, paste the output of the public key obtained in Step 2.2.

9. Finally, click on **Add SSH key**.

## Step 4 - Clone the Repository

After the SSH keys are in place, you should be able to authenticate to GitHub using them.

Go back to the terminal and run:

1. Verify that authentication works.

   ~~~bash
   ssh -T git@github.ibm.com
   ~~~

   After typing `yes`, you should receive a successful authentication message.

2. Clone the repository.

   ~~~bash
   git clone git@github.ibm.com:SRE-Academy/sre-academy-training.git
   ~~~

3. Navigate into the repository directory and list the files.

   ~~~bash
   cd sre-academy-training
   ls
   ~~~

## Step 5 - IDE Integration

For visual guidance on files and directories, use Visual Studio Code, since it is integrated natively.

1. Install VS Code.

   The application can be downloaded from [W3 Apps](https://w3.ibm.com/#/apps/visual-studio-code) or the `Mac@IBM` and `PC@IBM` applications.

2. **macOS** users:

   - 1. Open VS Code, click on **File**, then **Open Folder**.

   - 2. Navigate to the folder where you cloned the repository, e.g., `/Users/yourusername/`.

3. **Windows** users:

   - 1. Ensure you are inside the Ubuntu terminal.

   - 2. Run VS Code from the terminal:

     ~~~bash
     code .
     ~~~

---

## Final Notes

- Refer to the [helper video](https://ibm.box.com/s/inha1c43ukcrk237w1ygb0mtpg55r0jl) that runs through these instructions.

---