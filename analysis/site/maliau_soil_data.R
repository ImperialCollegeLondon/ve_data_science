#| ---
#| title: Compile initial soil data for the Maliau scenario
#|
#| description: |
#|     This R script compiles initial soil data for the Maliau scenario
#|     from various data analyses into a single netCDF file.
#|     See the metadata in data/scenarios/maliau/soil_litter_metadata.toml
#|     for specific file paths that analysed each variable.
#|
#| virtual_ecosystem_module: Soil
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: soil_litter_metadata.toml
#|     path: data/scenarios/maliau
#|     description: |
#|         Metadata for soil and litter data analyses, currently including
#|         file paths and units
#|   - name: maliau_grid_definition_100m.toml
#|     path: data/derived/site
#|     description: |
#|         Metadata for Maliau grids, primarily to define the data generation
#|         area
#|   - name:
#|     path:
#|     description: |
#|
#|
#| output_files:
#|   - name:
#|     path:
#|     description: |
#|
#|
#| package_dependencies:
#|     - tidyverse
#|     - readxl
#|     - RcppTOML
#|     - sf
#|     - terra
#|     - autoFRK
#|     - CBFM
#|     - ncdf4
#|
#| usage_notes: |
#|     For more details on statistical and data assumptions, see
#|     data/scenarios/maliau/soil_metadata.toml; The CBFM package needs to be
#|     installed from https://github.com/fhui28/CBFM
#| ---

library(tidyverse)
library(readxl)
library(RcppTOML)
library(sf)
library(terra)
library(autoFRK)
library(CBFM)
library(ncdf4)

set.seed(20260313)


# Soil metadata ---------------------------------------------------------

soil_meta <- parseTOML("data/scenarios/maliau/soil_litter_metadata.toml")


# Maliau site metadata ----------------------------------------------------

maliau <- parseTOML("data/derived/site/maliau_grid_definition_100m.toml")

# total number of grids
n_sim <- with(maliau, cell_nx * cell_ny)


# Set up dataframe --------------------------------------------------------
# this dataframe will store generated initial values, and then be converted
# to a netCDF output at the end

dat <-
  expand_grid(
    cell_x = maliau$cell_x_centres,
    cell_y = maliau$cell_y_centres
  ) |>
  # calculate displacements
  mutate(
    x = cell_x - min(cell_x),
    y = cell_y - min(cell_y)
  )



# Spatial prediction from SAFE soil campaign ------------------------------

# script that fits a spatial model to the SAFE data
source("analysis/soil/initialisation/model_safe.R")

# extract covariates to the Maliau region of interest
dat <-
  dat %>%
  mutate(
    elev = extract(elev, .[, c("cell_x", "cell_y")])[, "SRTM_UTM50N_processed"],
    topo = extract(topo, .[, c("cell_x", "cell_y")])[, "SRTM_UTM50N_TRI_Wilson2007"],
    hydro = extract(hydro, .[, c("cell_x", "cell_y")])[, "SRTM_Log_Flow_Accum"],
    # acd = extract(acd, .[, c("cell_x", "cell_y")])[, "acd"],  # nolint
    acd = mean(soil$acd),
    evi = extract(evi, .[, c("cell_x", "cell_y")])[, "EVI"]
  ) %>%
  mutate(
    elev = (elev - mean(soil$elev)) / sd(soil$elev),
    topo = (topo - mean(soil$topo)) / sd(soil$topo),
    hydro = (hydro - mean(soil$hydro)) / sd(soil$hydro),
    acd = (acd - mean(soil$acd)) / sd(soil$acd),
    evi = (evi - mean(soil$evi)) / sd(soil$evi)
  )

maliau_basis <-
  mrts(soil[, c("X", "Y")], num_basis) %>%
  predict(newx = dat[, c("cell_x", "cell_y")]) %>%
  as.matrix() %>%
  {
    .[, -(1)]
  }

# predict onto the Maliau grids
maliau_pred <- predict(
  fitcbfm,
  newdata = dat,
  new_B_space = maliau_basis
)
# backtransform
maliau_pred[, -c(1, 2)] <- exp(maliau_pred[, -c(1, 2)])

# convert to raster and then plot it
maliau_pred_rast <-
  bind_cols(dat, maliau_pred) %>%
  rast()

plot(maliau_pred_rast)




# Split SAFE campaign variables into specific pools -----------------------

# soil_c_pool_lmwc
# using DOC as a proxy
# then convert units to kg/m^3 using bulk density from SAFE converted to kg/m^3
# NB: the LWMC values are in the same order of magnitude as POM C, which is
#     possible although we expected LMWC to be lower; I am letting this pass
#     for now for the purpose of initialisation

source("analysis/soil/nutrient_pools/doc_don.R")

dat <-
  dat |>
  mutate(soil_c_pool_lmwc = rnorm(n_sim, doc_mean, doc_sd),
         soil_c_pool_lmwc = soil_c_pool_lmwc  / 1e6 * (bulk_density * 1e3))



