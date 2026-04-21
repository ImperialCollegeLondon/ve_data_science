"""
---
title: Maliau site definition generator (multi-scenario TOML)

description: |
  This script generates grid-based site definitions for the Maliau Basin and stores
  them as multiple scenarios within a single TOML file.

  Each scenario (e.g., maliau_1, maliau_2) is defined by a user-specified geographic
  bounding box (WGS84), grid resolution (meters), and grid dimensions (cell_nx, cell_ny).

  The workflow:
    1. Converts geographic coordinates (WGS84) to UTM Zone 50N
    2. Aligns the grid to the specified resolution using a snapped lower-left origin
    3. Computes grid extent (lower-left and upper-right coordinates)
    4. Calculates cell centre coordinates for compatibility with input datasets
    5. Writes all scenarios into a structured TOML file under [Scenario.<name>]

  The output TOML file contains:
    - Grid extent (UTM coordinates)
    - Corresponding WGS84 bounding box
    - Cell centre coordinates
    - VE-compatible grid configuration (core.grid)

  Existing scenarios are preserved across runs, and new scenarios are added without
  overwriting previous entries.

author:
  - name: David Orme
  - name: Lelavathy

virtual_ecosystem_module: all

status: draft

input_files:
  - description: User-defined grid configurations (within script)

output_files:
  - name: maliau_grid_definition.toml
    path: data/derived/site/maliau
    description: Multi-scenario grid definition file for VE simulations

package_dependencies:
  - pyproj
  - tomli_w
  - shapely
  - tomllib

usage_notes: |
  Run as: python maliau_site_definition.py

  Instructions:
  - Select scenario interactively (e.g., maliau_1, maliau_2)
  - Each run updates or adds a scenario to the TOML file
  - Scenarios are stored under [Scenario.<name>]

---

"""  # noqa: D400, D212, D205, D415

import math
import os

import pyproj
import tomli_w
import tomllib
from shapely.geometry import box
from shapely.ops import transform

# ============================================================
# CONFIGURATION
# ============================================================
# Define all available grid scenarios.
#    Each scenario includes:
#    - cell_nx, cell_ny : grid dimensions
#    - res              : grid resolution (meters)
#    - bbox             : bounding box (lat_min, lon_min, lat_max, lon_max)


def get_all_configs():
    return {
        "maliau_1": {
            "cell_nx": 50,
            "cell_ny": 50,
            "res": 100,
            "bbox": (4.7170137, 116.9492683, 4.7569565, 116.9890846),
        },
        "maliau_2": {
            "cell_nx": 10,
            "cell_ny": 10,
            "res": 100,
            "bbox": (4.7420402, 116.9679879, 4.7501825, 116.9761036),
        },
    }


def get_grid_config(grid_name: str):
    configs = get_all_configs()
    if grid_name not in configs:
        raise ValueError(f"Invalid grid_name: {grid_name}")
    return configs[grid_name]


# ============================================================
# GRID GENERATION
# ============================================================
# Generate grid definition from configuration.
#   Steps:
#    1. Convert bounding box (WGS84 → UTM)
#    2. Snap grid to resolution
#    3. Compute grid extent (LL and UR)
#    4. Convert back to WGS84
#    5. Compute cell centres
#    6. Assemble final grid definition dictionary


def build_grid_definition(config):
    # Extract parameters
    cell_nx = config["cell_nx"]  # Number of grid cells in X direction
    cell_ny = config["cell_ny"]  # Number of grid cells in Y direction
    res = config["res"]  # Grid resolution of each grid cell (in meters)
    (lat_min, lon_min, lat_max, lon_max) = config[
        "bbox"
    ]  # Bounding box in WGS84 geographic coordinates

    # Define projection systems and transformation functions between WGS84 and UTM Zone50N
    # - WGS84 (EPSG:4326): Geographic coordinate system using latitude and longitude (deg)
    # - UTM Zone 50N (EPSG:32650): Projected coordinate system in meters
    wgs84 = pyproj.Proj("epsg:4326")
    utm50 = pyproj.Proj("epsg:32650")

    # Transformers are defined for bidirectional conversion:
    #   - wgs84_to_utm50N: converts (lon, lat) → (x, y) in meters
    #   - utm50N_to_wgs84: converts (x, y) → (lon, lat)
    to_utm = pyproj.Transformer.from_proj(wgs84, utm50, always_xy=True)
    to_wgs = pyproj.Transformer.from_proj(utm50, wgs84, always_xy=True)

    # NOTE:
    # always_xy=True ensures coordinate order is always:
    # (longitude, latitude), avoiding axis confusion
    # Create bounding box (lon, lat order for shapely)

    # Create bounding box polygon in WGS84
    poly = box(lon_min, lat_min, lon_max, lat_max)
    poly_utm = transform(to_utm.transform, poly)

    # Extract bounding box limits in UTM
    minx, miny, _, _ = poly_utm.bounds

    # Snap lower-left corner to grid resolution
    ll_x = math.floor(minx / res) * res
    ll_y = math.floor(miny / res) * res

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
            )
        ),
    )


# ============================================================
# WRITE TOML FILE
# ============================================================
# Write all scenarios to a TOML file in VE-compatible format.

# For each scenario:
# - Writes the main grid definition
# - Ensures the `core.grid` block is always included

# The file is fully rewritten each time to maintain consistency and prevent missing
# or partial sections.


def write_all_scenarios(data, output_path):
    with open(output_path, "wb") as f:
        f.write(b"[Scenario]\n")

        for name, scenario in data["Scenario"].items():
            # Main block
            f.write(f"\n[Scenario.{name}]\n".encode())

            f.write(
                (
                    f"# Site definition file for {name}\n"
                    f"# Grid: {scenario['cell_nx']} x {scenario['cell_ny']} cells, "
                    f"resolution = {scenario['res']} m\n\n"
                ).encode()
            )

            # Write everything except core
            main = {k: v for k, v in scenario.items() if k != "core"}
            tomli_w.dump(main, f)

            # 🔥 ALWAYS write core.grid for every scenario
            f.write(f"\n[Scenario.{name}.core.grid]\n".encode())
            tomli_w.dump(scenario["core"]["grid"], f)


## ============================================================
# MAIN RUN FUNCTION
# ============================================================
# Generate and write a grid scenario to the TOML file.
# Loads existing scenarios, prevents overwriting, and ensures
# a complete VE-compatible TOML structure.


def run(grid_name):
    # Output file path
    output_path = "../../../data/derived/sites/maliau_grid_definition.toml"

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
