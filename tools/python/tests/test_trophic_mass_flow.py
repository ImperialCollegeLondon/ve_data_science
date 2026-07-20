"""Test file for TrophicFlowAnalysis class in trophic_mass_flow.py."""

from pathlib import Path

import pandas as pd
import pytest

# Import class (adjust path when needed)
from trophic_mass_flow import TrophicFlowAnalysis  # Change filename when different


@pytest.fixture
def analysis():
    """Fixture for flow analysis used in tests.

    Create a clean object with these parameters for every test we run for every method.
    """
    # first create path relative to test file
    data_file = (
        Path(__file__).resolve().parent.parent.parent
        / "testing_data"
        / "animal_trophic_interactions.csv"
    )
    # load csv first, then pass df to class
    df = pd.read_csv(data_file)
    # create new instance of the class
    return TrophicFlowAnalysis(
        df=df,
        config={"convert_to_grams": False, "value_to_sum": "C", "n_cols": 2},
    )


def test_class_initialisation(analysis):
    """Test that the class can be initialized correctly."""
    # check if object is an instance of our class.
    # Assert means "if this is false, fail the test."
    assert isinstance(analysis.df, pd.DataFrame)
    # make sure dataframe is not empty
    assert not analysis.df.empty
    assert analysis.config["convert_to_grams"] is False
    assert isinstance(analysis.config, dict)
    assert analysis.pivoted_df is None


def test_process_data(analysis):
    """Test process_data pipeline."""
    # calls process_data() running convert_units, group_and_aggregate(),pivot_data()
    analysis.process_data()
    # checks if its returns a dataframe that is populated
    assert analysis.grouped_df is not None
    assert analysis.pivoted_df is not None
    assert len(analysis.pivoted_df) > 0


def test_plot_faceted_saves_file(analysis, tmp_path):
    """Test plot_faceted saves a file without showing a plot.

    Args:
        analysis: class method
        tmp_path: a temporary folder to save file during testing.

    """
    # call load_data() and process_data method
    analysis.process_data()
    # create file path with pathlib to join files using "/"
    output_path = tmp_path / "test_plot.png"
    # calls plot_faceted() method, save plot into path, dont show graph
    analysis.plot_faceted(
        save_path=str(output_path), show=False, title="Test Plot Title"
    )
    # assert whether a PNG file is created.
    # if fails, shows the message "....was not saved"
    assert output_path.is_file(), "Plot file was not saved"
    # check if file is bigger than 10KB, smaller than that would indicate failure
    assert output_path.stat().st_size > 10000, "Plot file might be too small"
