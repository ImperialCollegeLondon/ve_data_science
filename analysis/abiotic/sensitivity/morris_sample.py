"""
---
title: Morris sampling and job configuration generation for sensitivity analysis

description: |
  This script generates Morris samples for selected Virtual Ecosystem model
  parameters/constants and creates a `job_config_morris.toml` file for batch model runs.

  It loads parameter and group definitions from
  `sensitivity_parameters.toml`, builds the Morris problem specification, and
  generates trajectories using the configured number of levels, trajectories,
  and random seed options (if present). The resulting samples are translated
  into `job_config_morris.toml` entries so each sampled parameter set is executed as a
  separate simulation job.

  The workflow is generic and can be used for constants from any Virtual
  Ecosystem module, provided the relevant parameter/constant ranges are defined
  in `sensitivity_parameters.toml`. In this script, the `hydrology` group is
  used as an example setup.

  This script performs the Morris sampling and job-configuration generation
  stage of the sensitivity-analysis workflow. It does not run the Virtual
  Ecosystem simulations or calculate the final Morris elementary-effect
  statistics. After the simulations have completed, the model outputs can
  be analysed to calculate and interpret Morris sensitivity measures.

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
  - name: job_config_morris.toml
    path: data/sensitivity/hydrology/config/job_config_morris.toml
    description: |
      HPC batch job configuration generated from the Morris
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
    - ve_data_tools.job_config_tools
    - ve_data_tools.sensitivity_tools

  notes: |
    `pyprojroot` is used to locate the repository root by searching for
    `pyproject.toml`. The local Python source directory is added to
    `sys.path` so that the `ve_data_tools` modules can be imported when
    the script is executed directly.

    `sys` and `pathlib` are part of the Python standard library and do not
    require separate installation.

    The `ve_data_tools.*` modules are part of the repository and do not
    require separate installation.

usage_notes: |
  1. Define the parameters, parameter groups and sampling bounds in
     `sensitivity_parameters.toml`.

  2. Select one or more parameter groups using `groups`.

  3. Set `number_of_trajectories` to control the number of Morris
     trajectories generated for the sensitivity analysis.

  4. Set `number_of_levels` to define the number of grid levels used for
     parameter perturbations.

  5. Optionally configure `optimal_trajectories` to select a subset of
     trajectories using trajectory optimisation.

  6. Set `random_seed` to a fixed integer to make the Sobol sampling design
       reproducible. Using the same seed and sampling configuration will reproduce
       the same sampling design.

  7. Run the script from the repository root using the project's uv-managed
     environment:

       `uv run python analysis/abiotic/sensitivity/morris_sample.py`

  8. The script generates `job_config_morris.toml`, containing one Virtual
     Ecosystem job for each sampled parameter combination.


 references: |
     Morris, M. D. (1991). Factorial sampling plans for preliminary computational
     experiments.technometrics, 33(2), 161-174.

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
python_source = project_root / "tools" / "python" / "src"

if str(python_source) not in sys.path:
    sys.path.insert(0, str(python_source))

from ve_data_tools.job_config_tools import (  # noqa: E402
    generate_job_config,
)
from ve_data_tools.sensitivity_tools import (  # noqa: E402
    generate_morris_samples,
    load_problem,
)

# =============================================================================
# USER SETTINGS
# =============================================================================
# Configure the sensitivity analysis by selecting the parameter groups to
# analyse and specifying the Morris sampling options used to generate the
# parameter sets for Virtual Ecosystem simulations.

# Parameter groups defined in `sensitivity_parameters.toml` to include in the
# sensitivity analysis. Multiple groups (e.g. hydrology, soil, abiotic) can be
# specified.
groups = [
    "hydrology",
]

# Morris sampling settings.
# NOTE:-
# Modify the sampling settings  based on the requirement of the sensitivity analysis.

# number_of_trajectories:
#     Number of Morris trajectories (N) to generate. Increasing the number of
#     trajectories improves the robustness of the estimated elementary effects
#     but increases the number of Virtual Ecosystem simulations.
number_of_trajectories = 20

# number_of_levels:
#     Number of grid levels used to discretise the parameter space. A value of
#     four is commonly recommended for Morris sampling.
number_of_levels = 4

# optimal_trajectories:
#     Number of optimised trajectories selected from a larger candidate set to
#     maximise coverage of the parameter space. Set to None to disable
#     trajectory optimisation.
optimal_trajectories = None

# Random seed used to make the Morris sampling design reproducible.
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

output_file = config_directory / "job_config_morris.toml"

# Scenario data directory containing the Virtual Ecosystem input datasets
# (e.g. climate, soil, vegetation and other site-specific data) required to
# execute each simulation. This directory is referenced by the generated
# `job_config_morris.toml` and is used by the HPC workflow when running VE.
site_directory = project_root / "data/sensitivity/hydrology/data"

# =============================================================================
# LOAD PARAMETER DEFINITIONS
# =============================================================================
# Read parameter definitions and build the Morris problem structure.

problem = load_problem(
    parameter_file=parameter_file,
    groups=groups,
)

# =============================================================================
# GENERATE MORRIS SAMPLES
# =============================================================================
# Generate Morris samples using the configured number of trajectories,
# grid levels, trajectory optimisation, and random seed.r.

samples = generate_morris_samples(
    problem=problem,
    n_trajectories=number_of_trajectories,
    num_levels=number_of_levels,
    optimal_trajectories=optimal_trajectories,
    seed=random_seed,
)

# =============================================================================
# GENERATE JOB CONFIGURATION
# =============================================================================
# Write sampled parameter sets into a job configuration TOML file.

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
# Print a summary of the generated Morris samples and job configuration details.

print("=" * 60)
print("Morris sampling completed successfully")
print("=" * 60)
print(f"Parameter groups : {groups}")
print(f"Parameters       : {problem['num_vars']}")
print(f"VE runs          : {metadata['num_jobs']}")
print(f"Output file      : {metadata['output_file']}")
