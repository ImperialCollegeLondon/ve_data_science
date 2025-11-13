#| ---
#| title: Plant input data Maliau 50x50
#|
#| description: |
#|     This script generates a NetCDF file that is part of the plant input data.
#|     It contains the variables:
#|     -plant_pft_propagules
#|     -downward_shortwave_radiation
#|     -subcanopy_vegetation_biomass
#|     -subcanopy_seedbank_biomass
#|     -time
#|     And contains the dimensions:
#|     -cell_id
#|     -pft
#|     -time_index
#|
#| virtual_ecosystem_module:
#|   - Plants
#|
#| author:
#|   - Arne Scheire
#|
#| status: final
#|
#| input_files:
#|   - name: plant_functional_type_cohort_distribution_Maliau_50x50.csv
#|     path: data/derived/plant/plant_functional_type
#|     description: |
#|       This CSV file contains an overview of the individuals per
#|       DBH class for each PFT, for each cell.
#|
#| output_files:
#|   - name: plant_input_data_Maliau_50x50.nc
#|     path: data/derived/plant/netcdf_plant_input_data
#|     description: |
#|       This NetCDF file contains the plant input data for plant_pft_propagules,
#|       downward_shortwave_radiation, subcanopy_vegetation_biomass,
#|       subcanopy_seedbank_biomass and time.
#|
#| package_dependencies:
#|     - RNetCDF
#|     - ncdf4
#|
#| usage_notes: |
#|   For now the data in this script are generated manually, using the base values
#|   from the VE example. These values should be updated according to values that
#|   more closely represent the Maliau site.
#|   This script can be used as a base to prepare the input data for other
#|   simulations, although the data will change depending on grid and time used
#|   in that particular simulation.
#| ---


# Load packages

library(RNetCDF)
library(ncdf4)

# Load the Maliau cohort distribution
cohort_distribution <- read.csv(
  "../../../data/derived/plant/plant_functional_type/plant_functional_type_cohort_distribution_Maliau_50x50.csv", # nolint
  header = TRUE
)

#####

# Obtain variable axes
# (see plant data under https://virtual-ecosystem.readthedocs.io/en/latest/using_the_ve/example_data.html#data-files) # nolint

# -plant_pft_propagules: cell_id and pft
# -subcanopy_vegetation_biomass: cel_id
# -subcanopy_seedbank_biomass: cell_id
# -downward_shortwave_radiation: cell_id and time_index
# -time: time_index

# Define the dimensions for these axes

# cell_id
n_cells <- max(cohort_distribution$plant_cohorts_cell_id)
cell_id_index <- unique(cohort_distribution$plant_cohorts_cell_id)

# pft
n_pft <- length(unique(cohort_distribution$plant_cohorts_pft))
print(unique(cohort_distribution$plant_cohorts_pft))
pft_index <- unique(cohort_distribution$plant_cohorts_pft)

# time_index
# The time_index depends on the intended runtime of the simulation
# For the Maliau site, use 10 years (2010-2020) with monthly intervals and
# express using seconds since 1970-01-01 UTC (Unix epoch reference time)
# Note that this matches the time_index used in the abiotic model
generate_monthly_timestamps <-
  function(start = "2010-01-01", end = "2020-12-31") {
    time <- seq(as.Date(start), as.Date(end), by = "month")
    as.numeric(as.POSIXct(time, tz = "UTC"))
  }

time_index <- generate_monthly_timestamps()

#####

# Generate the data for the desired variables, taking the axes into account,
# also check variable type (i.e., numeric / integer)
# Note that these could also be loaded (e.g., from CSV), which will likely
# happen when more detailed data for these variables are prepared through
# analysis scripts

# plant_pft_propagules: matrix of cell_id by pft (so 4 by 250)
# Use fill value = 100
plant_pft_propagules <-
  matrix(as.integer(100), nrow = length(pft_index), ncol = length(cell_id_index))

# downward_shortwave_radiation: matrix of cell_id by time_index (so 132 by 250)
# Use fill value = 2040
downward_shortwave_radiation <-
  matrix(as.integer(2040), nrow = length(time_index), ncol = length(cell_id_index))

# subcanopy_vegetation_biomass: cell_id only
# Use fill value = 0.7
subcanopy_vegetation_biomass <-
  as.numeric(matrix(0.07, nrow = 1, ncol = length(cell_id_index)))

# subcanopy_seedbank_biomass: cell_id only
# Use fill value = 0.7
subcanopy_seedbank_biomass <-
  as.numeric(matrix(0.07, nrow = 1, ncol = length(cell_id_index)))

# time: time_index only (use values calculated for time_index)
time <-
  as.integer(matrix(time_index, nrow = 1, ncol = length(time_index)))

#####

# Open NetCDF file
nc <-
  create.nc("../../../data/derived/plant/netcdf_plant_input_data/plant_input_data_Maliau_50x50.nc", format = "netcdf4") # nolint

# Define dimensions
dim.def.nc(nc, "cell_id", length(cell_id_index))
dim.def.nc(nc, "pft", length(pft_index))
dim.def.nc(nc, "time", length(time_index))

# Define variables (integer = NC_UINT, numeric = NC_FLOAT, character = NC_STRING)
# The arguments are: nc file name in R, data type, dimension names
# Note that the order of dimensions is "flipped"
var.def.nc(nc, "plant_pft_propagules", "NC_UINT", c("pft", "cell_id"))
var.def.nc(nc, "downward_shortwave_radiation", "NC_UINT", c("time", "cell_id"))
var.def.nc(nc, "subcanopy_vegetation_biomass", "NC_FLOAT", "cell_id")
var.def.nc(nc, "subcanopy_seedbank_biomass", "NC_FLOAT", "cell_id")
var.def.nc(nc, "time", "NC_UINT", "time")
var.def.nc(nc, "pft", "NC_STRING", "pft")

# Write the data to variables
var.put.nc(nc, "plant_pft_propagules", plant_pft_propagules)
var.put.nc(nc, "downward_shortwave_radiation", downward_shortwave_radiation)
var.put.nc(nc, "subcanopy_vegetation_biomass", subcanopy_vegetation_biomass)
var.put.nc(nc, "subcanopy_seedbank_biomass", subcanopy_seedbank_biomass)
var.put.nc(nc, "time", time)
var.put.nc(nc, "pft", pft_index)

# Sync data to file and close.
sync.nc(nc)
close.nc(nc)

# Load data file and check it
# Here we use NCDF4 for exploration in RStudio (as RNetCDF cannot do this)
plant_input_data_Maliau_50x50 <-
  nc_open("../../../data/derived/plant/netcdf_plant_input_data/plant_input_data_Maliau_50x50.nc") # nolint

names(plant_input_data_Maliau_50x50$var)
ncvar_get(plant_input_data_Maliau_50x50, "plant_pft_propagules")
ncvar_get(plant_input_data_Maliau_50x50, "downward_shortwave_radiation")
ncvar_get(plant_input_data_Maliau_50x50, "subcanopy_vegetation_biomass")
ncvar_get(plant_input_data_Maliau_50x50, "subcanopy_seedbank_biomass")

ncvar_get(plant_input_data_Maliau_50x50, "time")
ncvar_get(plant_input_data_Maliau_50x50, "pft")

# Close
nc_close(plant_input_data_Maliau_50x50)
