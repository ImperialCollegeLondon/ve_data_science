"""
---

title: Write Dataset.

description: |
  Provide shared helpers for writing workflow datasets to
  compressed NetCDF output files.

virtual_ecosystem_module:
  - All

author:
  - Lelavathy

status: final

package_dependencies:
  - pathlib
  - xarray

usage_notes: |
  Import from workflow modules to write datasets with consistent
  directory handling and compression behaviour.

---
"""  # noqa: D212

from pathlib import Path

import xarray as xr

# ============================================================
# DATASET OUTPUT
# ============================================================
# Write datasets to NetCDF with consistent directory creation
# and compression settings across workflows.


def save_dataset(
    dataset: xr.Dataset,
    outfile: Path | str,
    compression_level: int = 4,
) -> Path:
    """Save a dataset as a compressed NetCDF file.

    Args:
      dataset: Dataset to save.
      outfile: Output NetCDF file path.
      compression_level: Lossless NetCDF compression level.

    Returns:
      Path to the saved NetCDF file.

    """

    outfile = Path(outfile)

    outfile.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    encoding = {
        variable: {
            "zlib": True,
            "complevel": compression_level,
        }
        for variable in dataset.data_vars
    }

    dataset.to_netcdf(
        outfile,
        encoding=encoding,
    )

    print(f"\nSaved:\n{outfile}")

    return outfile
