"""
---

title: Animal Population Utilities.

description: |
  Shared validation and conversion helpers for animal population
  workflows, including required-column checks, density-unit
  conversion, grid-size validation, and territory parsing.

virtual_ecosystem_module:
  - Animal

author:
  - Siti Nor Baizurah 

status: wip

package_dependencies:
  - pandas

usage_notes: |
  Import these helpers in animal population processing scripts to
  validate input data and maintain consistent grid and unit handling.

---
"""

import ast

import pandas as pd


def check_required_columns(
    dataframe: pd.DataFrame,
    required_columns: set[str],
) -> None:
    """Check that a dataframe contains all required columns.

    Args:
        dataframe: Input dataframe to validate.
        required_columns: Set of required column names.

    Raises:
        ValueError: If any required columns are missing.
    """
    missing_columns = required_columns - set(dataframe.columns)
    if missing_columns:
        missing_text = ", ".join(sorted(missing_columns))
        raise ValueError(
            "Input dataframe is missing the following required columns: "
            f"{missing_text}"
        )


def get_area_conversion(density_unit: str) -> float:
    """Return the number of square metres in the selected area unit.

    Args:
        density_unit: Area unit label. One of "m2", "ha", or "km2".

    Returns:
        Number of square metres represented by the supplied unit.

    Raises:
        ValueError: If the density unit is unsupported.
    """
    area_conversions = {
        "m2": 1.0,
        "ha": 10_000.0,
        "km2": 1_000_000.0,
    }
    if density_unit not in area_conversions:
        raise ValueError(
            "density_unit must be one of: 'm2', 'ha', or 'km2'."
        )
    return area_conversions[density_unit]


def get_unit_label(density_unit: str) -> str:
    """Return the display label for the selected area unit.

    Args:
        density_unit: Area unit label. One of "m2", "ha", or "km2".

    Returns:
        Human-readable display label for the unit.

    Raises:
        ValueError: If the density unit is unsupported.
    """
    unit_labels = {
        "m2": "m²",
        "ha": "ha",
        "km2": "km²",
    }
    if density_unit not in unit_labels:
        raise ValueError(
            "density_unit must be one of: 'm2', 'ha', or 'km2'."
        )
    return unit_labels[density_unit]


def check_grid_dimensions(
    cohort_df: pd.DataFrame,
    n_cells_x: int,
    n_cells_y: int,
    grid_cell_column: str = "centroid_key",
) -> None:
    """Check that observed grid-cell identifiers fit the supplied grid.

    Args:
        cohort_df: Dataframe containing cell identifiers.
        n_cells_x: Number of grid cells in the x direction.
        n_cells_y: Number of grid cells in the y direction.
        grid_cell_column: Name of the cell-identifier column.

    Raises:
        ValueError: If the observed number of unique cells exceeds the
            expected grid size.
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


def parse_territory_cells(
    territory_value: str | list[int],
) -> set[int]:
    """Convert a territory value into unique grid-cell identifiers.

    Args:
        territory_value: A string representation of a list of grid cells or
            a list of integer cell identifiers.

    Returns:
        A set of unique grid-cell identifiers.

    Raises:
        ValueError: If the supplied string cannot be interpreted as a list.
        TypeError: If the value is neither a string nor a list.
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
        raise TypeError(
            "Territory values must be lists of grid-cell identifiers."
        )

    return set(territory_value)