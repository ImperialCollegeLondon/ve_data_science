"""Test file for TrophicFlowAnalysis class in trophic_mass_flow.py."""

import pandas as pd
import pytest

# Import class (adjust path when needed)
from trophic_mass_flow import TrophicFlowAnalysis  # Change filename when different


@pytest.fixture
def analysis():
    """Fixture for flow analysis used in tests.

    Create a clean object with these parameters for every test we run for every method.
    """
    # which data file to use
    test_file = "animal_trophic_interactions.csv"
    # create new instance of the class
    return TrophicFlowAnalysis(
        file_path=test_file,
        config={"convert_to_grams": False, "value_to_sum": "C", "n_cols": 2},
    )


def test_class_initialisation(analysis):
    """Test that the class can be initialized correctly."""
    # check if object is an instance of our class.
    # Assert means "if this is false, fail the test."
    assert isinstance(analysis, TrophicFlowAnalysis)
    assert analysis.file_path == "animal_trophic_interactions.csv"
    assert isinstance(analysis.config, dict)
    # is None make sure the dataframe start as none
    assert analysis.df is None
    assert analysis.pivoted_df is None


def test_load_data(analysis):
    """Test load_data method."""
    # call the method and store what it returns.
    result = analysis.load_data()
    # check method returns self (For method chaining)
    assert result is analysis
    # check whether data below was loaded
    assert isinstance(analysis.df, pd.DataFrame)
    assert len(analysis.df) > 0
    assert "time" in analysis.df.columns
    assert "resource_kind" in analysis.df.columns


def test_process_data(analysis):
    """Test process_data pipeline."""
    # call load_data() method
    analysis.load_data()
    # calls process_data() running convert_units, group_and_aggregate(),pivot_data()
    # store what method returns in "result" variable
    result = analysis.process_data()
    # checks if "result" is the same object as what we started
    assert result is analysis
    # checks again if its returns a dataframe that is populated
    assert analysis.group_df is not None
    assert analysis.pivoted_df is not None
    assert len(analysis.pivoted_df) > 0


def test_plot_faceted_saves_file(analysis, tmp_path):
    """Test plot_faceted saves a file without showing a plot.

    Args:
        analysis: class method
        tmp_path: a temporary folder to save file during testing.

    """
    # call load_data() and process_data method
    analysis.load_data().process_data()
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
