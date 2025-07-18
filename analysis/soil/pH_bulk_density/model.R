library(tidyverse)
library(readxl)
library(glmmTMB)
library(terra)
library(sf)



# Data --------------------------------------------------------------------

crs <-
  rast("data/primary/abiotic/STRM_data_elevation/SRTM_maliau_processed.tif") %>%
  st_crs()

soil_raw <-
  read_xlsx("data/primary/soil/gas_flux/3_GHG_jdrewer.xlsx",
    sheet = 3,
    skip = 5
  ) %>%
  select(
    Location,
    pH,
    bulk_density,
    Latitude,
    Longitude,
    Elevation
  ) %>%
  sdmTMB::add_utm_columns(
    .,
    ll_names = c("Longitude", "Latitude"),
    utm_crs = crs,
    units = "m"
  )

soil <-
  soil_raw %>%
  mutate(
    Elevation = as.numeric(scale(Elevation)),
    # dummy grouping variables for spatial modelling
    pos = numFactor(X, Y),
    group = factor(1)
  )




# Model -------------------------------------------------------------------

mod_pH <-
  glmmTMB(pH ~ 1 + Elevation + exp(pos + 0 | group),
    data = soil
  )

summary(mod_pH)




# Prediction --------------------------------------------------------------

# download DEM following ve_example/generation_scripts/elevation_example_data.py
# in 30-m resolution,
# then downscale to 9-m resolution (i.e., a factor of 3)
# Lela already stores the evelation data in the abiotic folder
# so I'll just use the same one
elev_maliau <-
  rast("data/primary/abiotic/STRM_data_elevation/SRTM_maliau_processed.tif") %>%
  aggregate(fact = 3)

dat_new <-
  elev_maliau %>%
  as.data.frame(., xy = TRUE) %>%
  rename(
    Elevation = SRTM_maliau_processed,
    X = x,
    Y = y
  ) %>%
  mutate(
    Elevation = (Elevation - mean(soil_raw$Elevation)) / sd(soil_raw$Elevation),
    pos = numFactor(X, Y),
    group = factor(1)
  )

pred <-
  predict(mod_pH,
    dat_new,
    type = "response",
    allow.new.levels = TRUE
  )
