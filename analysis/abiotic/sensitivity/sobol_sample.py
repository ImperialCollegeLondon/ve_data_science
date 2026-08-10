"""
---
title: Sobol sampling and job configuration generation for sensitivity analysis

description: |
  This script generates Sobol samples for selected Virtual Ecosystem model
  parameters/constants and creates a `job_config_sobol.toml` file for batch model runs.

  It can be used for any Virtual Ecosystem module (e.g. hydrology, soil,
  abiotic, plants, animals or litter) by defining the required parameter groups
  and parameter bounds in `sensitivity_parameters.toml`.

  The script reads parameter and group definitions from
  `sensitivity_parameters.toml`, constructs a Sobol problem, generates samples
  using the configured base sample size and interaction-order setting, and then
  exports run definitions to `job_config_sobol.toml`.

  The workflow is generic and can be used for constants from any Virtual
  Ecosystem module, provided the relevant parameter/constant ranges are defined
  in `sensitivity_parameters.toml`. In this script, the `hydrology` group is
  used as an example setup.

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

package_dependencies:
  - pathlib
  - tools.python.abiotic.job_config_tools
  - tools.python.abiotic.sensitivity_tools

usage_notes: |
  1. Edit `sensitivity_parameters.toml` to define the parameters and bounds.
  2. Select one or more parameter groups using `groups`.
  3. Adjust the Sobol base sample size (`base_sample_size`).
  4. Set `calculate_second_order=True` if second-order Sobol indices are
     required.
  5. Run as "python sobol_sample.py"  to generate `job_config_sobol.toml`.
  6. Submit the generated job configuration using your preferred execution
     workflow (e.g. HPC batch submission).

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
from pathlib import Path

from pyprojroot import here

project_root = here("pyproject.toml")

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
#
# base_sample_size:
#     Number of base Sobol samples (N). The total number of Virtual Ecosystem
#     simulations depends on both the number of selected parameters and whether
#     second-order sensitivity indices are calculated.

base_sample_size = 100

# calculate_second_order:
#     If True, generate additional samples required to estimate second-order
#     Sobol sensitivity indices. Setting this to False reduces the total number
#     of model runs and computes only first-order and total-order indice
calculate_second_order = True

# =============================================================================
# DIRECTORY SETTINGS
# =============================================================================
# Configuration directory containing the sensitivity analysis input files,
# including parameter definitions, the base VE configuration, and the generated
# HPC job configuration.

config_directory = Path("data/sensitivity/hydrology/config")

parameter_file = config_directory / "sensitivity_parameters.toml"

base_config = config_directory / "hydrology_base_config.toml"

output_file = config_directory / "job_config_sobol.toml"

# Scenario data directory containing the Virtual Ecosystem input datasets
# (e.g. climate, soil, vegetation and other site-specific data) required to
# execute each simulation. This directory is referenced by the generated
# `job_config.toml` and is used by the HPC workflow when running VE.
site_directory = Path("data/sensitivity/hydrology/data")

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
)

# =============================================================================
# GENERATE JOB CONFIGURATION
# =============================================================================
# Write sampled parameter sets into a VE job configuration TOML file.

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
