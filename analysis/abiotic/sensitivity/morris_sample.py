"""
---
title: Morris sampling design for Virtual Ecosystem sensitivity analysis

description: |
  Generates a Morris sampling design and an arrayJob_config_<run_name>.toml
  file for the first stage of a two-stage global sensitivity analysis of
  Virtual Ecosystem (VE) constants.

  Morris is a trajectory-based screening method. Each trajectory changes one
  constant at a time across its specified range, allowing elementary effects to
  identify constants with negligible, important, non-linear, or interacting
  effects on model responses. This provides an economical first-stage screen
  before applying the more expensive Sobol analysis to a smaller parameter set.

  The script reads parameter groups and bounds from
  sensitivity_parameters.toml, generates SALib trajectories using the selected
  levels, trajectories, and seed, then writes one VE sub-job for every sampled
  parameter combination. It is module-independent and can be used wherever VE
  constants have bounds defined in sensitivity_parameters.toml.

  This script creates the sampling design and job configuration only. It does
  not submit or run VE simulations, or calculate Morris statistics; those steps
  are completed by the array-job and Morris analysis workflows.

virtual_ecosystem_module: All

author:
  - Lelavathy

status: wip

input_files:
  - name: sensitivity_parameters.toml
    path: data/sensitivity/<module>/config/sensitivity_parameters.toml
    description: |
      Lower and upper bounds of every constant that may be sampled, grouped by
      VE configuration section as [[<group>.constants]] entries with a name and
      bounds.
  - name: base VE configuration
    path: data/sensitivity/<module>/config/<base config>.toml
    description: |
      Full VE configuration shared by every run. Only the sampled constants are
      overridden in the job file. Base values outside the sampled range are
      reported as warnings.

output_files:
  - name: arrayJob_config_<run_name>.toml
    path: data/sensitivity/<module>/config/arrayJob_config_<run_name>.toml
    description: |
      The configuration file used to run the Morris ensemble. Each sub-job
      contains one sampled set of constant values and corresponds to one row of
      the Morris design. Submit this file with hpc_jobs.submit_ve_array_job to
      run the VE simulations. The Morris analysis script reads it afterwards to
      match each completed model output to its sampled parameter values.

imported_files:
  - name: sensitivity_tools.py
    path: tools/python/src/ve_data_tools/sensitivity_tools.py
    description: |
      Shared utilities for the revised Morris and Sobol workflows. This script
      uses load_problem to read selected bounds, check_defaults_within_bounds
      to compare base values with them, generate_morris_samples to create SALib
      trajectories, and write_job_config to produce the array-job file and its
      reproducibility header. The module also contains functions used by later
      analysis scripts to read designs, verify their structure and row order,
      validate completed runs, extract model responses, and create plots.
  - name: hpc_arrayJob_config_tools.py
    path: tools/python/src/ve_data_tools/hpc_arrayJob_config_tools.py
    description: Used by write_job_config to write the [[subJobs]] entries.

package_dependencies:
  - numpy
  - pandas
  - SALib
  - tomli_w
  - pyprojroot

usage_notes: |
  1. Define the candidate constants, parameter groups, and lower and upper
    bounds in sensitivity_parameters.toml.

  2. In the user settings below, select parameter_groups and optionally set
    selected_parameters to screen only part of those groups.

  3. Set morris_settings. trajectories controls the number of elementary
    effects per constant, levels controls the Morris grid, and
    candidate_trajectories optionally selects widely spread trajectories.

  4. Set random_seed to a fixed integer so the same settings regenerate the
    same design. Use log10_parameters only for positive ranges that span more
    than about one order of magnitude.

  5. Run the script from the repository root:

    uv run python analysis/abiotic/sensitivity/morris_sample.py

  6. Review the reported run count and warnings, then submit
    arrayJob_config_<run_name>.toml with hpc_jobs.submit_ve_array_job.

  7. Analyse the completed output directory with the matching Morris analysis
    script before choosing constants for the Sobol stage.

  The design cost is trajectories * (constants + 1), for example 20 *
  (14 + 1) = 300 runs. Use a new run_name for every design. Do not edit the
  generated job file manually: change the settings and regenerate it instead.

 references: |
    Morris, M. D. (1991). Factorial sampling plans for preliminary computational
    experiments.technometrics, 33(2), 161-174.

    Iwanaga, T., Usher, W., & Herman, J. (2022). Toward SALib 2.0: Advancing the
    accessibility and interpretability of global sensitivity analyses.
    Socio-Environmental Systems Modelling, 4, 18155-18155.

Further information on SALib usage and supported sampling methods is available
in the SALib documentation: https://salib.readthedocs.io/en/latest
---
"""  # noqa: D400, D212, D205, D415

import sys

from pyprojroot import here

# Locate the repository from pyproject.toml and make the shared Python tools
# importable, so the script runs directly from the repository root.
project_root = here("pyproject.toml").parent
python_source = project_root / "tools" / "python" / "src"
if str(python_source) not in sys.path:
    sys.path.insert(0, str(python_source))

from ve_data_tools.sensitivity_tools import (  # noqa: E402
    check_defaults_within_bounds,
    generate_morris_samples,
    load_problem,
    write_job_config,
)

# -----------------------------------------------------------------------------
# User settings: the experiment specification. Edit these and rerun the script;
# never edit the generated job file by hand.
# -----------------------------------------------------------------------------

# Name of this experiment. It names the job file (arrayJob_config_<run_name>.toml)
# and must be the results folder passed to submit_ve_array_job (out/<run_name>).
run_name = "hydrology_morris_001"

# Module folder under data/sensitivity/ (holds config/, data/ and out/).
module_directory = project_root / "data/sensitivity/hydrology"
config_directory = module_directory / "config"
parameter_file = config_directory / "sensitivity_parameters.toml"
base_config = config_directory / "static_hydro_configuration.toml"
site_directory = module_directory / "data"

# VE configuration sections whose constants are sampled, e.g. ["hydrology"],
# ["abiotic_simple"] or ["hydrology", "soil"]. Each needs [[<group>.constants]]
# entries in parameter_file.
parameter_groups = ["hydrology"]

# None = every constant with bounds in those groups, or a list of names to
# screen a subset (order is kept). Use "group.name" if a name is in several
# groups.
selected_parameters = None

# Constants sampled uniformly in log10 space. Use for ranges spanning more than
# about one order of magnitude (bounds must be positive). Recorded in the job
# file header, where the analysis script reads it.
log10_parameters = ["saturated_hydraulic_conductivity"]

# Morris design.
morris_settings = {
    "trajectories": 20,  # r: elementary effects per constant
    "levels": 4,  # p: grid levels; delta = p / (2 (p - 1))
    "candidate_trajectories": 0,  # 0 = off; e.g. 100 -> keep the 20 most spread
}

# Fixed seed: the same seed and settings reproduce the same design.
random_seed = 2026

# Number of repeated runs of the base configuration (0 = none). VE hydrology
# splits monthly rain into days at random, so identical constants do not give
# identical output; replicates measure that noise.
replicates = 0


def main() -> None:
    """Generate the Morris design and write it as a VE array-job file."""

    problem = load_problem(
        parameter_file, parameter_groups, selected_parameters, log10_parameters
    )
    for warning in check_defaults_within_bounds(base_config, problem):
        print(f"Warning: {warning}")

    samples = generate_morris_samples(problem, morris_settings, random_seed)
    n_parameters = problem["num_vars"]
    n_trajectories = int(morris_settings["trajectories"])
    expected_shape = (n_trajectories * (n_parameters + 1), n_parameters)
    if samples.shape != expected_shape:
        raise ValueError(
            f"Morris design shape {samples.shape}, expected {expected_shape}"
        )

    result = write_job_config(
        method="morris",
        run_name=run_name,
        problem=problem,
        samples=samples,
        settings=morris_settings,
        seed=random_seed,
        parameter_file=parameter_file,
        base_config=base_config,
        site_directory=site_directory,
        config_dir=config_directory,
        project_root=project_root,
        replicates=replicates,
    )

    print("=" * 66)
    print(f"Morris design: {run_name}")
    print("=" * 66)
    print(f"Groups           : {parameter_groups}")
    print(f"Constants (D)    : {n_parameters}")
    for name, scale in zip(problem["names"], problem["scale"]):
        print(f"  - {name}{'  (log10)' if scale == 'log10' else ''}")
    print(f"Trajectories (r) : {n_trajectories}")
    print(f"Levels (p)       : {morris_settings['levels']}")
    print(f"VE runs r (D + 1): {result['n_runs']}")
    for label, path in result["files"].items():
        print(f"{label:<17}: {path}")
    print(f"Submit results to: {module_directory / 'out' / run_name}")


if __name__ == "__main__":
    main()
