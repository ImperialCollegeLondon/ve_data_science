# Uploading an R Script to a GitHub Repository

<!-- markdownlint-disable MD046 -->
<!-- The admonition syntax within mkdocs confuses markdownlint, because it thinks the
indented content of the admonition is code. It then complains about the mixture of
fenced code blocks (e.g. ```sh) and indented code blocks.-->

(This text was written by @arne-exe and is copied directly from
<https://github.com/ImperialCollegeLondon/ve_data_science/issues/22#issuecomment-2740835471>)

These notes should help guide you through uploading an R script to a GitHub repository
using Git, Visual Studio Code (VSC), and best practices for version control, branch
management, and code formatting

## ✅ Prerequisites

Before you start, make sure you have the following in place:

* Git is installed and configured
* You have access to the ve_data_science GitHub repository
* R (at least version 4.4.2) is installed and added to your system PATH
* Visual Studio Code (VSC) is installed, with Git integration enabled
* Pre-commit hooks are installed

## 1️⃣ Create a GitHub Issue

* In your GitHub repository, create a new **Issue** describing your task, e.g.,
  **"Uploading script X"**. This helps track your work and adds context for
  collaborators.

## 2️⃣ Prepare Your Local Repository

* Clone the repository (if not done already).
* Navigate into the cloned folder and open it in **Visual Studio Code**
* Check the status of the repository and update it from the remote repository

    ```sh

    git status
    git fetch
    git pull
    ```

    These commands ensure your local `main` branch is up to date.

##  3️⃣ Create a New Branch

Create a new branch for your changes:

```sh
git checkout -b meaningful-branch-name
```

Use a descriptive name like `uploading_t_model_parameters_script`, not a generic name
like `my_feature_branch`.

## 4️⃣ Make Your Changes

* Create any new folders under `data` or `analysis`.
* Use the **template scripts** provided in the repository.</li>
* Move your R script into the appropriate folder.</li>
* Ensure local datasets are placed in correct subfolders within `data/`.

## 5️⃣ Stage and Commit Changes

Check what’s changed:

```sh
git status
```

Stage your files:

```sh
git add path/to/script.R
```

Commit your changes:

```sh
git commit -m "Uploading script X"
```

## 6️⃣ Handle Pre-commit Checks

If the commit fails due to pre-commit hook issues then fix the issues, re-add the
updated files and re-commit the changes. Some common problems and fixes:

Error | Solution
-- | --
Rscript not found | Add R to system environment PATH
Lintr style issues | Follow suggested fixes or use # nolint where appropriate
Variable/function names too long | Rename using snake_case, max 30 characters
Lines > 88 characters | Reformat or split lines carefully

!!! TIP

    Use **VS Code's syntax highlighting** and **Ctrl + Click** to quickly navigate and
    fix code issues.

##  7️⃣ Push Your Branch

Once your commit passes:

```sh
git push -u origin your-branch-name
```

## 8️⃣ Create a Pull Request (PR)

* *Go to your GitHub repo
* *Click **"Compare & pull request"**
* *Add a title and description
* *Assign reviewers and submit

!!! TIP

    Any new commits pushed to this branch automatically update the same PR — no need to
    create a new one.

## 9️⃣ Address Review Feedback

If your reviewer suggests changes:

Edit your script locally (while still being on the same branch)
Commit and push again:

### On Relative Paths

Avoid hardcoded system paths like `C:/Users/...`. Use relative paths:

```R
data <- readxl::read_excel(
    "../../../data/primary/plant/tree_census/tree_census_11_20.xlsx"
)
```

* `../` moves one directory up.
* Always ensure you're working in the correct working directory (e.g., by opening the
  script directly or by setting the working directory manually).

## 🔐 Final Merge & Cleanup

Once the PR is approved

* Merge it via GitHub
* Update your local `main`:

```sh
git checkout main
git pull origin main
```

* Clean up your feature branch (optional):

```sh
git branch -d your-branch-name
```

## 🤝 Collaboration Best Practices

* Always pull latest changes before starting new work
* Keep commits clear and descriptive
* Never push directly to `main`
* Communicate clearly in PRs and commit messages
* Ask for help if `lintr` feedback is confusing — even paste the code into ChatGPT
  for help!`
