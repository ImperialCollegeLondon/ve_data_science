"""Tests for shared animal population utilities."""

import pandas as pd
import pytest
from ve_data_tools.animal_population_utils import (
    check_grid_dimensions,
    check_required_columns,
    get_area_conversion,
    get_unit_label,
    parse_territory_cells,
)


def test_check_required_columns():
    """Check that missing required columns raise an error."""
    dataframe = pd.DataFrame({"a": [1], "b": [2]})
    assert check_required_columns(dataframe, {"a", "b"}) is None

    with pytest.raises(ValueError, match=r"missing.*required columns: c"):
        check_required_columns(dataframe, {"a", "c"})


def test_check_required_columns_empty_dataframe():
    """Check required columns in a dataframe with no rows."""
    dataframe = pd.DataFrame(columns=["a", "b"])

    assert check_required_columns(dataframe, {"a", "b"}) is None

    with pytest.raises(ValueError, match=r"missing.*required columns: c"):
        check_required_columns(dataframe, {"a", "c"})


@pytest.mark.parametrize(
    ("unit", "expected"),
    [("m2", 1.0), ("ha", 10_000.0), ("km2", 1_000_000.0)],
)
def test_get_area_conversion(unit, expected):
    """Check that the correct area conversion factor is returned for each unit."""
    assert get_area_conversion(unit) == expected


def test_get_area_conversion_invalid():
    """Check that an invalid area unit raises an error."""
    with pytest.raises(ValueError, match="density_unit must be one of"):
        get_area_conversion("acres")


@pytest.mark.parametrize(
    ("unit", "expected"),
    [("m2", "m²"), ("ha", "ha"), ("km2", "km²")],
)
def test_get_unit_label(unit, expected):
    """Check that the correct unit label is returned for each unit."""
    assert get_unit_label(unit) == expected


def test_get_unit_label_invalid():
    """Check that an invalid unit label raises an error."""
    with pytest.raises(ValueError, match="density_unit must be one of"):
        get_unit_label("acres")


def test_check_grid_dimensions():
    """Check that the grid dimensions are correctly validated."""
    dataframe = pd.DataFrame({"centroid_key": [0, 1, 1, 2]})

    # 3 cells < 4 available: fewer cells used than exist
    assert check_grid_dimensions(dataframe, 2, 2) is None
    # 3 cells == 3 available: every cell used (boundary case)
    assert check_grid_dimensions(dataframe, 1, 3) is None

    # 3 cells > 2 available: more cells than the grid allows
    with pytest.raises(ValueError, match="3 unique"):
        check_grid_dimensions(dataframe, 1, 2)


def test_check_grid_dimensions_missing_column():
    """Check that a missing grid-cell column is handled gracefully."""
    dataframe = pd.DataFrame({"other_column": [0, 1, 2]})
    assert check_grid_dimensions(dataframe, 1, 1) is None


def test_check_grid_dimensions_custom_column():
    """Check that a custom grid-cell column is correctly validated."""
    dataframe = pd.DataFrame({"cell_id": [0, 1]})

    assert check_grid_dimensions(dataframe, 1, 2, grid_cell_column="cell_id") is None

    with pytest.raises(ValueError, match="'cell_id'"):
        check_grid_dimensions(dataframe, 1, 1, grid_cell_column="cell_id")


def test_check_grid_dimensions_empty_column():
    """Check that an empty grid-cell column is accepted."""
    dataframe = pd.DataFrame({"centroid_key": []})

    assert check_grid_dimensions(dataframe, 1, 2) is None


def test_check_grid_dimensions_zero_dimensions():
    """Check that a zero-sized grid cannot contain observed cells."""
    dataframe = pd.DataFrame({"centroid_key": [0, 1]})

    with pytest.raises(ValueError, match="2 unique"):
        check_grid_dimensions(dataframe, 0, 2)


def test_check_grid_dimensions_zero_dimensions_empty_data():
    """Check the current behaviour for zero dimensions with no observed cells."""
    dataframe = pd.DataFrame({"centroid_key": []})

    assert check_grid_dimensions(dataframe, 0, 2) is None


@pytest.mark.parametrize(
    "value",
    ["[1, 2, 2, 3]", [1, 2, 2, 3]],
)
def test_parse_territory_cells(value):
    """Check that territory cells are correctly parsed into a set."""
    assert parse_territory_cells(value) == {1, 2, 3}


def test_parse_territory_cells_invalid_string():
    """Check that an invalid string raises a ValueError."""
    with pytest.raises(ValueError, match="could not be interpreted as a list"):
        parse_territory_cells("not a list")


def test_parse_territory_cells_wrong_type():
    """Check that a non-list type raises a TypeError."""
    with pytest.raises(TypeError, match="Territory values must be lists"):
        parse_territory_cells(123)

    with pytest.raises(TypeError, match="Territory values must be lists"):
        parse_territory_cells("(1, 2)")
