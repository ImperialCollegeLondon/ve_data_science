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

2. Install `poetry`: `pip install poetry`

3. Run `poetry install`

4. Set the interpreter path
    * Run `poetry env list --full-path`, copy the result and add `/bin/python` to the
      end. For example:
      `/Users/dorme/Library/Caches/pypoetry/virtualenvs/ve-data-science-ND1juKN--py3.12/bin/python`
    * In the menus, select View > Command Palette and then enter `interpreter` in the
      box to find the `Python: Select Interpreter` command. Click on `Enter interpreter
      path` and paste in the path from above.

5. Run `poetry run pre-commit install`

6. Whenever you are working in the repo, use `poetry shell` to start up the environment
   first.
