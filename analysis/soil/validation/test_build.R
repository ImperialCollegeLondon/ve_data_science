library(tidyverse)
library(reshape2)
library(arrow)
library(pizzarr)
library(sf)
library(toml)
box::use(tools/R/R/get_ve_variables[...])


# Validation database ----------------------------------------------------

# Read the full validation database
db_path <- "data/derived/soil/validation/database"
validation_database <- open_dataset(db_path) |> collect()

# List the variables to be validated in the database
# this is to narrow down the target variables to be extracted from VE outputs
vars_target <- unique(validation_database$var_canonical)


# VE outputs -------------------------------------------------------------

# File paths to the VE outputs and configurations
# we are using Maliau 2 for now
zarr_path <- "data/scenarios/maliau/maliau_2/out/model_data.zarr"
config_path <- "data/scenarios/maliau/maliau_2/out/compiled_configuration.toml"

# Maliau scenario information, mainly to extract spatiotemporal bounds
maliau <- read_toml("data/derived/site/maliau/maliau_grid_definition.toml")

# Calculate grid offset to convert grid centroids to grid bounds later
# we use grid bounds to locate grids that contain a validation data point
# this remove the need to find the nearest neighbour, which is computationally
# more demanding
grid_offset <- maliau$Scenario$maliau_2$res / 2

# xy coordinates from VE simulation
xy <-
  get_data_variables(zarr_path, group = "outputs", variables = c("x", "y")) |>
  melt() |>
  pivot_wider(names_from = L1, values_from = value) |>
  # convert grid centroids to grid bounds
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

# timestamp from VE simulation
time <-
  get_data_variables(
    zarr_path,
    group = "outputs",
    variables = c("timestamp")
  ) |>
  melt() |>
  pivot_wider(names_from = L1, values_from = value)

# Extract the VE outputs
# We have data variables, which are directly from VE and can be extracted with
# get_data_variables(), but none of them are in the validation dataset currently
# so we only calculate the other set, which is the derived variables calculated
# from get_derived_variables()
vars_derived <-
  get_derived_variables(
    zarr_path,
    config_path,
    group = "outputs",
    variables = vars_target[vars_target != "groundwater_storage"]
  ) |>
  melt() |>
  rename(var_canonical = L1) |>
  # join spatial information
  left_join(xy |> select(cell_id, starts_with("lon"), starts_with("lat"))) |>
  # join temporal information
  left_join(time) |>
  mutate(
    date = ymd(maliau$Scenario$maliau_2$core$timing$start_date) + timestamp
  )

# TODO think about spatial having a footprint but not date, in vars_derived

# Join VE outputs to Validation Database ---------------------------------

# Spatial and temporal bounds classification
# first, retrieve the total spatiotemporal extent/bounds of Maliau 2
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
# Function that checks if spatial coordinates fall within bounds.
# bounds_spatial: c(xmin, ymin, xmax, ymax)
classify_spatial_bounds <- function(lat, lon, bounds_spatial) {
  xmin <- bounds_spatial[1]
  ymin <- bounds_spatial[2]
  xmax <- bounds_spatial[3]
  ymax <- bounds_spatial[4]

  within <- (lon >= xmin & lon <= xmax) & (lat >= ymin & lat <= ymax)

  case_when(
    within ~ "within",
    !within ~ "outside"
  )
}

# Function that classifies temporal overlap with a reference interval.
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

# Classify each validation datum into a spatiotemporal-match category
validation_database_classified <-
  validation_database |>
  mutate(
    spatial_join_class = classify_spatial_bounds(
      latitude,
      longitude,
      maliau_2_bounds$spatial
    ),
    temporal_join_class = classify_temporal_bounds(
      time_start,
      time_end,
      maliau_2_bounds$temporal
    )
  ) |>
  # combining both spatial and temporal categories
  mutate(
    spatiotemporal_join_class = paste(
      "spatial",
      spatial_join_class,
      "temporal",
      temporal_join_class,
      sep = "_"
    )
  )

# Summary
validation_database_classified |>
  count(
    dataset,
    # spatial_join_class,
    # temporal_join_class,
    spatiotemporal_join_class
  )

# #########or "mutate_ve_outputs" ?
# For non-missing inputs, this function is intended to return one numeric value.
join_ve_outputs <- function(
  var_canonical,
  time_start,
  time_end,
  latitude,
  longitude,
  spatiotemporal_join_class
) {
  # handle time_end missingness
  obs_end <- coalesce(time_end, time_start)

  # function to calculate median from filtered VE outputs
  get_median_value <- function(data) {
    values <- data |> pull(value)

    if (length(values) == 0) {
      return(NA_real_)
    }

    median(values)
  }

  switch(
    spatiotemporal_join_class,
    "spatial_within_temporal_within" = {
      vars_derived |>
        filter(
          var_canonical == !!var_canonical,
          date %within% interval(time_start, obs_end),
          lat_min <= latitude & latitude <= lat_max,
          lon_min <= longitude & longitude <= lon_max
        ) |>
        get_median_value()
    },
    "spatial_within_temporal_outside" = {
      # do thing B
      NA_real_
    },
    "spatial_within_temporal_partial" = {
      # do thing C
      NA_real_
    },
    "spatial_outside_temporal_within" = {
      vars_derived |>
        filter(
          var_canonical == !!var_canonical,
          date %within% interval(time_start, obs_end)
        ) |>
        get_median_value()
    },
    "spatial_outside_temporal_outside" = {
      # do thing B
      NA_real_
    },
    "spatial_outside_temporal_partial" = {
      # do thing C
      NA_real_
    },
    stop("Unknown case: ", spatiotemporal_join_class)
  )
}

# Apply rowwise
validation_database_classified <-
  validation_database_classified |>
  mutate(
    value_VE = pmap_dbl(
      list(
        var_canonical,
        time_start,
        time_end,
        latitude,
        longitude,
        spatiotemporal_join_class
      ),
      join_ve_outputs
    )
  )
