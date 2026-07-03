library(tidyverse)
library(readxl)
library(RcppTOML)
library(sf)
library(terra)
library(autoFRK)
library(CBFM)
library(RNetCDF)
library(glmmTMB)
library(biogas)
library(lubridate)
library(hms)
source("tools/R/convert_df_to_nc.R")

set.seed(20260703)


# Soil metadata ---------------------------------------------------------

soil_meta <- parseTOML("data/scenarios/maliau/soil_litter_metadata.toml")
soil_meta <- soil_meta$soil


# SAFE site metadata ----------------------------------------------------

safe <-
  parseTOML("data/derived/site/safe/safe_grid_definition.toml") |>
  pluck("Scenario") |>
  pluck("safe_1")

# total number of grids
n_sim <- with(safe, cell_nx * cell_ny)


# Set up dataframe --------------------------------------------------------
# this dataframe will store generated initial values, and then be converted
# to a netCDF output at the end

dat <-
  expand_grid(
    cell_x = safe$cell_x_centres,
    cell_y = safe$cell_y_centres
  )


# Spatial prediction from SAFE soil campaign ------------------------------

# script that fits a spatial model to the SAFE data
source("analysis/soil/initialisation/model_safe.R")

# clip spatial covariates to the SAFE region
# then fill in NAs using interpolation
safe_extent <- with(safe, ext(c(ll_x, ur_x, ll_y, ur_y)))
elev_safe <- crop(elev, safe_extent)
topo_safe <- crop(topo, safe_extent)
hydro_safe <- crop(hydro, safe_extent)
acd_safe <- crop(acd, safe_extent)
evi_safe <- crop(evi, safe_extent)

# extract covariates to the SAFE region of interest
dat <-
  dat |>
  mutate(
    elev = terra::extract(elev, pick("cell_x", "cell_y"))[,
      "SRTM_UTM50N_processed"
    ],
    topo = terra::extract(topo, pick("cell_x", "cell_y"))[,
      "SRTM_UTM50N_TRI_Wilson2007"
    ],
    hydro = terra::extract(hydro, pick("cell_x", "cell_y"))[,
      "SRTM_Log_Flow_Accum"
    ],
    acd = terra::extract(acd, pick("cell_x", "cell_y"))[, "acd"],
    evi = terra::extract(evi, pick("cell_x", "cell_y"))[, "EVI"]
  ) |>
  mutate(
    elev = (elev - mean(soil$elev)) / sd(soil$elev),
    topo = (topo - mean(soil$topo)) / sd(soil$topo),
    hydro = (hydro - mean(soil$hydro)) / sd(soil$hydro),
    acd = (acd - mean(soil$acd)) / sd(soil$acd),
    evi = (evi - mean(soil$evi)) / sd(soil$evi)
  ) |>
  # we need to fill in some NA grids in the EVI layer,
  # note sure what caused them, could be bare ground or cloud
  fill(evi) |>
  # also fill in NAs in the ACD layer
  # I opted to fill them in this time (for Maliau I decided to take the
  # regional mean), because for SAFE we have much fewer NA cells
  fill(acd)

# new basis functions for the Maliau region
maliau_basis <-
  mrts(soil[, c("X", "Y")], num_basis) |>
  predict(newx = dat[, c("cell_x", "cell_y")]) |>
  as.matrix()
# remove intercept
maliau_basis <- maliau_basis[, -1]

# predict onto the Maliau grids
maliau_pred <- predict(
  fitcbfm,
  newdata = dat,
  new_B_space = maliau_basis
)
# backtransform to observation scale
maliau_pred[, -c(1, 2)] <- exp(maliau_pred[, -c(1, 2)])

# add predictions to dataset
dat <- bind_cols(dat, maliau_pred)

# convert to raster and then plot it for a sanity check
plot(rast(dat))


# Soil variables that can be used as is -----------------------------------

# There are soil variables collected from the SAFE soil campaign that can be
# used directly in the Maliau scenario; they do not need further processing.
# These include:
# pH
# clay_fraction

dat <-
  dat |>
  rename(
    pH = pH,
    clay_fraction = clay
  ) |>
  mutate(clay_fraction = clay_fraction / 100)

# The remaining total C, N and P will be split into separate pools

# Split SAFE campaign variables into specific pools -----------------------

# first we predict POM and MAOM carbon and nitrogen fractions:
# soil_c_pool_pom
# soil_c_pool_maom
# soil_n_pool_particulate
# soil_n_pool_maom

#### Missing data ####

# soil_c_pool_lmwc
# using DOC as a proxy

#### Missing data ####

# Microbial C fractions, including:
# soil_c_pool_arbuscular_mycorrhiza
# soil_c_pool_bacteria
# soil_c_pool_ectomycorrhiza
# soil_c_pool_saprotrophic_fungi

# first we estimate the total microbial fraction in the carbon pool
source("analysis/soil/nutrient_pools/carbon_microbial.R")
C_mic_perc_safe <- extract_microbial_to_soil_C_ratio(safe)
soil_c_pool_microbe <- dat$total_carbon * C_mic_perc_safe / 100
