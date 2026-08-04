library(tidyverse)
library(reshape2)
library(arrow)
library(pizzarr)
library(sf)
library(toml)
box::use(tools/R/R/get_ve_variables[...])


# Validation database ----------------------------------------------------

db_path <- "data/derived/soil/validation/database"

validation_database <-
  open_dataset(db_path) |>
  collect()

vars <- unique(validation_database$var_canonical)


# VE outputs -------------------------------------------------------------

zarr_path <- "data/scenarios/maliau/maliau_2/out/model_data.zarr"
config_path <- "data/scenarios/maliau/maliau_2/out/compiled_configuration.toml"

# Maliau scenario information
maliau <- read_toml("data/derived/site/maliau/maliau_grid_definition.toml")


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
  mutate(
    date = ymd(maliau$Scenario$maliau_2$core$timing$start_date) + timestamp
  )


# Join VE outputs to Validation database ---------------------------------

# Spatial and temporal bounds classification

vars_derived |> select(lon, lat, date) |> map(range)

validation_database |>
  group_by(dataset) |>
  summarise(
    time_start = min(time_start, na.rm = TRUE),
    time_end = max(time_end, na.rm = TRUE),
    ymin = min(latitude, na.rm = TRUE),
    ymax = max(latitude, na.rm = TRUE),
    xmin = min(longitude, na.rm = TRUE),
    xmax = max(longitude, na.rm = TRUE)
  )

maliau_2_run_length <-
  str_split_1(maliau$Scenario$maliau_2$core$timing$run_length, " ")
maliau_2_bounds <- with(
  maliau$Scenario$maliau_2,
  list(
    spatial = unlist(wgs84_bounds),
    temporal = c(
      ymd(core$timing$start_date),
      ymd(core$timing$start_date) +
        lubridate::duration(
          as.numeric(maliau_2_run_length[1]),
          maliau_2_run_length[2]
        )
    )
  )
)

# Classify observations against maliau_2 bounds
classify_spatial_bounds <- function(lat, lon, bounds_spatial) {
  # bounds_spatial: c(xmin, ymin, xmax, ymax)
  xmin <- bounds_spatial[1]
  ymin <- bounds_spatial[2]
  xmax <- bounds_spatial[3]
  ymax <- bounds_spatial[4]

  (lon >= xmin & lon <= xmax) & (lat >= ymin & lat <= ymax)
}

classify_temporal_bounds <- function(
  time_start,
  time_end,
  bounds_start,
  bounds_end
) {
  obs_end <- coalesce(time_end, time_start)

  no_overlap <- obs_end <= bounds_start | time_start >= bounds_end
  fully_within <- time_start >= bounds_start & obs_end <= bounds_end

  case_when(
    is.na(time_start) ~ NA_character_,
    no_overlap ~ "outside",
    fully_within ~ "within",
    .default = "partial"
  )
}

# Apply classifiers
bounds_temporal_posixct <- as.POSIXct(maliau_2_bounds$temporal, tz = "UTC")

validation_database_classified <- tibble(
  validation_database,
  spatial_bounds_class = classify_spatial_bounds(
    lat = validation_database$latitude,
    lon = validation_database$longitude,
    bounds_spatial = maliau_2_bounds$spatial
  ),
  temporal_bounds_class = classify_temporal_bounds(
    time_start = validation_database$time_start,
    time_end = validation_database$time_end,
    bounds_start = bounds_temporal_posixct[1],
    bounds_end = bounds_temporal_posixct[2]
  )
) |>
  mutate(
    within_bounds = spatial_bounds_class == "within" &
      temporal_bounds_class == "within"
  )

# Summary
validation_database_classified |>
  count(dataset, spatial_bounds_class, temporal_bounds_class)
