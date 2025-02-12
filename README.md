# The Virtual Ecosystem data science repository

This repository is the data science repository for the Virtual Ecosystem project. It is
used to store all the research and analysis being used to parameterise and run the
Virtual Ecosystem model.

## Getting started with the repository

The first step is to clone the repository

```sh
git clone https://github.com/ImperialCollegeLondon/ve_data_science.git
```

That gives you a complete copy of all of the current files across all branches and all
of the changes ever made to those files.

However, we use a number of quality assurance tools (QA) to help manage the code files
and documents within this repository. You also need to do the following to get this set
up working:

1. Install python

2. Install `poetry`: follow the command line instructions on this page
   [](https://python-poetry.org/docs/#installing-with-the-official-installer)

3. Run `poetry install`. This will install the recommended python packages, which
   includes the `radian` front-end for R and the `xarray` package for handling NetCDF
   data. It creates a new Python environment that is specific to this project.

4. Visual Studio Code now needs to know which python setup to use for running Python
   code and for running Python code quality tools. This is done by setting the Python
   interpreter path to match the one that `poetry` just created:
    * Run `poetry env list --full-path`, copy the result and add `/bin/python` to the
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

6. Whenever you are working in the repo, use `poetry shell` to start up the environment
   first.

7. TODO - Setting up the R side of the repo.
