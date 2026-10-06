#| ---
#| title: VE join logic and scenario metadata handling
#|
#| description: |
#|     Functions for joining Virtual Ecosystem (VE) outputs to validation data,
#|     including spatial and temporal matching, scenario metadata parsing,
#|     and VE output aggregation.
#|     This file contains the main [join_ve_outputs()] function and supporting helpers.
#|
#| virtual_ecosystem_module: [Soil, Litter]
#|
#| author:
#|   - Hao Ran Lai
#|   - Nicholas Wei Cheng Tan
#|
#| status: final
#|
#| source_files:
#|   - name: get_ve_variables.R
#|     path: tools/R/R/get_ve_variables.R
#|     description: |
#|       Provides `get_data_variables()` and `get_derived_variables()` used by
#|       `join_ve_outputs()`.
#|
#| package_dependencies:
#|   - cli
#|   - dplyr
#|   - lubridate
#|   - pizzarr
#|   - purrr
#|   - reshape2
#|   - sf
#|   - stats
#|   - tidyr
#|   - toml
#| ---

#' Read VE scenario metadata from compiled configuration
#'
#' Internal helper for [join_ve_outputs()]. It reads VE grid and timing metadata
#' from a compiled configuration TOML and reconstructs WGS84 spatial bounds from
#' the UTM 50N grid definition.
#'
#' @param config_path Path to a compiled VE configuration TOML file.
#'
#' @returns A list with `grid_res`, `start_date`, `spatial_bounds`, and
#'   `temporal_bounds`.

read_scenario_definition <- function(config_path) {
  scenario <- toml::read_toml(config_path)
  scenario$res <- sqrt(scenario$core$grid$cell_area)
  run_length_parts <- stringr::str_split_1(scenario$core$timing$run_length, " ")
  start_date <- lubridate::ymd(scenario$core$timing$start_date)

  utm_bounds <- c(
    xmin = scenario$core$grid$xoff,
    ymin = scenario$core$grid$yoff,
    xmax = scenario$core$grid$xoff +
      scenario$core$grid$cell_nx * scenario$res,
    ymax = scenario$core$grid$yoff +
      scenario$core$grid$cell_ny * scenario$res
  )

  wgs84_bbox <-
    sf::st_bbox(utm_bounds, crs = sf::st_crs(32650)) |>
    sf::st_as_sfc() |>
    sf::st_transform(crs = 4326) |>
    sf::st_bbox()

  list(
    grid_res = scenario$res,
    start_date = start_date,
    spatial_bounds = stats::setNames(as.numeric(wgs84_bbox), names(wgs84_bbox)),
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


#' Classify whether coordinates are inside scenario bounds
#'
#' Internal helper for [join_ve_outputs()].
#'
#' @param lat Numeric latitude in WGS84.
#' @param lon Numeric longitude in WGS84.
#' @param bounds_spatial Numeric vector `c(xmin, ymin, xmax, ymax)`.
#'
#' @returns Character vector with values `"within"` or `"outside"`.

classify_spatial_bounds <- function(lat, lon, bounds_spatial) {
  within <-
    (lon >= bounds_spatial[1] & lon <= bounds_spatial[3]) &
    (lat >= bounds_spatial[2] & lat <= bounds_spatial[4])
  dplyr::if_else(within, "within", "outside")
}


#' Classify temporal overlap with scenario bounds
#'
#' Internal helper for [join_ve_outputs()].
#'
#' @param time_start Observation start time.
#' @param time_end Observation end time; if missing, `time_start` is used.
#' @param bounds_temporal Length-2 vector with scenario start and end time.
#' @param tz Time zone used for coercing `bounds_temporal`.
#'
#' @returns Character vector with values `"within"`, `"partial"`,
#'   `"outside"`, or `NA`.

classify_temporal_bounds <- function(
  time_start,
  time_end,
  bounds_temporal,
  tz = "UTC"
) {
  obs_end <- dplyr::coalesce(time_end, time_start)
  bounds_temporal <- as.POSIXct(bounds_temporal, tz = tz)
  bounds_start <- bounds_temporal[1]
  bounds_end <- bounds_temporal[2]

  no_overlap <- obs_end <= bounds_start | time_start >= bounds_end
  fully_within <- time_start >= bounds_start & obs_end <= bounds_end

  dplyr::case_when(
    is.na(time_start) ~ NA_character_,
    no_overlap ~ "outside",
    fully_within ~ "within",
    .default = "partial"
  )
}


#' Summarise VE outputs for one validation row
#'
#' Internal helper for [join_ve_outputs()].
#'
#' @param ve_data VE output table prepared by [join_ve_outputs()].
#' @param var_canonical Canonical variable name to match.
#' @param time_start Observation start time.
#' @param time_end Observation end time.
#' @param latitude Observation latitude.
#' @param longitude Observation longitude.
#' @param spatiotemporal_join_class Join class label used to choose matching
#'   logic.
#'
#' @returns Named numeric vector with `value_VE_q05`, `value_VE_q50`, and
#'   `value_VE_q95`.

join_ve_outputs_per_row <- function(
  ve_data,
  var_canonical,
  time_start,
  time_end,
  latitude,
  longitude,
  spatiotemporal_join_class
) {
  # placeholder to fill NA for empty variables
  empty_quantiles <- c(
    value_VE_q05 = NA_real_,
    value_VE_q50 = NA_real_,
    value_VE_q95 = NA_real_
  )

  # function to summarise/aggregate VE outputs
  # currently it is median and the lower/upper quantiles; this can be changed
  # later
  summarise_ve_outputs <- function(data) {
    values <- dplyr::pull(data, value)
    if (length(values) == 0) {
      return(empty_quantiles)
    }
    stats::quantile(values, probs = c(0.05, 0.5, 0.95)) |>
      stats::setNames(c("value_VE_q05", "value_VE_q50", "value_VE_q95"))
  }

  # For interval observations, match both time_start and time_end to their
  # nearest VE timestamps. For point observations (time_end is NA), match only
  # time_start. This ensures we aggregate VE values over the matched simulation
  # interval, not just a single timepoint.
  ve_dates <- ve_data |>
    dplyr::filter(var_canonical == !!var_canonical) |>
    dplyr::pull(date) |>
    unique() |>
    sort()

  if (length(ve_dates) == 0) {
    return(empty_quantiles)
  }

  # Find nearest VE timestamp to observation start
  obs_start_diff <- abs(as.numeric(difftime(
    ve_dates,
    time_start,
    units = "secs"
  )))
  nearest_start <- ve_dates[which.min(obs_start_diff)]

  # Find nearest VE timestamp to observation end (or start if no end provided)
  obs_end_effective <- if (!is.na(time_end) && time_end > time_start) {
    time_end
  } else {
    time_start
  }
  obs_end_diff <- abs(as.numeric(difftime(
    ve_dates,
    obs_end_effective,
    units = "secs"
  )))
  nearest_end <- ve_dates[which.min(obs_end_diff)]

  # Use the matched interval: all VE outputs from nearest_start to nearest_end
  ve_interval_start <- min(nearest_start, nearest_end)
  ve_interval_end <- max(nearest_start, nearest_end)

  switch(
    spatiotemporal_join_class,
    "spatial_within_temporal_within" = {
      ve_data |>
        dplyr::filter(
          var_canonical == !!var_canonical,
          date >= ve_interval_start,
          date <= ve_interval_end,
          lat_min <= latitude & latitude <= lat_max,
          lon_min <= longitude & longitude <= lon_max
        ) |>
        summarise_ve_outputs()
    },
    "spatial_within_temporal_outside" = empty_quantiles,
    "spatial_within_temporal_partial" = empty_quantiles,
    "spatial_outside_temporal_within" = {
      ve_data |>
        dplyr::filter(
          var_canonical == !!var_canonical,
          date >= ve_interval_start,
          date <= ve_interval_end
        ) |>
        summarise_ve_outputs()
    },
    "spatial_outside_temporal_outside" = empty_quantiles,
    "spatial_outside_temporal_partial" = empty_quantiles,
    stop("Unknown case: ", spatiotemporal_join_class)
  )
}


#' Join VE outputs to a validation database
#'
#' Reads direct and derived Virtual Ecosystem (VE) outputs, reshapes VE spatial
#' and temporal coordinates, classifies validation observations against scenario
#' bounds, and appends VE quantile predictions to each validation row.
#'
#' The output preserves all rows and columns of `validation_database` and adds
#' `value_VE_q05`, `value_VE_q50`, and `value_VE_q95`.
#'
#' @param validation_database A data frame containing at least
#'   `var_canonical`, `time_start`, `time_end`, `latitude`, and `longitude`.
#' @param zarr_path Path to VE model outputs in a Zarr store.
#' @param config_path Path to a compiled VE configuration TOML.
#'
#' @details
#' Temporal matching uses nearest-neighbor interval semantics:
#' \itemize{
#'   \item For point observations (no `time_end`): match `time_start` to the nearest
#'         VE output timestamp and aggregate all VE values at that timestamp.
#'   \item For interval observations (with `time_end`): match `time_start` and
#'         `time_end` separately to their nearest VE timestamps, then aggregate
#'         all VE values within the matched interval. This ensures observations
#'         spanning a time window are compared to VE predictions over the
#'         corresponding simulation interval.
#' }
#' Spatiotemporal join classes then determine spatial filtering:
#' \itemize{
#'   \item `spatial_within_temporal_within`: aggregate within the matched time
#'         interval, then filter to cells containing the observation coordinates.
#'   \item `spatial_outside_temporal_within`: aggregate within the matched time
#'         interval across all cells (temporal matching only, no spatial filter).
#'   \item Other classes are not yet implemented and currently return `NA` quantiles by design. There will be a warning to the user.
#' }
#'
#' @returns A data frame with three appended columns: `value_VE_q05`,
#'   `value_VE_q50`, and `value_VE_q95`.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' module_name <- "soil"
#' scenario_group <- "maliau"
#' scenario_name <- "maliau_2"
#' validation_root <- here::here(
#'   "data", "derived", module_name, "validation"
#' )
#' scenario_root <- here::here(
#'   "data", "scenarios", scenario_group, scenario_name, "out"
#' )
#' db <- arrow::open_dataset(file.path(validation_root, "database")) |>
#'   dplyr::collect()
#' join_ve_outputs(
#'   validation_database = db,
#'   zarr_path = file.path(scenario_root, "model_data.zarr"),
#'   config_path = file.path(scenario_root, "compiled_configuration.toml")
#' )
#' }

join_ve_outputs <- function(validation_database, zarr_path, config_path) {
  scenario_def <- read_scenario_definition(config_path)

  # Half-cell offset used to convert grid centroids to grid bounds.
  grid_offset <- scenario_def$grid_res / 2

  # xy coordinates: convert UTM centroids to WGS84 cell bounds.
  xy_ve <-
    get_data_variables(zarr_path, group = "outputs", variables = c("x", "y")) |>
    reshape2::melt() |>
    tidyr::pivot_wider(names_from = L1, values_from = value) |>
    dplyr::mutate(
      x_min = x - grid_offset,
      x_max = x + grid_offset,
      y_min = y - grid_offset,
      y_max = y + grid_offset,
      geometry = purrr::pmap(
        list(x_min, x_max, y_min, y_max),
        \(xmin, xmax, ymin, ymax) {
          sf::st_polygon(list(matrix(
            c(xmin, ymin, xmax, ymin, xmax, ymax, xmin, ymax, xmin, ymin),
            ncol = 2,
            byrow = TRUE
          )))
        }
      )
    ) |>
    sf::st_as_sf(sf_column_name = "geometry", crs = 32650) |>
    sf::st_transform(crs = 4326) |>
    dplyr::mutate(
      bbox = purrr::map(geometry, sf::st_bbox),
      lon_min = purrr::map_dbl(bbox, \(b) b[["xmin"]]),
      lon_max = purrr::map_dbl(bbox, \(b) b[["xmax"]]),
      lat_min = purrr::map_dbl(bbox, \(b) b[["ymin"]]),
      lat_max = purrr::map_dbl(bbox, \(b) b[["ymax"]])
    ) |>
    dplyr::select(-bbox) |>
    sf::st_drop_geometry()

  # Timestamps from VE simulation.
  timestamp_ve <-
    get_data_variables(
      zarr_path,
      group = "outputs",
      variables = c("timestamp")
    ) |>
    reshape2::melt() |>
    tidyr::pivot_wider(names_from = L1, values_from = value)

  # Direct data variables from the Zarr store.
  vars_target <- base::unique(validation_database$var_canonical)
  vars_ve_output <-
    pizzarr::zarr_open(zarr_path)$get_item("outputs")$get_store()$listdir(
      "outputs"
    )
  data_variables <-
    get_data_variables(
      zarr_path,
      group = "outputs",
      variables = base::intersect(vars_target, vars_ve_output)
    ) |>
    reshape2::melt() |>
    dplyr::rename(var_canonical = L1)

  # Derived variables, calculated from direct data variables.
  derived_variables <-
    get_derived_variables(
      zarr_path,
      config_path,
      group = "outputs"
    ) |>
    reshape2::melt() |>
    dplyr::rename(var_canonical = L1)

  ve_variables <-
    dplyr::bind_rows(data_variables, derived_variables) |>
    dplyr::left_join(
      dplyr::select(
        xy_ve,
        cell_id,
        dplyr::starts_with("lon"),
        dplyr::starts_with("lat")
      ),
      by = dplyr::join_by(cell_id)
    ) |>
    dplyr::left_join(timestamp_ve, by = dplyr::join_by(time_index)) |>
    dplyr::mutate(date = scenario_def$start_date + timestamp)

  scenario_bounds <- list(
    spatial = scenario_def$spatial_bounds,
    temporal = scenario_def$temporal_bounds
  )

  validation_database_classified <-
    validation_database |>
    dplyr::mutate(
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
    dplyr::mutate(
      spatiotemporal_join_class = paste(
        "spatial",
        spatial_join_class,
        "temporal",
        temporal_join_class,
        sep = "_"
      )
    )

  # A summary warning if any of the unimplemented spatiotemporal classes is
  # found in the database
  unimplemented_summary_classes <- c(
    "spatial_within_temporal_outside",
    "spatial_within_temporal_partial",
    "spatial_outside_temporal_outside",
    "spatial_outside_temporal_partial"
  )
  unimplemented_counts <-
    validation_database_classified |>
    dplyr::count(spatiotemporal_join_class, name = "n") |>
    dplyr::filter(spatiotemporal_join_class %in% unimplemented_summary_classes)
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

  validation_database_classified |>
    dplyr::mutate(
      value_VE = purrr::pmap(
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
    tidyr::unnest_wider(value_VE)
}
