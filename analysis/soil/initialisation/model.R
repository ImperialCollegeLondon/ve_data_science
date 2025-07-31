library(tidyverse)
library(readxl)
library(sdmTMB)
library(terra)
library(sf)



# Data --------------------------------------------------------------------

crs <-
  rast("data/primary/abiotic/STRM_data_elevation/SRTM_maliau_processed.tif") %>%
  st_crs()

soil <-
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
    units = "km"
  ) %>%
  mutate(
    Elevation_s = as.numeric(scale(Elevation))
  )




# Model -------------------------------------------------------------------

mesh <- make_mesh(
  soil,
  c("X", "Y"),
  fmesher_func = fmesher::fm_mesh_2d_inla,
  # minimum triangle edge length
  cutoff = 0.05,
  # inner and outer max triangle lengths
  max.edge = c(1, 5),
  # inner and outer border widths
  offset = c(1, 2)
)
plot(mesh)

mod_pH <-
  sdmTMB(
    data = soil,
    formula = pH ~ 1 + Elevation_s,
    mesh = mesh,
    family = student(df = 2),
    spatial = "on"
  )

summary(mod_pH)

mod_bulk_density <-
  sdmTMB(
    data = soil,
    formula = bulk_density ~ 1 + Elevation_s,
    mesh = mesh,
    family = student(df = 2),
    spatial = "on"
  )

summary(mod_bulk_density)




# Prediction --------------------------------------------------------------

# download DEM following ve_example/generation_scripts/elevation_example_data.py
# in 30-m resolution,
# then downscale to 9-m resolution (i.e., a factor of 3)
# Lela already stores the evelation data in the abiotic folder
# so I'll just use the same one
elev_safe <-
  rast("data/primary/abiotic/STRM_data_elevation/SRTM_UTM50N_processed.tif") %>%
  aggregate(fact = 3) %>%
  crop(., ext(1000 * c(range(soil$X), range(soil$Y))))

dat_new <-
  elev_safe %>%
  as.data.frame(., xy = TRUE) %>%
  mutate(
    Elevation = SRTM_UTM50N_processed,
    X = x / 1000,
    Y = y / 1000,
    .keep = "unused"
  ) %>%
  mutate(
    Elevation_s = (Elevation - mean(soil$Elevation)) / sd(soil$Elevation)
  )

pred_pH <-
  predict(mod_pH,
    newdata = dat_new,
    type = "link"
  )

ggplot() +
  geom_raster(
    data = pred_pH,
    aes(X, Y, fill = est)
  ) +
  geom_point(
    data = soil,
    aes(X, Y)
  ) +
  coord_fixed()

pred_bulk_density <-
  predict(mod_bulk_density,
    newdata = dat_new,
    type = "link"
  )

ggplot() +
  geom_raster(
    data = pred_bulk_density,
    aes(X, Y, fill = est_rf)
  ) +
  geom_point(
    data = soil,
    aes(X, Y)
  ) +
  coord_fixed()
