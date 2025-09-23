library(tidyverse)
library(readxl)
library(tinyVAST)
library(fmesher)



# Data --------------------------------------------------------------------

location <-
  read_xlsx("data/primary/soil/nutrient/50-ha_soil_data.xlsx", sheet = 2)

soil <-
  read_xlsx("data/primary/soil/nutrient/50-ha_soil_data.xlsx",
    sheet = 3,
    skip = 10
  ) %>%
  left_join(location, by = join_by("sample_ID" == "Location name"))

in_dat <-
  soil %>%
  select(sample_ID:soil_pH_water, Longitude, Latitude) %>%
  pivot_longer(
    cols = soil_pH_water,
    names_to = "soil_var",
    values_to = "soil_val"
  ) %>%
  as.data.frame()



# Model -------------------------------------------------------------------

# TODO add boundary from gazetteer

mesh <- fm_mesh_2d(
  soil[, c("Longitude", "Latitude")],
  # minimum triangle edge length
  cutoff = 0.00005,
  # inner and outer max triangle lengths
  # max.edge = c(0.0001, 0.001),  # nolint
  # inner and outer border widths
  offset = c(0.0001, 0.001)
)
plot(mesh)

# Define sem, with just one variance for the single variable
sem <- "
  soil_pH_water <-> soil_pH_water, sd_pH
"

mod <-
  tinyVAST(
    data = in_dat,
    formula = soil_val ~ 1,
    spatial_domain = mesh,
    space_columns = c("Longitude", "Latitude"),
    space_term = sem,
    variable_column = "soil_var"
  )

summary(mod)




# Prediction --------------------------------------------------------------

dat_new <-
  soil %>%
  data_grid(
    X = maliau$cell_x_centres / 1000,
    Y = maliau$cell_y_centres / 1000
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
