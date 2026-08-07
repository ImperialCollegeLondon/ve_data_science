"""
---
title: Sobol sampling and job configuration generation for sensitivity analysis

description: |
  This script generates Sobol samples for selected Virtual Ecosystem model
  parameters/constants and creates a `job_config.toml` file for batch model runs.

  It can be used for any Virtual Ecosystem module (e.g. hydrology, soil,
  abiotic, plants, animals or litter) by defining the required parameter groups
  and parameter bounds in `sensitivity_parameters.toml`.

  The script reads parameter and group definitions from
  `sensitivity_parameters.toml`, constructs a Sobol problem, generates samples
  using the configured base sample size and interaction-order setting, and then
  exports run definitions to `job_config.toml`.

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
  3. Adjust the Sobol base sample size (`base_sample_size`).
  4. Set `calculate_second_order=True` if second-order Sobol indices are
     required.
  5. Run as "python sobol_sample.py"  to generate `job_config.toml`.
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

project_root = Path(__file__).resolve().parents[3]

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
# Description: define input/output paths, target parameter groups, and sampling options.

parameter_file = Path("data/scenarios/sensitivity/config/sensitivity_parameters.toml")

# Select one or more parameter groups defined in
# sensitivity_parameters.toml.
groups = [
    "hydrology",
]

base_config = "data/scenarios/sensitivity/config/hydrology_base_config.toml"

site_directory = "data/scenarios/sensitivity/config/"

output_file = Path("data/scenarios/sensitivity/config/job_config_sobol.toml")

base_sample_size = 100

calculate_second_order = True

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

generate_job_config(
    samples=samples,
    parameter_names=problem["names"],
    common_config_paths=[base_config],
    site_directory="data/scenarios/sensitivity/config",
    config_paths=[],
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
print(f"Parameters       : {problem['num_vars']}")
print(f"VE runs          : {len(samples)}")
