"""title: Calculate functional group population density over time.

description: |
  Calculate functional group population density from Virtual Ecosystem
  animal cohort output.

virtual_ecosystem_module:
  - Animal

author:
  - Siti Nor Baizurah

status: wip

input_files:
  - name: animal_cohort_data.csv
    path: user-defined
    description: |
      Cohort-level animal output containing time_index,
      functional_group, and individuals.

output_files:
  - name: Functional group population density table
    path: user-defined
    description: |
      Population density by functional group and timestep.

package_dependencies:
  - pandas
  - matplotlib

usage_notes: |
  Load the cohort dataframe separately and pass it to the calculation
  and plotting functions. Requires the
  ve_data_tools.animal_population_utils module.
"""

import matplotlib.pyplot as plt
import pandas as pd
from ve_data_tools.animal_population_utils import (
    check_grid_dimensions,
    check_required_columns,
    get_area_conversion,
    get_unit_label,
    parse_territory_cells,
)


def calculate_fg_population_density(
    cohort_df: pd.DataFrame,
    cell_size: float,
    n_cells_x: int,
    n_cells_y: int,
    density_unit: str = "km2",
    density_scope: str = "landscape",
    territory_column: str = "territory",
) -> pd.DataFrame:
    """Calculate functional group population density over time.

    The number of individuals is summed for each functional group at each
    simulation time step. Density is then calculated using either the total
    simulation area or the combined unique territory area associated with the
    functional group.

    Args:
        cohort_df: Cohort-level animal dataframe containing time_index,
            functional_group, and individuals.
        cell_size: Length of one side of a square grid cell in metres.
        n_cells_x: Number of grid cells in the x direction.
        n_cells_y: Number of grid cells in the y direction.
        density_unit: Unit used to report population density. Accepted values
            are "m2", "ha", and "km2".
        density_scope: Area used to calculate population density. Accepted
            values are "landscape" and "territory".
        territory_column: Column containing territory grid-cell lists.

    Returns:
        Total individuals, area used, and population density for each
        functional group at each simulation time step.

    Raises:
        ValueError: If required columns are missing or settings are invalid.
        TypeError: If a territory value is not a list of grid-cell
            identifiers (territory scope only).

    """
    # TODO: Add validation output naming once the species-to-FG mapping
    # and the need for complexity_level are agreed.

    if density_scope not in {"landscape", "territory"}:
        raise ValueError("density_scope must be either 'landscape' or 'territory'.")

    required_columns = {
        "time_index",
        "functional_group",
        "individuals",
    }

    if density_scope == "territory":
        required_columns.add(territory_column)

    check_required_columns(
        dataframe=cohort_df,
        required_columns=required_columns,
    )

    if cohort_df.empty:
        raise ValueError("Input dataframe is empty.")

    if cohort_df[["time_index", "functional_group"]].isna().any().any():
        raise ValueError(
            "The time_index and functional_group columns must not contain "
            "missing values."
        )

    if cell_size <= 0:
        raise ValueError("cell_size must be greater than zero.")

    if n_cells_x <= 0:
        raise ValueError("n_cells_x must be greater than zero.")

    if n_cells_y <= 0:
        raise ValueError("n_cells_y must be greater than zero.")

    if cohort_df["individuals"].isna().any():
        raise ValueError("The individuals column contains missing values.")

    if (cohort_df["individuals"] < 0).any():
        raise ValueError("The individuals column contains negative values.")

    area_conversion = get_area_conversion(density_unit)

    check_grid_dimensions(
        cohort_df=cohort_df,
        n_cells_x=n_cells_x,
        n_cells_y=n_cells_y,
    )

    density_df = (
        cohort_df.groupby(
            ["time_index", "functional_group"],
            as_index=False,
        )["individuals"]
        .sum()
        .rename(columns={"individuals": "total_individuals"})
    )

    cell_area_m2 = cell_size**2

    if density_scope == "landscape":
        density_df["area_m2"] = cell_area_m2 * n_cells_x * n_cells_y

    else:
        territory_df = cohort_df.copy()
        territory_df["_territory_cells"] = territory_df[territory_column].apply(
            parse_territory_cells
        )

        territory_cells_df = (
            territory_df.groupby(["time_index", "functional_group"])["_territory_cells"]
            .apply(lambda territories: len(set().union(*territories)))
            .reset_index(name="territory_cells")
        )

        density_df = density_df.merge(
            territory_cells_df,
            on=["time_index", "functional_group"],
            how="left",
        )

        density_df["area_m2"] = density_df["territory_cells"] * cell_area_m2

        zero_area_groups = density_df.loc[
            density_df["territory_cells"] == 0,
            ["time_index", "functional_group"],
        ]

        if not zero_area_groups.empty:
            affected_groups = "; ".join(
                f"time_index={row.time_index}, functional_group={row.functional_group}"
                for row in zero_area_groups.itertuples(index=False)
            )
            raise ValueError(
                "Territory density cannot be calculated because no territory "
                f"cells were found for: {affected_groups}."
            )

    area_in_selected_unit = density_df["area_m2"] / area_conversion
    density_df["population_density"] = (
        density_df["total_individuals"] / area_in_selected_unit
    )

    density_df["density_scope"] = density_scope
    density_df["density_unit"] = density_unit

    return density_df.sort_values(["functional_group", "time_index"]).reset_index(
        drop=True
    )


def plot_fg_population_density(
    density_df: pd.DataFrame,
    density_unit: str = "km2",
    density_scope: str = "landscape",
    output_path: str | None = None,
) -> None:
    """Plot functional group population density over time.

    Args:
        density_df: Dataframe returned by calculate_fg_population_density.
        density_unit: Unit used to display density. Accepted values are "m2",
            "ha", and "km2".
        density_scope: Area used to calculate density. Accepted values are
            "landscape" and "territory".
        output_path: Save the figure to this path when provided.

    Raises:
        ValueError: If required columns are missing, the dataframe is empty,
            or settings are invalid.

    """
    if density_scope not in {"landscape", "territory"}:
        raise ValueError("density_scope must be either 'landscape' or 'territory'.")

    unit_label = get_unit_label(density_unit)

    check_required_columns(
        dataframe=density_df,
        required_columns={
            "time_index",
            "functional_group",
            "population_density",
        },
    )

    if density_df.empty:
        raise ValueError("Density dataframe is empty.")

    figure, axis = plt.subplots()

    for functional_group, group_data in density_df.groupby("functional_group"):
        group_data = group_data.sort_values("time_index")
        axis.plot(
            group_data["time_index"],
            group_data["population_density"],
            label=functional_group,
        )

    scope_labels = {
        "landscape": "Landscape",
        "territory": "Territory",
    }

    axis.set_xlabel("Time step")
    axis.set_ylabel(f"Population density (individuals/{unit_label})")
    axis.set_title(
        f"{scope_labels[density_scope]} functional group population density over time"
    )
    axis.legend()

    figure.tight_layout()

    if output_path is not None:
        figure.savefig(output_path, dpi=150)
        print(f"Plot saved to {output_path}")

    plt.show()
