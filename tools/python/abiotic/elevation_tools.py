"""
---

title: Elevation Input Data Processing Tools.

description: |
  Provide reusable functions for preparing SRTM elevation data for the
  Virtual Ecosystem (VE) hydrology workflow.

  Specifically, it:
    1. Reprojects and resamples a source elevation raster onto a VE target grid.
    2. Fills any remaining missing values using nearest-neighbour interpolation.
    3. Builds a VE-formatted elevation dataset with x/y coordinates.
    4. Adds global metadata to the processed elevation dataset.

virtual_ecosystem_module:
  - hydrology

author:
  - Lelavathy

status: final

package_dependencies:
  - pathlib
  - numpy
  - xarray
  - rasterio

usage_notes: |
  This module performs elevation processing only and does not download source
  elevation rasters. It is designed to be called from site-specific analysis
  scripts.

---
"""  # noqa: D212

from pathlib import Path

import numpy as np
import rasterio
import xarray as xr
from rasterio.enums import Resampling
from rasterio.warp import reproject

from tools.python.abiotic import fill_missing_array

# ============================================================
# ELEVATION PROCESSING
# ============================================================
# Reproject the source elevation raster onto the VE target
# grid and fill any remaining missing cells.


def interpolate_elevation_to_grid(
    input_raster: Path | str,
    target_grid: dict,
    source_nodata: float | None = None,
) -> np.ndarray:
    """Interpolate elevation raster onto a VE target grid.

    Args:
      input_raster: Path to the source elevation raster.
      target_grid: Target grid dictionary from grid_tools.get_target_grid.
      source_nodata: Optional override for source nodata value.

    Returns:
      Elevation array with shape (ny, nx).

    """

    input_raster = Path(input_raster)

    with rasterio.open(input_raster) as src:
        source = src.read(1).astype(np.float32)

        nodata = source_nodata if source_nodata is not None else src.nodata

        if nodata is not None:
            source = np.where(source == nodata, np.nan, source)

        destination = np.empty(target_grid["shape"], dtype=np.float32)

        reproject(
            source=source,
            destination=destination,
            src_transform=src.transform,
            src_crs=src.crs,
            dst_transform=target_grid["transform"],
            dst_crs=target_grid["crs"],
            resampling=Resampling.bilinear,
        )

    return fill_missing_array.fill_nan_nearest_2d(destination)


# ============================================================
# DATASET CREATION
# ============================================================
# Convert the interpolated elevation array into a
# VE-formatted x/y dataset with variable metadata.


def create_elevation_dataset(
    elevation: np.ndarray,
    target_grid: dict,
) -> xr.Dataset:
    """Create an elevation dataset in VE x/y layout.

    Args:
      elevation: Elevation array in (ny, nx) raster order.
      target_grid: Target grid dictionary from grid_tools.get_target_grid.

    Returns:
      Virtual Ecosystem elevation dataset with dimensions (x, y).

    """

    x = np.asarray(target_grid["x"], dtype=np.float32)
    y = np.asarray(target_grid["y"], dtype=np.float32)

    x_idx = np.argsort(x)
    y_idx = np.argsort(y)

    x_sorted = x[x_idx]
    y_sorted = y[y_idx]

    # Raster arrays are (y, x); transpose to VE convention (x, y).
    elevation_xy = elevation[np.ix_(y_idx, x_idx)].astype(np.float32).T

    dataset = xr.Dataset(
        {
            "elevation": (
                (
                    "x",
                    "y",
                ),
                elevation_xy,
            )
        },
        coords={
            "x": ("x", x_sorted),
            "y": ("y", y_sorted),
        },
    )

    dataset["elevation"].attrs = {
        "long_name": "Surface elevation",
        "units": "m",
    }

    return dataset


# ============================================================
# METADATA
# ============================================================
# Attach global metadata describing the site, source,
# and file conventions used by the elevation dataset.


def add_global_attributes(
    dataset: xr.Dataset,
    scenario_name: str,
    source: str,
) -> xr.Dataset:
    """Add global metadata to an elevation dataset.

    Args:
      dataset: Elevation dataset.
      scenario_name: Scenario name.
      source: Source dataset name.

    Returns:
      Elevation dataset with global metadata added.

    """

    elevation_ds = dataset.copy()

    elevation_ds.attrs = {
        "title": "Virtual Ecosystem elevation input",
        "site": scenario_name,
        "source": source,
        "Conventions": "CF-1.10",
    }

    return elevation_ds
