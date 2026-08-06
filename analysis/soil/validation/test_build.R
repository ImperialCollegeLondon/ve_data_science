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


# VE outputs: load ----------------------------------------------------------

# Helper that reads a scenario TOML and returns a flat list of the fields used
# downstream. Isolating all maliau$Scenario$<name>$... access here makes the
# dependency easy to swap out or remove later.
read_scenario_definition <- function(toml_path, scenario_name) {
  scenario <- read_toml(toml_path) |> pluck("Scenario", scenario_name)
  run_length_parts <- str_split_1(scenario$core$timing$run_length, " ")
  start_date <- ymd(scenario$core$timing$start_date)

  list(
    grid_res = scenario$res,
    start_date = start_date,
    spatial_bounds = unlist(scenario$wgs84_bounds),
    temporal_bounds = c(
      start_date,
      start_date +
        lubridate::duration(
          as.numeric(run_length_parts[1]),
          run_length_parts[2]
        )
    )
  )
}

# File paths to the VE outputs and configuration for the target scenario
zarr_path <- "data/scenarios/maliau/maliau_2/out/model_data.zarr"
config_path <- "data/scenarios/maliau/maliau_2/out/compiled_configuration.toml"

scenario_def <- read_scenario_definition(
  "data/derived/site/maliau/maliau_grid_definition.toml",
  scenario_name = "maliau_2"
)

# Half-cell offset used to convert grid centroids to grid bounds.
# Grid bounds allow point-in-cell lookup without nearest-neighbour search.
grid_offset <- scenario_def$grid_res / 2


# VE outputs: spatiotemporal coordinates -----------------------------------

# xy coordinates from VE simulation
xy_ve <-
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
          c(xmin, ymin, xmax, ymin, xmax, ymax, xmin, ymax, xmin, ymin),
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
timestamp_ve <-
  get_data_variables(
    zarr_path,
    group = "outputs",
    variables = c("timestamp")
  ) |>
  melt() |>
  pivot_wider(names_from = L1, values_from = value)

# VE outputs: data and derived variables -----------------------------------

# Data variables, directly from the Zarr store.
# NOTE: variables with extra dimensions (e.g. element, pft) will need
# additional handling here.
vars_ve_output <-
  zarr_open(zarr_path)$get_item("outputs")$get_store()$listdir("outputs")
data_variables <-
  get_data_variables(
    zarr_path,
    group = "outputs",
    variables = intersect(vars_target, vars_ve_output)
  ) |>
  melt() |>
  rename(var_canonical = L1)

# Derived variables, calculated from the direct data variables
derived_variables <-
  get_derived_variables(
    zarr_path,
    config_path,
    group = "outputs"
  ) |>
  melt() |>
  rename(var_canonical = L1)

# Combine direct and derived variables, then join spatial and temporal lookup
# tables to produce a flat VE output table ready for row-level matching.
ve_variables <-
  bind_rows(data_variables, derived_variables) |>
  # join spatial information
  left_join(xy_ve |> select(cell_id, starts_with("lon"), starts_with("lat"))) |>
  # join temporal information
  left_join(timestamp_ve) |>
  mutate(
    date = scenario_def$start_date + timestamp
  )

# TODO think about spatial having a footprint but not date, in `ve_variables`

# Classify validation observations against scenario bounds ------------------

# Derive the spatiotemporal extent of the target scenario run.
scenario_bounds <- list(
  spatial = scenario_def$spatial_bounds,
  temporal = scenario_def$temporal_bounds
)

# Classify observations against maliau_2 bounds
# Function that checks if spatial coordinates fall within bounds.
# bounds_spatial: named or positional c(xmin, ymin, xmax, ymax)
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
      scenario_bounds$spatial
    ),
    temporal_join_class = classify_temporal_bounds(
      time_start,
      time_end,
      scenario_bounds$temporal
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

# Spatiotemporal classification summary (diagnostic)
# THIS SHOULD NOT BE IN THE FUNCTION; MOVE IT OUTSIDE LATER
validation_database_classified |>
  count(
    dataset,
    # spatial_join_class,
    # temporal_join_class,
    spatiotemporal_join_class
  )

# Join VE outputs to validation database -----------------------------------

# Row-level join function: returns VE quantiles for a single validation datum.
# For non-missing inputs, returns three quantiles (q05, q50, q95).
join_ve_outputs_per_row <- function(
  ve_data,
  var_canonical,
  time_start,
  time_end,
  latitude,
  longitude,
  spatiotemporal_join_class
) {
  empty_quantiles <- c(
    value_VE_q05 = NA_real_,
    value_VE_q50 = NA_real_,
    value_VE_q95 = NA_real_
  )

  # function to summarise or aggregate from filtered VE outputs
  summarise_ve_outputs <- function(data) {
    values <- data |> pull(value)

    if (length(values) == 0) {
      return(empty_quantiles)
    }

    quantile(values, probs = c(0.05, 0.5, 0.95)) |>
      setNames(c("value_VE_q05", "value_VE_q50", "value_VE_q95"))
  }

  switch(
    spatiotemporal_join_class,
    "spatial_within_temporal_within" = {
      ve_data |>
        filter(
          var_canonical == !!var_canonical,
          date %within% interval(time_start, time_end),
          lat_min <= latitude & latitude <= lat_max,
          lon_min <= longitude & longitude <= lon_max
        ) |>
        summarise_ve_outputs()
    },
    "spatial_within_temporal_outside" = {
      empty_quantiles
    },
    "spatial_within_temporal_partial" = {
      empty_quantiles
    },
    "spatial_outside_temporal_within" = {
      ve_data |>
        filter(
          var_canonical == !!var_canonical,
          date %within% interval(time_start, time_end)
        ) |>
        summarise_ve_outputs()
    },
    "spatial_outside_temporal_outside" = {
      empty_quantiles
    },
    "spatial_outside_temporal_partial" = {
      empty_quantiles
    },
    stop("Unknown case: ", spatiotemporal_join_class)
  )
}

# Warn about unimplemented summary classes before applying rowwise.
unimplemented_summary_classes <- c(
  "spatial_within_temporal_outside",
  "spatial_within_temporal_partial",
  "spatial_outside_temporal_outside",
  "spatial_outside_temporal_partial"
)
unimplemented_counts <-
  validation_database_classified |>
  count(spatiotemporal_join_class, name = "n") |>
  filter(spatiotemporal_join_class %in% unimplemented_summary_classes)
if (nrow(unimplemented_counts) > 0) {
  counts_text <- paste0(
    unimplemented_counts$spatiotemporal_join_class,
    "=",
    unimplemented_counts$n,
    collapse = ", "
  )
  cli::cli_warn(c(
    "Summary method not implemented yet for selected classes.",
    "i" = "Rows will return NA quantiles for: {.val {counts_text}}"
  ))
}

# Apply rowwise to append VE quantile columns to the validation database.
out <-
  validation_database_classified |>
  mutate(
    value_VE = pmap(
      list(
        var_canonical,
        time_start,
        time_end,
        latitude,
        longitude,
        spatiotemporal_join_class
      ),
      \(...) join_ve_outputs_per_row(ve_data = ve_variables, ...)
    )
  ) |>
  unnest_wider(value_VE)
