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
from virtual_ecosystem.models.litter.inputs import (
    find_nutrient_split_between_litter_pools,
    split_pool_into_metabolic_and_structural_litter,
)
from virtual_ecosystem.models.litter.model_config import LitterConstants

# Litter pools specified in input data
INPUT_POOLS = [
    "litter_pool_above_metabolic_cnp",
    "litter_pool_above_structural_cnp",
    "litter_pool_woody_cnp",
    "litter_pool_below_metabolic_cnp",
    "litter_pool_below_structural_cnp",
]

# Flows driven by animal consumption of litter
ANIMAL_LITTER_CONSUMPTION = [
    "litter_consumed_above_metabolic_cnp",
    "litter_consumed_above_structural_cnp",
    "litter_consumed_woody_cnp",
    "litter_consumed_below_metabolic_cnp",
    "litter_consumed_below_structural_cnp",
]

PLANT_INPUTS = [
    {"name": "stem_turnover_cnp", "strata": None, "lignin": None},
    {
        "name": "root_turnover_cnp",
        "strata": "below",
        "lignin": {"variable_name": "root_lignin", "source": "init"},
    },
    {
        "name": "foliage_turnover_cnp",
        "strata": "above",
        "lignin": {"variable_name": "senesced_leaf_lignin", "source": "init"},
    },
    {
        "name": "subcanopy_vegetation_litter_cnp",
        "strata": "above",
        "lignin": {
            "variable_name": "subcanopy_vegetation_litter_lignin",
            "source": "init",
        },
    },
    {
        "name": "subcanopy_seedbank_litter_cnp",
        "strata": "above",
        "lignin": {
            "variable_name": "subcanopy_seedbank_litter_lignin",
            "source": "init",
        },
    },
]

# Flows that are first generated on model initialisation
FLOW_GENERATED_ON_INIT = [
    *ANIMAL_LITTER_CONSUMPTION,
    *[input["name"] for input in PLANT_INPUTS],
]

# Flows from plant matter inputs due to herbivory
HERBIVORE_INPUTS = [
    {
        "name": "herbivory_waste_above_cnp",
        "strata": "above",
        "lignin": {
            "variable_name": "herbivory_waste_above_lignin",
            "source": "outputs",
        },
    },
    {
        "name": "herbivory_waste_below_cnp",
        "strata": "below",
        "lignin": {
            "variable_name": "herbivory_waste_below_lignin",
            "source": "outputs",
        },
    },
]
# Flows that are first generated on model update
FLOW_GENERATED_ON_UPDATE = [
    *[input["name"] for input in HERBIVORE_INPUTS],
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
        stocks, the respiration by litter layer and the flows to and from other
        models.

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
        for var in litter_nodes.data_vars:
            litter_nodes[var].attrs["category"] = "node"

        return litter_nodes


def define_litter_consumption_flows(litter_cycles: xr.Dataset) -> xr.Dataset:
    """Add animal consumption flows as links in the litter cycle data.

    This function is straightforward as litter consumption flows are explicitly
    linked to specific litter pools, and the entire process happens within a
    time step.

    Args:
        litter_cycles: Data structure containing the macronutrient cycles within
            the litter model.

    Returns:
        The data array containing the litter model macronutrient cycles with the
        animal consumption links populated.

    """

    for animal_consumption in ANIMAL_LITTER_CONSUMPTION:
        # Find corresponding litter pool
        pool_name = animal_consumption.replace("consumed", "pool")

        # From this construct the flow variable name
        flow_variable = f"{pool_name}_→_{animal_consumption}"

        # Add the consumption flow as a flow variable
        litter_cycles[flow_variable] = litter_cycles[animal_consumption]
        litter_cycles[flow_variable].attrs["category"] = "link"

    return litter_cycles


def define_plant_matter_input_flows(
    litter_cycles: xr.Dataset, litter_constants: LitterConstants, model_data_path: Path
) -> xr.Dataset:
    """Add plant matter input flows as links in the litter cycle data.

    This function has to calculate how plant input flows are split between
    litter pools. The only input this doesn't need to be done for is the dead
    wood inputs. These calculations are performed by importing the relevant
    functionality from `virtual_ecosystem`.

    Args:
        litter_cycles: Data structure containing the macronutrient cycles within
            the litter model.
        litter_constants: Set of constants used by the litter model.
        model_data_path: Path to simulation's netcdf output file.

    Returns:
        The data array containing the litter model macronutrient cycles with the
        plant matter input links populated.

    """

    # Wood input needs special handling as it only flows to a single pool
    wood_input = "stem_turnover_cnp"
    wood_flow_variable = f"{wood_input}_→_litter_pool_woody_cnp"
    litter_cycles[wood_flow_variable] = litter_cycles[wood_input]
    litter_cycles[wood_flow_variable].attrs["category"] = "link"

    # As wood has already been handled it is removed from the list of input
    # streams
    input_streams = [
        item for item in PLANT_INPUTS + HERBIVORE_INPUTS if item["name"] != wood_input
    ]
    for input_stream in input_streams:
        # Need to find lignin proportion of the input as this effects the split
        # between pools
        lignin_proportion = xr.open_dataset(
            model_data_path, group=input_stream["lignin"]["source"]
        )[input_stream["lignin"]["variable_name"]]

        # The lignin proportions of the herbivore consumption inputs vary over
        # time, but lack a value for the initial timestep (time_index = -1). We
        # therefore reindex to add NaN values for the initial timestep, so that
        # the lengths of the different variables match.
        if input_stream["lignin"]["source"] == "outputs":
            lignin_proportion = lignin_proportion.reindex(
                time_index=[-1, *lignin_proportion.time_index.values]
            )

        # Store input stream name as a variable as it gets reused
        input_stream_name = input_stream["name"]

        # Some inputs have a pft dimension which the litter model sums over
        if "pft" in litter_cycles[input_stream_name].dims:
            input_masses = litter_cycles[input_stream_name].sum(dim="pft")
        else:
            input_masses = litter_cycles[input_stream_name]

        # Fraction of input that goes to the metabolic pool can now be found
        metabolic_fraction = split_pool_into_metabolic_and_structural_litter(
            input_masses=input_masses,
            lignin_proportion=lignin_proportion.to_numpy(),
            max_metabolic_fraction=litter_constants.max_metabolic_fraction_of_input,
            split_sensitivity_nitrogen=litter_constants.metabolic_split_nitrogen_sensitivity,
            split_sensitivity_phosphorus=litter_constants.metabolic_split_phosphorus_sensitivity,
        )

        # Split input masses by element
        total_carbon_input = input_masses.sel(element="C")
        total_nitrogen_input = input_masses.sel(element="N")
        total_phosphorus_input = input_masses.sel(element="P")

        # And from this the split of nitrogen and phosphorus between pools
        metabolic_nitrogen, structural_nitrogen = (
            find_nutrient_split_between_litter_pools(
                input_carbon_rate=total_carbon_input,
                input_nutrient_rate=total_nitrogen_input,
                metabolic_split=metabolic_fraction,
                meta_to_struct_nutrient_ratio=litter_constants.metabolic_to_structural_n_ratio,
            )
        )

        metabolic_phosphorus, structural_phosphorus = (
            find_nutrient_split_between_litter_pools(
                input_carbon_rate=total_carbon_input,
                input_nutrient_rate=total_phosphorus_input,
                metabolic_split=metabolic_fraction,
                meta_to_struct_nutrient_ratio=litter_constants.metabolic_to_structural_p_ratio,
            )
        )

        # Make variable names for the link variables
        strata = input_stream["strata"]
        meta_flow_variable = f"{input_stream_name}_→_litter_pool_{strata}_metabolic_cnp"
        struct_flow_variable = (
            f"{input_stream_name}_→_litter_pool_{strata}_structural_cnp"
        )

        litter_cycles[meta_flow_variable] = xr.concat(
            [
                metabolic_fraction * total_carbon_input,
                metabolic_nitrogen,
                metabolic_phosphorus,
            ],
            dim=xr.IndexVariable("element", ["C", "N", "P"]),
        )
        litter_cycles[meta_flow_variable].attrs["category"] = "link"
        litter_cycles[meta_flow_variable].attrs["description"] = (
            f"C, N and P flow from {input_stream_name} to the {strata} metabolic litter"
            " pool"
        )
        litter_cycles[struct_flow_variable] = xr.concat(
            [
                (1 - metabolic_fraction) * total_carbon_input,
                structural_nitrogen,
                structural_phosphorus,
            ],
            dim=xr.IndexVariable("element", ["C", "N", "P"]),
        )
        litter_cycles[struct_flow_variable].attrs["category"] = "link"
        litter_cycles[struct_flow_variable].attrs["description"] = (
            f"C, N and P flow from {input_stream_name} to the {strata} structural "
            "litter pool"
        )

    return litter_cycles
