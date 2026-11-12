"""
---
title: Analyse litter stocks and flows.

description: |
  Load carbon, nitrogen, and phosphorus litter stocks and flows from Virtual
  Ecosystem simulation output. Partition litter inputs into metabolic and
  structural pools, derive decay, mineralisation, and respiration losses from
  stock balances, and compare calculated rates with recorded outputs.

virtual_ecosystem_module: Litter

author: Jacob Cook

status: wip

input_files:
  - name: Virtual Ecosystem simulation output
    path: model_data.nc in the simulation output directory
    description: |
      Simulation output with litter stocks and flows in its outputs group and
      litter input lignin variables in its init and outputs groups.
  - name: Compiled simulation configuration
    path: compiled_configuration.toml in the simulation output directory
    description: |
      Simulation configuration used for grid cell area, update interval, and
      litter-process parameters.

output_files: []

imported_files: []

package_dependencies:
  - matplotlib
  - numpy
  - pint
  - pathlib
  - virtual-ecosystem
  - xarray

usage_notes: |
  Call analyse_litter with the simulation output directory and its compiled
  configuration to receive stocks, flows, and derived diagnostics in an
  xarray Dataset. The plotting helper compares stock-balance expected outflows
  with mapped outgoing flows for all litter pools or one selected pool at a
  timestep. Analysis variables include a source dimension: values read from
  the output are labelled simulation_output, while calculated values,
  including litter-pool splits from Virtual Ecosystem functions, are labelled
  inferred.
---
"""  # noqa: D212, D205

# TODO - ONCE I'M DONE ASK COPILOT TO UPDATE THE ABOVE BASED ON THE UPDATED CODE

from pathlib import Path

import xarray as xr

# Litter pools specified in input data
INPUT_POOLS = [
    "litter_pool_above_metabolic_cnp",
    "litter_pool_above_structural_cnp",
    "litter_pool_woody_cnp",
    "litter_pool_below_metabolic_cnp",
    "litter_pool_below_structural_cnp",
]
# Flows that are first generated on model initialisation
FLOW_GENERATED_ON_INIT = [
    "stem_turnover_cnp",
    "root_turnover_cnp",
    "foliage_turnover_cnp",
    "subcanopy_vegetation_litter_cnp",
    "subcanopy_seedbank_litter_cnp",
    "litter_consumed_above_metabolic_cnp",
    "litter_consumed_above_structural_cnp",
    "litter_consumed_woody_cnp",
    "litter_consumed_below_metabolic_cnp",
    "litter_consumed_below_structural_cnp",
]
# Flows that are first generated on model update
FLOW_GENERATED_ON_UPDATE = [
    "herbivory_waste_above_cnp",
    "herbivory_waste_below_cnp",
    "litter_mineralisation_rate_cnp",
    "above_ground_litter_respiration",
    "below_ground_litter_respiration",
]
# All the categories above are considered nodes
NODES = [*INPUT_POOLS, *FLOW_GENERATED_ON_INIT, *FLOW_GENERATED_ON_UPDATE]


def load_litter_nodes(
    model_data_path: Path,
) -> xr.Dataset:
    """Load litter output data as nodes in the macronutrient tracker.

    This process involves extracting the initial/init data for variables this is
    relevant for and add this data to the combined node data with a time index
    of -1.

    Args:
        model_data_path: Path to simulation's netcdf output file.

    Returns:
        An xarray Dataset containing variables corresponding to each node of the
        litter macronutrient cycles. These consist both of the litter pool
        stocks as well as the

    """
    with (
        xr.open_dataset(model_data_path, group="outputs") as outputs,
        xr.open_dataset(model_data_path, group="inputs") as inputs,
        xr.open_dataset(model_data_path, group="init") as initial,
    ):
        # Select the initial node variables and give them a time_index of minus 1
        initial_nodes = xr.merge([inputs[INPUT_POOLS], initial[FLOW_GENERATED_ON_INIT]])
        initial_nodes = initial_nodes.expand_dims(time_index=[-1])

        # Then find values for nodes through the simulation and concatenate
        continuous_nodes = outputs[NODES]
        litter_nodes = xr.concat([initial_nodes, continuous_nodes], dim="time_index")

        # All these nodes are by definition nodes
        litter_nodes = litter_nodes.assign_coords(category="node")

        return litter_nodes
