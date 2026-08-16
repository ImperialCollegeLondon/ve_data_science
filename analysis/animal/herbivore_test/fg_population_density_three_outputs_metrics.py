#' ---
#' title: Compare functional group population density across herbivore tests
#'
#' description: |
#'     Calculate functional group population density for three herbivore test
#'     simulations and combine the results for direct comparison.
#'
#'     Density can be calculated using either the total simulation area
#'     (landscape density) or the combined unique territory area associated
#'     with each functional group (territory density). A comparison summary
#'     reports trajectory-based metrics that can be derived from these outputs.
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
#'   - name: herbivore test comparison metrics
#'     path: user-defined
#'     description: |
#'         A CSV summary of initial, final, minimum, maximum, and shared-timestep
#'         population density metrics for comparison among the three tests.
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
from pathlib import Path

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
        raise TypeError("Territory values must be lists of grid-cell identifiers.")

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


def summarise_test_comparison(combined_df: pd.DataFrame) -> pd.DataFrame:
    """Summarise population-density metrics used to compare herbivore tests.

    The summary is based only on population trajectories available in the
    processed cohort outputs. It does not estimate survival rate, maturity,
    or reproduction directly.

    Args:
        combined_df: Combined density dataframe containing the ``test`` column.

    Returns:
        One row per test and functional group with trajectory-based comparison
        metrics, including initial and final density, density change, minimum
        and maximum density, peak timing, last observed timestep, and density
        at the last timestep shared by all tests for that functional group.

    Raises:
        ValueError: If required columns are missing or the dataframe is empty.

    """
    check_required_columns(
        dataframe=combined_df,
        required_columns={
            "test",
            "functional_group",
            "time_index",
            "total_individuals",
            "population_density",
        },
    )

    if combined_df.empty:
        raise ValueError("Combined density dataframe is empty.")

    summary_rows = []

    for functional_group, fg_data in combined_df.groupby("functional_group"):
        time_sets = [
            set(test_data["time_index"]) for _, test_data in fg_data.groupby("test")
        ]
        shared_times = set.intersection(*time_sets) if time_sets else set()
        last_shared_time = max(shared_times) if shared_times else None

        for test_name, test_data in fg_data.groupby("test"):
            test_data = test_data.sort_values("time_index").reset_index(drop=True)

            first_row = test_data.iloc[0]
            last_row = test_data.iloc[-1]
            peak_row = test_data.loc[test_data["population_density"].idxmax()]

            initial_density = first_row["population_density"]
            final_density = last_row["population_density"]
            density_change = final_density - initial_density

            if initial_density == 0:
                percent_density_change = pd.NA
            else:
                percent_density_change = (density_change / initial_density) * 100

            shared_density = pd.NA
            shared_individuals = pd.NA
            if last_shared_time is not None:
                shared_row = test_data.loc[test_data["time_index"] == last_shared_time]
                if not shared_row.empty:
                    shared_density = shared_row.iloc[0]["population_density"]
                    shared_individuals = shared_row.iloc[0]["total_individuals"]

            summary_rows.append(
                {
                    "test": test_name,
                    "functional_group": functional_group,
                    "n_time_steps": test_data["time_index"].nunique(),
                    "first_time_index": first_row["time_index"],
                    "last_time_index": last_row["time_index"],
                    "initial_individuals": first_row["total_individuals"],
                    "final_individuals": last_row["total_individuals"],
                    "initial_density": initial_density,
                    "final_density": final_density,
                    "absolute_density_change": density_change,
                    "percent_density_change": percent_density_change,
                    "minimum_density": test_data["population_density"].min(),
                    "maximum_density": test_data["population_density"].max(),
                    "peak_density_time_index": peak_row["time_index"],
                    "last_shared_time_index": last_shared_time,
                    "density_at_last_shared_time": shared_density,
                    "individuals_at_last_shared_time": shared_individuals,
                }
            )

    return (
        pd.DataFrame(summary_rows)
        .sort_values(["functional_group", "test"])
        .reset_index(drop=True)
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
    """Run population density analysis for three herbivore test outputs."""
    # Update path to match the location of your simulation outputs.

    data_dir = Path("path/to/herbivore_test")

    cohort_files = {
        "elephant": data_dir / "animal_cohort_data_elephant.csv",
        "kancil": data_dir / "animal_cohort_data_kancil.csv",
        "kancil_density": data_dir / "animal_cohort_data_kancil_density.csv",
    }

    # Grid settings shared by the three simulations.
    cell_size = 100
    n_cells_x = 10
    n_cells_y = 10

    # Population density settings.
    density_unit = "km2"
    density_scope = "landscape"

    all_density_data = []

    for test_name, cohort_file in cohort_files.items():
        print(f"\nProcessing: {test_name}")

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

        # Identify which simulation each row came from.
        density_df["test"] = test_name
        all_density_data.append(density_df)

        # Save one processed density table per simulation.
        output_csv = f"fg_population_density_{test_name}.csv"
        density_df.to_csv(output_csv, index=False)
        print(f"Density table saved to {output_csv}")

    # Combine the three processed outputs for direct comparison.
    combined_df = pd.concat(all_density_data, ignore_index=True)
    combined_output = "fg_population_density_three_outputs.csv"
    combined_df.to_csv(combined_output, index=False)

    print(f"\nCombined density table saved to {combined_output}")

    comparison_df = summarise_test_comparison(combined_df)
    comparison_output = "herbivore_test_comparison_metrics.csv"
    comparison_df.to_csv(comparison_output, index=False)

    print(f"Comparison metrics saved to {comparison_output}")
    print("\nComparison metrics:")
    print(comparison_df)

    # No plot is produced automatically here.
    # A single comparison plot can be generated later from combined_df.


if __name__ == "__main__":
    main()
