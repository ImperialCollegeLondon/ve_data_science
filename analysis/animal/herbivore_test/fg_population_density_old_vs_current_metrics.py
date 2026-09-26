"""
---
title: Compare old and current herbivore outputs

description: |
  Compare old and current Virtual Ecosystem animal-module outputs for two
  representative herbivore tests used in Maliau Level 1: Elephant as a
  slow-growing reference and Kancil as a faster-growing case.

  Population-density and body-mass trajectories are compared to assess
  changes in model output following recent animal-module mass-transfer fixes.

virtual_ecosystem_module:
  - Animal

author:
  - name: Siti Nor Baizurah

status: wip

input_files:
  - name: animal_cohort_data_elephant_old.csv
    path: user-defined
  - name: animal_cohort_data_elephant_current.csv
    path: user-defined
  - name: animal_cohort_data_kancil_old.csv
    path: user-defined
  - name: animal_cohort_data_kancil_current.csv
    path: user-defined

output_files:
  - name: herbivore_old_current_trajectories.csv
    path: user-defined
  - name: herbivore_old_current_summary.csv
    path: user-defined
  - name: herbivore_slow_fast_summary.csv
    path: user-defined
  - name: elephant_old_current_comparison.png
    path: user-defined
  - name: kancil_old_current_comparison.png
    path: user-defined

package_dependencies:
  - pandas
  - matplotlib
  - ve_data_tools

usage_notes: |
  The cohort exporter records both the initial state and the first updated
  state at time_index 0. The initial state is used for initialisation, while
  the updated state is used for the trajectory.

  Population density is calculated using
  ve_data_tools.fg_population_density.

  Old and current runs are compared over their shared time period. Elephant
  and Kancil are also compared over the time period shared by all four runs.

  The runs differ in VE version and configuration, so the comparison does not
  isolate a single code change.
---
"""

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
from ve_data_tools.fg_population_density import (
    calculate_fg_population_density,
    check_required_columns,
)


REQUIRED_COLUMNS = {
    "cohort_id",
    "time",
    "time_index",
    "age",
    "functional_group",
    "individuals",
    "mass_carbon",
    "mass_nitrogen",
    "mass_phosphorus",
}


def prepare_states(
    cohort_df: pd.DataFrame,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Return initial and trajectory cohort states."""
    check_required_columns(
        dataframe=cohort_df,
        required_columns=REQUIRED_COLUMNS,
    )

    initial = (
        cohort_df.loc[cohort_df["time_index"] == 0]
        .sort_values(["cohort_id", "age"])
        .drop_duplicates("cohort_id", keep="first")
        .reset_index(drop=True)
    )

    later = cohort_df.loc[cohort_df["time_index"] > 0]
    if later.duplicated(["cohort_id", "time_index"]).any():
        raise ValueError("Unexpected duplicate cohort states after time_index 0.")

    trajectory = (
        cohort_df.sort_values(["cohort_id", "time_index", "age"])
        .drop_duplicates(["cohort_id", "time_index"], keep="last")
        .reset_index(drop=True)
    )

    return initial, trajectory


def calculate_metrics(
    cohort_df: pd.DataFrame,
    test: str,
    version: str,
    cell_size: float,
    n_cells_x: int,
    n_cells_y: int,
) -> pd.DataFrame:
    """Calculate population density and mean body mass."""
    density = calculate_fg_population_density(
        cohort_df=cohort_df,
        cell_size=cell_size,
        n_cells_x=n_cells_x,
        n_cells_y=n_cells_y,
        density_unit="km2",
        density_scope="landscape",
    )

    mass = cohort_df.copy()
    mass["individual_body_mass"] = (
        mass["mass_carbon"]
        + mass["mass_nitrogen"]
        + mass["mass_phosphorus"]
    )
    mass["population_body_mass"] = (
        mass["individual_body_mass"] * mass["individuals"]
    )

    mass = (
        mass.groupby(["time_index", "functional_group"], as_index=False)
        .agg(
            total_individuals=("individuals", "sum"),
            total_population_body_mass=("population_body_mass", "sum"),
        )
    )
    mass["mean_individual_body_mass"] = (
        mass["total_population_body_mass"] / mass["total_individuals"]
    )

    times = cohort_df[["time_index", "time"]].drop_duplicates()
    if times.duplicated("time_index").any():
        raise ValueError("A time index maps to more than one simulation date.")

    result = (
        density.merge(
            mass[
                [
                    "time_index",
                    "functional_group",
                    "mean_individual_body_mass",
                ]
            ],
            on=["time_index", "functional_group"],
        )
        .merge(times, on="time_index")
    )
    result["test"] = test
    result["version"] = version

    return result[
        [
            "test",
            "version",
            "time",
            "time_index",
            "functional_group",
            "total_individuals",
            "population_density",
            "mean_individual_body_mass",
        ]
    ]


def process_run(
    cohort_df: pd.DataFrame,
    test: str,
    version: str,
    cell_size: float,
    n_cells_x: int,
    n_cells_y: int,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Prepare one run and calculate its metrics."""
    initial, trajectory = prepare_states(cohort_df)

    settings = {
        "test": test,
        "version": version,
        "cell_size": cell_size,
        "n_cells_x": n_cells_x,
        "n_cells_y": n_cells_y,
    }

    return (
        calculate_metrics(initial, **settings),
        calculate_metrics(trajectory, **settings),
    )


def percent_change(start: float, end: float) -> float:
    """Return percentage change from a starting value."""
    return float("nan") if start == 0 else ((end - start) / start) * 100


def build_old_current_summary(
    trajectories: pd.DataFrame,
    initialisation: pd.DataFrame,
) -> pd.DataFrame:
    """Summarise old-versus-current changes for each herbivore test."""
    rows = []

    for test, data in trajectories.groupby("test"):
        old = data.loc[data["version"] == "old"]
        current = data.loc[data["version"] == "current"]

        if old.empty or current.empty:
            raise ValueError(f"{test} requires both old and current outputs.")

        shared_dates = sorted(set(old["time"]) & set(current["time"]))
        if not shared_dates:
            raise ValueError(f"No shared simulation dates found for {test}.")

        shared_end = shared_dates[-1]
        old_end = old.loc[old["time"] == shared_end].iloc[0]
        current_end = current.loc[current["time"] == shared_end].iloc[0]

        old_init = initialisation.loc[
            (initialisation["test"] == test)
            & (initialisation["version"] == "old")
        ].iloc[0]
        current_init = initialisation.loc[
            (initialisation["test"] == test)
            & (initialisation["version"] == "current")
        ].iloc[0]

        rows.append(
            {
                "test": test,
                "last_shared_date": shared_end,
                "old_initial_density": old_init["population_density"],
                "current_initial_density": current_init["population_density"],
                "old_density_at_shared_end": old_end["population_density"],
                "current_density_at_shared_end": current_end["population_density"],
                "current_vs_old_density_percent": percent_change(
                    old_end["population_density"],
                    current_end["population_density"],
                ),
                "old_initial_body_mass": old_init["mean_individual_body_mass"],
                "current_initial_body_mass": current_init[
                    "mean_individual_body_mass"
                ],
                "old_body_mass_at_shared_end": old_end[
                    "mean_individual_body_mass"
                ],
                "current_body_mass_at_shared_end": current_end[
                    "mean_individual_body_mass"
                ],
                "current_vs_old_body_mass_percent": percent_change(
                    old_end["mean_individual_body_mass"],
                    current_end["mean_individual_body_mass"],
                ),
                "old_last_time_index": int(old["time_index"].max()),
                "current_last_time_index": int(current["time_index"].max()),
            }
        )

    return pd.DataFrame(rows).sort_values("test").reset_index(drop=True)


def build_slow_fast_summary(trajectories: pd.DataFrame) -> pd.DataFrame:
    """Compare slow- and fast-growing cases over one common time period."""
    common_dates = set.intersection(
        *[
            set(group["time"])
            for _, group in trajectories.groupby(["test", "version"])
        ]
    )
    if not common_dates:
        raise ValueError("No simulation dates are shared by all four runs.")

    first_date = min(common_dates)
    last_date = max(common_dates)
    rows = []

    for (test, version), data in trajectories.groupby(["test", "version"]):
        data = data.loc[data["time"].isin(common_dates)].sort_values("time")
        start = data.loc[data["time"] == first_date].iloc[0]
        end = data.loc[data["time"] == last_date].iloc[0]

        rows.append(
            {
                "test": test,
                "version": version,
                "comparison_start": first_date,
                "comparison_end": last_date,
                "start_density": start["population_density"],
                "end_density": end["population_density"],
                "density_change_over_common_period_percent": percent_change(
                    start["population_density"],
                    end["population_density"],
                ),
                "start_body_mass": start["mean_individual_body_mass"],
                "end_body_mass": end["mean_individual_body_mass"],
                "body_mass_change_over_common_period_percent": percent_change(
                    start["mean_individual_body_mass"],
                    end["mean_individual_body_mass"],
                ),
            }
        )

    return (
        pd.DataFrame(rows)
        .sort_values(["version", "test"])
        .reset_index(drop=True)
    )


def plot_comparison(test_data: pd.DataFrame, output_path: Path) -> None:
    """Plot old and current density and body-mass trajectories."""
    old = test_data.loc[test_data["version"] == "old"]
    current = test_data.loc[test_data["version"] == "current"]
    shared_dates = set(old["time"]) & set(current["time"])
    shared = test_data.loc[test_data["time"].isin(shared_dates)].copy()

    figure, axes = plt.subplots(2, 1, figsize=(9, 8), sharex=True)

    for version, data in shared.groupby("version"):
        data = data.sort_values("time_index")
        axes[0].plot(
            data["time_index"],
            data["population_density"],
            label=version,
        )
        axes[1].plot(
            data["time_index"],
            data["mean_individual_body_mass"],
            label=version,
        )

    density = shared["population_density"]
    if (density > 0).all() and density.max() / density.min() >= 100:
        axes[0].set_yscale("log")

    label = str(test_data["test"].iloc[0]).capitalize()
    axes[0].set_ylabel("Population density (individuals/km²)")
    axes[0].set_title("Population density")
    axes[0].legend(title="Output")
    axes[1].set_xlabel("Time index")
    axes[1].set_ylabel("Mean individual body mass")
    axes[1].set_title("Body mass")
    axes[1].legend(title="Output")
    figure.suptitle(f"{label}: old vs current output")
    figure.tight_layout()
    figure.savefig(output_path, dpi=150)
    plt.close(figure)


def main() -> None:
    """Run the Task 1 herbivore comparison."""
    data_dir = Path("path/to/herbivore_test")
    output_dir = data_dir / "old_current_comparison"

    cohort_files = {
        ("elephant", "old"): data_dir / "animal_cohort_data_elephant_old.csv",
        ("elephant", "current"): data_dir / "animal_cohort_data_elephant_current.csv",
        ("kancil", "old"): data_dir / "animal_cohort_data_kancil_old.csv",
        ("kancil", "current"): data_dir / "animal_cohort_data_kancil_current.csv",
    }
    grid = {"cell_size": 100, "n_cells_x": 10, "n_cells_y": 10}

    output_dir.mkdir(parents=True, exist_ok=True)
    initial_tables = []
    trajectory_tables = []

    for (test, version), cohort_file in cohort_files.items():
        initial, trajectory = process_run(
            pd.read_csv(cohort_file),
            test,
            version,
            **grid,
        )
        initial_tables.append(initial)
        trajectory_tables.append(trajectory)

    initialisation = pd.concat(initial_tables, ignore_index=True)
    trajectories = pd.concat(trajectory_tables, ignore_index=True)

    outputs = {
        "herbivore_old_current_trajectories.csv": trajectories,
        "herbivore_old_current_summary.csv": build_old_current_summary(
            trajectories,
            initialisation,
        ),
        "herbivore_slow_fast_summary.csv": build_slow_fast_summary(trajectories),
    }

    for filename, dataframe in outputs.items():
        dataframe.to_csv(output_dir / filename, index=False)

    for test, data in trajectories.groupby("test"):
        plot_comparison(
            data,
            output_dir / f"{test}_old_current_comparison.png",
        )


if __name__ == "__main__":
    main()
