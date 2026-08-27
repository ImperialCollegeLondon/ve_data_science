#| ---
#| title: plant_cohort_data_maliau_2
#|
#| description: |
#|     This script predicts basal area across a scenario grid using field plot
#|     observations and LiDAR-derived canopy height. The predicted basal area
#|     is then partitioned among plant functional type and DBH cohorts to
#|     estimate the number of cohort stems in each grid cell.
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
#|   - name: pft_cohort_data_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       Plot-level PFT cohort counts and densities for the 27 sampled Maliau
#|       OG census plots.
#|   - name: maliau_grid_definition.toml
#|     path: data/derived/site/maliau
#|     description: |
#|       TOML configuration file containing grid and timing definitions for the
#|       Maliau scenarios. It includes coordinate reference systems, spatial
#|       extents, grid dimensions, cell-centre coordinates, cell resolution, and
#|       core simulation timing settings for each scenario.
#|   - name: pft_cohort_data_maliau_mean_per_ha.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       Mean PFT cohort stem density across the sampled Maliau old-growth
#|       census plots, used to compare predicted cell-level cohort densities.
#|   - name: Maliau_acd.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived above-canopy density raster used as an environmental predictor.
#|   - name: Maliau_chm.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived canopy height model raster used to estimate canopy height.
#|   - name: Maliau_dtm.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived digital terrain model raster used as a spatial predictor.
#|   - name: Maliau_pad_canopy_height.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived canopy-height profile raster used as a canopy predictor.
#|   - name: Maliau_pad_kurt.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived canopy profile kurtosis raster used as a canopy predictor.
#|   - name: Maliau_pad_mean.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived mean canopy profile raster used as a canopy predictor.
#|   - name: Maliau_pad_n_layers.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived canopy layer-count raster used as a canopy predictor.
#|   - name: Maliau_pad_shannon.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived canopy profile Shannon index raster used as a canopy predictor.
#|   - name: Maliau_pad_shape.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived canopy profile shape raster used as a canopy predictor.
#|   - name: Maliau_pad_skew.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived canopy profile skewness raster used as a canopy predictor.
#|   - name: Maliau_pad_std.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived canopy profile standard-deviation raster used as a canopy predictor.
#|   - name: Maliau_pai.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived plant area index raster used as a canopy predictor.
#|   - name: Maliau_pai_02_10m.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived plant area index raster for the 2-10 m height layer.
#|   - name: Maliau_pai_10_20m.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived plant area index raster for the 10-20 m height layer.
#|   - name: Maliau_pai_20_30m.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived plant area index raster for the 20-30 m height layer.
#|   - name: Maliau_pai_30_40m.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived plant area index raster for the 30-40 m height layer.
#|   - name: Maliau_pai_40_50m.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived plant area index raster for the 40-50 m height layer.
#|   - name: Maliau_pai_50_60m.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived plant area index raster for the 50-60 m height layer.
#|   - name: Maliau_pai_60_70m.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived plant area index raster for the 60-70 m height layer.
#|   - name: Maliau_pai_70_80m.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived plant area index raster for the 70-80 m height layer.
#|   - name: Maliau_point_density.tif
#|     path: data/primary/plant/lidar
#|     description: LiDAR-derived point-density raster used as an environmental predictor.
#|
#| output_files:
#|   - name: maliau_2_cohort_data_10_cm.csv
#|     path: data/derived/plant/input_data/scenarios/maliau_2
#|     description: |
#|       Spatially predicted PFT cohort distribution for individuals with DBH
#|       greater than 10 cm.
#|     variables:
#|       - name: cell_id
#|         type: integer
#|         units: dimensionless
#|         description: |
#|           Identifier of the scenario grid cell.
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
#|           Cell identifiers are inherited from the scenario grid definition.
#|       - name: plant_cohorts_pft
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Plant functional type name.
#|         references:
#|           - citation: "pft_cohort_data_maliau.csv"
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: |
#|           PFT categories are inherited from the field-derived cohort data.
#|       - name: plant_cohorts_dbh
#|         type: numeric
#|         units: m
#|         description: |
#|           Midpoint DBH of the 100 mm cohort class.
#|         references:
#|           - citation: "pft_cohort_data_maliau.csv"
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: |
#|           Cohorts represent trees with DBH greater than 10 cm and retain the
#|           source cohort-class midpoint.
#|       - name: plant_cohorts_n
#|         type: integer
#|         units: stems cell-1
#|         description: |
#|           Predicted number of cohort stems in the grid cell.
#|         references:
#|           - citation: "pft_cohort_data_maliau.csv"
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_chm.tif"
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|           - citation: "Jucker et al. (2018)"
#|             doi: "https://doi.org/10.5194/bg-15-3811-2018"
#|             url: "https://bg.copernicus.org/articles/15/3811/2018/"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|         assumptions: |
#|           Cohort abundance is spatially predicted from field plot data using
#|           the TCH-only basal-area model. In the current
#|           implementation, this model uses canopy height model-derived total
#|           canopy height, and predicted abundances are rounded to whole stems.
#|   - name: maliau_2_cohort_data_1_cm.csv
#|     path: data/derived/plant/input_data/scenarios/maliau_2
#|     description: |
#|       Spatially predicted PFT cohort distribution for individuals with DBH
#|       greater than or equal to 1 cm. Cohorts below
#|       the 10 cm census threshold are estimated from modelled basal-area
#|       residuals and the assumed small-tree cohort distribution.
#|     variables:
#|       - name: cell_id
#|         type: integer
#|         units: dimensionless
#|         description: |
#|           Identifier of the scenario grid cell.
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
#|           Cell identifiers are inherited from the scenario grid definition.
#|       - name: plant_cohorts_pft
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Plant functional type name.
#|         references:
#|           - citation: "pft_cohort_data_maliau.csv"
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: |
#|           PFT categories are inherited from the field-derived cohort data;
#|           estimated small-tree cohorts use the same PFT categories.
#|       - name: plant_cohorts_dbh
#|         type: numeric
#|         units: m
#|         description: |
#|           Midpoint DBH of the 100 mm cohort class, including estimated
#|           classes from 1 cm up to the census-derived classes.
#|         references:
#|           - citation: "pft_cohort_data_maliau.csv"
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: |
#|           Census-derived DBH classes are retained and smaller classes are
#|           estimated from the modelled basal-area residual.
#|       - name: plant_cohorts_n
#|         type: integer
#|         units: stems cell-1
#|         description: |
#|           Predicted number of cohort stems in the grid cell.
#|         references:
#|           - citation: "pft_cohort_data_maliau.csv"
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|           - citation: "Maliau_chm.tif"
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|           - citation: "Jucker et al. (2018)"
#|             doi: "https://doi.org/10.5194/bg-15-3811-2018"
#|             url: "https://bg.copernicus.org/articles/15/3811/2018/"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|         assumptions: |
#|           Basal area for cohorts above 10 cm DBH is spatially predicted using
#|           the TCH-only model and canopy-height-model-derived total canopy
#|           height. Jucker et al. (2018, Eq. S3) supplies the correction used
#|           to estimate total basal area for stems at or above 1 cm. The
#|           difference between estimated total basal area and the basal area
#|           above 10 cm is assigned to the missing 1-10 cm cohorts. These
#|           cohorts are distributed across three DBH classes using reported
#|           tree-number fractions and class midpoint basal areas, then
#|           allocated among PFTs according to their existing cell-level
#|           abundance. Final cohort abundances are rounded to whole stems.
#|
#| package_dependencies:
#|   - sf
#|   - terra
#|   - dplyr
#|   - ggplot2
#|   - RcppTOML
#|
#| usage_notes: |
#|   Run from this script's directory because input and output paths are
#|   relative. The 10 cm output uses only census-derived cohorts above the
#|   census minimum DBH. The 1 cm output adds estimated smaller cohorts using
#|   the modelled basal-area residual and assumed small-tree distributions.
#|   All LiDAR rasters in the input directory are loaded, but the current
#|   TCH-only model uses only the canopy height model; other rasters are
#|   available for alternative model fits.
#| ---

# This script is part of scenarios and actually does the (desired) spatial
# prediction based on enviromental/LIDAR/remotely sensed data

# Approach

# What is needed as outputs?
# File type, variables, units, dimensions, etc.

# We need a csv file with a spatially predicted cohort distribution across the grid
# We need a NetCDF file with spatially predicted propagules, subcanopy vegetation and seedbank mass
# I think the NetCDF can be created separately from the cohort distribution

# The cohort distribution must be scaled according to the grid used in the simulation
# We can extract this data from the maliau_site_definition
# To start, we can set up the structure using the coordinates and convert this to cell_id

# The other variables needed are plant_cohorts_n,	plant_cohorts_pft	and plant_cohorts_dbh

# Instead of using the mean OG distribution per hectare scaled to cell size, we
# need to spatially predict the distribution by using the OG plots from Maliau
# and interpolate these towards the wider landscape, specifically for the
# coordinates listed in the maliau_site_definition

# For interpolation:
# First load the distribution for the OG plots and then use spatial prediction
# based on remote sensing data (e.g. to correct for expected basal area,
# aboveground biomass, etc.)

# How to include trees with dbh <10cm as they are not included in census data?
# Potentially scale the expected smaller individuals across pfts based on local pft density

library(sf)
library(terra)
library(dplyr)
library(ggplot2)
library(RcppTOML)

###############################################################################
# Step 1: Load OG Plot PFT Cohort Data
###############################################################################

pft_cohort_data <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/pft_cohort_data_maliau.csv",
  header = TRUE
)

# Exclude the 0.1 m placeholder class
# This script strictly focuses on predicting basal area for trees >10cm dbh
# In step 10 we account for smaller individuals
pft_cohort_data <- pft_cohort_data[
  pft_cohort_data$plant_cohorts_dbh > 0.1,
]

###############################################################################
# Step 2: Load Site Grid Definition File
###############################################################################

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

###############################################################################
# Step 3: Load LiDAR Products at Native Resolutions
###############################################################################

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
    pft_cohort_data$x_utm32650,
    pft_cohort_data$y_utm32650,
    col = "cyan",
    pch = 16,
    cex = 0.8
  )
}

# Individual raster plot loop
for (layer_name in names(lidar_layers)) {
  plot(lidar_layers[[layer_name]], main = layer_name)
  add_site_overlay()
}

###############################################################################
# Step 4: Spatial Metric Extraction & Local Parameter Calibration
###############################################################################

# 4.1 Native 1m CHM & Binary Canopy Cover Calculation
chm_1m <- lidar_layers[["Maliau_chm"]]
cover_20_1m <- (chm_1m >= 20) * 1 # Convert logical TRUE/FALSE to 1/0

# 4.2 Aggregate to Plot Grid Scale (25x25m)
tch <- terra::aggregate(chm_1m, fact = 25, fun = "mean", na.rm = TRUE)
cover_20_obs <- terra::aggregate(
  cover_20_1m,
  fact = 25,
  fun = "mean",
  na.rm = TRUE
)

# 4.3 Calculate total basal area at field plot locations
plot_observed_ba <- pft_cohort_data %>%
  mutate(
    stem_ba_m2 = pi * (plant_cohorts_dbh / 2)^2, # DBH in meters
    cohort_ba_ha = stem_ba_m2 * plant_cohorts_n_per_ha
  ) %>%
  group_by(plot_id, x_utm32650, y_utm32650) %>%
  summarise(
    obs_ba_m2_ha = sum(cohort_ba_ha, na.rm = TRUE),
    .groups = "drop"
  )

# Convert coordinates directly to a terra SpatVector (Guarantees clean extraction)
plot_pts <- terra::vect(
  plot_observed_ba,
  geom = c("x_utm32650", "y_utm32650"),
  crs = terra::crs(tch)
)

# Extract values using bilinear interpolation via SpatVector
plot_observed_ba$tch_plot <- terra::extract(
  tch,
  plot_pts,
  method = "bilinear"
)[, 2]
plot_observed_ba$cover_20_plot <- terra::extract(
  cover_20_obs,
  plot_pts,
  method = "bilinear"
)[, 2]

# Filter missing values and clamp low heights
calibration_data <- plot_observed_ba %>%
  filter(!is.na(obs_ba_m2_ha) & !is.na(tch_plot) & !is.na(cover_20_plot)) %>%
  mutate(tch_plot = ifelse(tch_plot < 0.1, 0.1, tch_plot))

# 4.4 Estimate canopy-cover residuals
#
# Canopy cover is first modelled as a function of TCH. The residual compares
# observed cover with the cover expected for a plot of that height:
#
#   cover_resid > 0: more cover than expected from TCH
#   cover_resid < 0: less cover than expected from TCH
#
# Only fractional cover values can be used to fit the logit relationship.
logit_data <- calibration_data %>%
  filter(cover_20_plot > 0 & cover_20_plot < 1)

logit_model <- lm(
  qlogis(cover_20_plot) ~ log(tch_plot),
  data = logit_data
)

p0_cover <- coef(logit_model)[1]
p1_cover <- coef(logit_model)[2]

# Calculate expected cover and the residual used by the full basal-area model.
calibration_data <- calibration_data %>%
  mutate(
    cover_20_pred = 1 / (1 + exp(-(p0_cover + p1_cover * log(tch_plot)))),
    cover_resid = cover_20_plot - cover_20_pred
  )

# 4.5 Fit the linear TCH-only model (Jucker et al., 2018; Eq. 9)
#
# This is the simplest baseline: basal area is directly proportional to TCH.
# It estimates one coefficient and assumes the relationship has an exponent
# of one.
tch_only_model <- nls(
  obs_ba_m2_ha ~ rho0 * tch_plot,
  data = calibration_data,
  start = list(rho0 = 1.112)
)

print(summary(tch_only_model))

# 4.6 Fit the non-linear TCH-only model
#
# This extends the baseline by estimating the TCH exponent. It tests whether
# basal area changes non-linearly with canopy height, without using cover data.
tch_power_model <- nls(
  obs_ba_m2_ha ~ rho0 * (tch_plot^rho1),
  data = calibration_data,
  start = list(rho0 = 1.287, rho1 = 0.987)
)

print(summary(tch_power_model))

# 4.7 Fit the full TCH and canopy-cover model (Jucker et al., 2018; Eq. 10)
#
# This model keeps the non-linear TCH relationship and adds a correction for
# canopy cover that is higher or lower than expected from TCH alone. This is
# The three fitted models are compared below, and the model with the lowest
# AIC is used to generate the Step 5 raster.
local_ba_model <- nls(
  obs_ba_m2_ha ~ rho0 * (tch_plot^rho1) * (1 + rho2 * cover_resid),
  data = calibration_data,
  start = list(rho0 = 1.287, rho1 = 0.987, rho2 = 1.983)
)

# Summary of locally calibrated parameters
print(summary(local_ba_model))

# Compare model complexity and fit using AIC; lower AIC indicates a preferred
# balance between fit and the number of estimated parameters.
candidate_models <- list(
  tch_only = tch_only_model,
  tch_power = tch_power_model,
  tch_cover = local_ba_model
)
model_aic <- sapply(candidate_models, AIC)
print(model_aic)

# Store the coefficients from the TCH-only model for Step 5.
local_params <- coef(tch_only_model)
rho0_local <- local_params["rho0"]

###############################################################################
# Step 5: Generate TCH-only Spatial Prediction Raster & Validate Model
###############################################################################

# 5.1 Spatial Prediction Across the Maliau Landscape
tch_safe <- terra::clamp(tch, lower = 0.1)

# Apply the fitted linear relationship: BA = rho0 * TCH.
ba_pred_local <- rho0_local * tch_safe
ba_pred_local <- terra::clamp(ba_pred_local, lower = 0)
names(ba_pred_local) <- "Predicted_BA_Local"

# Plot locally calibrated raster map
plot(
  ba_pred_local,
  main = "TCH-only Basal Area (m²/ha) - Maliau Model",
  col = terrain.colors(100)
)
add_site_overlay()

# 5.2 Extract TCH-only predictions at ground plot locations
plot_observed_ba$pred_ba_m2_ha <- terra::extract(
  ba_pred_local,
  plot_pts,
  method = "bilinear"
)[, 2]

# 5.3 Compute Validation Error Metrics
validation_stats <- plot_observed_ba %>%
  filter(!is.na(pred_ba_m2_ha) & !is.na(obs_ba_m2_ha)) %>%
  summarise(
    n = n(),
    rmse = sqrt(mean((obs_ba_m2_ha - pred_ba_m2_ha)^2)),
    mae = mean(abs(obs_ba_m2_ha - pred_ba_m2_ha)),
    r2 = cor(obs_ba_m2_ha, pred_ba_m2_ha)^2
  )

print(validation_stats)

# 5.4 Observed vs. Predicted Scatterplot
ggplot(plot_observed_ba, aes(x = obs_ba_m2_ha, y = pred_ba_m2_ha)) +
  geom_point(color = "forestgreen", size = 3, alpha = 0.8) +
  geom_abline(
    intercept = 0,
    slope = 1,
    linetype = "dashed",
    color = "red",
    linewidth = 0.8
  ) +
  labs(
    title = "Observed vs. Predicted Basal Area (Locally Calibrated)",
    subtitle = paste0(
      "R² = ",
      round(validation_stats$r2, 2),
      " | RMSE = ",
      round(validation_stats$rmse, 2),
      " m²/ha"
    ),
    x = "Observed Basal Area (m²/ha)",
    y = "Predicted Basal Area (m²/ha) [Local Model]"
  ) +
  theme_minimal()

# Landscape Mean BA
terra::global(ba_pred_local, fun = "mean", na.rm = TRUE)$mean

# Plot Observed Mean BA
mean(calibration_data$obs_ba_m2_ha, na.rm = TRUE)

###############################################################################
# Step 6: Apply observed pooled pft distribution (expressed as fraction of total
# basal area) to predicted total basal area
###############################################################################

# 6.1 Calculate the pooled fraction of basal area for each PFT/DBH cohort

cohort_fraction <- pft_cohort_data

cohort_fraction <-
  cohort_fraction[, c(
    "plot_id",
    "plant_cohorts_pft",
    "plant_cohorts_dbh",
    "plant_cohorts_n"
  )]

# Create unique cohort_id (pft + dbh in cm to avoid decimal in name)
cohort_fraction$cohort_id <-
  paste(
    cohort_fraction$plant_cohorts_pft,
    "_",
    (cohort_fraction$plant_cohorts_dbh * 100),
    "_",
    "cm",
    sep = ""
  )

# Calculate basal area (m2) for each cohort in a plot
cohort_fraction$cohort_ba <-
  pi *
  (cohort_fraction$plant_cohorts_dbh / 2)^2 *
  cohort_fraction$plant_cohorts_n

# Sum the basal area by cohort_id across plots
cohort_fraction$cohort_ba_sum <-
  ave(cohort_fraction$cohort_ba, cohort_fraction$cohort_id, FUN = sum)

# Calculate the total basal area across all cohort_id across plots
cohort_fraction$total_ba <- sum(cohort_fraction$cohort_ba, na.rm = TRUE)

# Verify is realistic (total ba in m2 per area across all plots)
# Express as m2 per hectare and compare to Maliau from Riutta et al. 2018
# where basal area = 34.7-41.6 m2 per hectare
unique(cohort_fraction$total_ba) /
  (length(unique(cohort_fraction$plot_id)) * 25 * 25) *
  10000

# Now calculate cohort_ba_fraction, representing the pooled fraction that a pft dbh
# basal area makes up of the total basal area
cohort_fraction$cohort_ba_fraction <-
  cohort_fraction$cohort_ba_sum / cohort_fraction$total_ba

# The sum of all cohort_ba_fraction per unique cohort_id should = 1
test <- cohort_fraction[, c("cohort_id", "cohort_ba_fraction")]
test <- unique(test)
sum(test$cohort_ba_fraction)

# Store the observed OG mean basal area density before reducing the cohort table.
og_mean_ba_m2_ha <- cohort_fraction$total_ba[1] /
  (length(unique(cohort_fraction$plot_id)) * 25 * 25) *
  10000

# Keep one row per cohort for applying pooled fractions to the raster cells.
cohort_fraction <- unique(
  cohort_fraction[
    c(
      "cohort_id",
      "plant_cohorts_pft",
      "plant_cohorts_dbh",
      "cohort_ba_fraction"
    )
  ]
)

# 6.2 Apply cohort_ba_fraction to predicted basal area from LiDAR
# This also needs to scale both to the grid used in maliau_site_definition.toml

# Represent the grid-cell centres as spatial points in the site CRS.
grid_points <- terra::vect(
  grid_cells,
  geom = c("x", "y"),
  crs = paste0("EPSG:", epsg_code)
)

# Extract predicted total basal area density at each model-cell centre.
grid_cells$predicted_total_ba_m2_ha <- terra::extract(
  ba_pred_local,
  grid_points,
  method = "bilinear"
)[, 2]

# Convert each model cell's area from square metres to hectares.
cell_area_ha <- (cell_length * cell_length) / 10000

# Create one row for every cell/cohort combination.
model_output_df <- merge(grid_cells, cohort_fraction, by = NULL)

# Allocate each cell's predicted total basal area among cohorts.
model_output_df$predicted_cohort_ba_m2_ha <-
  model_output_df$predicted_total_ba_m2_ha *
  model_output_df$cohort_ba_fraction

# Calculate the basal area of one tree for each DBH cohort.
model_output_df$stem_ba_m2 <-
  pi * (model_output_df$plant_cohorts_dbh / 2)^2

# Convert cohort basal area density to tree density.
model_output_df$plant_cohorts_n_per_ha <- ifelse(
  model_output_df$stem_ba_m2 > 0,
  model_output_df$predicted_cohort_ba_m2_ha /
    model_output_df$stem_ba_m2,
  0
)

# Convert tree density to the actual number of trees in each model cell.
model_output_df$plant_cohorts_n <-
  model_output_df$plant_cohorts_n_per_ha * cell_area_ha

# Keep the fields required by the model-ready plant cohort input.
model_output_df <- model_output_df[
  c(
    "x",
    "y",
    "plant_cohorts_n",
    "plant_cohorts_pft",
    "plant_cohorts_dbh"
  )
]

# Step 7: Compare predicted cell-level variability with the OG plot mean cohort distribution

pft_cohort_data_maliau_mean_per_ha <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/pft_cohort_data_maliau_mean_per_ha.csv",
  header = TRUE
)

# Convert predicted individuals per cell to individuals per hectare, retaining
# one value per cell so the spatial variability is visible.
predicted_cell_density <- model_output_df
predicted_cell_density$density <-
  predicted_cell_density$plant_cohorts_n / cell_area_ha
predicted_cell_density$cohort <- paste(
  predicted_cell_density$plant_cohorts_pft,
  predicted_cell_density$plant_cohorts_dbh * 100,
  "cm"
)

# Prepare the OG plot mean for overlay on each predicted cohort distribution.
og_mean_plot_data <- pft_cohort_data_maliau_mean_per_ha
og_mean_plot_data$density <- og_mean_plot_data$plant_cohorts_n
og_mean_plot_data$cohort <- paste(
  og_mean_plot_data$plant_cohorts_pft,
  og_mean_plot_data$plant_cohorts_dbh * 100,
  "cm"
)
cohort_levels <- unique(predicted_cell_density$cohort)
predicted_cell_density$cohort <- factor(
  predicted_cell_density$cohort,
  levels = cohort_levels
)
og_mean_plot_data$cohort <- factor(
  og_mean_plot_data$cohort,
  levels = cohort_levels
)

ggplot(predicted_cell_density, aes(x = cohort, y = density)) +
  geom_jitter(
    width = 0.15,
    height = 0,
    colour = "steelblue",
    alpha = 0.35,
    size = 1.5
  ) +
  geom_point(
    data = og_mean_plot_data,
    colour = "firebrick",
    size = 2.5
  ) +
  coord_flip() +
  labs(
    title = "Predicted cell values and OG plot mean cohort density",
    x = "PFT and DBH cohort",
    y = "Individuals per hectare",
    subtitle = "Blue: predicted cells; red: OG plot mean"
  ) +
  scale_y_log10() +
  theme_minimal()

# Lastly, create 2 panel plot
# - predicted total basal area for maliau_2 grid
# - difference between predicted total basal area and OG mean for maliau_2 grid

og_mean_ba_m2_ha <- sum(
  pi *
    (pft_cohort_data$plant_cohorts_dbh / 2)^2 *
    pft_cohort_data$plant_cohorts_n,
  na.rm = TRUE
) /
  (length(unique(pft_cohort_data$plot_id)) * 25 * 25) *
  10000

# Use only the values extracted at the TOML-defined Maliau_2 grid centres.
maliau_2_map <- grid_cells[, c("x", "y", "predicted_total_ba_m2_ha")]
maliau_2_map$difference_m2_ha <-
  maliau_2_map$predicted_total_ba_m2_ha - og_mean_ba_m2_ha

map_data <- rbind(
  data.frame(
    x = maliau_2_map$x,
    y = maliau_2_map$y,
    value = maliau_2_map$predicted_total_ba_m2_ha,
    panel = "Predicted total BA"
  ),
  data.frame(
    x = maliau_2_map$x,
    y = maliau_2_map$y,
    value = maliau_2_map$difference_m2_ha,
    panel = "Difference from OG mean"
  )
)
map_data$panel <- factor(
  map_data$panel,
  levels = c("Predicted total BA", "Difference from OG mean")
)

ggplot(map_data, aes(x = x, y = y, fill = value)) +
  geom_tile(width = cell_length, height = cell_length) +
  facet_wrap(~panel, nrow = 1) +
  coord_equal() +
  scale_fill_gradient2(
    low = "blue",
    mid = "white",
    high = "red",
    midpoint = 0
  ) +
  labs(
    title = "Maliau_2 basal area maps",
    x = "Easting",
    y = "Northing",
    fill = "m²/ha"
  ) +
  theme_minimal()

####################

# Step 8: assign cell_id based on coordinates, use either top left or bottom left
# corner as cell_id = 0 and add it to model_output_df

# Set the origin manually: use either "top-left" or "bottom-left".
cell_id_origin <- "bottom-left"

# Order the TOML-defined coordinates from left to right within each row.
# Reverse the y order when the origin should be at the top of the grid.
grid_order <- order(
  if (cell_id_origin == "top-left") -grid_cells$y else grid_cells$y,
  grid_cells$x
)
grid_cells$cell_id <- NA_integer_
grid_cells$cell_id[grid_order] <- seq_len(nrow(grid_cells)) - 1L

# Match each output row to its grid-cell ID using its x/y coordinate pair.
model_output_df$cell_id <- grid_cells$cell_id[
  match(
    paste(model_output_df$x, model_output_df$y),
    paste(grid_cells$x, grid_cells$y)
  )
]

ggplot(grid_cells, aes(x = x, y = y)) +
  geom_tile(
    width = cell_length,
    height = cell_length,
    fill = "white",
    colour = "black"
  ) +
  geom_text(aes(label = cell_id), size = 3) +
  coord_fixed(
    xlim = range(grid_cells$x) + c(-cell_length / 2, cell_length / 2),
    ylim = range(grid_cells$y) + c(-cell_length / 2, cell_length / 2),
    expand = FALSE
  ) +
  labs(
    title = "Maliau_2 cell IDs",
    x = "Easting",
    y = "Northing"
  ) +
  theme_minimal()

# Order model_output_df

model_output_df <- model_output_df[
  order(
    model_output_df$cell_id,
    model_output_df$plant_cohorts_pft,
    model_output_df$plant_cohorts_dbh
  ),
]

####################

# Step 9: Write CSV file with cohort individuals >10cm dbh

# Clean and save pft cohort distribution (individuals >10cm dbh)

maliau_2_cohort_data_10_cm <- model_output_df[, c(
  "cell_id",
  "plant_cohorts_pft",
  "plant_cohorts_dbh",
  "plant_cohorts_n"
)]

if (any(is.na(maliau_2_cohort_data_10_cm$plant_cohorts_n))) {
  message(
    "Some plant_cohorts_n values are NA or NaN in the >10 cm output; replacing with 0."
  )
  maliau_2_cohort_data_10_cm$plant_cohorts_n[
    is.na(maliau_2_cohort_data_10_cm$plant_cohorts_n)
  ] <- 0
}

# Round down plant_cohorts_n to the nearest integer (cannot have decimal trees)
maliau_2_cohort_data_10_cm$plant_cohorts_n <- round(
  maliau_2_cohort_data_10_cm$plant_cohorts_n
)

dir.create(
  "../../../../data/derived/plant/input_data/scenarios/maliau_2",
  recursive = TRUE,
  showWarnings = FALSE
)

write.csv(
  maliau_2_cohort_data_10_cm,
  "../../../../data/derived/plant/input_data/scenarios/maliau_2/maliau_2_cohort_data_10_cm.csv",
  row.names = FALSE
)

####################

# Step 10: add trees with dbh <10cm to pft cohort distribution based on relative
# pft abundance

# Reasoning: the SAFE census data only included trees with dbh >10cm (except for
# a few exceptions that were close to this threshold)
# Hence, if we want the entire cohort distribution, we need to account for the
# smaller individuals <10cm dbh

# Recalculate BA per cell in m²/cell from model_output_df (≥10cm cohorts only).
model_output_df$stem_ba_m2 <-
  pi * (model_output_df$plant_cohorts_dbh / 2)^2
model_output_df$cohort_ba_m2 <-
  model_output_df$stem_ba_m2 * model_output_df$plant_cohorts_n

ba_10cm_per_cell <- aggregate(
  cohort_ba_m2 ~ cell_id,
  data = model_output_df,
  FUN = sum,
  na.action = na.omit
)
names(ba_10cm_per_cell)[2] <- "ba_10cm_m2"

# Apply Jucker et al. (2018) Eq. S3 to estimate BA including all stems ≥1cm:
# Convert the intercept to cell units before applying the equation.
ba_10cm_per_cell$ba_1cm_m2 <-
  4.168 * cell_area_ha + 1.009 * ba_10cm_per_cell$ba_10cm_m2

# Missing BA is the contribution of stems with 1cm <= dbh < 10cm.
ba_10cm_per_cell$ba_missing_m2 <-
  ba_10cm_per_cell$ba_1cm_m2 - ba_10cm_per_cell$ba_10cm_m2

# The table percentages describe tree numbers, not basal-area fractions.
small_dbh_percent <- c(
  "1_2cm" = 41.15,
  "2_5cm" = 37.59,
  "5_10cm" = 12.11
)
small_dbh_fraction <- small_dbh_percent / sum(small_dbh_percent)

small_dbh_midpoint_m <- c(
  "1_2cm" = 0.015,
  "2_5cm" = 0.035,
  "5_10cm" = 0.075
)

# Calculate the average basal area of one missing stem, weighted by the
# reported number fractions.
small_dbh_stem_ba_m2 <- pi * (small_dbh_midpoint_m / 2)^2
weighted_small_stem_ba_m2 <- sum(
  small_dbh_fraction * small_dbh_stem_ba_m2
)

# Calculate the total number of missing stems and split them by size class.
ba_10cm_per_cell$n_missing <-
  ba_10cm_per_cell$ba_missing_m2 / weighted_small_stem_ba_m2
ba_10cm_per_cell$n_1_2cm <-
  ba_10cm_per_cell$n_missing * small_dbh_fraction["1_2cm"]
ba_10cm_per_cell$n_2_5cm <-
  ba_10cm_per_cell$n_missing * small_dbh_fraction["2_5cm"]
ba_10cm_per_cell$n_5_10cm <-
  ba_10cm_per_cell$n_missing * small_dbh_fraction["5_10cm"]

# Calculate each PFT's share of the existing individuals in each cell.
pft_abundance_by_cell <- aggregate(
  plant_cohorts_n ~ cell_id + plant_cohorts_pft,
  data = model_output_df,
  FUN = sum,
  na.action = na.omit
)
pft_totals_by_cell <- aggregate(
  plant_cohorts_n ~ cell_id,
  data = pft_abundance_by_cell,
  FUN = sum
)
names(pft_totals_by_cell)[2] <- "total_n"
pft_abundance_by_cell <- merge(
  pft_abundance_by_cell,
  pft_totals_by_cell,
  by = "cell_id"
)
pft_abundance_by_cell$pft_fraction <-
  pft_abundance_by_cell$plant_cohorts_n /
  pft_abundance_by_cell$total_n

# Allocate the missing individuals across PFTs and the three DBH categories.
small_dbh_categories <- data.frame(
  plant_cohorts_dbh = as.numeric(small_dbh_midpoint_m),
  dbh_category = names(small_dbh_midpoint_m),
  stringsAsFactors = FALSE
)
small_dbh_rows <- merge(
  pft_abundance_by_cell[, c("cell_id", "plant_cohorts_pft", "pft_fraction")],
  small_dbh_categories,
  by = NULL
)
small_dbh_rows <- merge(
  small_dbh_rows,
  ba_10cm_per_cell[, c("cell_id", "n_missing")],
  by = "cell_id"
)
small_dbh_rows$plant_cohorts_n <-
  small_dbh_rows$n_missing *
  small_dbh_rows$pft_fraction *
  small_dbh_fraction[small_dbh_rows$dbh_category]

small_dbh_rows <- small_dbh_rows[
  c(
    "cell_id",
    "plant_cohorts_pft",
    "plant_cohorts_dbh",
    "plant_cohorts_n"
  )
]

# Append the new small-stem rows and restore the model input ordering.
model_output_df <- model_output_df[
  c("cell_id", "plant_cohorts_pft", "plant_cohorts_dbh", "plant_cohorts_n")
]
model_output_df <- rbind(
  model_output_df,
  small_dbh_rows
)
model_output_df <- model_output_df[
  order(
    model_output_df$cell_id,
    model_output_df$plant_cohorts_pft,
    model_output_df$plant_cohorts_dbh
  ),
]

####################

# Step 11: Write CSV file with cohort individuals <10cm dbh

# Clean and save pft cohort distribution (individuals <10cm dbh)

maliau_2_cohort_data_1_cm <- model_output_df[, c(
  "cell_id",
  "plant_cohorts_pft",
  "plant_cohorts_dbh",
  "plant_cohorts_n"
)]

if (any(is.na(maliau_2_cohort_data_1_cm$plant_cohorts_n))) {
  message(
    "Some plant_cohorts_n values are NA or NaN in the <10 cm output; replacing with 0."
  )
  maliau_2_cohort_data_1_cm$plant_cohorts_n[
    is.na(maliau_2_cohort_data_1_cm$plant_cohorts_n)
  ] <- 0
}

# Round down plant_cohorts_n to the nearest integer (cannot have decimal trees)
maliau_2_cohort_data_1_cm$plant_cohorts_n <- round(
  maliau_2_cohort_data_1_cm$plant_cohorts_n
)

dir.create(
  "../../../../data/derived/plant/input_data/scenarios/maliau_2",
  recursive = TRUE,
  showWarnings = FALSE
)

write.csv(
  maliau_2_cohort_data_1_cm,
  "../../../../data/derived/plant/input_data/scenarios/maliau_2/maliau_2_cohort_data_1_cm.csv",
  row.names = FALSE
)

################################################################################
################################################################################
