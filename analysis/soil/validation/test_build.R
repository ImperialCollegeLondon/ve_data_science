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


grid_offset <- maliau$Scenario$maliau_2$res / 2

xy <-
  get_data_variables(zarr_path, group = "outputs", variables = c("x", "y")) |>
  melt() |>
  pivot_wider(names_from = L1, values_from = value) |>
  mutate(
    x_min = x - grid_offset,
    x_max = x + grid_offset,
    y_min = y - grid_offset,
    y_max = y + grid_offset,
    geometry = pmap(
      list(x_min, x_max, y_min, y_max),
      \(xmin, xmax, ymin, ymax) {
        st_polygon(list(matrix(
          c(
            xmin,
            ymin,
            xmax,
            ymin,
            xmax,
            ymax,
            xmin,
            ymax,
            xmin,
            ymin
          ),
          ncol = 2,
          byrow = TRUE
        )))
      }
    )
  ) |>
  st_as_sf(sf_column_name = "geometry", crs = 32650) |>
  st_transform(crs = 4326) |>
  mutate(
    bbox = map(geometry, st_bbox),
    lon_min = map_dbl(bbox, \(b) b[["xmin"]]),
    lon_max = map_dbl(bbox, \(b) b[["xmax"]]),
    lat_min = map_dbl(bbox, \(b) b[["ymin"]]),
    lat_max = map_dbl(bbox, \(b) b[["ymax"]])
  ) |>
  select(-bbox) |>
  st_drop_geometry()

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
  left_join(xy |> select(cell_id, starts_with("lon"), starts_with("lat"))) |>
  left_join(time) |>
  mutate(
    date = ymd(maliau$Scenario$maliau_2$core$timing$start_date) + timestamp
  )

# TODO think about spatial having a footprint but not date, in vars_derived

# Join VE outputs to Validation database ---------------------------------

# Spatial and temporal bounds classification
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
# Vectorized function that checks if spatial coordinates fall within bounds.
# bounds_spatial: c(xmin, ymin, xmax, ymax)
classify_spatial_bounds <- function(lat, lon, bounds_spatial) {
  xmin <- bounds_spatial[1]
  ymin <- bounds_spatial[2]
  xmax <- bounds_spatial[3]
  ymax <- bounds_spatial[4]

  (lon >= xmin & lon <= xmax) & (lat >= ymin & lat <= ymax)
}

# Vectorized function that classifies temporal overlap with a reference interval.
# Returns one of: "within" (fully inside), "partial" (overlapping), "outside"
# (no overlap), or NA if time_start is missing.
classify_temporal_bounds <- function(
  time_start,
  time_end,
  bounds_temporal,
  tz = "UTC"
) {
  obs_end <- coalesce(time_end, time_start)

  bounds_temporal <- as.POSIXct(bounds_temporal, tz = tz)
  bounds_start <- bounds_temporal[1]
  bounds_end <- bounds_temporal[2]

  no_overlap <- obs_end <= bounds_start | time_start >= bounds_end
  fully_within <- time_start >= bounds_start & obs_end <= bounds_end

  case_when(
    is.na(time_start) ~ NA_character_,
    no_overlap ~ "outside",
    fully_within ~ "within",
    .default = "partial"
  )
}

validation_database_classified <-
  validation_database |>
  mutate(
    spatial_bounds_class = classify_spatial_bounds(
      latitude,
      longitude,
      maliau_2_bounds$spatial
    ),
    temporal_bounds_class = classify_temporal_bounds(
      time_start,
      time_end,
      maliau_2_bounds$temporal
    )
  )

# Summary
validation_database_classified |>
  count(dataset, spatial_bounds_class, temporal_bounds_class)


test_row <- validation_database_classified[1, ]

# TODO check that test_row$var_canonical is length 1 (select one var only)

# spatial out of bound, temporal within bound
vars_derived |>
  filter(
    var_canonical == test_row$var_canonical,
    date %within% interval(test_row$time_start, test_row$time_end)
  ) |>
  summarise(value = median(value))

# spatial within of bound, temporal within bound
vars_derived |>
  filter(
    var_canonical == test_row$var_canonical,
    date %within% interval(test_row$time_start, test_row$time_end),
    lat,
    lon
  ) |>
  group_by(date) |>
  summarise(value = median(value))
