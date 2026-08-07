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

package_dependencies:
  - pathlib
  - tools.python.abiotic.job_config_tools
  - tools.python.abiotic.sensitivity_tools

usage_notes: |
  1. Edit `sensitivity_parameters.toml` to define the parameters and bounds.
  2. Select one or more parameter groups using `groups`.
  3. Adjust the number of Morris trajectories (`number_of_trajectories`).
  4. Adjust the number of grid levels (`number_of_levels`) if required.
  5. Optionally specify `optimal_trajectories` for trajectory optimisation.
  6. Run as "python morris_sample.py"  to generate `job_config_morris.toml`.
  7. Submit the generated job configuration using your preferred execution
     workflow (e.g. HPC batch submission).

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
from pathlib import Path

project_root = Path(__file__).resolve().parents[3]

if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

from tools.python.abiotic.job_config_tools import (  # noqa: E402
    generate_job_config,
)
from tools.python.abiotic.sensitivity_tools import (  # noqa: E402
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
#
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

# =============================================================================
# DIRECTORY SETTINGS
# =============================================================================
# Configuration directory containing the sensitivity analysis input files,
# including parameter definitions, the base VE configuration, and the generated
# HPC job configuration.

config_directory = Path("data/sensitivity/hydrology/config")

parameter_file = config_directory / "sensitivity_parameters.toml"

base_config = config_directory / "hydrology_base_config.toml"

output_file = config_directory / "job_config_morris.toml"

# Scenario data directory containing the Virtual Ecosystem input datasets
# (e.g. climate, soil, vegetation and other site-specific data) required to
# execute each simulation. This directory is referenced by the generated
# `job_config.toml` and is used by the HPC workflow when running VE.
site_directory = Path("data/sensitivity/hydrology/data")

# =============================================================================
# LOAD PARAMETER DEFINITIONS
# =============================================================================
# Read parameter definitions and build the Sobol problem structure.

problem = load_problem(
    parameter_file=parameter_file,
    groups=groups,
)

# =============================================================================
# GENERATE MORRIS SAMPLES
# =============================================================================
# Generate Morris samples using the configured sample size and order.

samples = generate_morris_samples(
    problem=problem,
    n_trajectories=number_of_trajectories,
    num_levels=number_of_levels,
    optimal_trajectories=optimal_trajectories,
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
# Print a summary of the generated Sobol samples and job configuration details=

print("=" * 60)
print("Morris sampling completed successfully")
print("=" * 60)
print(f"Parameter groups : {groups}")
print(f"Parameters       : {problem['num_vars']}")
print(f"VE runs          : {metadata['num_jobs']}")
print(f"Output file      : {metadata['output_file']}")
