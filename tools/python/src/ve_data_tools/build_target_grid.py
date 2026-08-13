"""
---

title: Build Target Grid.

description: |
  Provide helper functions for constructing target-grid metadata
  used by spatial interpolation workflows.

virtual_ecosystem_module:
  - All

author:
  - Lelavathy

status: final

package_dependencies:
  - numpy
  - rasterio

usage_notes: |
  Import from workflow modules when converting site configuration
  values into interpolation-ready grid definitions.

---
"""  # noqa: D212

import numpy as np
from rasterio.crs import CRS
from rasterio.transform import from_origin

# ============================================================
# TARGET GRID
# ============================================================
# Build the target grid metadata used by interpolation workflows
# from the scenario coordinate, resolution, and CRS settings.


def get_target_grid(scenario: dict) -> dict:
    """Create a target grid dictionary used for spatial interpolation.

    Args:
      scenario: Site configuration dictionary containing target grid
        values.

    Returns:
      Dictionary with coordinate reference system, affine transform,
      shape, resolution, and x/y coordinates.

    """

    x = np.asarray(scenario["cell_x_centres"], dtype=float)
    y = np.asarray(scenario["cell_y_centres"], dtype=float)

    resolution = float(scenario["res"])

    transform = from_origin(
        x.min() - resolution / 2,
        y.max() + resolution / 2,
        resolution,
        resolution,
    )

    return {
        "crs": CRS.from_epsg(scenario["epsg_code"]),
        "transform": transform,
        "shape": (
            scenario["cell_ny"],
            scenario["cell_nx"],
        ),
        "res": resolution,
        "x": x,
        "y": y,
    }
