#| ---
#| title: plant_input_data_maliau_2
#|
#| description: |
#|     This script prepares the NetCDF file containing plant_pft_propagules,
#|     subcanopy_vegetation_biomass and subcanopy_seedbank_biomass for the
#|     maliau_2 scenario.
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
#|   - name: maliau_2_cohort_data_1_cm.csv
#|     path: data/derived/plant/input_data/scenarios/maliau_2
#|     description: |
#|       Cohorts below the 10 cm census threshold are estimated from the
#|       difference between modelled total basal area for stems at or above 1 cm
#|       DBH and modelled basal area for stems above 10 cm DBH. The missing basal
#|       area is converted to stem numbers using assumed 1–2 cm, 2–5 cm and
#|       5–10 cm size-class fractions, then allocated across PFTs using cell-level
#|       PFT abundance.
#|   - name: maliau_grid_definition.toml
#|     path: data/derived/site/maliau
#|     description: |
#|       TOML configuration file containing grid and timing definitions for the
#|       Maliau scenarios, including the cell coordinates used here.
#|   - name: t_model_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       A CSV file listing T-model parameters by pft.
#|   - name: subcanopy_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       This CSV file contains the subcanopy parameters used as plant model
#|       constants in the plant input data library workflow.
#|   - name: dobert_subcanopy_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       This CSV file contains the subcanopy vegetation and seedbank carbon mass
#|       at plot level. The file is used for spatial predictions in the scenario
#|       scripts.
#|   - name: dobert_2019_plot_species_trait_data.xlsx
#|     path: data/primary/plant/traits_data
#|     description: |
#|       https://doi.org/10.5281/zenodo.2536270
#|       Dobert et al. (2019) plot, species, trait, and location data used to
#|       interpolate subcanopy vegetation biomass across the scenario grid.
#|       The script reads the Locations, DoebertTF_SAFE_PlotData, and
#|       DoebertTF_SAFE_PlotSpeciesMeasu sheets.
#|   - name: Maliau LiDAR raster collection (*.tif)
#|     path: data/primary/plant/lidar
#|     description: |
#|       LiDAR-derived raster layers loaded dynamically from this directory.
#|       Each available raster is evaluated as a candidate predictor of
#|       subcanopy vegetation biomass. For the current parameterisation,
#|       Maliau_pad_mean.tif was selected as the predictor with the strongest
#|       univariate fit; a different raster may be selected for another run.
#|
#| output_files:
#|   - name: plant_input_data_maliau_2.nc
#|     path: data/derived/plant/input_data/scenarios/maliau_2
#|     description: |
#|       NetCDF file containing spatially distributed plant propagule and
#|       subcanopy vegetation and seedbank carbon mass for the Maliau 2 scenario.
#|       The file contains cell_id and pft dimensions; plant_pft_propagules is
#|       stored over pft by cell_id, while the subcanopy variables are stored
#|       over cell_id only.
#|     variables:
#|       - name: cell_id
#|         type: integer
#|         units: dimensionless
#|         description: |
#|           Zero-based identifier for each scenario grid cell.
#|         references:
#|           - citation: "maliau_grid_definition.toml"
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: |
#|           Cell identifiers are assigned by matching each grid-cell centre's
#|           coordinates to the scenario grid definition. The numbering starts
#|           at the bottom-left cell, then proceeds from left to right within
#|           each row and from bottom to top across rows.
#|       - name: pft
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Plant functional type name.
#|         references:
#|           - citation: "maliau_2_cohort_data_1_cm.csv"
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: |
#|           PFT categories are inherited from the scenario cohort distribution
#|           and define the pft dimension of the NetCDF file.
#|       - name: plant_pft_propagules
#|         type: integer
#|         units: propagules cell-1
#|         description: |
#|           Number of plant propagules per PFT and scenario grid cell.
#|         references:
#|           - citation: "t_model_maliau.csv"
#|             doi: null
#|             url: null
#|             origin: "Virtual Ecosystem plant input data library"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "maliau_2_cohort_data_1_cm.csv"
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: |
#|           Total propagules per hectare from t_model_maliau.csv are scaled to
#|           the scenario cell area. The resulting total is distributed among
#|           PFTs according to each cell's relative cohort abundance from
#|           maliau_2_cohort_data_1_cm.csv, and values are rounded to whole
#|           propagules.
#|       - name: subcanopy_vegetation_biomass
#|         type: numeric
#|         units: kg C m-2
#|         description: |
#|           Spatially predicted subcanopy vegetation carbon mass per unit area.
#|         references:
#|           - citation: "subcanopy_maliau.csv"
#|             doi: null
#|             url: null
#|             origin: "Virtual Ecosystem plant input data library"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "dobert_subcanopy_maliau.csv"
#|             doi: null
#|             url: null
#|             origin: "Virtual Ecosystem plant input data library"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: null
#|           - citation: "dobert_2019_plot_species_trait_data.xlsx"
#|             doi: "https://doi.org/10.5281/zenodo.2536270"
#|             url: "https://zenodo.org/records/2536270"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2014"
#|           - citation: "Maliau_pad_mean.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_acd.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_chm.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_dtm.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_pad_canopy_height.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_pad_kurt.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_pad_n_layers.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_pad_shannon.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_pad_shape.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_pad_skew.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_pad_std.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_pai.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_pai_02_10m.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_pai_10_20m.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_pai_20_30m.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_pai_30_40m.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_pai_40_50m.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_pai_50_60m.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_pai_60_70m.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_pai_70_80m.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_point_density.tif"
#|             doi: null
#|             url: null
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|         assumptions: |
#|           Observed plot-level biomass from the Dobert-derived input is joined
#|           to values extracted from every available LiDAR raster. A separate
#|           univariate linear model is fitted for each candidate predictor and
#|           the predictor with the highest R-squared is selected. For the
#|           current parameterisation, this is Maliau_pad_mean.tif. That raster
#|           is extracted at each grid-cell centre, the fitted model is used to
#|           predict biomass, negative predictions are clipped to zero, and the
#|           results are ordered by cell_id before being written as one value for
#|           each cell. The selected predictor should be re-evaluated when the
#|           script is reused with another calibration dataset or scenario.
#|       - name: subcanopy_seedbank_biomass
#|         type: numeric
#|         units: kg C m-2
#|         description: |
#|           Spatially distributed subcanopy seedbank carbon mass per unit area.
#|         references:
#|           - citation: "subcanopy_maliau.csv"
#|             doi: null
#|             url: null
#|             origin: "Virtual Ecosystem plant input data library"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|         assumptions: |
#|           Seedbank biomass is calculated for each cell by applying the
#|           vegetation-to-seedbank ratio from subcanopy_maliau.csv to the
#|           spatially predicted vegetation biomass. The ratio is assumed to be
#|           constant across the scenario grid.
#|
#| package_dependencies:
#|     - RNetCDF
#|     - ncdf4
#|     - RcppTOML
#|     - readxl
#|     - sf
#|     - ggplot2
#|     - terra
#|
#| usage_notes: |
#|   Run from this script's directory because input and output paths are
#|   relative. The script currently targets the maliau_2 scenario and writes a
#|   NetCDF file with cell and PFT dimensions. Propagules are distributed from
#|   local cohort abundance, vegetation biomass is spatially predicted, and
#|   seedbank biomass is derived from the vegetation-to-seedbank ratio.
#| ---

# Load packages

library(RNetCDF)
library(ncdf4)
library(RcppTOML)
library(readxl)
library(sf)
library(ggplot2)
library(terra)


# Approach explained:

####################

# Load the Maliau cohort distribution
cohort_distribution <- read.csv(
  "../../../../data/derived/plant/input_data/scenarios/maliau_2/maliau_2_cohort_data_1_cm.csv",
  header = TRUE
)

# Load the T model parameters to gain access to base propagules calculation
t_model_maliau <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/t_model_maliau.csv",
  header = TRUE
)

# Load Site Grid Definition File
site_definition <- parseTOML(
  "../../../../data/derived/site/maliau/maliau_grid_definition.toml"
)

site <- "maliau_2"
site_def <- site_definition$Scenario[[site]]

cell_x_centres <- site_def$cell_x_centres
cell_y_centres <- site_def$cell_y_centres

# Safely calculate cell length
cell_length <- if (length(cell_x_centres) > 1) {
  cell_x_centres[2] - cell_x_centres[1]
} else {
  NA
}

grid_cells <- expand.grid(
  x = cell_x_centres,
  y = cell_y_centres
)

epsg_code <- site_def$epsg_code
bounds_epsg <- site_def$bounds
bounds_wgs84 <- site_def$wgs84_bounds
n_cells <- site_def$cell_nx * site_def$cell_ny

# Obtain variable axes
# (see plant data under https://virtual-ecosystem.readthedocs.io/en/latest/using_the_ve/example_data.html#data-files)

# -plant_pft_propagules: cell_id and pft
# -subcanopy_vegetation_biomass: cel_id
# -subcanopy_seedbank_biomass: cell_id

# Define the dimensions for these axes

# cell_id
cell_id_index <- 0:(n_cells - 1)

# pft
n_pft <- length(unique(cohort_distribution$plant_cohorts_pft))
print(unique(cohort_distribution$plant_cohorts_pft))
pft_index <- unique(cohort_distribution$plant_cohorts_pft)

####################

# Generate the data for the desired variables, taking the axes into account,
# also check variable type (i.e., numeric / integer)

# plant_pft_propagules: matrix of cell_id by pft (so 4 by 100)

# Approach: use the base propagules calculation from t_model_maliau, which is
# the total propagules per hectare across all pfts.
# We will then distribute these propagules across pfts based on local pft
# abundance, which we already calculated in the cohort distribution. Below are
# some additional thoughts, which mostly just serve as notes for myself.

# We could distribute this number across the 3 PFTs, assuming no initial seedbank
# for pioneers in primary forest (based on findings by Miyamoto et al., 2024;
# DOI: https://doi.org/10.3759/tropics.MS23-09). However, I think it makes more
# sense to distribute seeds based on local PFT density in each of the cells.

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

# Note: for pioneers in logged forest, we could use fill value = 1000 m-2 using
# value from Metcalfe and Turner (1998; https://www.jstor.org/stable/2559870)
# Then scale this according to the cell area used (here 10000 m2)

# First set up the empty structure, we will then add the propagules per PFT

plant_pft_propagules <-
  matrix(as.integer(0), nrow = length(pft_index), ncol = length(cell_id_index))

# take the total number of propagules per hectare from t_model_maliau (the
# column called propagules_per_ha), then calculate the fraction of total stem
# density per pft based on cohort_distribution (column named plant_cohorts_n and
# plant_cohorts_pft), then distribute the total propagules across pfts per cell

propagules_per_ha <- unique(t_model_maliau$propagules_per_ha)

cell_area_ha <- (cell_length^2) / 10000
propagules_per_cell <- propagules_per_ha * cell_area_ha

# Sum stem counts per cell and pft; default = 0 fills missing combinations
# so the resulting matrix aligns directly with plant_pft_propagules
# (rows = pft, columns = cell_id)
pft_abundance <- tapply(
  cohort_distribution$plant_cohorts_n,
  list(
    factor(cohort_distribution$plant_cohorts_pft, levels = pft_index),
    factor(cohort_distribution$cell_id, levels = cell_id_index)
  ),
  sum,
  default = 0
)

cell_totals <- colSums(pft_abundance)

# Divide each cell's stem counts by that cell's total, giving each pft's
# share of stems in that cell. Cells with no stems are left at 0 (instead of
# 0 / 0) so they get 0 propagules.
pft_proportions <- pft_abundance
for (cell in seq_len(ncol(pft_abundance))) {
  if (cell_totals[cell] > 0) {
    pft_proportions[, cell] <- pft_abundance[, cell] / cell_totals[cell]
  }
}

# Round to the nearest whole propagule
plant_pft_propagules <- round(pft_proportions * propagules_per_cell)

# NetCDF expects plant_pft_propagules as an integer (NC_INT, see var.def.nc()
# below), so convert it from double to integer
storage.mode(plant_pft_propagules) <- "integer"

####################

# Note that subcanopy_maliau calculated mean values that could in theory be used
# However, in this script we will try to interpolate Dobert's plot data towards
# the broader Maliau landscape, similar to how we accounted for spatial
# variability in the cohort distribution. We'll keep the mean values in here
# for now so that we can compare our predictions with the mean later.

# Load the subcanopy parameters
subcanopy_maliau <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/subcanopy_maliau.csv",
  header = TRUE
)

# Load dobert_2019_plot_species_data
# This data is derived from during the subcanopy script and contains the carbon
# mass per area (kg C m-2) for subcanopy vegetation and seedbank at plot level.

dobert_subcanopy_maliau <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/dobert_subcanopy_maliau.csv",
  header = TRUE
)

# Load Dobert's original dataset to have access to locations data

dobert_2019_locations_data <-
  read_excel(
    "../../../../data/primary/plant/traits_data/dobert_2019_plot_species_trait_data.xlsx",
    sheet = "Locations",
    col_names = TRUE
  )

# Most are points (rest are NA without coordinates)
unique(dobert_2019_locations_data$Type)
dobert_2019_locations_data <- na.omit(dobert_2019_locations_data)

# Subset and rename columns
names(dobert_2019_locations_data)

dobert_2019_locations_data <-
  dobert_2019_locations_data[, c("Location name", "Longitude", "Latitude")]

colnames(dobert_2019_locations_data) <-
  c("plot_code", "lon_wgs84", "lat_wgs84")

# Add x and y coordinates based on epsg_code specified in maliau_site_definition
# call them x_utm32650 y_utm32650 (so "x_" + "epsg_code")

utm_coords <- sf::st_coordinates(sf::st_transform(
  sf::st_as_sf(
    dobert_2019_locations_data,
    coords = c("lon_wgs84", "lat_wgs84"),
    crs = 4326,
    remove = FALSE
  ),
  crs = epsg_code
))

dobert_2019_locations_data[[paste0("x_utm", epsg_code)]] <- utm_coords[, "X"]
dobert_2019_locations_data[[paste0("y_utm", epsg_code)]] <- utm_coords[, "Y"]

##########

# Load Dobert's original plot data and add it to locations data

dobert_2019_plot_data <-
  read_excel(
    "../../../../data/primary/plant/traits_data/dobert_2019_plot_species_trait_data.xlsx",
    sheet = "DoebertTF_SAFE_PlotData",
    col_names = FALSE
  )

# Clean dataset and create subset based on species classification
colnames(dobert_2019_plot_data) <- dobert_2019_plot_data[10, ]
dobert_2019_plot_data <- dobert_2019_plot_data[
  11:max(nrow(dobert_2019_plot_data)),
]
names(dobert_2019_plot_data)

# Subset columns
# Keep all columns except: field_name and Fragment (with capital letter)
dobert_2019_plot_data <-
  dobert_2019_plot_data[,
    !names(dobert_2019_plot_data) %in% c("field_name", "Fragment")
  ]

# Rename columns
names(dobert_2019_plot_data) <- tolower(gsub(
  "\\.",
  "_",
  names(dobert_2019_plot_data)
))

# Note that fragment (lower case) column contains missing values for OG plots
# We'll need to load/overwrite these from dobert_2019_plot_species_data
# Load Dobert plot species data

dobert_2019_plot_species_data <-
  read_excel(
    "../../../../data/primary/plant/traits_data/dobert_2019_plot_species_trait_data.xlsx",
    sheet = "DoebertTF_SAFE_PlotSpeciesMeasu",
    col_names = FALSE
  )

# Clean dataset and overwrite fragment column to dobert_2019_plot_data
colnames(dobert_2019_plot_species_data) <- dobert_2019_plot_species_data[10, ]
dobert_2019_plot_species_data <- dobert_2019_plot_species_data[
  11:max(nrow(dobert_2019_plot_species_data)),
]
names(dobert_2019_plot_species_data)

# Rename columns
names(dobert_2019_plot_species_data) <- tolower(gsub(
  "\\.",
  "_",
  names(dobert_2019_plot_species_data)
))

# Overwrite fragment column with the values from the species-level sheet,
# matched by plot_code
dobert_2019_plot_data$fragment <- dobert_2019_plot_species_data$fragment[
  match(
    dobert_2019_plot_data$plot_code,
    dobert_2019_plot_species_data$plot_code
  )
]

#####

# Add "lon_wgs84", "lat_wgs84", "x_utm32650" and "y_utm32650" from locations
# data to plot data
location_cols <- c(
  "plot_code",
  "lon_wgs84",
  "lat_wgs84",
  paste0("x_utm", epsg_code),
  paste0("y_utm", epsg_code)
)
dobert_2019_plot_data <- merge(
  dobert_2019_plot_data,
  dobert_2019_locations_data[location_cols],
  by = "plot_code",
  all.x = TRUE
)

# Then add "subcanopy_vegetation_carbon_mass_mean", "subcanopy_seedbank_carbon_mass_mean",
# "subcanopy_vegetation_carbon_mass_plot" and "subcanopy_seedbank_carbon_mass_plot"
# from dobert_subcanopy_maliau to plot data
dobert_2019_plot_data <- merge(
  dobert_2019_plot_data,
  dobert_subcanopy_maliau,
  by = "plot_code",
  all.x = TRUE
)

# At this point, we have all plot data with coordinates, together with the
# subcanopy carbon mass for vegetation and seedbank where measured by Dobert

# The next steps are to plot all plots, together with the coordinates for maliau_2
# Then subset to maliau OG representative data only (OG plots) and spatially
# predict the plot subcanopy vegetation and seedbank carbon mass.

#####

# Load LiDAR Products at Native Resolutions and plot with all Dobert plots

lidar_dir <- file.path("../../../../data/primary/plant/lidar")

lidar_files <- list.files(
  path = lidar_dir,
  pattern = "\\.tif$",
  full.names = TRUE,
  recursive = TRUE
)

# Load rasters into a named list (preserves native resolutions)
lidar_layers <- lapply(lidar_files, terra::rast)
names(lidar_layers) <- tools::file_path_sans_ext(basename(lidar_files))
print(lapply(lidar_layers, terra::res))

# Convert extent to polygon object once for base plotting
boundary_poly <-
  as.polygons(ext(
    bounds_epsg[1],
    bounds_epsg[3],
    bounds_epsg[2],
    bounds_epsg[4]
  ))

# Overlay helper function
add_site_overlay <- function() {
  plot(boundary_poly, add = TRUE, border = "red", lwd = 2)
  points(
    dobert_2019_plot_data$x_utm32650,
    dobert_2019_plot_data$y_utm32650,
    col = "cyan",
    pch = 16,
    cex = 0.8
  )
}

# Canopy height plot
for (layer_name in names(lidar_layers)) {
  plot(lidar_layers[[layer_name]], main = layer_name)
  add_site_overlay()
}

###############################################################################

# Subset dobert_2019_plot_data to only include OG plots with subcanopy vegetation
# and seedbank mass values

dobert_2019_plot_data <- dobert_2019_plot_data[
  !is.na(dobert_2019_plot_data$subcanopy_vegetation_carbon_mass_plot),
]

#####

# Set up model to spatially predict the subcanopy vegetation biomass
#
# This section follows a simple calibration workflow: use observed subcanopy
# biomass at plot locations, compare candidate LiDAR predictors, select the
# strongest predictor, validate the fitted relationship, and then apply the model
# across the Maliau grid.

# Step 1: build the calibration dataset
#
# We need a training dataset linking observed subcanopy biomass to spatial
# predictor variables. The field plots are the observed data, while the LiDAR
# rasters provide the spatial covariates we want to use to predict biomass across
# the landscape.
#
# Create a terra SpatVector from the plot coordinates so the LiDAR rasters can be
# extracted at each plot location.
plots_vect <- vect(
  dobert_2019_plot_data,
  geom = c("x_utm32650", "y_utm32650"),
  crs = "EPSG:32650"
)

# Convert any raster path strings into terra rasters so they can all be analysed
# in the same way.
raster_list <- lapply(lidar_layers, function(x) {
  if (is.character(x)) rast(x) else x
})

# Extract the value of each LiDAR layer at every known plot location.
# The result is a table with one column per predictor.
plot_lidar_extracted <- do.call(
  cbind,
  lapply(raster_list, function(r) {
    extract(r, plots_vect)[, 2, drop = FALSE]
  })
)

# Combine the response variable (measured biomass) with all candidate predictors.
# Each row corresponds to one plot and each column is a covariate used in the
# regression.
model_data <- cbind(
  biomass = dobert_2019_plot_data$subcanopy_vegetation_carbon_mass_plot,
  plot_lidar_extracted
)

# Remove rows where the response or any candidate predictor is missing. This
# ensures that every fitted model is based on complete observations only.
model_data <- model_data[complete.cases(model_data), , drop = FALSE]

# Step 2: screen candidate predictors and compare their fit
#
# We fit a simple univariate regression for every LiDAR layer:
# biomass ~ predictor
# This lets us assess which spatial metric best explains the observed variance in
# subcanopy biomass before choosing a final model.
candidate_predictors <- names(plot_lidar_extracted)

candidate_results <- lapply(candidate_predictors, function(pred_name) {
  fit <- lm(as.formula(paste("biomass ~", pred_name)), data = model_data)
  s <- summary(fit)

  data.frame(
    predictor = pred_name,
    r_squared = s$r.squared,
    p_value = s$coefficients[2, 4],
    rmse = sqrt(mean(residuals(fit)^2)),
    n = nobs(fit),
    stringsAsFactors = FALSE
  )
})

# Bind all candidate models into one comparison table and rank them by R^2.
candidate_results <- do.call(rbind, candidate_results)
candidate_results <- candidate_results[order(-candidate_results$r_squared), ]
print(candidate_results)

# Highlight the subset of candidate predictors that are statistically significant
# at the conventional 5% level. These are the predictors that are worth keeping
# under consideration before we decide on the final single-predictor model.
significant_candidates <- subset(candidate_results, p_value < 0.05)
print(significant_candidates)

# Print the pairwise correlation among the statistically significant candidate
# predictors. This shows whether the viable predictors are carrying similar
# information or whether they represent distinct signals that could be worth
# combining in a small multi-predictor check.

significant_predictors <- as.character(significant_candidates$predictor)
if (length(significant_predictors) > 1) {
  correlation_matrix <- cor(
    model_data[, significant_predictors],
    use = "complete.obs"
  )
  print(round(correlation_matrix, 3))
} else if (length(significant_predictors) == 1) {
  cat(
    "Only one candidate predictor is statistically significant; no pairwise correlation matrix is printed.\n"
  )
} else {
  cat(
    "No candidate predictors are statistically significant; no pairwise correlation matrix is printed.\n"
  )
}

# Step 3: select the best predictor and fit the final model
#
# A single-predictor model is used as the default because it is simpler, more
# interpretable, and less prone to overfitting with the limited calibration data.
selected_predictor <- as.character(candidate_results$predictor[1])
final_model <- lm(
  as.formula(paste("biomass ~", selected_predictor)),
  data = model_data
)

# Summarise the final model fit so that we can see whether the chosen predictor is
# statistically credible and how much variance it explains.
model_summary <- summary(final_model)
cat(sprintf(
  "\n=== FINAL BIOMASS MODEL ===\nSelected predictor: %s\nR²: %.4f | RSE: %.4f | p-value: %.5e\n\n",
  selected_predictor,
  model_summary$r.squared,
  model_summary$sigma,
  pf(
    model_summary$fstatistic[1],
    model_summary$fstatistic[2],
    model_summary$fstatistic[3],
    lower.tail = FALSE
  )
))

# Step 4: Compare the fitted model at observed plot locations
#
# This is an in-sample validation step: the model is asked to predict biomass at
# the same plot locations used to fit it. In other words, the model sees the
# observed plot data it was trained on, so this checks how well the relationship
# reproduces the calibration data. It does not test extrapolation to new spatial
# locations; that happens in Step 5 when we predict across the whole grid.
#
# This is a useful diagnostic because it tells us whether the chosen predictor is
# capturing the biomass signal in a sensible way before we use it for landscape
# predictions.
observed_predictions <- predict(
  final_model,
  newdata = model_data,
  interval = "prediction",
  level = 0.95
)

# Store observed and predicted biomass values, along with prediction intervals and
# the residual difference (observed minus predicted). The residual is useful for
# understanding whether the model tends to over- or under-estimate biomass.
validation_df <- data.frame(
  observed = model_data$biomass,
  predicted = observed_predictions[, "fit"],
  residual = model_data$biomass - observed_predictions[, "fit"],
  lwr_95 = observed_predictions[, "lwr"],
  upr_95 = observed_predictions[, "upr"]
)

# Summarise prediction quality using RMSE, MAE, and R^2.
validation_stats <- data.frame(
  n = nrow(validation_df),
  rmse = sqrt(mean((validation_df$observed - validation_df$predicted)^2)),
  mae = mean(abs(validation_df$observed - validation_df$predicted)),
  r_squared = cor(validation_df$observed, validation_df$predicted)^2
)

print(validation_stats)
print(head(validation_df))

# A quick visual check: points close to the 1:1 line indicate good agreement
# between observed and predicted biomass.
plot(
  validation_df$observed,
  validation_df$predicted,
  xlab = "Observed biomass",
  ylab = "Predicted biomass",
  main = "Observed vs predicted subcanopy vegetation biomass",
  pch = 16,
  col = "forestgreen"
)
abline(0, 1, col = "red", lty = 2)

# Step 5: predict across the Maliau grid cells
#
# Once the final model is chosen, we apply it to every cell in the study area by
# extracting the same predictor variable at each cell centre and predicting the
# biomass at that location.
prediction_grid <- data.frame(
  x_utm32650 = grid_cells$x,
  y_utm32650 = grid_cells$y
)

grid_vect <- vect(
  prediction_grid,
  geom = c("x_utm32650", "y_utm32650"),
  crs = "EPSG:32650"
)

# Extract the selected LiDAR field value for each cell.
prediction_grid[[selected_predictor]] <- extract(
  raster_list[[selected_predictor]],
  grid_vect
)[, 2]

# Predict biomass for each cell using the final fitted model.
preds <- predict(
  final_model,
  newdata = prediction_grid,
  interval = "prediction",
  level = 0.95
)

# Save the predicted mean and uncertainty bounds for each cell.
prediction_grid$predicted_biomass <- preds[, "fit"]
prediction_grid$lwr_95 <- preds[, "lwr"]
prediction_grid$upr_95 <- preds[, "upr"]

# Step 6: post-process predictions for ecological realism
#
# Biomass cannot be negative, so values below zero are truncated to zero. Cells
# with missing LiDAR values cannot be predicted by the model; these are treated as
# zero biomass in the final grid so that missing values do not enter the input
# file. The same treatment is applied to the prediction interval bounds.
prediction_grid$predicted_biomass_clipped <- ifelse(
  is.na(prediction_grid$predicted_biomass),
  0,
  pmax(0, prediction_grid$predicted_biomass)
)
prediction_grid$lwr_95_clipped <- ifelse(
  is.na(prediction_grid$lwr_95),
  0,
  pmax(0, prediction_grid$lwr_95)
)
prediction_grid$upr_95_clipped <- ifelse(
  is.na(prediction_grid$upr_95),
  0,
  pmax(0, prediction_grid$upr_95)
)

# Print a quick summary of the resulting spatial predictions to confirm that the
# model output is numerically sensible before export.
cat(sprintf(
  "Total cells: %d | Valid predictions: %d | Missing values: %d\n\n",
  nrow(prediction_grid),
  sum(!is.na(prediction_grid$predicted_biomass)),
  sum(is.na(prediction_grid$predicted_biomass))
))

print(summary(prediction_grid[, c(
  "predicted_biomass_clipped",
  "lwr_95_clipped",
  "upr_95_clipped"
)]))
head(prediction_grid)

# For the final NetCDF export, use the clipped spatial prediction as the cell-wise
# subcanopy vegetation biomass estimate. The seedbank biomass can be derived from
# this in a separate, explicit step if required.

#####

# Step 7: Add cell_id to each set of spatial coordinates in prediction_grid

cell_id_origin <- "bottom-left"

grid_order <- order(
  if (cell_id_origin == "top-left") {
    -prediction_grid$y_utm32650
  } else {
    prediction_grid$y_utm32650
  },
  prediction_grid$x_utm32650
)
prediction_grid$cell_id <- NA_integer_
prediction_grid$cell_id[grid_order] <- seq_len(nrow(prediction_grid)) - 1L

ggplot(prediction_grid, aes(x = x_utm32650, y = y_utm32650)) +
  geom_tile(
    width = cell_length,
    height = cell_length,
    fill = "white",
    colour = "black"
  ) +
  geom_text(aes(label = cell_id), size = 3) +
  coord_fixed(
    xlim = range(prediction_grid$x_utm32650) +
      c(-cell_length / 2, cell_length / 2),
    ylim = range(prediction_grid$y_utm32650) +
      c(-cell_length / 2, cell_length / 2),
    expand = FALSE
  ) +
  labs(
    title = "Maliau 2 prediction grid cell IDs",
    x = "Easting (UTM 32650)",
    y = "Northing (UTM 32650)"
  ) +
  theme_minimal()

#####

# Step 8: Convert prediction grid into NetCDF-ready vectors with the correct
# cell_id ordering and dimensions

prediction_grid <- prediction_grid[order(prediction_grid$cell_id), ]

# NetCDF stores one vegetation biomass value per cell_id.
subcanopy_vegetation_biomass <- prediction_grid$predicted_biomass_clipped

stopifnot(
  length(prediction_grid$cell_id) == length(cell_id_index),
  identical(prediction_grid$cell_id, cell_id_index),
  length(subcanopy_vegetation_biomass) == length(cell_id_index)
)

#####

# Step 9: Prepare subcanopy_seedbank_biomass

# In Step 8, the clipped prediction for each grid cell was copied into the
# `subcanopy_vegetation_biomass` vector in `cell_id` order. The corresponding
# seedbank value for each cell is obtained by applying the vegetation-to-seedbank
# ratio from the output of `subcanopy_maliau.R`.
#
# In `subcanopy_maliau.R`, the relationship is calculated as:
# seedbank biomass = vegetation biomass * reproductive allocation * 0.23.
# The resulting vegetation and seedbank values are written to
# `subcanopy_maliau.csv`. Their ratio therefore represents the same calculation:
# seedbank biomass / vegetation biomass = reproductive allocation * 0.23.
#
# The spatial model predicts vegetation biomass rather than seedbank biomass.
# Applying this output-derived ratio to each predicted vegetation value transfers
# the `subcanopy_maliau.R` logic to every grid cell without repeating its
# scientific assumptions here. Those assumptions and references remain documented
# in `subcanopy_maliau.R`.

seedbank_to_vegetation_ratio <-
  unique(
    subcanopy_maliau$subcanopy_seedbank_biomass /
      subcanopy_maliau$subcanopy_vegetation_biomass
  )
subcanopy_seedbank_biomass <-
  subcanopy_vegetation_biomass * seedbank_to_vegetation_ratio

stopifnot(
  length(seedbank_to_vegetation_ratio) == 1,
  is.finite(seedbank_to_vegetation_ratio),
  length(subcanopy_seedbank_biomass) == length(cell_id_index)
)

################################################################################

# Open NetCDF file
nc <-
  create.nc(
    "../../../../data/derived/plant/input_data/scenarios/maliau_2/plant_input_data_maliau_2.nc",
    format = "netcdf4"
  )

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
plant_input_data_maliau_2 <-
  nc_open(
    "../../../../data/derived/plant/input_data/scenarios/maliau_2/plant_input_data_maliau_2.nc"
  )

names(plant_input_data_maliau_2$var)
ncvar_get(plant_input_data_maliau_2, "plant_pft_propagules")
ncvar_get(plant_input_data_maliau_2, "subcanopy_vegetation_biomass")
ncvar_get(plant_input_data_maliau_2, "subcanopy_seedbank_biomass")

ncvar_get(plant_input_data_maliau_2, "cell_id")
ncvar_get(plant_input_data_maliau_2, "pft")

# Close
nc_close(plant_input_data_maliau_2)
