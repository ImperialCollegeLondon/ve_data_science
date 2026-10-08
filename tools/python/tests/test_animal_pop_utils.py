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
    dataframe = pd.DataFrame({"a": [1], "b": [2]})
    assert check_required_columns(dataframe, {"a", "b"}) is None

    with pytest.raises(ValueError, match="missing.*required columns: c"):
        check_required_columns(dataframe, {"a", "c"})


@pytest.mark.parametrize(
    ("unit", "expected"),
    [("m2", 1.0), ("ha", 10_000.0), ("km2", 1_000_000.0)],
)
def test_get_area_conversion(unit, expected):
    assert get_area_conversion(unit) == expected


def test_get_area_conversion_invalid():
    with pytest.raises(ValueError, match="density_unit must be one of"):
        get_area_conversion("acres")


@pytest.mark.parametrize(
    ("unit", "expected"),
    [("m2", "m²"), ("ha", "ha"), ("km2", "km²")],
)
def test_get_unit_label(unit, expected):
    assert get_unit_label(unit) == expected


def test_get_unit_label_invalid():
    with pytest.raises(ValueError, match="density_unit must be one of"):
        get_unit_label("acres")


def test_check_grid_dimensions():
    dataframe = pd.DataFrame({"centroid_key": [0, 1, 1, 2]})
    assert check_grid_dimensions(dataframe, 2, 2) is None

    with pytest.raises(ValueError, match="3 unique"):
        check_grid_dimensions(dataframe, 1, 2)


def test_check_grid_dimensions_missing_column():
    dataframe = pd.DataFrame({"other_column": [0, 1, 2]})
    assert check_grid_dimensions(dataframe, 1, 1) is None


def test_check_grid_dimensions_custom_column():
    dataframe = pd.DataFrame({"cell_id": [0, 1]})

    assert check_grid_dimensions(
        dataframe, 1, 2, grid_cell_column="cell_id"
    ) is None

    with pytest.raises(ValueError, match="'cell_id'"):
        check_grid_dimensions(
            dataframe, 1, 1, grid_cell_column="cell_id"
        )


@pytest.mark.parametrize(
    "value",
    ["[1, 2, 2, 3]", [1, 2, 2, 3]],
)
def test_parse_territory_cells(value):
    assert parse_territory_cells(value) == {1, 2, 3}


def test_parse_territory_cells_invalid_string():
    with pytest.raises(ValueError, match="could not be interpreted as a list"):
        parse_territory_cells("not a list")


def test_parse_territory_cells_wrong_type():
    with pytest.raises(TypeError, match="Territory values must be lists"):
        parse_territory_cells(123)

    with pytest.raises(TypeError, match="Territory values must be lists"):
        parse_territory_cells("(1, 2)")
