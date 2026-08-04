library(tidyverse)
library(reshape2)
library(arrow)
library(pizzarr)
library(sf)
library(toml)
box::use(tools/R/R/get_ve_variables[...])


db_path <- "data/derived/soil/validation/database"

validation_database <-
  open_dataset(db_path) |>
  collect()

vars <- unique(validation_database$var_canonical)


# Read VE outputs
zarr_path <- "data/scenarios/maliau/maliau_2/out/model_data.zarr"
config_path <- "data/scenarios/maliau/maliau_2/out/compiled_configuration.toml"

# Maliau scenario information
maliau <- read_toml(config_path)


#
xy <-
  get_data_variables(zarr_path, group = "outputs", variables = c("x", "y")) |>
  melt() |>
  pivot_wider(names_from = L1, values_from = value)

#
time <-
  get_data_variables(
    zarr_path,
    group = "outputs",
    variables = c("timestamp")
  ) |>
  melt() |>
  pivot_wider(names_from = L1, values_from = value)


vars_derived <-
  get_derived_variables(
    zarr_path,
    config_path,
    group = "outputs",
    variables = vars[vars != "groundwater_storage"]
  ) |>
  melt() |>
  rename(var_canonical = L1) |>
  left_join(xy) |>
  left_join(time) |>
  st_as_sf(coords = c("x", "y"), crs = 32650) |>
  st_transform(crs = 4326) |>
  mutate(
    lon = st_coordinates(geometry)[, 1],
    lat = st_coordinates(geometry)[, 2]
  ) |>
  st_drop_geometry() |>
  mutate(date = ymd(maliau$core$timing$start_date) + timestamp)


vars_derived |> select(lon, lat, date) |> map(range)

foo <- validation_database |>
  group_by(dataset) |>
  summarise(
    time_start = min(time_start, na.rm = TRUE),
    time_end = max(time_end, na.rm = TRUE),
    ymin = min(latitude, na.rm = TRUE),
    ymax = max(latitude, na.rm = TRUE),
    xmin = min(longitude, na.rm = TRUE),
    xmax = max(longitude, na.rm = TRUE)
  )
