# Repository Overview

This page explains what each top-level folder in the repository is for. The
[data flow page](data_flow.md) explains how the folders relate to each other.

<!-- markdownlint-disable MD013 -->
| Folder | What it holds |
| --- | --- |
| `analysis/` | Scripts that turn data into model inputs and that analyse model outputs. One folder per module, plus `site/` for grids and configuration and `troubleshoot/` for investigations of specific problems. |
| `data/` | Data files. Most are shared through Globus, not GitHub. |
| `tools/` | Shared R and Python functions used by more than one analysis, with their tests. |
| `notebook/` | Notebooks that report results, such as the hydrology sensitivity analysis. |
| `hpc_jobs/` | Scripts for running batches of simulations on a computing cluster. |
| `templates/` | Starting points for new scripts and notebooks, including the metadata header. |
| `docs/` | The source for this website. |
| `bib/` | Shared bibliography file. |
<!-- markdownlint-enable MD013 -->

## Analysis

Analysis folders are named after the part of the model they support.

| Folder | Covers |
| --- | --- |
| `analysis/abiotic/` | Climate and elevation inputs, and sensitivity analysis sampling |
| `analysis/animal/` | Animal traits and stoichiometry |
| `analysis/litter/` | Litter stocks, chemistry, turnover and initial state |
| `analysis/plant/` | Plant functional types, plant input data and validation of plant outputs |
| `analysis/soil/` | Soil pools, microbial properties, initial state, validation and sensitivity |
| `analysis/site/` | Grid definitions and model configuration for each scenario |
| `analysis/troubleshoot/` | Investigations of unexpected model behaviour |

## Data

The `data/` folder mirrors the stages on the [data pipeline page](data_pipeline.md).

| Folder | Contents |
| --- | --- |
| `data/primary/` | Data as obtained from its source |
| `data/derived/` | Results of analysis scripts |
| `data/scenarios/` | Input data and configuration for each [scenario](scenarios.md) |
| `data/sensitivity/` | Configuration and results for sensitivity analyses |

Scripts refer to data using paths relative to the repository root, so that the same
script works on every computer once the data has been downloaded. See
[Data with Globus](../using_globus.md).

## Tools

Functions that are useful to more than one analysis live in `tools/`, so that they
are written and tested once.

* `tools/R/R/` holds R functions, with tests in `tools/R/tests/testthat/`.
* `tools/python/src/ve_data_tools/` holds Python functions, with tests in
  `tools/python/tests/`.

Check here before writing a new helper function.

## Configuration files

The repository root also contains a number of small files that configure the tools we
use. They are described on the
[configuration files page](../what_are_those_odd_files.md).
