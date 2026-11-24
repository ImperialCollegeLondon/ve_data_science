# The Virtual Ecosystem data science repository

This repository holds the data science work used to parameterise, run and test the
[Virtual Ecosystem](https://github.com/ImperialCollegeLondon/virtual_ecosystem) model
at our field sites in Sabah, Malaysian Borneo. It contains the analysis code that turns
field data into model inputs, the scenario configurations, and the tools used to
validate model outputs against observations.

**Documentation: <https://imperialcollegelondon.github.io/ve_data_science/>**

The documentation site covers the study sites, the scenarios, how data moves through
the repository, and each module's work. It complements the
[Virtual Ecosystem documentation](https://virtual-ecosystem.readthedocs.io/en/latest/),
which explains the model itself.

## Where to start

| If you want to | Go to |
| --- | --- |
| Understand the sites and simulations | [Study sites](https://imperialcollegelondon.github.io/ve_data_science/background/study_sites/) and [Scenarios](https://imperialcollegelondon.github.io/ve_data_science/background/scenarios/) |
| See how field data becomes model inputs and validation | [Data pipeline](https://imperialcollegelondon.github.io/ve_data_science/background/data_pipeline/) |
| Find your way around the folders | [Repository tour](https://imperialcollegelondon.github.io/ve_data_science/background/repository_tour/) |
| See each module's work and its scripts | [Soil and litter](https://imperialcollegelondon.github.io/ve_data_science/modules/soil/), [Abiotic and hydrology](https://imperialcollegelondon.github.io/ve_data_science/modules/abiotic/), [Animals](https://imperialcollegelondon.github.io/ve_data_science/modules/animal/) and [Plants](https://imperialcollegelondon.github.io/ve_data_science/modules/plant/) |
| Set up your computer to run or contribute code | [Getting started](https://imperialcollegelondon.github.io/ve_data_science/getting_started/) |
| Get the data files | [Data with Globus](https://imperialcollegelondon.github.io/ve_data_science/using_globus/) |
| Run batches of simulations on the cluster | [Running VE on the HPC](https://imperialcollegelondon.github.io/ve_data_science/hpc_setup/) |
| Learn how the model works | [Virtual Ecosystem documentation](https://virtual-ecosystem.readthedocs.io/en/latest/) |

## What is in the repository

| Folder | What it holds |
| --- | --- |
| `analysis/` | Scripts and notebooks for each module (`abiotic`, `animal`, `litter`, `plant`, `soil`), plus `site/` for grids and configuration and `troubleshoot/` for investigations |
| `data/` | Data files, organised as `primary/`, `derived/`, `scenarios/` and `sensitivity/`. Most files are shared through Globus, not GitHub |
| `tools/` | Shared R and Python functions used by more than one analysis, with their tests |
| `notebook/` | Notebooks that report results |
| `hpc_jobs/` | Scripts for running batches of simulations on a computing cluster |
| `templates/` | Starting points for new scripts, notebooks and documentation pages |
| `docs/` | The source for the documentation site |

## Getting started

The repository uses a set of tools to keep code quality and formatting consistent. In
brief:

1. Clone the repository:

    ```sh
    git clone https://github.com/ImperialCollegeLondon/ve_data_science.git
    ```

2. Install [uv](https://docs.astral.sh/uv/), then set up the Python environment from
   the repository root. This also installs the Virtual Ecosystem:

    ```sh
    uv sync
    ```

3. Install the checks that run when you commit:

    ```sh
    uv run pre-commit install
    ```

4. Install R if you will work with R scripts. The R packages used by the automated
   checks are recorded with `renv`, but you do not need to use `renv` on your own
   computer.
5. Request access to the data on Globus and download the files you need into `data/`.

The [Getting started](https://imperialcollegelondon.github.io/ve_data_science/getting_started/)
page explains each step in more detail.

The tools involved are:

* **Python**, used to run the Virtual Ecosystem, for some analyses and for the quality
  checks.
* **uv**, a Python package and environment manager. It installs the correct Python
  version and the shared set of Python packages used across the project.
* **R**, used extensively for analysis and data visualisation.
* **pre-commit**, which runs a set of checks whenever you `git commit`. If your
  changes fail a check, fix them and commit again. Some checks fix problems for you; in
  that case, add the changed files and commit again.

The repository root also contains many small configuration files with odd names. The
[configuration files](https://imperialcollegelondon.github.io/ve_data_science/what_are_those_odd_files/)
page explains what each one is for.

## Contributing

We work through issues, branches and pull requests. The
[Git and GitHub](https://imperialcollegelondon.github.io/ve_data_science/github_overview/)
page walks through the process.

* Start new scripts and notebooks from the files in `templates/`, which include the
  metadata header every analysis file should have.
* Record changes to scenario input data in the scenario's `change_log.txt`.
* Document your module's work on its landing page on the documentation site, as
  described in [Documenting your work](https://imperialcollegelondon.github.io/ve_data_science/documenting_your_work/).

If you are not part of the project team, please read [CONTRIBUTING.md](CONTRIBUTING.md)
before opening an issue or pull request. Everyone taking part is expected to follow
the [Code of Conduct](CODE_OF_CONDUCT.md).

## Licence

The code in this repository is released under the [BSD 3-Clause License](LICENSE).
