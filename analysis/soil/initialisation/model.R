library(tidyverse)
library(readxl)
library(sdmTMB)
library(terra)
library(sf)
library(modelr)



# Data --------------------------------------------------------------------

# https://zenodo.org/records/3906082
gazetteer <- st_read("data/primary/soil/nutrient/gazetteer.geojson")

crs <- st_crs(gazetteer)

soil <-
  read_xlsx("data/primary/soil/nutrient/SAFE_soil_nutrient_data.xlsx",
    sheet = 3,
    skip = 5
  ) %>%
  select(
    location = plot_code,
    pH,
    bulk_density,
    clay
  ) %>%
  left_join(
    gazetteer %>%
      st_drop_geometry() %>%
      select(location, centroid_x, centroid_y)
  ) %>%
  ########## temporary fix #############
  filter(!is.na(centroid_x)) %>%
  #########################
  sdmTMB::add_utm_columns(
    .,
    ll_names = c("centroid_x", "centroid_y"),
    ll_crs = crs,
    # UTM50N
    utm_crs = "epsg:32650",
    units = "km"
  ) %>%
  ###
  filter(X > 540)




# Model -------------------------------------------------------------------

mesh <- make_mesh(
  soil,
  c("X", "Y"),
  fmesher_func = fmesher::fm_mesh_2d_inla,
  # minimum triangle edge length
  cutoff = 0.01,
  # inner and outer max triangle lengths
  max.edge = c(0.5, 1),
  # inner and outer border widths
  offset = c(1, 4)
)
plot(mesh)

mod_pH <-
  sdmTMB(
    data = soil,
    formula = pH ~ 1,
    mesh = mesh,
    spatial = "on"
  )

summary(mod_pH)

mod_bulk_density <-
  sdmTMB(
    data = soil,
    formula = bulk_density ~ 1,
    mesh = mesh,
    family = gengamma(),
    spatial = "on"
  )

summary(mod_bulk_density)




# Prediction --------------------------------------------------------------

dat_new <-
  soil %>%
  data_grid(
    X = seq_range(X, n = 50),
    Y = seq_range(Y, n = 50)
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
  scale_fill_viridis_c() +
  coord_fixed()

pred_bulk_density <-
  predict(mod_bulk_density,
    newdata = dat_new,
    type = "link"
  )

ggplot() +
  geom_raster(
    data = pred_bulk_density,
    aes(X, Y, fill = est)
  ) +
  geom_point(
    data = soil,
    aes(X, Y)
  ) +
  coord_fixed()
