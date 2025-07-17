"""Script to generate data to initialise the plants model.

This script exports a NetCDF file containing the plant community setup for the 9 by
9 example grid. Each cell contains 4 different plant functional types and 34 cohorts.

"""

import numpy as np
import pandas as pd
from xarray import DataArray, Dataset

from generation_scripts.plant.common import (
    cell_id,
    n_cells,
    n_dates,
    time,
    time_index,
)

data = Dataset()

# Load cohort distribution
plant_cohorts = pd.read_csv(
    "../../data/derived/plant/plant_functional_type/plant_functional_type_cohort_distribution_per_hectare.csv"
)

# Determine cohorts per cell
n_cohorts_per_cell = len(plant_cohorts)

# Define plant cohort dimensions (note that Python starts counting from 0, not 1)
n_cohorts = n_cells * n_cohorts_per_cell
cohort_index = np.arange(n_cohorts)

# Add cohort configurations to data
data["plant_cohorts_n"] = DataArray(
    np.tile(plant_cohorts["plant_cohorts_n"].values, n_cells),
    coords={"cohort_index": cohort_index},
)
data["plant_cohorts_pft"] = DataArray(
    np.tile(plant_cohorts["plant_cohorts_pft"].values, n_cells),
    coords={"cohort_index": cohort_index},
)
data["plant_cohorts_cell_id"] = DataArray(
    np.repeat(cell_id, n_cohorts_per_cell), coords={"cohort_index": cohort_index}
)
data["plant_cohorts_dbh"] = DataArray(
    np.tile(plant_cohorts["plant_cohorts_dbh"].values, n_cells),
    coords={"cohort_index": cohort_index},
)

# Subcanopy vegetation
# Spatio-temporal data
data["subcanopy_vegetation_biomass"] = DataArray(
    data=np.full((n_cells,), fill_value=0.07),
    coords={"cell_id": cell_id},
)
data["subcanopy_seedbank_biomass"] = DataArray(
    data=np.full((n_cells,), fill_value=0.07),
    coords={"cell_id": cell_id},
)

# Spatio-temporal data
data["downward_shortwave_radiation"] = DataArray(
    data=np.full((n_cells, n_dates), fill_value=2040),
    coords={"cell_id": cell_id, "time_index": time_index},
)


data["time"] = DataArray(time, coords={"time_index": time_index})

data.to_netcdf("plant_data.nc")
