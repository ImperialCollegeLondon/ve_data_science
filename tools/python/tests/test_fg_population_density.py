"""Tests for the functional group population density functions."""

import pandas as pd
import pytest
from ve_data_tools.fg_population_density import (
    calculate_fg_population_density,
    parse_territory_cells,
)


def test_calculate_landscape_population_density():
    """Calculate density using the full simulation area."""
    cohort_df = pd.DataFrame(
        {
            "time_index": [0, 0],
            "functional_group": ["herbivore", "herbivore"],
            "individuals": [40, 60],
            "centroid_key": [0, 1],
        }
    )

    result = calculate_fg_population_density(
        cohort_df=cohort_df,
        cell_size=100,
        n_cells_x=2,
        n_cells_y=2,
        density_unit="km2",
        density_scope="landscape",
    )

    assert result.loc[0, "total_individuals"] == 100
    assert result.loc[0, "area_m2"] == 40_000
    assert result.loc[0, "population_density"] == pytest.approx(2_500)


def test_parse_territory_cells():
    """Convert a stored territory string into unique cell identifiers."""
    result = parse_territory_cells("[1, 2, 2, 3]")

    assert result == {1, 2, 3}


def test_calculate_territory_population_density():
    """Calculate density from unique occupied territory cells."""
    cohort_df = pd.DataFrame(
        {
            "time_index": [0, 0],
            "functional_group": ["herbivore", "herbivore"],
            "individuals": [40, 60],
            "centroid_key": [0, 1],
            "territory": ["[0, 1]", "[1, 2]"],
        }
    )

    result = calculate_fg_population_density(
        cohort_df=cohort_df,
        cell_size=100,
        n_cells_x=2,
        n_cells_y=2,
        density_unit="km2",
        density_scope="territory",
    )

    assert result.loc[0, "territory_cells"] == 3
    assert result.loc[0, "area_m2"] == 30_000
    assert result.loc[0, "population_density"] == pytest.approx(100 / 0.03)
