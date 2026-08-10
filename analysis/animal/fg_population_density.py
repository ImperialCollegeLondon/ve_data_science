#' ---
#' title: Calculate functional group population density over time
#'
#' description: |
#'     Calculate the total number of individuals in each functional group at
#'     every simulation time step and estimate population density over time.
#'
#'     Density can be calculated using either the total simulation area
#'     (landscape density) or the combined unique territory area associated
#'     with each functional group (territory density).
#'
#' VE_module: Animal
#'
#' author:
#'   - name: Siti Nor Baizurah
#'
#' status: wip
#'
#' input_files:
#'   - name: animal_cohort_data.csv
#'     path: user-defined
#'     description: |
#'         Cohort-level output from a Virtual Ecosystem animal simulation.
#'         The file must contain time_index, functional_group, and individuals.
#'         Territory density additionally requires the territory column.
#'
#' output_files:
#'   - name: functional group population density table
#'     path: user-defined
#'     description: |
#'         A CSV file containing total individuals, area used, and population
#'         density for each functional group at every simulation time step.
#'
#' package_dependencies:
#'   - pandas
#'   - matplotlib
#'
#' usage_notes: |
#'     The user must provide the grid cell size and the number of grid cells
#'     in the x and y directions for the simulation being analysed.
#'
#'     Population density can use either the total simulation area
#'     ("landscape") or the combined unique territory area occupied by each
#'     functional group ("territory"). Overlapping territory cells are counted
#'     only once within each functional group and time step.
#'
#'     Density can be reported as individuals per square metre ("m2"),
#'     hectare ("ha"), or square kilometre ("km2").
#' ---

import ast

import matplotlib.pyplot as plt
import pandas as pd


def check_required_columns(
    dataframe: pd.DataFrame,
    required_columns: set[str],
) -> None:
    """Check that a dataframe contains all required columns.

    Args:
        dataframe: Dataframe to check.
        required_columns: Column names required by the analysis.

    Raises:
        ValueError: If one or more required columns are missing.

    """
    missing_columns = required_columns - set(dataframe.columns)

    if missing_columns:
        missing_text = ", ".join(sorted(missing_columns))
        raise ValueError(
            f"Input dataframe is missing the following required columns: {missing_text}"
        )


def get_area_conversion(density_unit: str) -> float:
    """Return the number of square metres in the selected area unit.

    Args:
        density_unit: Output area unit. Accepted values are "m2", "ha",
            and "km2".

    Returns:
        Number of square metres in the selected area unit.

    Raises:
        ValueError: If density_unit is unsupported.

    """
    area_conversions = {
        "m2": 1.0,
        "ha": 10_000.0,
        "km2": 1_000_000.0,
    }

    if density_unit not in area_conversions:
        raise ValueError("density_unit must be one of: 'm2', 'ha', or 'km2'.")

    return area_conversions[density_unit]


def get_unit_label(density_unit: str) -> str:
    """Return the display label for the selected area unit."""
    unit_labels = {
        "m2": "m²",
        "ha": "ha",
        "km2": "km²",
    }

    if density_unit not in unit_labels:
        raise ValueError("density_unit must be one of: 'm2', 'ha', or 'km2'.")

    return unit_labels[density_unit]


def check_grid_dimensions(
    cohort_df: pd.DataFrame,
    n_cells_x: int,
    n_cells_y: int,
    grid_cell_column: str = "centroid_key",
) -> None:
    """Check that observed grid-cell identifiers fit the supplied grid.

    This check only tests whether the cohort output contains more unique grid
    cells than the user-defined grid can hold. Fewer observed cells are valid
    because animal cohorts may occupy only part of the simulation grid.

    Args:
        cohort_df: Cohort-level animal dataframe.
        n_cells_x: Number of grid cells in the x direction.
        n_cells_y: Number of grid cells in the y direction.
        grid_cell_column: Column containing grid-cell identifiers. The check
            is skipped when this column is absent.

    Raises:
        ValueError: If the number of observed grid cells exceeds the supplied
            grid dimensions.

    """
    if grid_cell_column not in cohort_df.columns:
        return

    n_cells_observed = cohort_df[grid_cell_column].nunique()
    n_cells_expected = n_cells_x * n_cells_y

    if n_cells_observed > n_cells_expected:
        raise ValueError(
            f"The data contains {n_cells_observed} unique "
            f"'{grid_cell_column}' values, but n_cells_x * n_cells_y = "
            f"{n_cells_expected}. Check that n_cells_x and n_cells_y match "
            "the simulation that produced this data."
        )


def parse_territory_cells(territory_value: object) -> set[int]:
    """Convert a territory value into unique grid-cell identifiers.

    Args:
        territory_value: Territory stored as a list or as the string
            representation of a list.

    Returns:
        Unique territory grid-cell identifiers.

    Raises:
        ValueError: If the territory value cannot be interpreted as a list.

    """
    if isinstance(territory_value, str):
        try:
            territory_value = ast.literal_eval(territory_value)
        except (ValueError, SyntaxError) as error:
            raise ValueError(
                "A territory value could not be interpreted as a list: "
                f"{territory_value}"
            ) from error

    if not isinstance(territory_value, list):
        raise ValueError("Territory values must be lists of grid-cell identifiers.")

    return set(territory_value)


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

    """
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


def main() -> None:
    """Run the functional group population density analysis."""
    # Path to the cohort-level animal output CSV.
    cohort_file = "tools/python/testing_data/animal_cohort_data_tool_test.csv"

    # Grid settings for the simulation being analysed.
    cell_size = 100
    n_cells_x = 10
    n_cells_y = 10

    # Population density settings.
    density_unit = "km2"
    density_scope = "landscape"

    # Output file names. Set to None to skip saving.
    output_csv = "fg_population_density_output.csv"

    cohort_df = pd.read_csv(cohort_file)

    density_df = calculate_fg_population_density(
        cohort_df=cohort_df,
        cell_size=cell_size,
        n_cells_x=n_cells_x,
        n_cells_y=n_cells_y,
        density_unit=density_unit,
        density_scope=density_scope,
        territory_column="territory",
    )

    print(density_df.head())

    if output_csv is not None:
        density_df.to_csv(output_csv, index=False)
        print(f"Density table saved to {output_csv}")

if __name__ == "__main__":
    main()
