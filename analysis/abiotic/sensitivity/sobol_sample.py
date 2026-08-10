"""
---
title: Sobol sampling and job configuration generation for sensitivity analysis

description: |
  This script generates Sobol samples for selected Virtual Ecosystem model
  parameters/constants and creates a `job_config_sobol.toml` file for batch model runs.

  The sensitivity analysis is configured through `sensitivity_parameters.toml`,
  which defines the parameter groups, parameter names, and lower and upper
  sampling bounds. The selected parameter groups are used to construct the
  Sobol sampling problem.

  The script reads parameter and group definitions from
  `sensitivity_parameters.toml`, constructs a Sobol problem, generates samples
  using the configured base sample size and interaction-order setting, and then
  exports run definitions to `job_config_sobol.toml`. Each job in the generated
  configuration represents one simulation with a unique combination of
  sampled parameter values.

  The workflow is generic and can be used for constants from any Virtual
  Ecosystem module, provided the relevant parameter/constant ranges are defined
  in `sensitivity_parameters.toml`. In this script, the `hydrology` group is
  used as an example setup.

  This script performs the sampling and job-configuration generation stage
  of the sensitivity-analysis workflow. It does not run the Virtual
  Ecosystem simulations or calculate the final Sobol sensitivity indices.
  The generated jobs must subsequently be executed using the appropriate
  Virtual Ecosystem or HPC workflow, after which the model outputs can be
  analysed to calculate and interpret the sensitivity indices.

virtual_ecosystem_module: all

author:
  - Lelavathy

status: final

input_files:
  - name: sensitivity_parameters.toml
    path: data/sensitivity/hydrology/config/sensitivity_parameters.toml
    description: |
      Defines the parameter groups, parameter names and sampling bounds used
      for sensitivity analysis.

  - name: hydrology_base_config.toml
    path: data/sensitivity/hydrology/config/hydrology_base_config.toml
    description: |
      Base configuration containing the default hydrology constants, parameter
      values, and model settings for the Virtual Ecosystem hydrology module.
      Each sensitivity analysis simulation inherits this configuration, with
      only the selected parameters replaced by the sampled values specified in
      the generated `job_config_sobol.toml`.

output_files:
  - name: job_config_sobol.toml
    path: data/sensitivity/hydrology/config/job_config_sobol.toml
    description: |
      HPC batch job configuration generated from the Sobol
      sampling workflow. Each `[[jobs]]` entry represents a single Virtual
      Ecosystem simulation with a unique set of sampled parameter values. This
      file is used as input to the HPC batch submission workflow to execute the
      complete sensitivity analysis experiment.


requirements:
  python: ">=3.12"
  package_manager: uv

  installation: |
    All external Python dependencies are defined in `pyproject.toml`.
    From the repository root, synchronise the project environment using:

      `uv sync`

  external_packages:
    - pyprojroot
    - SALib

  standard_library:
    - sys
    - pathlib

  local_modules:
    - tools.python.abiotic.job_config_tools
    - tools.python.abiotic.sensitivity_tools

  notes: |
    `pyprojroot` is used to locate the repository root by searching for
    `pyproject.toml`. The repository root is added to `sys.path` so that
    the local `tools.python.abiotic` modules can be imported when the
    script is executed directly.

    `sys` and `pathlib` are part of the Python standard library and do not
    require separate installation.

    The local `tools.python.abiotic.*` modules are part of the repository
    and do not require separate installation.

usage_notes: |
  1. Define the parameters, parameter groups and sampling bounds in
     `sensitivity_parameters.toml`.

  2. Select one or more parameter groups using `groups`.

  3. Set `base_sample_size` to define the Sobol base sample size (N).

  4. Set `calculate_second_order = True` when second-order Sobol indices
     are required. Set it to `False` when only first-order and total-order
     sensitivity indices are required.

  5. Set `random_seed` to a fixed integer to make the Sobol sampling design
     reproducible. Using the same seed and sampling configuration will reproduce
     the same sampling design.

  6. Run the script from the repository root using the project's uv-managed
     environment:

       `uv run python analysis/abiotic/sensitivity/sobol_sample.py`

  7. The script generates `job_config_sobol.toml`, containing one Virtual
     Ecosystem job for each sampled parameter combination.


references: |
    Sobol, I. M. (2001). Global sensitivity indices for nonlinear mathematical models
    and their Monte Carlo estimates. Mathematics and computers in simulation, 55(1-3),
    271-280.

    Iwanaga, T., Usher, W., & Herman, J. (2022). Toward SALib 2.0: Advancing the
    accessibility and interpretability of global sensitivity analyses.
    Socio-Environmental Systems Modelling, 4, 18155-18155.

Further information on SALib usage and supported sampling methods is available
in the SALib documentation: https://salib.readthedocs.io/en/latest/
---
"""  # noqa: D400, D205, D212, D415

import sys

from pyprojroot import here

project_root = here("pyproject.toml").parent

if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

from tools.python.abiotic.job_config_tools import (  # noqa: E402
    generate_job_config,
)
from tools.python.abiotic.sensitivity_tools import (  # noqa: E402
    generate_sobol_samples,
    load_problem,
)

# =============================================================================
# USER SETTINGS
# =============================================================================
# Configure the sensitivity analysis by selecting the parameter groups to
# analyse and specifying the Sobol sampling options used to generate the
# parameter sets for each simulation run.

# Parameter groups defined in `sensitivity_parameters.toml` to include in the
# sensitivity analysis. Multiple groups (e.g. hydrology, soil, abiotic) can be
# specified.
groups = [
    "hydrology",
]
# Sobol sampling settings.
# NOTE:-
# Modify the sampling settings  based on the requirement of the sensitivity analysis.

# base_sample_size:
#     Number of base Sobol samples (N). The total number of Virtual Ecosystem
#     simulations depends on both the number of selected parameters and whether
#     second-order sensitivity indices are calculated.

base_sample_size = 100

# calculate_second_order:
#     If True, generate additional samples required to estimate second-order
#     Sobol sensitivity indices. Setting this to False reduces the total number
#     of model runs and computes only first-order and total-order indices.
calculate_second_order = True

# Random seed used to make the Sobol sampling design reproducible.
random_seed = 2026
# NOTE:-
# Use the same seed and sampling settings to producethe same sample set.

# =============================================================================
# DIRECTORY SETTINGS
# =============================================================================
# Configuration directory containing the sensitivity analysis input files,
# including parameter definitions, the base VE configuration, and the generated
# HPC job configuration.

config_directory = project_root / "data/sensitivity/hydrology/config"

parameter_file = config_directory / "sensitivity_parameters.toml"

base_config = config_directory / "hydrology_base_config.toml"

output_file = config_directory / "job_config_sobol.toml"

# Scenario data directory containing the Virtual Ecosystem input datasets
# (e.g. climate, soil, vegetation and other site-specific data) required to
# execute each simulation. This directory is referenced by the generated
# `job_config_sobol.toml` and is used by the HPC workflow when running VE.
site_directory = project_root / "data/sensitivity/hydrology/data"

# =============================================================================
# LOAD PARAMETER DEFINTIONS
# =============================================================================
# Read parameter definitions and build the Sobol problem structure.

problem = load_problem(
    parameter_file=parameter_file,
    groups=groups,
)

# =============================================================================
# GENERATE SOBOL SAMPLES
# =============================================================================
# Generate Sobol samples using the configured sample size and order.

samples = generate_sobol_samples(
    problem=problem,
    n_samples=base_sample_size,
    calc_second_order=calculate_second_order,
    seed=random_seed,
)

# =============================================================================
# GENERATE JOB CONFIGURATION
# =============================================================================
# Write sampled parameter sets into a  job configuration TOML file.

metadata = generate_job_config(
    samples=samples,
    parameter_names=problem["names"],
    common_config_paths=[base_config],
    site_directory=site_directory,
    output_file=output_file,
)

# =============================================================================
# SUMMARY
# =============================================================================
# Print a summary of the generated Sobol samples and job configuration details.

print("=" * 60)
print("Sobol sampling completed successfully")
print("=" * 60)
print(f"Parameter groups : {groups}")
print(f"VE runs          : {metadata['num_jobs']}")
print(f"Output file      : {metadata['output_file']}")
