"""
---
title: Build a litter macronutrient network.

description: |
  Load carbon, nitrogen, and phosphorus litter stocks and flows from Virtual
  Ecosystem simulation output. Partition plant and herbivore matter inputs into
  metabolic and structural litter pools, derive litter decay,
  mineralisation, and respiration losses from stock balances, and combine the
  stocks and links into one xarray network Dataset.

virtual_ecosystem_module: Litter

author: Jacob Cook

status: wip

input_files:
  - name: Virtual Ecosystem simulation output
    path: NetCDF file supplied to generate_litter_network
    description: |
      Simulation data from the inputs, init, and outputs NetCDF groups.
      It provides litter pool stocks, litter input flows, lignin proportions,
      animal consumption flows, and litter mineralisation and respiration nodes.
  - name: Litter and core configurations
    path: LitterConfiguration and CoreConfiguration objects
    description: |
      Litter constants control pool splitting and carbon use efficiency.
      Core grid configuration provides cell area for stock-balance calculations.

output_files: []

imported_files: []

package_dependencies:
  - pathlib
  - virtual-ecosystem
  - xarray

usage_notes: |
  Call generate_litter_network with the simulation NetCDF path and the litter
  and core configuration objects to return the complete litter macronutrient
  network. The result marks litter stocks and recorded flows as nodes and
  inferred plant-input splits, animal consumption flows, decay losses,
  mineralisation, and respiration as links.
---
"""  # noqa: D212, D205

from pathlib import Path

import xarray as xr
from virtual_ecosystem.core.model_config import CoreConfiguration
from virtual_ecosystem.models.litter.inputs import (
    find_nutrient_split_between_litter_pools,
    split_pool_into_metabolic_and_structural_litter,
)
from virtual_ecosystem.models.litter.model_config import (
    LitterConfiguration,
    LitterConstants,
)

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
    litter_cycles[wood_flow_variable] = litter_cycles[wood_input].sum(dim="pft")
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


def calculate_litter_decay_losses(
    litter_cycles: xr.DataArray,
    cell_area: float,
    litter_constants: LitterConstants,
) -> xr.DataArray:
    """Calculate the decay from each litter pool and its expected destination.

    The changes in the litter pools that are already accounted for (i.e. plant
    inputs and animal consumption) are summed, and then subtracted from the
    change in pools between time steps. The remainder is taken to be the pool
    decay rate. The destination of this decay is then determined using

    Args:
        litter_cycles: Data structure containing the macronutrient cycles within
            the litter model.
        cell_area: The area of the grid cells used in the simulation [m2].
        litter_constants: Set of constants used by the litter model.

    Returns:
        The data array containing the litter model macronutrient cycles with the
        litter pool decay links populated.

    """

    # Extract per pool carbon use efficiencies from the litter constants +
    # define strata
    pool_specific_details = {
        "litter_pool_above_metabolic_cnp": {
            "cue": litter_constants.cue_metabolic,
            "strata": "above",
        },
        "litter_pool_above_structural_cnp": {
            "cue": litter_constants.cue_structural_above_ground,
            "strata": "above",
        },
        "litter_pool_woody_cnp": {"cue": litter_constants.cue_woody, "strata": "above"},
        "litter_pool_below_metabolic_cnp": {
            "cue": litter_constants.cue_metabolic,
            "strata": "below",
        },
        "litter_pool_below_structural_cnp": {
            "cue": litter_constants.cue_structural_below_ground,
            "strata": "below",
        },
    }

    for litter_pool in INPUT_POOLS:
        # Find all variables that are inputs to the pool in question
        inputs_streams = [
            var for var in litter_cycles.data_vars if var.endswith(f"_→_{litter_pool}")
        ]

        total_pool_inputs = sum(
            litter_cycles[inputs_stream] for inputs_stream in inputs_streams
        )

        # Next step is to subtract the consumption from the total input (divide
        # by cell area so that units match that of the litter pool)
        animal_consumption_flow = litter_pool.replace("pool", "consumed")
        non_decay_pool_changes = (
            total_pool_inputs - litter_cycles[animal_consumption_flow]
        ) / cell_area

        # Now calculate implied decay by calculating the change in the litter stock
        # that isn't accounted for
        change_in_pool = (
            litter_cycles[litter_pool].shift(time_index=1) - litter_cycles[litter_pool]
        )
        decay_loss = change_in_pool - non_decay_pool_changes

        # Extract pool specific details
        cue = pool_specific_details[litter_pool]["cue"]
        strata = pool_specific_details[litter_pool]["strata"]

        # Respiration and mineralisation are then trivial to calculate
        respiration_flow = f"{litter_pool}_→_{strata}_ground_litter_respiration"
        litter_cycles[respiration_flow] = (1 - cue) * decay_loss.sel(element="C")
        litter_cycles[respiration_flow].attrs["description"] = (
            f"C respiration from {litter_pool}, goes to {strata}-ground litter "
            "respiration."
        )
        litter_cycles[respiration_flow].attrs["category"] = "link"
        litter_cycles[respiration_flow].attrs["unit"] = "kg m-2"

        mineralisation_flow = f"{litter_pool}_→_litter_mineralisation_rate_cnp"
        litter_cycles[mineralisation_flow] = xr.concat(
            [
                cue * decay_loss.sel(element="C"),
                decay_loss.sel(element="N"),
                decay_loss.sel(element="P"),
            ],
            dim=xr.IndexVariable("element", ["C", "N", "P"]),
        )
        litter_cycles[mineralisation_flow].attrs["description"] = (
            f"C, N and P mineralisation from {litter_pool}"
        )
        litter_cycles[mineralisation_flow].attrs["category"] = "link"
        litter_cycles[mineralisation_flow].attrs["unit"] = "kg m-2"

    return litter_cycles


def generate_litter_network(
    model_data_path: Path,
    litter_config: LitterConfiguration,
    core_config: CoreConfiguration,
) -> xr.DataArray:
    """Generate the full macronutrient cycling network for the litter model.

    This function loads in the litter model variables from the data object in as
    nodes. The flows between these nodes are then inferred, using functionality
    imported from the `virtual_ecosystem`, and add to the same object to obtain
    a complete representation of the litter model macronutrient cycles.

    Args:
        model_data_path: Path to simulation's netcdf output file.
        litter_config: Complete configuration of the litter model.
        core_config: Complete configuration of the virtual ecosystem simulation core.

    Returns:
        A data array containing a complete representation of the litter model
        macronutrient cycles.

    """
    litter_nodes = load_litter_nodes(model_data_path=model_data_path)

    litter_cycles = define_litter_consumption_flows(litter_nodes)

    litter_cycles = define_plant_matter_input_flows(
        litter_cycles=litter_cycles,
        litter_constants=litter_config.constants,
        model_data_path=model_data_path,
    )

    litter_cycles = calculate_litter_decay_losses(
        litter_cycles=litter_cycles,
        cell_area=core_config.grid.cell_area,
        litter_constants=litter_config.constants,
    )

    return litter_cycles
