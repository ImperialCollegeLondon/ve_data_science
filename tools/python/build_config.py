"""
---
title: Helper Functions for Building VE Modular Configuration Files

description: |
  This module contains reusable helper functions for generating
  Virtual Ecosystem (VE) configuration files.

  The functions simplify common preprocessing and configuration
  tasks such as:
    - loading TOML scenario definitions
    - displaying available scenarios
    - interactive scenario selection
    - generating grid suffixes
    - adding VE variable definitions
    - writing TOML configuration files

  Centralising reusable utilities in this module improves:
    - maintainability
    - readability
    - modularity
    - consistency across VE workflows

virtual_ecosystem_module:
  - Abiotic
  - Hydrology
  - Soil
  - Litter
  - Plant
  - Animal

author:
  - Lelavathy Samikan

status: final

input_files: []

output_files: []

package_dependencies:
  - pathlib
  - toml

usage_notes: |
  - This module is intended to be imported into VE
    configuration-building workflows.

  - Available helper functions include:
      - load_scenario()
      - get_available_scenarios()
      - display_scenarios()
      - select_scenario()
      - get_grid_suffix()
      - add_data_variables()
      - write_toml()

  - The helper functions automate repetitive tasks such as:
      - scenario loading
      - TOML formatting
      - variable block generation
      - output directory creation

  - Scenario definitions must exist under the
    `Scenario` section of the grid definition TOML file
    (e.g., maliau_grid_definition.toml).

  - Run as:

      imported as helper module

---
"""  # noqa: D400, D212, D205, D415


# =============================================================================
# Import libraries
# =============================================================================
# Import required Python libraries for TOML parsing,
# file handling, and VE helper utilities.

from pathlib import Path

import toml

# =============================================================================
# Load scenario
# =============================================================================
# Load VE scenario configuration from a TOML file
# and return the selected core configuration.


def load_scenario(
    toml_path,
    scenario_name,
):
    """Load VE scenario configuration from a TOML file.

    This function reads a TOML configuration file containing multiple
    Virtual Ecosystem (VE) simulation scenarios and extracts the
    selected scenario configuration.

    The returned configuration includes:
      - core.grid settings
      - core.timing settings

    Args:
        toml_path (str | Path):
            Path to the TOML scenario definition file.

        scenario_name (str):
            Name of the scenario under `Scenario`.

    Returns:
        dict:
            Dictionary containing:
              - grid configuration
              - timing configuration

    Raises:
        ValueError:
            If the requested scenario is not found.

    """

    # Load TOML configuration file
    scenario_data = toml.load(toml_path)

    # Access scenario definitions
    scenarios = scenario_data["Scenario"]

    # Validate selected scenario
    if scenario_name not in scenarios:
        raise ValueError(f"invalid scenario: {scenario_name}")

    # Return VE core configuration
    return scenarios[scenario_name]["core"]


# =============================================================================
# Get available scenarios
# =============================================================================
# Extract all available VE simulation scenario names
# directly from the TOML configuration file.


def get_available_scenarios(
    toml_path,
):
    """Get available VE scenarios from a TOML file.

    Args:
        toml_path (str | Path):
            Path to the TOML scenario definition file.

    Returns:
        list:
            List of available scenario names.

    """

    # Load TOML configuration file
    scenario_data = toml.load(toml_path)

    # Return available scenario names
    return list(scenario_data["Scenario"].keys())


# =============================================================================
# Display scenarios
# =============================================================================
# Display available VE simulation scenarios and
# associated grid dimensions to the user.


def display_scenarios(
    toml_path,
):
    """Display available VE scenarios."""

    # Load TOML configuration file
    scenario_data = toml.load(toml_path)

    # Access scenario definitions
    scenarios = scenario_data["Scenario"]

    print("\navailable maliau scenarios:\n")

    # Display available scenarios
    for index, scenario_name in enumerate(
        scenarios,
        start=1,
    ):
        scenario_info = scenarios[scenario_name]

        # Access VE grid configuration
        grid = scenario_info["core"]["grid"]

        cell_nx = grid["cell_nx"]

        cell_ny = grid["cell_ny"]

        print(f"{index}. {scenario_name} ({cell_nx}x{cell_ny} grid)")


# =============================================================================
# Select scenario
# ============================================================================
# Prompt the user to select a VE simulation scenario
# interactively from the TOML configuration file.


def select_scenario(
    toml_path,
):
    """Select VE scenario interactively."""

    # Get available scenarios
    scenario_options = get_available_scenarios(toml_path)

    # Display scenarios
    display_scenarios(toml_path)

    print("\nyou can type:")

    for index, scenario_name in enumerate(
        scenario_options,
        start=1,
    ):
        print(f"  {index}")
        print(f"  {scenario_name}")

    # User selection
    selection = input("\nselect scenario: ").strip().lower()

    # Create numeric mapping automatically
    numeric_map = {
        str(index): scenario_name
        for index, scenario_name in enumerate(
            scenario_options,
            start=1,
        )
    }

    # Numeric selection
    if selection in numeric_map:
        return numeric_map[selection]

    # Direct scenario selection
    if selection in scenario_options:
        return selection

    raise ValueError("\ninvalid scenario selection.")


# =============================================================================
# Grid suffix
# =============================================================================
# Generate a VE grid suffix string based on
# grid dimensions for dataset naming consistency.


def get_grid_suffix(
    core_grid,
):
    """Generate VE grid suffix string.

    Args:
        core_grid (dict):
            VE grid configuration dictionary.

    Returns:
        str:
            Grid suffix string formatted as:
            '<cell_nx>x<cell_ny>'

    """

    cell_nx = core_grid["cell_nx"]

    cell_ny = core_grid["cell_ny"]

    return f"{cell_nx}x{cell_ny}"


# =============================================================================
# Add data variables
# =============================================================================
# Add VE variable definitions to TOML configuration text.


def add_data_variables(
    text,
    file_path,
    variables,
    section_name,
):
    """Add VE variable definitions to TOML text.

    Args:
        text (str):
            Existing TOML configuration text.

        file_path (str):
            NetCDF dataset file path.

        variables (list):
            List of VE variable names.

        section_name (str):
            Section title for TOML formatting.

    Returns:
        str:
            Updated TOML configuration text.

    """

    # Add section title
    text += f"\n# {section_name}\n"

    # Add variable definitions
    for variable in variables:
        text += f"""
[[core.data.variable]]
file_path = "{file_path}"
var_name = "{variable}"
"""

    return text


# =============================================================================
# Write toml
# =============================================================================
# Write Python dictionary data to a TOML file
# and create parent directories automatically.


def write_toml(
    data,
    output_file,
):
    """Write dictionary data to a TOML file.

    Args:
        data (dict):
            Dictionary containing TOML-compatible data.

        output_file (str | Path):
            Output TOML file path.

    """

    output_file = Path(output_file)

    # Create output directory if needed
    output_file.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    # Write TOML file
    with open(
        output_file,
        "w",
    ) as file:
        toml.dump(
            data,
            file,
        )

    print(f"written: {output_file}")
