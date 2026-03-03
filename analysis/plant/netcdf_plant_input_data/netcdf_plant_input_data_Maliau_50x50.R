#| ---
#| title: NetCDF plant input data Maliau 50x50
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
#|   - name: subcanopy_parameters.csv
#|     path: data/derived/plant/subcanopy
#|     description: |
#|       This CSV file contains the subcanopy parameters, which are part of the
#|       plant model constants.
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
#|   Some of the data in this script are generated manually, using the base values
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
n_cells <- length(unique(cohort_distribution$plant_cohorts_cell_id))
cell_id_index <- unique(cohort_distribution$plant_cohorts_cell_id)

# pft
n_pft <- length(unique(cohort_distribution$plant_cohorts_pft))
print(unique(cohort_distribution$plant_cohorts_pft))
pft_index <- unique(cohort_distribution$plant_cohorts_pft)

# time_index
# The time_index depends on the intended runtime of the simulation
# For the Maliau site, use 11 years (2010-2020) with monthly intervals and
# express:
# -using days since origin (in this case 2010-01-01) OR
# -converting these days since origin to actual dates

# Approach suggested by David, following current implementation of time in VE
generate_timestamps <- function(
  start = "2010-01-01",
  end = "2020-12-31",
  interval_in_days = 30.4375
) {
  # Get the start and end as datetime objects and find the runtime as a difftime
  start <- as.POSIXct(start)
  end <- as.POSIXct(end)
  interval <- as.difftime(interval_in_days, units = "days")
  config_runtime <- (end - start)

  # Check the difftimes use the same units
  stopifnot(
    attr(config_runtime, "units") == "days" &&
      attr(interval, "units") == "days"
  )

  # Get the time sequence, which can extend the actual runtime to fit the last iteration
  n_updates <- ceiling(unclass(config_runtime) / unclass(interval))
  time_indices <- seq(0, n_updates - 1)
  diffs <- interval * time_indices
  interval_starts <- start + diffs

  # Converts start datetimes to dates, which truncates to day
  interval_starts <- as.Date(format(interval_starts, "%Y-%m-%d"))

  return(list(interval_starts = interval_starts, time_indices = time_indices))
}

timestamps <- generate_timestamps()
time_index <- timestamps$time_indices
interval_starts <- timestamps$interval_starts

# Define the time unit (do not use start of simulation as reference date, as this
# gives -1 for the first index)
time_unit <- "days since 2010-01-01"
# RNetCDF::utinvcal.nc can convert POSIXct to the specified time unit
time <- utinvcal.nc(time_unit, as.POSIXct(interval_starts))

#####

# Generate the data for the desired variables, taking the axes into account,
# also check variable type (i.e., numeric / integer)
# Note that these could also be loaded (e.g., from CSV), which will likely
# happen when more detailed data for these variables are prepared through
# analysis scripts

# plant_pft_propagules: matrix of cell_id by pft (so 4 by 250)
# Use fill value = 1000 using value reported in Metcalfe and Turner (1998;
# https://www.jstor.org/stable/2559870)
plant_pft_propagules <-
  matrix(as.integer(1000), nrow = length(pft_index), ncol = length(cell_id_index))

# downward_shortwave_radiation: matrix of cell_id by time_index (so 132 by 250)
# Use fill value = 2040
downward_shortwave_radiation <-
  matrix(as.integer(2040), nrow = length(time_index), ncol = length(cell_id_index))

# Load the subcanopy parameters
subcanopy_parameters <- read.csv(
  "../../../data/derived/plant/subcanopy/subcanopy_parameters.csv", # nolint
  header = TRUE
)

# subcanopy_vegetation_biomass: cell_id only
# Use value from subcanopy_parameters
subcanopy_vegetation_biomass <-
  as.numeric(matrix(subcanopy_parameters$subcanopy_vegetation_biomass,
    nrow = 1, ncol = length(cell_id_index)
  ))

# subcanopy_seedbank_biomass: cell_id only
# Use value from subcanopy_parameters
subcanopy_seedbank_biomass <-
  as.numeric(matrix(subcanopy_parameters$subcanopy_seedbank_biomass,
    nrow = 1, ncol = length(cell_id_index)
  ))

#####

# Open NetCDF file
nc <-
  create.nc("../../../data/derived/plant/netcdf_plant_input_data/plant_input_data_Maliau_50x50.nc", format = "netcdf4") # nolint

# Define dimensions
dim.def.nc(nc, "cell_id", length(cell_id_index))
dim.def.nc(nc, "pft", length(pft_index))
dim.def.nc(nc, "time_index", length(time_index))

# Define variables (integer = NC_UINT, numeric = NC_FLOAT, character = NC_STRING)
# The arguments are: nc file name in R, data type, dimension names
# Note that the order of dimensions is "flipped"
var.def.nc(nc, "plant_pft_propagules", "NC_INT", c("pft", "cell_id"))
var.def.nc(nc, "downward_shortwave_radiation", "NC_DOUBLE", c("time_index", "cell_id"))
var.def.nc(nc, "subcanopy_vegetation_biomass", "NC_FLOAT", "cell_id")
var.def.nc(nc, "subcanopy_seedbank_biomass", "NC_FLOAT", "cell_id")
var.def.nc(nc, "time", "NC_DOUBLE", "time_index")
var.def.nc(nc, "cell_id", "NC_INT", "cell_id")
var.def.nc(nc, "pft", "NC_STRING", "pft")
var.def.nc(nc, "time_index", "NC_INT", "time_index")

# For time, also need to add the attributes so that the actual dates can be
# calculated from days since reference date
att.put.nc(nc, "time", "long_name", "NC_CHAR", "time")
att.put.nc(nc, "time", "units", "NC_CHAR", time_unit)

# Write the data to variables
var.put.nc(nc, "plant_pft_propagules", plant_pft_propagules)
var.put.nc(nc, "downward_shortwave_radiation", downward_shortwave_radiation)
var.put.nc(nc, "subcanopy_vegetation_biomass", subcanopy_vegetation_biomass)
var.put.nc(nc, "subcanopy_seedbank_biomass", subcanopy_seedbank_biomass)
var.put.nc(nc, "time", time)
var.put.nc(nc, "cell_id", cell_id_index)
var.put.nc(nc, "pft", pft_index)
var.put.nc(nc, "time_index", time_index)

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

ncvar_get(plant_input_data_Maliau_50x50, "cell_id")
ncvar_get(plant_input_data_Maliau_50x50, "pft")
ncvar_get(plant_input_data_Maliau_50x50, "time_index")

# Close
nc_close(plant_input_data_Maliau_50x50)
