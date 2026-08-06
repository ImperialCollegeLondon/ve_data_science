"""
---
title: Utilities for mapping VE.

description: A collection of mapping functions to visualise VE metadata and data

virtual_ecosystem_module: All

author: Hao Ran Lai, Lelavathy

status: final

input_files:

output_files:

package_dependencies:
  - tomllib
  - pathlib
  - folium

usage_notes: See function documentation below.
---
"""  # noqa: D205, D212

import tomllib
from pathlib import Path

import folium


def map_scenario_extent(site_definition: str | Path, site_name: str) -> folium.Map:
    """Map VE Scenario Extent.

    Creates an interactive leaflet map showing the geographic extent of a
    scenario defined in a TOML site-definition file.

    Args:
        site_definition: Path to a TOML file containing scenario definitions
          with WGS84 bounds.
        site_name: Character string naming the site within the TOML file.

    Returns:
        A folium map with satellite imagery and a yellow rectangle indicating
        the scenario bounds.

    Examples:
        >>> map_scenario_extent(
        ...     "data/derived/site/safe/safe_grid_definition.toml",
        ...     "safe_1",
        ... )

    """
    # read the site definition TOML file
    site_definition = Path(site_definition)
    with open(site_definition, "rb") as f:
        config = tomllib.load(f)

    # unpack the spatial extents
    min_lon, min_lat, max_lon, max_lat = config["Scenario"][site_name]["wgs84_bounds"]

center = (
(min_lat + max_lat) / 2,
(min_lon + max_lon) / 2,
)
fit_bounds = [
[min_lat, min_lon],
[max_lat, max_lon],
]

    # define the map background layer
    esri_tiles = (
        "https://server.arcgisonline.com/ArcGIS/rest/services"
        "/World_Imagery/MapServer/tile/{z}/{y}/{x}"
    )

    # create the folium map
    folium_map = folium.Map(location=center, tiles=esri_tiles, attr="Esri")
    folium_map.fit_bounds(fit_bounds)

    # add the extent rectangle
    folium.Rectangle(
        bounds=fit_bounds,
        color="#FFFF00",
        fill=False,
        weight=2,
    ).add_to(folium_map)

    return folium_map
