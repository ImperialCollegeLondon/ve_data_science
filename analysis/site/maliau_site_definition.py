"""
---
title: Maliau site definition generator

description: |
  This file defines the site parameters for the Maliau basin and exports them to a TOML
  file that can be read in by other scripts.

author:
  - name: David Orme, Lelavathy

virtual_ecosystem_module: all

status: draft

input_files:

output_files:
  - name: maliau_grid_definition_100m_50x50.toml
    path: data/derived/site/maliau
    description: Site definition file for the Maliau Basin

package_dependencies:
  - pyproj
  - tomli_w
  - shapely

usage_notes: Run as `python maliau_site_definition.py`

---
"""  # noqa: D205, D212, D400, D415

import math

import pyproj
import tomli_w
from shapely.geometry import box
from shapely.ops import transform

# Define projection systems and transformation functions between WGS84 and UTM Zone 50N.
#
# - WGS84 (EPSG:4326): Geographic coordinate system using latitude and longitude (deg).
# - UTM Zone 50N (EPSG:32650): Projected coordinate system in meters, suitable for
#   spatial analysis and grid-based modelling in the Maliau region.
#
# Transformers are defined for bidirectional conversion:
#   - wgs84_to_utm50N: converts (lon, lat) → (x, y) in meters
#   - utm50N_to_wgs84: converts (x, y) → (lon, lat)
#
# The argument `always_xy=True` ensures coordinate order is consistently interpreted as
# (longitude, latitude), which avoids axis-order confusion when working with pyproj.
wgs84_proj = pyproj.Proj("epsg:4326")
utm50N_proj = pyproj.Proj("epsg:32650")
wgs84_to_utm50N = pyproj.Transformer.from_proj(wgs84_proj, utm50N_proj, always_xy=True)
utm50N_to_wgs84 = pyproj.Transformer.from_proj(utm50N_proj, wgs84_proj, always_xy=True)

# These coordinates define the initial bounding box for the Maliau study area in WGS84
# (latitude_longitude). This represents a first-pass spatial extent before snapping to
# a clean grid in UTM50N.
# The bounds are provided as:
#   (lat_min, lon_min) → lower-left corner
#   (lat_max, lon_max) → upper-right corner
#
# Note: shapely's `box` function expects coordinates in (lon, lat) order.
lat_min, lon_min = 4.7170137, 116.9492683
lat_max, lon_max = 4.7569565, 116.9890846
maliau_prototype_wgs84 = box(lon_min, lat_min, lon_max, lat_max)

# Convert to UTM50N
maliau_prototype_utm50N = transform(wgs84_to_utm50N.transform, maliau_prototype_wgs84)
minx, miny, maxx, maxy = maliau_prototype_utm50N.bounds

print("Original UTM bounds:", maliau_prototype_utm50N.bounds)

# Those coords have the following bounds in UTM50N
maliau_prototype_utm50N.bounds
# Example output:
# >>> (494373.82, 521383.56, 498789.55, 525798.94)

# This is a 50 x 50 grid at 100 m resolution (so ~ 5000 m by 5000 m) but on awkward
# coordinate boundaries. What we want is a grid in UTM50N that uses actual 100 m cells
# (not degree approximations, although at this spatial scale the approximation is pretty
# good)

# Defines grid dimensions (cell count in x and y) and spatial resolution (in meters)
cell_nx = 50  # Define number of cells in x direction (e.g., 50 for a 50x50 grid)
cell_ny = 50  # Define number of cells in y direction (e.g., 50 for a 50x50 grid)
res = 100  # Define desired resolution in meters (e.g., 100m, 500m, etc.)

# Snap lower-left coordinates to the nearest multiple of the resolution (grid alignment)
ll_x_utm50N = math.floor(minx / res) * res
ll_y_utm50N = math.floor(miny / res) * res

# Calculate the upper right bounds from grid dimensions and resolution
ur_x_utm50N = ll_x_utm50N + cell_nx * res
ur_y_utm50N = ll_y_utm50N + cell_ny * res
print("Snapped LL:", ll_x_utm50N, ll_y_utm50N)
print("Computed UR:", ur_x_utm50N, ur_y_utm50N)

# Create a polygon of those bounds and transform to WGS84 to identify what coords should
# be used in any bounding box for latlong data download
maliau_grid_bounds_utm50N = box(ll_x_utm50N, ll_y_utm50N, ur_x_utm50N, ur_y_utm50N)
maliau_grid_bounds_wgs84 = transform(
    utm50N_to_wgs84.transform, maliau_grid_bounds_utm50N
)

print("Final WGS84 bounds:", maliau_grid_bounds_wgs84.bounds)
# Example output:
# >>> (4.716255907706633, 116.94859967285831, 4.756967848389091, 116.98917950990788)

# Write a definition file as TOMLI
cell_x_centres = [(ll_x_utm50N + res / 2) + res * idx for idx in range(cell_nx)]
cell_y_centres = [(ll_y_utm50N + res / 2) + res * idx for idx in range(cell_ny)]

grid_definition = dict(
    epsg_code=32650,
    ll_x=ll_x_utm50N,
    ll_y=ll_y_utm50N,
    ur_x=ur_x_utm50N,
    ur_y=ur_y_utm50N,
    bounds=maliau_grid_bounds_utm50N.bounds,
    wgs84_bounds=maliau_grid_bounds_wgs84.bounds,
    cell_nx=cell_nx,
    cell_ny=cell_ny,
    cell_x_centres=cell_x_centres,
    cell_y_centres=cell_y_centres,
    res=res,
    core=dict(
        grid=dict(
            cell_area=res * res,
            cell_nx=cell_nx,
            cell_ny=cell_ny,
            grid_type="square",
            xoff=ll_x_utm50N,
            yoff=ll_y_utm50N,
        )
    ),
)

with open(
    "../../../data/derived/sites/maliau_grid_definition_100m_50x50.toml", "ab"
) as outfile:
    outfile.write(b"# Site definition file for Maliau Basin\n")
    tomli_w.dump(grid_definition, outfile)
