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
  The analysis dataset includes a source dimension distinguishing simulation
  output from inferred quantities, including litter-pool splits calculated
  with Virtual Ecosystem functions.
---
"""  # noqa: D212, D205

from __future__ import annotations

from pathlib import Path

from litter_analysis import generate_litter_network
from virtual_ecosystem.core.config_builder import (
    ConfigurationLoader,
    generate_configuration,
)
from virtual_ecosystem.core.model_config import CoreConfiguration
from virtual_ecosystem.models.litter.model_config import LitterConfiguration

# TODO - Hard coding path for testing, address this later
data_dir = Path("/Users/jc2017/Desktop/litter_nutrient_cycling/maliau_2/out")

model_data_path = data_dir / "model_data.nc"

simulation_configuration = data_dir / "compiled_configuration.toml"

# Load in configuration from simulation, and extract relevant litter part
config_data = ConfigurationLoader(cfg_paths=simulation_configuration)
full_config = generate_configuration(config_data.data)
litter_config = full_config.get_subconfiguration("litter", LitterConfiguration)
core_config = full_config.get_subconfiguration("core", CoreConfiguration)

litter_cycles = generate_litter_network(
    model_data_path=model_data_path,
    litter_config=litter_config,
    core_config=core_config,
)