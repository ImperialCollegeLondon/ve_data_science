"""
---
title: Utility functions for sensitivity analysis

description: |
  This module provides reusable utility functions for global sensitivity
  analysis within the Virtual Ecosystem framework.

  The module provides functions for loading parameter definitions from a
  TOML configuration file, constructing SALib problem definitions, and
  generating parameter samples using supported global sensitivity analysis
  methods.

  Each parameter definition stores the full Virtual Ecosystem configuration
  key (e.g. `hydrology.constants.groundwater_capacity`) together with its
  sampling bounds. This allows sampled values to be written directly into
  Virtual Ecosystem job configuration files without additional parameter
  mapping.

  These utilities are designed to be independent of any individual Virtual
  Ecosystem module and may therefore be reused for hydrology, soil, abiotic,
  plant, litter and animal sensitivity analyses.

virtual_ecosystem_module: all

author:
  - Lelavathy

status: final

package_dependencies:
  - pathlib
  - tomllib
  - numpy
  - SALib

usage_notes: |
  This module contains reusable helper functions only and is not intended to be
  executed directly.

references: |
  Sobol, I. M. (2001). Global sensitivity indices for nonlinear mathematical
  models and their Monte Carlo estimates. Mathematics and Computers in
  Simulation, 55(1-3), 271-280.

  Morris, M. D. (1991). Factorial sampling plans for preliminary computational
  experiments. Technometrics, 33(2), 161-174.

  Iwanaga, T., Usher, W., & Herman, J. (2022). Toward SALib 2.0:
  Advancing the accessibility and interpretability of global sensitivity
  analyses. Socio-Environmental Systems Modelling, 4, 18155.

  SALib documentation:
  https://salib.readthedocs.io/en/latest/
---
"""  # noqa: D400, D205, D212, D415

import tomllib
from pathlib import Path

import numpy as np
from SALib.sample import morris, sobol

# =============================================================================
# LOAD SENSITIVITY PROBLEM
# =============================================================================
# Read parameter groups and bounds from a TOML file and build a SALib-compatible
# problem dictionary (`num_vars`, `names`, `bounds`) for downstream sampling.


def load_problem(
    parameter_file: str | Path,
    groups: list[str],
) -> dict:
    """Load a SALib problem definition from a TOML parameter file.

    The TOML file may contain parameter definitions for multiple Virtual
    Ecosystem modules. Only the requested parameter groups are included in the
    returned problem definition.

    Args:
        parameter_file:
            Path to ``sensitivity_parameters.toml`` containing one or more
            parameter groups. Each parameter entry should define the full
            Virtual Ecosystem configuration key (for example
            ``hydrology.constants.groundwater_capacity``) together with its
            sampling bounds.

        groups:
            List of parameter groups to include in the SALib problem definition.
            Each group corresponds to a section in
            ``sensitivity_parameters.toml``.

            Example::

                ["hydrology"]

                ["hydrology", "soil"]

    Returns:
        Dictionary formatted according to the SALib problem specification,
        containing:

        - ``num_vars``: number of selected parameters;
        - ``names``: Virtual Ecosystem configuration keys;
        - ``bounds``: lower and upper sampling bounds.

    Example:
        Given the following entry in `sensitivity_parameters.toml`

        [[hydrology.parameters]]
        name = "hydrology.constants.groundwater_capacity"
        bounds = [200.0, 1500.0]

        the returned problem definition contains

        names = [
            "hydrology.constants.groundwater_capacity",
        ]

        These configuration keys are written directly to the generated
        `job_config.toml` as parameter overrides.

    Raises:
        ValueError:
            If a requested parameter group is not found in the TOML file.

    """

    parameter_file = Path(parameter_file)

    with open(parameter_file, "rb") as file:
        parameter_data = tomllib.load(file)

    config_keys = []
    bounds = []

    for group in groups:
        if group not in parameter_data:
            raise ValueError(f"Unknown parameter group '{group}'.")

        for parameter in parameter_data[group]["parameters"]:
            config_keys.append(parameter["name"])
            bounds.append(parameter["bounds"])

    return {
        "num_vars": len(config_keys),
        "names": config_keys,
        "bounds": bounds,
    }


# =============================================================================
# GENERATE SOBOL SAMPLES
# =============================================================================
# Generate quasi-random Sobol samples from a SALib problem definition, with
# optional second-order sampling and scrambling controls.


def generate_sobol_samples(
    problem: dict,
    n_samples: int,
    calc_second_order: bool = False,
    scramble: bool = True,
) -> np.ndarray:
    """Generate Sobol parameter samples.

    Args:
        problem:
            SALib problem definition.

        n_samples:
            Base Sobol sample size.

        calc_second_order:
            Generate samples required for second-order Sobol indices.

        scramble:
            Apply Owen scrambling to improve sample uniformity.

    Returns:
        Returns:
            A NumPy array containing Morris trajectory samples generated by SALib..

    """

    return sobol.sample(
        problem=problem,
        N=n_samples,
        calc_second_order=calc_second_order,
        scramble=scramble,
    )


# =============================================================================
# GENERATE MORRIS SAMPLES
# =============================================================================
# Generate Morris elementary-effects trajectories from a SALib problem
# definition, including optional trajectory optimisation settings.


def generate_morris_samples(
    problem: dict,
    n_trajectories: int,
    num_levels: int = 4,
    optimal_trajectories: int | None = None,
) -> np.ndarray:
    """Generate Morris elementary effect samples.

    Args:
        problem:
            SALib problem definition.

        n_trajectories:
            Number of Morris trajectories.

        num_levels:
            Number of grid levels.

        optimal_trajectories:
            Number of optimal trajectories.

    Returns:
        Returns:
        A NumPy array containing Morris trajectory samples generated by SALib.

    """

    return morris.sample(
        problem=problem,
        N=n_trajectories,
        num_levels=num_levels,
        optimal_trajectories=optimal_trajectories,
    )
