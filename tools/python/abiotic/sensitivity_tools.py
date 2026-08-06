"""
---
title: Utility functions for sensitivity analysis

description: |
  This module provides reusable utility functions for global sensitivity
  analysis within the Virtual Ecosystem framework.

  The functions support loading parameter definitions from a TOML file,
  constructing SALib problem definitions, and generating parameter samples
  using supported sampling methods.

  These utilities are designed to be independent of any individual Virtual
  Ecosystem module and may therefore be reused for hydrology, soil, abiotic,
  plant, litter and animal sensitivity analyses.
.
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
            Path to ``sensitivity_parameters.toml``.

        groups:
            List of parameter groups to include.

            Example::

                ["hydrology"]

                ["hydrology", "soil"]

    Returns:
        Dictionary formatted according to the SALib problem specification.

    """

    parameter_file = Path(parameter_file)

    with open(parameter_file, "rb") as file:
        parameter_data = tomllib.load(file)

    names = []
    bounds = []

    for group in groups:
        if group not in parameter_data:
            raise ValueError(f"Unknown parameter group '{group}'.")

        for parameter in parameter_data[group]["parameters"]:
            names.append(parameter["name"])
            bounds.append(parameter["bounds"])

    return {
        "num_vars": len(names),
        "names": names,
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
        Sobol sample matrix.

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
        Morris sample matrix.

    """

    return morris.sample(
        problem=problem,
        N=n_trajectories,
        num_levels=num_levels,
        optimal_trajectories=optimal_trajectories,
    )
