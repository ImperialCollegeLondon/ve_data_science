# The Virtual Ecosystem Data Science Repository

This site documents how the Virtual Ecosystem (VE) model is parameterised, run and
tested for specific field sites. It covers the data we use, the choices we make when
turning that data into model inputs, and what the model results mean for those sites.

It is a companion to the main
[Virtual Ecosystem documentation](https://virtual-ecosystem.readthedocs.io/en/latest/).
That site explains the model itself: the theory, the implementation and how to use the
software. This site does not repeat that material and links to it wherever the model
needs explaining.

## Where to start

| If you want to | Go to |
| --- | --- |
| Understand our simulation sites | [Study sites](background/study_sites.md) and [Scenarios](background/scenarios.md) |
| See how field data becomes model inputs and validation | [From field data to validation](background/data_pipeline.md) |
| Find your way around the repository | [Repository tour](background/repository_tour.md) |
| Learn how the model is designed | [Virtual Ecosystem documentation](https://virtual-ecosystem.readthedocs.io/en/latest/) |
| Set up your computer to run or contribute code | [Getting started](getting_started.md) |

## What is on this site

### Background

Context that applies to every module: the [study sites](background/study_sites.md), the
[scenarios](background/scenarios.md) we simulate, the path
[from field data to validation](background/data_pipeline.md) and a
[tour of the repository](background/repository_tour.md).

### Getting started

How to set up the tools used in this repository:

* [Getting started](getting_started.md) gives the overall setup steps.
* [Python with uv](uv_setup.md) installs Python, the project packages and the VE.
* [R with renv](renv.md) explains how R package versions are recorded.
* [Data with Globus](using_globus.md) explains how to get the data files.
* [Git and GitHub](github_overview.md) and
  [Uploading an R script](uploading_r_scripts.md) cover sharing your work.
* [Configuration files](what_are_those_odd_files.md) explains the small files in the
  repository root.

### Modules

Work is organised around four areas of the model: soil and litter, abiotic and
hydrology, animals, and plants. A landing page for each area is planned. For now, this
section holds:

* the [animal model validation plan](animal_model_validation_plan.md)
* the [plant validation tracker](plant_validation_tracker.md)
* the [abiotic sensitivity analysis methods](sensitivity_analysis.md)

### Shared workflows

Methods that are used across multiple modules:

* [Building the validation database](validation_database.md)
* [Derived variables](derived_variables.md)

## Contributing

If you have found a problem or want to suggest a change, please read the
[contributing guide](https://github.com/ImperialCollegeLondon/ve_data_science/blob/main/CONTRIBUTING.md)
first.
