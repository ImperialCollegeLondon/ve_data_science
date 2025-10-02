library(tidyverse)
library(readxl)
library(RcppTOML)
library(sf)
library(terra)
library(autoFRK)
library(CBFM)
library(modelr)


# Data --------------------------------------------------------------------

maliau <-
  parseTOML("data/sites/maliau_site_definition.toml")

# TODO update path to match abiotic module input
elev <-
  rast("data/primary/abiotic/STRM_data_elevation/SRTM_UTM50N_processed.tif")

extra_locations <-
  tribble(
    ~location, ~lat, ~lon,
    "OG3_DW1", 4.733986, 116.970434,
    "OG3_DW2", 4.7341235, 116.967075,
    "OG3_DW3", 4.734606, 116.965199
  ) %>%
  st_as_sf(coords = c("lon", "lat"), crs = 4326)

location_sf <-
  st_read("data/sites/gazetteer.geojson") %>%
  bind_rows(extra_locations) %>%
  st_transform(crs = st_crs(elev)) %>%
  st_centroid()

location <-
  location_sf %>%
  st_coordinates() %>%
  as.data.frame() %>%
  mutate(location = location_sf$location)

soil <-
  read_xlsx(
    "data/primary/soil/nutrient/SAFE_soil_nutrient_data.xlsx",
    sheet = 3,
    skip = 5
  ) %>%
  left_join(location, by = join_by("plot_code" == "location")) %>%
  mutate(elevation = extract(elev, .[, c("X", "Y")])[, "SRTM_UTM50N_processed"])

soil_vars <-
  c(
    "pH",
    "bulk_density",
    "clay",
    "total_carbon",
    "total_nitrogen",
    "total_phosphorus",
    "available_phosphorus",
    "plot_mean_o_horizon"
  )
soil_mat <- as.matrix(soil[, soil_vars])
soil_mat[, -c(1, 2)] <- log(soil_mat[, -c(1, 2)])
rownames(soil_mat) <- soil$plot_code

# TODO scale covariates

# Model -------------------------------------------------------------------

# Set up spatial basis functions for CBFM
# Number of spatial basis functions to use
num_basis <- 25

# basis functions
basis_func <-
  mrts(soil[, c("X", "Y")], num_basis) %>%
  as.matrix() %>%
  # Remove the first intercept column
  {
    .[, -(1)]
  }

# Fit CBFM
tic <- proc.time()
fitcbfm <-
  CBFM(
    y = soil_mat,
    formula = ~ 1 + elevation,
    data = soil,
    B_space = basis_func,
    family = gaussian(),
    control = list(trace = 1),
    G_control = list(rank = 2)
  )
toc <- proc.time()
toc - tic

summary(fitcbfm) %>%
  str()

coef(fitcbfm)

corrplot::corrplot(corB(fitcbfm), order = "FPC", diag = FALSE, type = "lower")
corrplot::corrplot(corX(fitcbfm), order = "FPC", diag = FALSE, type = "lower")


# Prediction --------------------------------------------------------------

maliau_grid <-
  soil %>%
  data_grid(
    X = maliau$cell_x_centres,
    Y = maliau$cell_y_centres
  )

maliau_elev <-
  maliau_grid %>%
  mutate(elevation = extract(elev, .[, c("X", "Y")])$SRTM_UTM50N_processed)

maliau_basis <-
  mrts(maliau_grid[, c("X", "Y")], num_basis) %>%
  as.matrix() %>%
  {
    .[, -(1)]
  }

maliau_pred <- predict(
  fitcbfm,
  newdata = maliau_elev,
  new_B_space = maliau_basis
)

maliau_pred_rast <-
  cbind(maliau_elev, maliau_pred) %>%
  rast()

plot(maliau_pred_rast)
