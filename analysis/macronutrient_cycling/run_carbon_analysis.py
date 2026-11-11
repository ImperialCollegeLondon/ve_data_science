"""
---
title: Run carbon analysis on Virtual Ecosystem simulation output.

description: |
  Load and analyse litter stocks and flows from a Virtual Ecosystem simulation
  output directory, then save a plot comparing expected and mapped actual
  outflows for each litter pool at a selected timestep.

virtual_ecosystem_module: Litter

author: Jacob Cook

status: wip

input_files:
  - name: Virtual Ecosystem simulation output
    path: User-supplied output directory via --simulation-output
    description: |
      Directory containing model_data.nc and compiled_configuration.toml.

output_files:
  - name: Litter outflow comparison
    path: litter_outflows.png in the simulation output directory
    description: |
      Comparison of expected total outflows and mapped actual outflows for
      each litter stock pool at the selected time index.

package_dependencies:
  - argparse
  - matplotlib
  - pathlib
  - tomllib

imported_files:
  - name: Litter stock analysis
    path: analysis/macronutrient_cycling/analyse_litter.py
    description: |
      Loads and derives litter stocks, flows, stock-balance losses, and
      expected-versus-actual node outflow plots.

usage_notes: |
  Provide the simulation output directory with --simulation-output, for example:
  python analysis/macronutrient_cycling/run_carbon_analysis.py \
  --simulation-output /path/to/simulation/output --time-index -1
  Use --node to plot one litter pool instead of all pools. The output image is
  saved as litter_outflows.png in the supplied simulation output directory.
---
"""  # noqa: D212, D205

from __future__ import annotations

import argparse
import tomllib
from pathlib import Path
from typing import Any

from analyse_litter import (
    LITTER_STOCKS,
    analyse_litter,
    plot_expected_vs_actual_node_outflows,
)


def parse_args() -> argparse.Namespace:
    """Parse and validate the simulation output directory and its files."""
    parser = argparse.ArgumentParser(
        description="Run carbon analysis on Virtual Ecosystem simulation output."
    )
    parser.add_argument(
        "--simulation-output",
        type=Path,
        required=True,
        help="Path to a directory containing model_data.nc.",
    )
    parser.add_argument(
        "--time-index",
        type=int,
        default=-1,
        help="Timestep index to plot; defaults to the latest timestep.",
    )
    parser.add_argument(
        "--node",
        choices=LITTER_STOCKS,
        help="Litter pool to plot; defaults to plotting all litter pools.",
    )
    args = parser.parse_args()
    simulation_output = args.simulation_output.expanduser().resolve()

    if not simulation_output.is_dir():
        parser.error(f"simulation output directory does not exist: {simulation_output}")

    model_data_path = simulation_output / "model_data.nc"
    if not model_data_path.is_file():
        parser.error(
            f"simulation output does not contain model_data.nc: {model_data_path}"
        )

    configuration_path = simulation_output / "compiled_configuration.toml"
    if not configuration_path.is_file():
        parser.error(
            "simulation output does not contain compiled_configuration.toml: "
            f"{configuration_path}"
        )

    args.simulation_output = simulation_output
    return args


def load_simulation_configuration(simulation_output: Path) -> dict[str, Any]:
    """Load the compiled simulation configuration.

    Args:
        simulation_output: Directory containing compiled_configuration.toml.

    Returns:
        The full simulation configuration.

    """
    configuration_path = simulation_output / "compiled_configuration.toml"
    with configuration_path.open("rb") as configuration_file:
        return tomllib.load(configuration_file)


args = parse_args()
print(f"Simulation output folder: {args.simulation_output}")
simulation_configuration = load_simulation_configuration(args.simulation_output)
litter_data = analyse_litter(args.simulation_output, simulation_configuration)
outflow_plot_path = args.simulation_output / "litter_outflows.png"
plot_expected_vs_actual_node_outflows(
    litter_data=litter_data,
    cell_area=simulation_configuration["core"]["grid"]["cell_area"],
    time_index=args.time_index,
    node_name=args.node,
    output_path=outflow_plot_path,
)
print(f"Litter outflow comparison saved to: {outflow_plot_path}")
