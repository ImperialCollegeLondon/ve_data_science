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
  timestep.
---
"""  # noqa: D212, D205

from __future__ import annotations

from pathlib import Path
from typing import Any

import matplotlib.pyplot as plt
import numpy as np
import xarray as xr
from pint import Quantity
from virtual_ecosystem.models.litter.inputs import (
    find_nutrient_split_between_litter_pools,
    split_pool_into_metabolic_and_structural_litter,
)

LITTER_STOCKS = [
    "litter_pool_above_metabolic_cnp",
    "litter_pool_above_structural_cnp",
    "litter_pool_woody_cnp",
    "litter_pool_below_metabolic_cnp",
    "litter_pool_below_structural_cnp",
]

FLOWS = [
    "stem_turnover_cnp",
    "root_turnover_cnp",
    "foliage_turnover_cnp",
    "subcanopy_vegetation_litter_cnp",
    "subcanopy_seedbank_litter_cnp",
    "herbivory_waste_above_cnp",
    "herbivory_waste_below_cnp",
    "litter_consumed_above_metabolic_cnp",
    "litter_consumed_above_structural_cnp",
    "litter_consumed_woody_cnp",
    "litter_consumed_below_metabolic_cnp",
    "litter_consumed_below_structural_cnp",
    "litter_mineralisation_rate_cnp",
    "above_ground_litter_respiration",
    "below_ground_litter_respiration",
]

SPLIT_INPUTS = {
    "root_turnover_cnp": ("init", "root_lignin", "below"),
    "foliage_turnover_cnp": ("init", "senesced_leaf_lignin", "above"),
    "subcanopy_vegetation_litter_cnp": (
        "init",
        "subcanopy_vegetation_litter_lignin",
        "above",
    ),
    "subcanopy_seedbank_litter_cnp": (
        "init",
        "subcanopy_seedbank_litter_lignin",
        "above",
    ),
    "herbivory_waste_above_cnp": (
        "outputs",
        "herbivory_waste_above_lignin",
        "above",
    ),
    "herbivory_waste_below_cnp": (
        "outputs",
        "herbivory_waste_below_lignin",
        "below",
    ),
}

SPLIT_FLOW_NAMES = {
    input_name: (
        f"{input_name.removesuffix('_cnp')}_{ground}_metabolic_cnp",
        f"{input_name.removesuffix('_cnp')}_{ground}_structural_cnp",
    )
    for input_name, (_, _, ground) in SPLIT_INPUTS.items()
}

DECAY_LOSS_FLOW_NAMES = {
    stock: f"litter_decay_loss_{stock.removeprefix('litter_pool_')}"
    for stock in LITTER_STOCKS
}

POOL_MINERALISATION_FLOW_NAMES = {
    stock: f"litter_mineralisation_{stock.removeprefix('litter_pool_')}"
    for stock in LITTER_STOCKS
}

POOL_RESPIRATION_FLOW_NAMES = {
    stock: (
        f"litter_respiration_"
        f"{stock.removeprefix('litter_pool_').removesuffix('_cnp')}_c"
    )
    for stock in LITTER_STOCKS
}

OUTSIDE_LITTER_POOLS = "outside_litter_pools"
FLOW_CONNECTIONS = {
    "stem_turnover_cnp": (OUTSIDE_LITTER_POOLS, "litter_pool_woody_cnp"),
    **{
        flow_name: (
            OUTSIDE_LITTER_POOLS,
            f"litter_pool_{ground}_{pool_type}_cnp",
        )
        for input_name, (_, _, ground) in SPLIT_INPUTS.items()
        for flow_name, pool_type in zip(
            SPLIT_FLOW_NAMES[input_name],
            ("metabolic", "structural"),
            strict=True,
        )
    },
    **{
        flow_name: (stock, OUTSIDE_LITTER_POOLS)
        for flow_names in (
            POOL_MINERALISATION_FLOW_NAMES,
            POOL_RESPIRATION_FLOW_NAMES,
        )
        for stock, flow_name in flow_names.items()
    },
    "litter_consumed_above_metabolic_cnp": (
        "litter_pool_above_metabolic_cnp",
        OUTSIDE_LITTER_POOLS,
    ),
    "litter_consumed_above_structural_cnp": (
        "litter_pool_above_structural_cnp",
        OUTSIDE_LITTER_POOLS,
    ),
    "litter_consumed_woody_cnp": (
        "litter_pool_woody_cnp",
        OUTSIDE_LITTER_POOLS,
    ),
    "litter_consumed_below_metabolic_cnp": (
        "litter_pool_below_metabolic_cnp",
        OUTSIDE_LITTER_POOLS,
    ),
    "litter_consumed_below_structural_cnp": (
        "litter_pool_below_structural_cnp",
        OUTSIDE_LITTER_POOLS,
    ),
}


def _calculate_litter_decay_losses(
    stocks: xr.DataArray,
    flows: xr.DataArray,
    simulation_configuration: dict[str, Any],
    cell_area: float,
) -> tuple[xr.DataArray, xr.DataArray, xr.DataArray, xr.DataArray]:
    """Derive per-pool decay, mineralisation, and respiration from stock balances."""
    constants = simulation_configuration["litter"]["constants"]
    update_interval_days = float(
        Quantity(simulation_configuration["core"]["timing"]["update_interval"])
        .to("day")
        .magnitude
    )
    microbial_simulation_depth = simulation_configuration["core"]["constants"][
        "microbial_simulation_depth"
    ]

    pool_input_rates = {
        stock: xr.zeros_like(stocks.sel(stock=stock, drop=True))
        for stock in LITTER_STOCKS
    }
    pool_input_rates["litter_pool_woody_cnp"] += flows.sel(
        flow="stem_turnover_cnp", drop=True
    ) / (cell_area * update_interval_days)

    for input_name, (_, _, ground) in SPLIT_INPUTS.items():
        metabolic_flow_name, structural_flow_name = SPLIT_FLOW_NAMES[input_name]
        pool_input_rates[f"litter_pool_{ground}_metabolic_cnp"] += flows.sel(
            flow=metabolic_flow_name, drop=True
        ) / (cell_area * update_interval_days)
        pool_input_rates[f"litter_pool_{ground}_structural_cnp"] += flows.sel(
            flow=structural_flow_name, drop=True
        ) / (cell_area * update_interval_days)

    consumption_flows = dict(
        zip(
            LITTER_STOCKS,
            (
                "litter_consumed_above_metabolic_cnp",
                "litter_consumed_above_structural_cnp",
                "litter_consumed_woody_cnp",
                "litter_consumed_below_metabolic_cnp",
                "litter_consumed_below_structural_cnp",
            ),
            strict=True,
        )
    )
    decay_losses = xr.concat(
        [
            stocks.sel(stock=stock, drop=True).shift(time_index=1)
            + pool_input_rates[stock] * update_interval_days
            - flows.sel(flow=consumption_flows[stock], drop=True) / cell_area
            - stocks.sel(stock=stock, drop=True)
            for stock in LITTER_STOCKS
        ],
        dim=xr.IndexVariable("stock", LITTER_STOCKS),
    ).transpose("time_index", "stock", "element", "y", "x")
    decay_losses.attrs.update(
        unit="kg m^-2",
        description=(
            "Total carbon, nitrogen, and phosphorus lost from each litter pool "
            "by decay per update interval"
        ),
    )

    carbon_use_efficiencies = {
        "litter_pool_above_metabolic_cnp": constants["cue_metabolic"],
        "litter_pool_above_structural_cnp": constants["cue_structural_above_ground"],
        "litter_pool_woody_cnp": constants["cue_woody"],
        "litter_pool_below_metabolic_cnp": constants["cue_metabolic"],
        "litter_pool_below_structural_cnp": constants["cue_structural_below_ground"],
    }
    pool_mineralisation_rates = []
    pool_mineralisation_losses = []
    pool_respiration_losses = []
    for stock in LITTER_STOCKS:
        loss = decay_losses.sel(stock=stock, drop=True)
        carbon_loss = loss.sel(element="C", drop=True)
        carbon_mineralisation_loss = carbon_loss * carbon_use_efficiencies[stock]
        pool_mineralisation_losses.append(
            xr.concat(
                [
                    carbon_mineralisation_loss.expand_dims(element=["C"]),
                    loss.sel(element=["N", "P"]),
                ],
                dim="element",
            ).reindex(element=["C", "N", "P"])
        )
        pool_respiration_losses.append(
            (carbon_loss * (1 - carbon_use_efficiencies[stock])).expand_dims(
                element=["C"]
            )
        )
        carbon_rate = (
            carbon_mineralisation_loss
            / (update_interval_days * microbial_simulation_depth)
        ).expand_dims(element=["C"])
        nutrient_rates = loss.sel(element=["N", "P"]) / (
            update_interval_days * microbial_simulation_depth
        )
        pool_mineralisation_rates.append(
            xr.concat(
                [carbon_rate, nutrient_rates],
                dim="element",
            ).reindex(element=["C", "N", "P"])
        )

    mineralisation_rates = xr.concat(
        pool_mineralisation_rates,
        dim=xr.IndexVariable("pool", LITTER_STOCKS),
    ).transpose("time_index", "pool", "element", "y", "x")
    mineralisation_rates.attrs.update(
        unit="kg m^-3 day^-1",
        description="Per-pool carbon, nitrogen, and phosphorus mineralisation rates",
    )
    mineralisation_losses = xr.concat(
        pool_mineralisation_losses,
        dim=xr.IndexVariable("stock", LITTER_STOCKS),
    ).transpose("time_index", "stock", "element", "y", "x")
    mineralisation_losses.attrs.update(
        unit="kg m^-2",
        description=(
            "Per-pool mineralised carbon, nitrogen, and phosphorus per update interval"
        ),
    )
    respiration_losses = xr.concat(
        pool_respiration_losses,
        dim=xr.IndexVariable("stock", LITTER_STOCKS),
    ).transpose("time_index", "stock", "element", "y", "x")
    respiration_losses.attrs.update(
        unit="kg m^-2",
        description="Per-pool carbon sent to respiration per update interval",
    )
    return (
        decay_losses,
        mineralisation_rates,
        mineralisation_losses,
        respiration_losses,
    )


def load_litter_data(
    simulation_output: Path,
    simulation_configuration: dict[str, Any],
) -> xr.Dataset:
    """Load litter stocks, flows, and known direct stock-flow connections.

    Args:
        simulation_output: Directory containing the simulation's model_data.nc.
        simulation_configuration: Full compiled simulation configuration.

    Returns:
        An xarray Dataset containing the raw stocks and flows,
        ``litter_decay_losses``, pool-level mineralisation and respiration
        outflows, calculated rates, and differences from the recorded rates.
        ``stock_flow_effects`` contains mapped flows, and
        ``stocks_after_trivial_flows`` contains their partial stock balance.
        Effects at time ``t`` describe the transition from stock at ``t - 1``
        to stock at ``t``.

    Raises:
        ValueError: If a stock or flow variable or the timestamp is missing.

    """
    model_data_path = simulation_output / "model_data.nc"
    with (
        xr.open_dataset(model_data_path, group="outputs") as outputs,
        xr.open_dataset(model_data_path, group="init") as initial,
    ):
        missing_variables = [
            name for name in LITTER_STOCKS + FLOWS if name not in outputs
        ]
        for group, lignin_name, _ in SPLIT_INPUTS.values():
            data_group = initial if group == "init" else outputs
            if lignin_name not in data_group:
                missing_variables.append(f"{group}/{lignin_name}")
        if missing_variables:
            raise ValueError(
                "Simulation data is missing required litter variables: "
                f"{', '.join(missing_variables)}"
            )
        if "timestamp" not in outputs:
            raise ValueError("Output group is missing the timestamp variable.")

        cell_area = simulation_configuration["core"]["grid"]["cell_area"]
        if cell_area <= 0:
            raise ValueError(
                "Simulation configuration core.grid.cell_area must be positive."
            )
        litter_stocks = xr.concat(
            [outputs[stock] for stock in LITTER_STOCKS],
            dim=xr.IndexVariable("stock", LITTER_STOCKS),
        ).transpose("time_index", "stock", "element", "y", "x")
        litter_stocks = litter_stocks.assign_coords(
            stock_unit=(
                "stock",
                [outputs[name].attrs.get("unit") for name in LITTER_STOCKS],
            ),
            stock_description=(
                "stock",
                [outputs[name].attrs.get("description") for name in LITTER_STOCKS],
            ),
        )
        litter_stocks.attrs["description"] = (
            "Litter stock mass density by pool and element"
        )

        litter_constants = simulation_configuration["litter"]["constants"]
        split_flow_arrays = []
        split_flow_descriptions = []
        for input_name, (group, lignin_name, _) in SPLIT_INPUTS.items():
            input_flow = outputs[input_name]
            if "pft" in input_flow.dims:
                input_flow = input_flow.sum(dim="pft")
            data_group = initial if group == "init" else outputs
            lignin_proportion = data_group[lignin_name].broadcast_like(
                input_flow.sel(element="C", drop=True)
            )
            missing_nutrients = (input_flow.sel(element="N", drop=True) == 0) | (
                input_flow.sel(element="P", drop=True) == 0
            )
            lignin_proportion = lignin_proportion.where(
                ~missing_nutrients,
                other=1.0,
            )
            metabolic_fraction = split_pool_into_metabolic_and_structural_litter(
                input_masses=input_flow,
                lignin_proportion=lignin_proportion.to_numpy(),
                max_metabolic_fraction=litter_constants[
                    "max_metabolic_fraction_of_input"
                ],
                split_sensitivity_nitrogen=litter_constants[
                    "metabolic_split_nitrogen_sensitivity"
                ],
                split_sensitivity_phosphorus=litter_constants[
                    "metabolic_split_phosphorus_sensitivity"
                ],
            )
            carbon_flow = input_flow.sel(element="C", drop=True)
            metabolic_fraction = xr.DataArray(
                metabolic_fraction,
                dims=carbon_flow.dims,
                coords=carbon_flow.coords,
            )
            metabolic_elements = [
                (carbon_flow * metabolic_fraction).expand_dims(element=["C"])
            ]
            structural_elements = [
                (carbon_flow * (1 - metabolic_fraction)).expand_dims(element=["C"])
            ]
            for element, ratio_key in (
                ("N", "metabolic_to_structural_n_ratio"),
                ("P", "metabolic_to_structural_p_ratio"),
            ):
                metabolic_nutrient, structural_nutrient = (
                    find_nutrient_split_between_litter_pools(
                        input_carbon_rate=carbon_flow,
                        input_nutrient_rate=input_flow.sel(element=element, drop=True),
                        metabolic_split=metabolic_fraction,
                        meta_to_struct_nutrient_ratio=litter_constants[ratio_key],
                    )
                )
                metabolic_elements.append(
                    metabolic_nutrient.expand_dims(element=[element])
                )
                structural_elements.append(
                    structural_nutrient.expand_dims(element=[element])
                )
            split_flow_arrays.extend(
                [
                    xr.concat(metabolic_elements, dim="element").reindex(
                        element=["C", "N", "P"]
                    ),
                    xr.concat(structural_elements, dim="element").reindex(
                        element=["C", "N", "P"]
                    ),
                ]
            )
            split_flow_descriptions.extend(
                [
                    f"{input_name} allocated to metabolic litter",
                    f"{input_name} allocated to structural litter",
                ]
            )

        split_flow_names = [
            flow_name
            for flow_pair in SPLIT_FLOW_NAMES.values()
            for flow_name in flow_pair
        ]
        flow_names = [*FLOWS, *split_flow_names]
        flow_arrays = []
        for flow_name in FLOWS:
            flow = outputs[flow_name]
            if "pft" in flow.dims:
                flow = flow.sum(dim="pft")
            if "element" not in flow.dims:
                flow = flow.expand_dims(element=["C"])
            flow = flow.reindex(element=["C", "N", "P"])
            flow_arrays.append(flow)
        flow_arrays.extend(split_flow_arrays)

        litter_flows = xr.concat(
            flow_arrays,
            dim=xr.IndexVariable("flow", flow_names),
            coords="minimal",
            compat="override",
            join="exact",
        ).transpose("time_index", "flow", "element", "y", "x")
        (
            decay_losses,
            mineralisation_rates_by_pool,
            mineralisation_losses,
            respiration_losses,
        ) = _calculate_litter_decay_losses(
            stocks=litter_stocks,
            flows=litter_flows,
            simulation_configuration=simulation_configuration,
            cell_area=cell_area,
        )
        decay_flow_names = list(DECAY_LOSS_FLOW_NAMES.values())
        decay_flows = xr.concat(
            [decay_losses.sel(stock=stock, drop=True) for stock in LITTER_STOCKS],
            dim=xr.IndexVariable("flow", decay_flow_names),
        ).transpose("time_index", "flow", "element", "y", "x")
        mineralisation_flow_names = list(POOL_MINERALISATION_FLOW_NAMES.values())
        mineralisation_flows = xr.concat(
            [
                mineralisation_losses.sel(stock=stock, drop=True)
                for stock in LITTER_STOCKS
            ],
            dim=xr.IndexVariable("flow", mineralisation_flow_names),
        ).transpose("time_index", "flow", "element", "y", "x")
        respiration_flow_names = list(POOL_RESPIRATION_FLOW_NAMES.values())
        respiration_flows = xr.concat(
            [respiration_losses.sel(stock=stock, drop=True) for stock in LITTER_STOCKS],
            dim=xr.IndexVariable("flow", respiration_flow_names),
        ).transpose("time_index", "flow", "element", "y", "x")
        litter_flows = xr.concat(
            [
                litter_flows,
                decay_flows,
                mineralisation_flows,
                respiration_flows,
            ],
            dim="flow",
            join="outer",
        )
        flow_names.extend(
            [
                *decay_flow_names,
                *mineralisation_flow_names,
                *respiration_flow_names,
            ]
        )
        litter_flows = litter_flows.assign_coords(
            flow_unit=(
                "flow",
                [outputs[name].attrs.get("unit") for name in FLOWS]
                + [
                    outputs[input_name].attrs.get("unit")
                    for input_name in SPLIT_INPUTS
                    for _ in range(2)
                ]
                + ["kg m^-2"]
                * (
                    len(decay_flow_names)
                    + len(mineralisation_flow_names)
                    + len(respiration_flow_names)
                ),
            ),
            flow_description=(
                "flow",
                [outputs[name].attrs.get("description") for name in FLOWS]
                + split_flow_descriptions
                + [f"Total decay loss from {stock}" for stock in LITTER_STOCKS]
                + [f"Mineralised mass from {stock}" for stock in LITTER_STOCKS]
                + [f"Carbon respired from {stock}" for stock in LITTER_STOCKS],
            ),
        )
        litter_flows.attrs["description"] = "Litter flow by pool and element"

        mineralisation_rate_difference = (
            mineralisation_rates_by_pool.sum(dim="pool", skipna=False)
            - outputs["litter_mineralisation_rate_cnp"]
        )
        mineralisation_rate_difference.attrs.update(
            unit="kg m^-3 day^-1",
            description=(
                "Per-pool calculated mineralisation rates summed and compared "
                "with the simulation output (calculated minus recorded)"
            ),
        )
        update_interval_days = float(
            Quantity(simulation_configuration["core"]["timing"]["update_interval"])
            .to("day")
            .magnitude
        )
        respiration_rate_by_pool = (
            respiration_losses.sel(element="C", drop=True) / update_interval_days
        ).rename(stock="pool")
        respiration_rate_by_pool.attrs.update(
            unit="kg{C} m^-2 day^-1",
            description="Carbon respiration rate from each litter pool",
        )
        above_respiration_pools = [
            "litter_pool_above_metabolic_cnp",
            "litter_pool_above_structural_cnp",
            "litter_pool_woody_cnp",
        ]
        below_respiration_pools = [
            "litter_pool_below_metabolic_cnp",
            "litter_pool_below_structural_cnp",
        ]
        respiration_rate_by_ground = xr.concat(
            [
                respiration_rate_by_pool.sel(pool=above_respiration_pools).sum(
                    dim="pool", skipna=False
                ),
                respiration_rate_by_pool.sel(pool=below_respiration_pools).sum(
                    dim="pool", skipna=False
                ),
            ],
            dim=xr.IndexVariable("ground", ["above", "below"]),
        )
        respiration_rate_by_ground.attrs.update(
            unit="kg{C} m^-2 day^-1",
            description="Calculated aggregate litter respiration rate by ground layer",
        )
        recorded_respiration_by_ground = xr.concat(
            [
                outputs["above_ground_litter_respiration"],
                outputs["below_ground_litter_respiration"],
            ],
            dim=xr.IndexVariable("ground", ["above", "below"]),
        )
        respiration_rate_difference = (
            respiration_rate_by_ground - recorded_respiration_by_ground
        )
        respiration_rate_difference.attrs.update(
            unit="kg{C} m^-2 day^-1",
            description=("Calculated minus recorded aggregate litter respiration rate"),
        )
        dataset = xr.Dataset(
            {
                "stocks": litter_stocks,
                "flows": litter_flows,
                "litter_decay_losses": decay_losses,
                "litter_mineralisation_rate_by_pool": mineralisation_rates_by_pool,
                "litter_mineralisation_rate_difference": (
                    mineralisation_rate_difference
                ),
                "litter_mineralisation_losses": mineralisation_losses,
                "litter_respiration_losses": respiration_losses,
                "litter_respiration_rate_by_pool": respiration_rate_by_pool,
                "litter_respiration_rate_by_ground": respiration_rate_by_ground,
                "litter_respiration_rate_difference": respiration_rate_difference,
            },
            coords={"timestamp": outputs["timestamp"]},
        )

        connection_effects = []
        for flow_name, (source_pool, destination_pool) in FLOW_CONNECTIONS.items():
            flow = dataset["flows"].sel(flow=flow_name, drop=True)
            unit = str(dataset["flows"].coords["flow_unit"].sel(flow=flow_name).item())
            if unit == "kg":
                flow_density = flow / cell_area
            elif unit == "kg m^-2":
                flow_density = flow
            else:
                raise ValueError(
                    f"Cannot connect flow {flow_name!r} with unit {unit!r} "
                    "to litter stocks measured in kg m^-2."
                )

            stock_effects = []
            for stock_name in LITTER_STOCKS:
                if stock_name == source_pool:
                    stock_effect = -flow_density
                elif stock_name == destination_pool:
                    stock_effect = flow_density
                else:
                    stock_effect = xr.zeros_like(flow_density)
                stock_effects.append(stock_effect)

            connection_effects.append(
                xr.concat(
                    stock_effects,
                    dim=xr.IndexVariable("stock", LITTER_STOCKS),
                )
            )

        effects = xr.concat(
            connection_effects,
            dim=xr.IndexVariable("connection", list(FLOW_CONNECTIONS)),
        ).transpose("time_index", "connection", "stock", "element", "y", "x")
        effects = effects.assign_coords(
            source_pool=(
                "connection",
                [source for source, _ in FLOW_CONNECTIONS.values()],
            ),
            destination_pool=(
                "connection",
                [destination for _, destination in FLOW_CONNECTIONS.values()],
            ),
        )
        effects = effects.where(dataset["time_index"] != dataset["time_index"][0])
        effects.attrs["unit"] = "kg m^-2"
        effects.attrs["description"] = (
            "Signed stock effects from explicitly connected flows; positive "
            "values add to a pool and negative values remove from a pool"
        )

        partial_stocks = dataset["stocks"].shift(time_index=1) + effects.sum(
            dim="connection"
        )
        partial_stocks.attrs["unit"] = "kg m^-2"
        partial_stocks.attrs["description"] = (
            "Previous timestep's stock plus mapped flow effects only; not a "
            "complete stock balance"
        )
        dataset["stock_flow_effects"] = effects
        dataset["stocks_after_trivial_flows"] = partial_stocks

        return dataset.load()


def analyse_litter(
    simulation_output: Path,
    simulation_configuration: dict[str, Any],
) -> xr.Dataset:
    """Load and return litter stocks, flows, and direct stock-flow links.

    Args:
        simulation_output: Directory containing the simulation's model_data.nc.
        simulation_configuration: Full compiled simulation configuration.

    Returns:
        Litter data, per-pool decay losses and mineralisation rates, and partial
        stock effects from the known direct connections.

    """
    return load_litter_data(simulation_output, simulation_configuration)


def plot_expected_vs_actual_node_outflows(
    litter_data: xr.Dataset,
    cell_area: float,
    time_index: int = -1,
    node_name: str | None = None,
    output_path: Path | None = None,
) -> plt.Figure:
    """Plot expected and mapped actual outflows from litter-pool nodes.

    Expected total outflow is derived from the stock balance and recorded
    consumption. Mapped actual outflows are shown as stacked components.

    Args:
        litter_data: Dataset returned by :func:`analyse_litter`.
        cell_area: Area of one simulation grid cell in square metres.
        time_index: Index of the timestep to plot; defaults to the latest.
        node_name: Optional litter stock to plot; defaults to all litter stocks.
        output_path: Optional path to save the resulting figure.

    Returns:
        The Matplotlib figure.

    Raises:
        ValueError: If the cell area or timestep is invalid, or the selected
            timestep has no previous stock state.

    """
    number_of_timesteps = litter_data.sizes["time_index"]
    if cell_area <= 0:
        raise ValueError("cell_area must be positive.")
    if not -number_of_timesteps <= time_index < number_of_timesteps:
        raise ValueError(
            f"time_index {time_index} is outside the available timestep range."
        )
    if node_name is not None and node_name not in LITTER_STOCKS:
        raise ValueError(f"Unknown litter-pool node: {node_name!r}.")

    selected_flows = litter_data["flows"].isel(time_index=time_index)
    selected_decay_losses = litter_data["litter_decay_losses"].isel(
        time_index=time_index
    )
    if bool(selected_decay_losses.isnull().any().item()):
        raise ValueError(
            "Expected outflows are unavailable for this timestep because "
            "there is no previous stock state."
        )

    stocks_to_plot = [node_name] if node_name is not None else LITTER_STOCKS
    fig, axes = plt.subplots(
        nrows=len(stocks_to_plot),
        figsize=(12, 3.5 * len(stocks_to_plot)),
        sharex=True,
        squeeze=False,
    )
    elements = ["C", "N", "P"]
    x_positions = np.arange(len(elements))
    expected_x = x_positions - 0.2
    actual_x = x_positions + 0.2
    bar_width = 0.36

    for axis, stock in zip(axes[:, 0], stocks_to_plot, strict=True):
        outgoing_flows = [
            flow_name
            for flow_name, (source, _) in FLOW_CONNECTIONS.items()
            if source == stock
        ]
        if not outgoing_flows:
            raise ValueError(f"No mapped outflows are available for node {stock!r}.")

        consumption_flow = next(
            (
                flow_name
                for flow_name in outgoing_flows
                if flow_name.startswith("litter_consumed_")
            ),
            None,
        )
        if consumption_flow is None:
            raise ValueError(
                f"No consumption flow is mapped out of node {stock!r}, "
                "so expected total outflow cannot be calculated."
            )

        consumption = selected_flows.sel(flow=consumption_flow, drop=True)
        consumption_unit = str(
            litter_data["flows"].coords["flow_unit"].sel(flow=consumption_flow).item()
        )
        if consumption_unit == "kg":
            consumption = consumption / cell_area
        elif consumption_unit != "kg m^-2":
            raise ValueError(
                f"Cannot compare flow {consumption_flow!r} with unit "
                f"{consumption_unit!r} to litter stocks."
            )

        expected = (
            selected_decay_losses.sel(stock=stock, drop=True) + consumption
        ).sum(dim=("y", "x"), skipna=False) * cell_area
        axis.bar(
            expected_x,
            expected.sel(element=elements).to_numpy(),
            width=bar_width,
            label="Expected total",
            color="black",
        )

        actual_bottom = np.zeros(len(elements))
        for flow_name in outgoing_flows:
            flow = selected_flows.sel(flow=flow_name, drop=True)
            flow_unit = str(
                litter_data["flows"].coords["flow_unit"].sel(flow=flow_name).item()
            )
            if flow_unit == "kg":
                flow = flow / cell_area
            elif flow_unit != "kg m^-2":
                raise ValueError(
                    f"Cannot compare flow {flow_name!r} with unit {flow_unit!r} "
                    "to litter stocks."
                )
            flow_mass = (
                flow.fillna(0)
                .sum(dim=("y", "x"), skipna=False)
                .sel(element=elements)
                .to_numpy()
                * cell_area
            )
            axis.bar(
                actual_x,
                flow_mass,
                width=bar_width,
                bottom=actual_bottom,
                label=flow_name,
            )
            actual_bottom += flow_mass

        axis.set_title(stock)
        axis.set_ylabel("Outflow (kg)")
        axis.set_xticks(x_positions, elements)
        axis.legend(fontsize="small")

    timestamp = str(litter_data["timestamp"].isel(time_index=time_index).item())
    fig.suptitle(
        f"Expected and mapped actual litter-pool outflows\n"
        f"Time index {time_index}: {timestamp}"
    )
    fig.tight_layout()
    if output_path is not None:
        fig.savefig(output_path, dpi=160, bbox_inches="tight")

    return fig
