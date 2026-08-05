# Getting started with the `ve_data_science` repository

<!-- markdownlint-disable MD046 -->
<!-- The admonition syntax within mkdocs confuses markdownlint, because it thinks the
indented content of the admonition is code. It then complains about the mixture of
fenced code blocks (e.g. ```sh) and indented code blocks.-->

!!! IMPORTANT

    This is a draft document

This is a how to guide to getting started with the `ve_data_science` repository

## Getting the repository

The first step is to clone the repository. If you do not already have `git` then you
will need to install it:

<https://git-scm.com/downloads>

Next, in your terminal, change directory to the location where you want the repository
to live and then run the following command.

``` sh
git clone https://github.com/ImperialCollegeLondon/ve_data_science.git
```

That will create a new directory called `ve_data_science` that contains all of the
current files, all of the changes ever made to those files. It also contains the details
of all of the branches containing active versions of the code that differ from the core
`main` branch. Those changes are hidden away in the `.git` folder.

See the [GitHub Overview](github_overview.md) for details on working with Git and GitHub.

## Setting up the repository for use

However, we use a number of quality assurance tools (QA) to help manage the code files
and documents within this repository. You also need to do the following to get this set
up working and make the most of working with VSCode, if that is the editor tool you want
to use.

1. Install `uv` and set up the Python environment by following the
   [Python setup guide](uv_setup.md). This will install the correct Python version and
   all project dependencies automatically. You do not need to install Python separately.

2. You now need to setup the `pre-commit` tool, which is used to run a standard set of
    checks on files when `git commit` is run. At the command line, enter:

    `uv run pre-commit install`

    This command can take quite a long time to run - among other things, it is installing
    a separate version of R just to be used for file checking!

3. If you do not have R 4.4 installed, you will now need to install it.

4. You now need to configure VSCode to work with R. This involves changing some of the
   settings so that it [TBD]
