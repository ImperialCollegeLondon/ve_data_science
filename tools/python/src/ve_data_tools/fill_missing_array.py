"""
---

title: Fill Missing Array.

description: |
  Provide reusable array-level helpers for filling missing values
  in gridded datasets used by processing workflows.

virtual_ecosystem_module:
  - All

author:
  - Lelavathy

status: final

package_dependencies:
  - numpy
  - scipy.ndimage

usage_notes: |
  Import from workflow modules when nearest-neighbour filling of
  missing raster cells is required.

---
"""  # noqa: D212

import numpy as np
from scipy import ndimage

# ============================================================
# ARRAY UTILITIES
# ============================================================
# Provide shared array-level helpers for filling missing values
# and supporting raster-processing steps.


def fill_nan_nearest_2d(array: np.ndarray) -> np.ndarray:
    """Fill NaN values in a 2D array using nearest-neighbour values.

    Args:
      array: 2D array that may include NaN values.

    Returns:
      Array with missing values filled.

    """

    filled = np.asarray(array, dtype=np.float32).copy()
    mask = np.isnan(filled)

    if not mask.any():
        return filled

    indices = ndimage.distance_transform_edt(
        mask,
        return_distances=False,
        return_indices=True,
    )

    filled[mask] = filled[tuple(indices[:, mask])]

    return filled
