"""Maliau grid definition.

This script is used to generate

"""

import pyproj
import tomli_w
from shapely.geometry import box
from shapely.ops import transform

# Define reprojection functions between WGS84 and UTM50N
wgs84_proj = pyproj.Proj("epsg:4326")
utm50N_proj = pyproj.Proj("epsg:32650")
wgs84_to_utm50N = pyproj.Transformer.from_proj(wgs84_proj, utm50N_proj)
utm50N_to_wgs84 = pyproj.Transformer.from_proj(utm50N_proj, wgs84_proj)

# These coords are the latlong bounds of the first pass at the grid definition in WGS84
maliau_prototype_wgs84 = box(4.7170137, 116.9492683, 4.7569565, 116.9890846)
maliau_prototype_utm50N = transform(wgs84_to_utm50N.transform, maliau_prototype_wgs84)

# Those coords have the following bounds in UTM50N
maliau_prototype_utm50N.bounds
# >>> (494373.8239959609, 521383.5637796852, 498789.5451954976, 525798.942726805)

# This is a 49 x 49 grid at 90 m resolution (so ~ 4410m by 4410m) but on awkward
# coordinate boundaries. What we want is a grid in UTM50N that uses actual 90m cells
# (not degree approximations, although at this spatial scale the approximation is pretty
# good)

# Round down the lower left corner to neat metre coordinates and add a cell to maintain
# the approximate limits of the original grid
min_x_utm50N = 494300
min_y_utm50N = 521300
cell_nx = 50
cell_ny = 50
res = 90
max_x_utm50N = min_x_utm50N + cell_nx * res
max_y_utm50N = min_y_utm50N + cell_ny * res

# Create a polygon of those bounds and transform to WGS84 to identify what coords should
# be used in any bounding box for latlong data download
maliau_grid_bounds_utm50N = box(min_x_utm50N, min_y_utm50N, max_x_utm50N, max_y_utm50N)
maliau_grid_bounds_wgs84 = transform(
    utm50N_to_wgs84.transform, maliau_grid_bounds_utm50N
)
maliau_grid_bounds_wgs84.bounds
# >>> (4.716255907706633, 116.94859967285831, 4.756967848389091, 116.98917950990788)


# Write a definition file as TOMLI

cell_x_bounds = [min_x_utm50N + res * idx for idx in range(cell_nx + 1)]
cell_y_bounds = [min_y_utm50N + res * idx for idx in range(cell_ny + 1)]

grid_definition = dict(
    epsg_code=32650,
    min_x=min_x_utm50N,
    min_y=min_y_utm50N,
    max_x=max_x_utm50N,
    max_y=max_y_utm50N,
    cell_nx=cell_nx,
    cell_ny=cell_ny,
    cell_x_bounds=cell_x_bounds,
    cell_y_bounds=cell_y_bounds,
    res=res,
    core=dict(
        grid=dict(
            cell_area=res * res,
            cell_nx=cell_nx,
            cell_ny=cell_ny,
            grid_type="square",
            xoff=min_x_utm50N,
            yoff=min_y_utm50N,
        )
    ),
)

with open("maliau_grid_definition.toml", "wb") as outfile:
    tomli_w.dump(grid_definition, outfile)
