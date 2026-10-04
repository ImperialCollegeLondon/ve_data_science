# Contributing to the Virtual Ecosystem Data Science

This repository contains the data science workflows used to parameterise
and run the Virtual Ecosystem model, including analysis code, utilities, tests,
and documentation.

The structure of the data analysis workflows - and indeed the Virtual Ecosystem
model itself - are currently changing rapidly and most of the live issues assume
familiarity with day to day changes across two code bases. This makes it 
challenging to identify good "first issues" as the changes required for one issue
often require discussion within our teams about other changes in the code base.

However, we do really appreciate interest in the development of this repository. If 
you have identified an issue with the code or have suggestions for new features 
or development then, at the moment, we request that you contact the core team
to discuss issues and features rather than directly submitting pull requests to
the code.

To make contributions easy to review and maintain, please follow the guidance
below.

## Development setup

This repository is a mixed-language research codebase. Most local development
uses Python with `uv` and R with `renv`.

* Install the Python toolchain and project dependencies from the repository
  root: `uv sync`
* Install the git hooks used for local quality checks:
  `uv run pre-commit install`
* Ensure that `Rscript` is available on your `PATH` for the R test workflow.
* If needed, install the commonly used R packages listed in the project setup
  notes before running local R tests.

The project also expects local code quality checks to run before submission:

* `uv run pre-commit run --all-files`
* R test suite:
  `Rscript -e "testthat::test_dir(here::here('tools/R/tests/testthat'), reporter='progress', stop_on_failure=TRUE)"`

## Contributing code

We expect all contributors to abide by our
[Code of Conduct](CODE_OF_CONDUCT.md). The repository is organised around the
following areas:

* `analysis/` for domain analysis and model parameterisation scripts
* `tools/` for shared utility and helper code
* `tests/` and `tools/R/tests/testthat/` for automated checks
* `docs/` for documentation and project notes
* `data/` for project inputs and derived datasets

The typical contribution flow is:

* Identify or create an issue describing the change you want to make.
* If you are fixing an existing issue, please check whether it is already being
  worked on before starting.
* Create a branch in your local clone and make the change there.
* Keep the change scoped to the relevant analysis or utility area.
* Run the smallest relevant checks before opening a pull request.
* If the change resolves a GitHub issue, include `Closes #nnn` in the pull
  request description or final commit message body.
* Open a pull request against the repository and be ready to address review
  feedback.

We aim for small, reviewable contributions that are easy to understand and test.
