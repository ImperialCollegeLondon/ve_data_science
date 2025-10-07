# The Virtual Ecosystem data science repository

This repository is the data science repository for the Virtual Ecosystem project. It is
used to store all the research and analysis being used to parameterise and run the
Virtual Ecosystem model using `git` and GitHub to share all the code.

For details on using GitHub and `git`, please see the Wiki page here: [GitHub
overview](https://imperialcollegelondon.github.io/ve_data_science/github_overview/)

## Getting started with the repository

The repository uses a reasonably complex set of tools to help ensure code quality
assurance (QA) and common code formatting. You will need to follow some steps to get
these tools working: see the wiki page on [Getting
Started](https://imperialcollegelondon.github.io/ve_data_science/getting_started/)

As a brief overview, this involves setting up the following tools:

* **Python**. Obviously, we use Python for running the `virtual_ecosystem` but it may also
  be used within this repository for analyses and we also require it to run some QA
  tools.
* **Poetry**. This is a Python package manager that we use to manage a shared set of
  Python packages used across the project.
* **R**. We will be using R extensively for analysis and data visualisation. At the
  moment, we are managing package use and versioning with a simple list of packages.
  This is currently very light touch and we may use something stricter in the future.
* **pre-commit**. This is a QA tool - we have a set of configured checks that run
  whenever you try and `git commit` some changes to the repo. If the changes fail any of
  the checks, then you will have to fix them and try again. Sometimes, the QA checks can
  automatically fix issues for you - in which case you just need to add the new changes
  to your commit and try again.

You will also notice a large number of small files with odd names in the repo. These are
mostly used to configure the system - you can see more details on the [what are these
odd files wiki
page](https://github.com/ImperialCollegeLondon/ve_data_science/wiki/What-are-all-those-odd-files%3F)
