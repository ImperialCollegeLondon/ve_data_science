"""
---
title: Morris sampling and job configuration generation for sensitivity analysis

description: |
  This script generates Morris samples for selected Virtual Ecosystem model
  parameters/constants and creates a `job_config.toml` file for batch model runs.

   It loads parameter and group definitions from
   `sensitivity_parameters.toml`, builds the Morris problem specification, and
   generates trajectories using the configured number of levels, trajectories,
   and random seed options (if present). The resulting samples are translated
   into `job_config.toml` entries so each sampled parameter set is executed as a
   separate simulation job.

   The workflow is generic and can be used for constants from any Virtual
   Ecosystem module, provided the relevant parameter/constant ranges are defined
   in `sensitivity_parameters.toml`. In this script, the `hydrology` group is
   use  d as an example setup.

virtual_ecosystem_module: all

author:
  - Lelavathy

status: final

input_files:
  - name: sensitivity_parameters.toml
    path: data/scenarios/sensitivity/config/sensitivity_parameters.toml
    description: |
      Defines the parameter groups, parameter names and sampling bounds used
      for sensitivity analysis.

  - name: Base model configuration
    path: data/scenarios/sensitivity/config/default_job_config.toml
    description: |
      Base Virtual Ecosystem configuration used for every generated run.

output_files:
  - name: job_config.toml
    path: data/scenarios/sensitivity/config/job_config.toml
    description: |
      Virtual Ecosystem batch job configuration containing one sampled
      parameter set for each model run.

package_dependencies:
  - pathlib
  - tools.python.job_config_tools
  - tools.python.sensitivity_tools

usage_notes: |
  1. Edit `sensitivity_parameters.toml` to define the parameters and bounds.
  2. Select one or more parameter groups using `groups`.
  3. Adjust the number of Morris trajectories (`number_of_trajectories`).
  4. Adjust the number of grid levels (`number_of_levels`) if required.
  5. Optionally specify `optimal_trajectories` for trajectory optimisation.
  6. Run as "python morris_sample.py"  to generate `job_config.toml`.
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
# Description: define input/output paths, target parameter groups, and sampling
# options.

parameter_file = Path("data/scenarios/sensitivity/config/sensitivity_parameters.toml")

# Select one or more parameter groups defined in
# sensitivity_parameters.toml.
groups = [
    "hydrology",
]

base_config = "data/scenarios/sensitivity/config/hydrlogy_base_config.toml"

site_directory = "data/scenarios/sensitivity/config/"

output_file = Path("data/scenarios/sensitivity/config/job_config_morris.toml")

number_of_trajectories = 20

number_of_levels = 4

optimal_trajectories = None

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

generate_job_config(
    samples=samples,
    parameter_names=problem["names"],
    config_paths=[base_config],
    common_config_paths=[base_config],
    site_directory="data/scenarios/sensitivity/config",
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
print(f"VE runs          : {len(samples)}")
