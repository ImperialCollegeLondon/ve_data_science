# Getting started with the `ve_data_science` repository

!!! IMPORTANT

    This is a draft document

This is a how to guide to getting started with the `ve_data_science` repository

## Getting the repository

The first step is to clone the repository. If you do not already have `git` then you
will need to install it:

<https://git-scm.com/downloads>

Next, in your terminal, change directory to the location where you want the repository
to live and then run the following command.

```sh
git clone https://github.com/ImperialCollegeLondon/ve_data_science.git
```

That will create a new directory called `ve_data_science` that contains all of the current
files, all of the changes ever made to those files. It also contains the details of all of
the branches containing active versions of the code that differ from the core `main` branch.
Those changes are hidden away in the `.git` folder.

See the [GitHub Overview](github_overview) for details on working with Git and GitHub.

## Setting up the repository for use

However, we use a number of quality assurance tools (QA) to help manage the code files
and documents within this repository. You also need to do the following to get this set
up working and make the most of working with VSCode, if that is the editor tool you want
to use.

1. Install python if needed. You probably already have this since it is needed to run
   `virtual_ecosystem`!

2. Install `poetry`. This is a python package manager, which we are using here to
   maintain a set of Python tools that are likely to be used within the project. Follow
   the command line instructions on the [poetry installation page](https://python-poetry.org/docs/#installing-with-the-official-installer).

3. In the command line, run `poetry install`. This will install the recommended python
   packages, which includes the `radian` front-end for R, the `xarray` package for
   handling NetCDF data and the `pre-commit` framework for running code quality checks
   on changes being committed to the repository. The `poetry` tool creates a new Python
   environment that is specific to this project.

4. If you are using Visual Studio Code, then it needs to know which python setup to use
   for running Python code and for running Python code quality tools. This is done by
   setting the Python interpreter path to match the one that `poetry` just created:

    * Run `poetry env list --full-path`, copy the result and then either add
      `/bin/python` (on MacOS or Linux) or `\Scripts\python.exe` (on Windows) to the
      end. For example:
      `/Users/dorme/Library/Caches/pypoetry/virtualenvs/ve-data-science-ND1juKN--py3.12/bin/python`
    * In the VSCode menus, select View > Command Palette and then enter `interpreter` in
      the box to find the `Python: Select Interpreter` command. Click on `Enter
      interpreter path` and paste in the path from above.

5. You now need to setup the `pre-commit` tool, which is used to run a standard set of
    checks on files when `git commit` is run. At the command line, enter:

    `poetry run pre-commit install`

    This command can take quite a long time to run - among other things, it is installing
    a separate version of R just to be used for file checking!

6. If you do not have R 4.4.2 installed, you will now need to install it. We are using
   a system called `renv` to ensure that the project team uses the same versions of the R
   and all the required packages, so if you have an older version of R then you will need
   to upgrade it.

7. You now need to configure VSCode to work with R. This involves changing some of the
   settings so that it
