"""
---
title: Maliau site definition generator (multi-scenario TOML)

description: |
  This script generates grid-based site definitions for the Maliau Basin and stores
  them as multiple scenarios within a single TOML file.

  Each scenario (e.g., maliau_1, maliau_2) is defined by a user-specified bounding
  box in projected UTM Zone 50N coordinates (meters), grid resolution (meters), grid
  dimensions (cell_nx, cell_ny), simulation timing configuration (core.timing)

  The workflow:
    1. Uses the bbox lower-left corner directly (already in UTM Zone 50N) as the
       grid origin
    2. Computes grid extent (lower-left and upper-right coordinates) in UTM Zone 50N
    3. Converts the grid extent to WGS84 for reference/output only
    4. Calculates cell centre coordinates for compatibility with input datasets
    5. Attaches VE-compatible configuration blocks:
         - core.grid   (spatial configuration)
         - core.timing (temporal configuration)
    6. Writes all scenarios into a structured TOML file under [Scenario.<name>]

  The bounding box is specified directly in UTM Zone 50N rather than WGS84 so the
  grid is defined and aligned purely in projected coordinates; deriving the UTM
  extent from a WGS84 bounding box would introduce reprojection rounding before
  the grid origin is even set. The bbox corner is used as-is, with no snapping to
  a resolution multiple, so a deliberately chosen extent (e.g. buffered around
  known plot coordinates) is preserved exactly.

  The output TOML file contains:
    - Grid extent (UTM coordinates)
    - Corresponding WGS84 bounding box
    - Cell centre coordinates
    - VE-compatible grid configuration (core.grid) and
      timing configuration (core.timing)

  Existing scenarios are preserved across runs, and new scenarios are added without
  overwriting previous entries.

author:
  - name: David Orme
  - name: Lelavathy
  - name: Arne Scheire

virtual_ecosystem_module: all

status: final

input_files:
  - description: User-defined grid and timing configurations (within script)

output_files:
  - name: maliau_grid_definition.toml
    path: data/derived/site/maliau
    description: Multi-scenario grid and timing definition file for VE simulations

package_dependencies:
  - pyproj
  - tomli_w
  - shapely
  - tomllib

usage_notes: |
  - Add and edit scenario information to the list under `get_all_configs` in this script
  - In the terminal, run this script `python maliau_site_definition.py` from the root
    directory
  - Select a scenario interactively by typing, for example, `maliau_1,
    `maliau_2` etc.
  - A TOML file will be created at the specified `output_path`
  - To update or add additional scenario to the TOML file, rerun the script and select
    the new scenario name.
  - Scenarios are stored under [Scenario.<name>] with their own grid and timing
    configuration blocks.

  Run as: python maliau_site_definition.py
---

"""  # noqa: D400, D212, D205, D415

import os
import tomllib

import pyproj
import tomli_w
from shapely.geometry import box
from shapely.ops import transform

# ============================================================
# CONFIGURATION
# ============================================================
# Define all available grid scenarios.
#    Each scenario includes:
#    - cell_nx, cell_ny : grid dimensions
#    - res              : grid resolution (meters)
#    - bbox             : bounding box in UTM Zone 50N, EPSG:32650
#                         (minx, miny, maxx, maxy), in meters
#    - timing           : simulation timing configuration (core.timing)
#        - start_date      : simulation start date (YYYY-MM-DD)
#        - update_interval : model update timestep (e.g. "1 month", "1 day")
#        - run_length      : total simulation duration (e.g. "11 years")


def get_all_configs():
    """Return predefined grid configurations."""
    return {
        "maliau_1": {
            "cell_nx": 50,
            "cell_ny": 50,
            "res": 100,
            "bbox": (491559.3, 520298.8, 496559.3, 525298.8),
            "timing": {
                "start_date": "2010-01-01",
                "update_interval": "1 month",
                "run_length": "11 years",
            },
        },
        "maliau_2": {
            "cell_nx": 10,
            "cell_ny": 10,
            "res": 100,
            "bbox": (495559.3, 524298.8, 496559.3, 525298.8),
            "timing": {
                "start_date": "2010-01-01",
                "update_interval": "1 month",
                "run_length": "11 years",
            },
        },
    }


def get_grid_config(grid_name: str):
    """Return the configuration dictionary for a given grid scenario."""
    configs = get_all_configs()
    if grid_name not in configs:
        raise ValueError(f"Invalid grid_name: {grid_name}")
    return configs[grid_name]


# ============================================================
# GRID GENERATION
# ============================================================
# Generate grid definition from configuration.
#   Steps:
#    1. Use bbox lower-left corner directly (already in UTM, no snapping)
#    2. Compute grid extent (LL and UR)
#    3. Convert to WGS84 for reference/output only
#    4. Compute cell centres
#    5. Assemble final grid definition dictionary


def build_grid_definition(config):
    """Build a grid definition dictionary from a given configuration."""
    # Extract parameters
    cell_nx = config["cell_nx"]  # Number of grid cells in X direction
    cell_ny = config["cell_ny"]  # Number of grid cells in Y direction
    res = config["res"]  # Grid resolution of each grid cell (in meters)
    (minx, miny, _, _) = config[
        "bbox"
    ]  # Bounding box in UTM Zone 50N projected coordinates
    timing = config.get("timing", None)  # timing configuration

    # UTM Zone 50N (EPSG:32650) is a projected coordinate system in meters.
    # The bounding box is already supplied in this system, so no WGS84 to UTM
    # conversion is needed here. WGS84 (EPSG:4326) is only used afterwards to
    # report the grid extent in geographic coordinates.
    utm50 = pyproj.Proj("epsg:32650")
    wgs84 = pyproj.Proj("epsg:4326")
    to_wgs = pyproj.Transformer.from_proj(utm50, wgs84, always_xy=True)

    # No snapping: the bbox corner is used as-is, so the caller's exact
    # extent (e.g. buffered around known plot coordinates) is preserved.
    ll_x = minx
    ll_y = miny

    # Compute upper-right corner of grid
    ur_x = ll_x + cell_nx * res
    ur_y = ll_y + cell_ny * res

    # Convert grid bounds back to WGS84
    grid_bounds = box(ll_x, ll_y, ur_x, ur_y)
    grid_bounds_wgs = transform(to_wgs.transform, grid_bounds)

    # Compute grid cell centre coordinates
    cx = [(ll_x + res / 2) + res * i for i in range(cell_nx)]  # X centres (eastings)
    cy = [(ll_y + res / 2) + res * i for i in range(cell_ny)]  # Y centres (northings)

    # Assemble final grid definition
    return dict(
        epsg_code=32650,
        ll_x=ll_x,
        ll_y=ll_y,
        ur_x=ur_x,
        ur_y=ur_y,
        bounds=grid_bounds.bounds,
        wgs84_bounds=grid_bounds_wgs.bounds,
        cell_nx=cell_nx,
        cell_ny=cell_ny,
        cell_x_centres=cx,
        cell_y_centres=cy,
        res=res,
        core=dict(
            grid=dict(
                cell_area=res * res,
                cell_nx=cell_nx,
                cell_ny=cell_ny,
                grid_type="square",
                xoff=ll_x,  # x offset (lower-left corner cell in UTM50N)
                yoff=ll_y,  # y offset (lower-left corner cell in UTM50N)
            ),
            timing=timing,  # timing configuration
        ),
    )


# ============================================================
# WRITE TOML FILE
# ============================================================
# Write all scenarios to a TOML file in VE-compatible format.

# For each scenario:
# - Writes the main grid definition
# - Ensures the `core.grid` and `core.timing`block are always included

# The file is fully rewritten each time to maintain consistency and prevent missing
# or partial sections.


def write_all_scenarios(data, output_path):
    """Write all grid scenarios to a TOML file."""
    with open(output_path, "wb") as f:
        f.write(b"[Scenario]\n")

        for name, scenario in data["Scenario"].items():
            f.write(f"\n[Scenario.{name}]\n".encode())

            # Temporal formatting
            timing = scenario["core"].get("timing", None)

            if timing:
                start_year = int(timing["start_date"][:4])
                run_years = int(timing["run_length"].split()[0])
                end_year = start_year + run_years - 1
                temporal_str = (
                    f"# Temporal: {start_year}-{end_year} ({run_years} years)\n"
                )
            else:
                temporal_str = ""

            # Write header comment for each scenario with grid and temporal info
            f.write(
                (
                    f"# Site definition file for {name}\n"
                    f"# Grid: {scenario['cell_nx']} x {scenario['cell_ny']} cells, "
                    f"resolution = {scenario['res']} m\n"
                    f"{temporal_str}\n"
                ).encode()
            )

            # Write everything except core
            main = {k: v for k, v in scenario.items() if k != "core"}
            tomli_w.dump(main, f)

            # Write core.grid for every scenario
            f.write(f"\n[Scenario.{name}.core.grid]\n".encode())
            tomli_w.dump(scenario["core"]["grid"], f)

            # Write core.timing for every scenario
            if "timing" in scenario["core"] and scenario["core"]["timing"] is not None:
                f.write(f"\n[Scenario.{name}.core.timing]\n".encode())
                tomli_w.dump(scenario["core"]["timing"], f)


## ============================================================
# MAIN RUN FUNCTION
# ============================================================
# Generate and write a grid scenario to the TOML file.
# Loads existing scenarios, prevents overwriting, and ensures
# a complete VE-compatible TOML structure.
def run(grid_name):
    """Generate and save a grid scenario to the TOML file."""

    # Output file path
    output_path = "data/derived/site/maliau/maliau_grid_definition.toml"

    # Load existing scenarios (if file exists)
    if os.path.exists(output_path):
        with open(output_path, "rb") as f:
            data = tomllib.load(f)
    else:
        data = {}

    # Ensure "Scenario" container exists
    if "Scenario" not in data:
        data["Scenario"] = {}

    # Prevent overwriting existing scenario
    if grid_name in data["Scenario"]:
        raise ValueError(
            f"❌ Scenario '{grid_name}' already exists.\n"
            f"Delete it manually if you want to regenerate."
        )
    # Build new scenario
    config = get_grid_config(grid_name)
    new_grid = build_grid_definition(config)

    # Add only if new
    data["Scenario"][grid_name] = new_grid

    # Write full TOML file
    write_all_scenarios(data, output_path)
    print(f"\n✔ Scenario '{grid_name}' written successfully (write-once).\n")


# ============================================================
# INTERACTIVE ENTRY POINT
# ============================================================
# Displays available scenarios, prompts user selection,validates input, and executes
# the selected scenario via the run() function.

if __name__ == "__main__":
    configs = get_all_configs()
    names = list(configs.keys())

    print("\nAvailable scenarios:")
    for n in names:
        print(f" - {n}")

    choice = input("\nEnter scenario: ").strip()

    if choice not in names:
        raise ValueError("Invalid choice")

    run(choice)
