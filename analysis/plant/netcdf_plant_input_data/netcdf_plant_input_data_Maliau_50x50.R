#| ---
#| title: NetCDF plant input data Maliau 50x50
#|
#| description: |
#|     This script generates a NetCDF file that is part of the plant input data.
#|     It contains the variables:
#|     -plant_pft_propagules
#|     -subcanopy_vegetation_biomass
#|     -subcanopy_seedbank_biomass
#|     And contains the dimensions:
#|     -cell_id
#|     -pft
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

# Define the dimensions for these axes

# cell_id
n_cells <- length(unique(cohort_distribution$plant_cohorts_cell_id))
cell_id_index <- unique(cohort_distribution$plant_cohorts_cell_id)

# pft
n_pft <- length(unique(cohort_distribution$plant_cohorts_pft))
print(unique(cohort_distribution$plant_cohorts_pft))
pft_index <- unique(cohort_distribution$plant_cohorts_pft)

#####

# Generate the data for the desired variables, taking the axes into account,
# also check variable type (i.e., numeric / integer)
# Note that these could also be loaded (e.g., from CSV), which will likely
# happen when more detailed data for these variables are prepared through
# analysis scripts

# plant_pft_propagules: matrix of cell_id by pft (so 4 by 2500)

# First estimate the germinated recruits prior to seedling mortality for
# emergent, overstory and understory as recruits per hectare per year
# (from Kuusipalo et al., 1996; DOI: https://doi.org/10.1016/0378-1127(95)03654-7)
# divided by seedling survival 0.9007 (0.84^(12/20) from Kuusipalo et al., 1996;
# DOI: https://doi.org/10.1016/0378-1127(95)03654-7).
# Next, divide this number by the germination rate 0.0115
# (0.023 / 2 to get yearly rate from Kennedy, D. N., & Swaine, M. D., 1992;
# DOI: https://doi.org/10.1098/rstb.1992.0027).
# The result represents the number of propagules across PFTs in the seedbank.
# Then distribute this number across the 3 PFTs, assuming no initial seedbank
# for pioneers in primary forest (based on findings by Miyamoto et al., 2024;
# DOI: https://doi.org/10.3759/tropics.MS23-09).
# Note that 0 pioneers found by Miyamoto et al. was based on a 50x50m plot.
# If that plot is really mature and closed-canopy, then 0 pioneer recruits
# >5cm dbh is believable although throughout the Maliau landscape some cells
# are going to have canopy gaps, and then there will be non-zero pioneer recruits
# >5cm dbh. This does not break the line of reasoning here but it is something
# we'll need to consider when implementing variation across cells later.
# Also note that canopy gaps will be much smaller than the cell area used so
# to account for this within cells we'd have to increase the overall
# pioneer seedbank for a specific cell that is expected to have more canopy gaps.
# This would also require the recruitment probability in these cells to
# be different, and preferably PFT specific (at the moment this is a constant).
# Note: for pioneers in logged forest, we can use fill value = 1000 m-2 using
# value from Metcalfe and Turner (1998; https://www.jstor.org/stable/2559870)
# Then scale this according to the cell area used (here 10000 m2)

# First set up the empty structure, we will then add the propagules per PFT

plant_pft_propagules <-
  matrix(as.integer(0), nrow = length(pft_index), ncol = length(cell_id_index))

# Calculate recruits per hectare, using "Recruitment of new seedlings" for
# Plot 3, which is the unlogged forest
# Note that we need to standardize the values to per year (instead of per
# 20 months; July 1990 - February 1992)
# Also note that the values are reported per 100 m2, so convert this to hectare
# by multiplying by 100

recruits_per_hectare <- (121 * 100) / 20 * 12 # converted to per hectare per year

seedling_survival_rate <- 0.84^(12 / 20) # converted to per year

recruits_per_hectare_without_mortality <- # nolint
  recruits_per_hectare / seedling_survival_rate # these represent germinated seeds

germination_rate <- 0.023 / 2 # converted to per year

seedbank <-
  recruits_per_hectare_without_mortality / germination_rate # all seeds across PFTs # nolint

# Distribute seedbank evenly across PFTs, assuming no seedbank for pioneers
# Round down to avoid decimal seeds

seedbank_emergent <- floor(seedbank / 3)
seedbank_overstory <- floor(seedbank / 3)
seedbank_understory <- floor(seedbank / 3)
seedbank_pioneer <- 0

# Now add these to plant_pft_propagules
pft_index

# 1 = emergent, 2 = overstory, 3 = pioneer, 4 = understory

plant_pft_propagules[1, ] <- seedbank_emergent
plant_pft_propagules[2, ] <- seedbank_overstory
plant_pft_propagules[3, ] <- seedbank_pioneer
plant_pft_propagules[4, ] <- seedbank_understory

#####

# Load the subcanopy parameters
subcanopy_parameters <- read.csv(
  "../../../data/derived/plant/subcanopy/subcanopy_parameters.csv", # nolint
  header = TRUE
)

# subcanopy_vegetation_biomass: cell_id only
# Use value from subcanopy_parameters
subcanopy_vegetation_biomass <-
  as.numeric(matrix(
    subcanopy_parameters$subcanopy_vegetation_biomass,
    nrow = 1,
    ncol = length(cell_id_index)
  ))

# subcanopy_seedbank_biomass: cell_id only
# Use value from subcanopy_parameters
subcanopy_seedbank_biomass <-
  as.numeric(matrix(
    subcanopy_parameters$subcanopy_seedbank_biomass,
    nrow = 1,
    ncol = length(cell_id_index)
  ))

#####

# Open NetCDF file
nc <-
  create.nc(
    "../../../data/derived/plant/netcdf_plant_input_data/plant_input_data_Maliau_50x50.nc",
    format = "netcdf4"
  ) # nolint

# Define dimensions
dim.def.nc(nc, "cell_id", length(cell_id_index))
dim.def.nc(nc, "pft", length(pft_index))

# Define variables (integer = NC_UINT, numeric = NC_FLOAT, character = NC_STRING)
# The arguments are: nc file name in R, data type, dimension names
# Note that the order of dimensions is "flipped"
var.def.nc(nc, "plant_pft_propagules", "NC_INT", c("pft", "cell_id"))
var.def.nc(nc, "subcanopy_vegetation_biomass", "NC_FLOAT", "cell_id")
var.def.nc(nc, "subcanopy_seedbank_biomass", "NC_FLOAT", "cell_id")
var.def.nc(nc, "cell_id", "NC_INT", "cell_id")
var.def.nc(nc, "pft", "NC_STRING", "pft")

# Write the data to variables
var.put.nc(nc, "plant_pft_propagules", plant_pft_propagules)
var.put.nc(nc, "subcanopy_vegetation_biomass", subcanopy_vegetation_biomass)
var.put.nc(nc, "subcanopy_seedbank_biomass", subcanopy_seedbank_biomass)
var.put.nc(nc, "cell_id", cell_id_index)
var.put.nc(nc, "pft", pft_index)

# Sync data to file and close.
sync.nc(nc)
close.nc(nc)

# Load data file and check it
# Here we use NCDF4 for exploration in RStudio (as RNetCDF cannot do this)
plant_input_data_Maliau_50x50 <-
  nc_open(
    "../../../data/derived/plant/netcdf_plant_input_data/plant_input_data_Maliau_50x50.nc"
  ) # nolint

names(plant_input_data_Maliau_50x50$var)
ncvar_get(plant_input_data_Maliau_50x50, "plant_pft_propagules")
ncvar_get(plant_input_data_Maliau_50x50, "subcanopy_vegetation_biomass")
ncvar_get(plant_input_data_Maliau_50x50, "subcanopy_seedbank_biomass")

ncvar_get(plant_input_data_Maliau_50x50, "cell_id")
ncvar_get(plant_input_data_Maliau_50x50, "pft")

# Close
nc_close(plant_input_data_Maliau_50x50)
