#| ---
#| title: Profile and read validation dataset environments
#|
#| description: |
#|     Profiles validation dataset polygons or coordinates with global
#|     remote-sensing resources and loads saved environmental reference
#|     portfolios.
#|
#| virtual_ecosystem_module: All
#|
#| author:
#|   - Hao Ran Lai
#|
#| status: wip
#|
#| input_files:
#|
#| output_files:
#|
#| source_files:
#|
#| package_dependencies:
#|   - cli
#|   - mapme.biodiversity
#|   - sf
#|
#| usage_notes: |
#|     Profiling requires internet access unless all requested resources are
#|     cached.
#| ---

#' Profile the remote-sensing environment for validation datasets
#'
#' Accepts polygon datasets directly or coordinates in EPSG:4326. Point inputs
#' are buffered because mapme.biodiversity only accepts polygon portfolios.
#' Timeless profiles omit observation windows and use all requested years,
#' which default to 2010--2020.
#'
#' @param x An `sf` object containing polygon or point datasets.
#' @param longitude,latitude Matching numeric vectors in EPSG:4326. Use these
#'   instead of `x` when datasets are supplied as coordinates.
#' @param point_radius_m Radius in metres used to convert points to polygons.
#'   This is an extraction adapter, not an inferred sampling footprint. Defaults
#'   to 5 m as this is a common GPS error range.
#' @param time_start,time_end Observation window endpoints as `Date` or
#'   date-time vectors. Supply both endpoints or neither. Windows use an
#'   exclusive `time_end`. If both are omitted, matching columns in `x` are used.
#'   If `x` also lacks both columns, the profile is timeless.
#' @param time_zone Time zone name used to assign observations to calendar
#'   periods. Use `OlsonNames()` to list valid names.
#' @param years Years used for the human-footprint and precipitation resources.
#'   Defaults to the observation window years, or 2010--2020 for a timeless
#'   profile.
#' @param mapme.outdir Directory used to cache remote-sensing resources.
#' @param verbose Whether mapme should print progress information.
#'
#' @returns An `sf` object containing nested indicator data. Temporal indicators
#'   are restricted to each observation's window when endpoints are supplied.

profile_validation_environment <- function(
  x = NULL,
  longitude = NULL,
  latitude = NULL,
  point_radius_m = 5,
  time_start = NULL,
  time_end = NULL,
  time_zone = "UTC",
  years = NULL,
  mapme.outdir = "data/primary/validation",
  verbose = TRUE
) {
  datasets <- prepare_mapme_polygons(
    x = x,
    longitude = longitude,
    latitude = latitude,
    point_radius_m = point_radius_m
  )
  time_windows <- prepare_profile_time(
    datasets,
    time_start = time_start,
    time_end = time_end,
    time_zone = time_zone
  )
  profile_years <- prepare_profile_years(years, time_windows)

  # Set mapme_options()
  # `mapme_options()` mutates package-global state; restoration prevents helper
  # calls from leaking `outdir` or `verbose`.
  options_before <- mapme.biodiversity::mapme_options()
  on.exit(
    do.call(mapme.biodiversity::mapme_options, options_before),
    add = TRUE
  )
  mapme.biodiversity::mapme_options(outdir = mapme.outdir, verbose = verbose)

  # Download resources or reuse from cache
  # The environmental and anthropogenic factors to profile a site is subjected
  # to change
  resources <-
    mapme.biodiversity::get_resources(
      datasets,
      mapme.biodiversity::get_nasa_srtm(),
      mapme.biodiversity::get_humanfootprint(years = profile_years),
      mapme.biodiversity::get_worldclim_precipitation(
        years = profile_years,
        resolution = "10m"
      ),
      mapme.biodiversity::get_soilgrids(
        layers = "soc",
        depths = "0-5cm",
        stats = "mean"
      )
    )

  # Calculate zonal statistics
  portfolio <- mapme.biodiversity::calc_indicators(
    resources,
    mapme.biodiversity::calc_elevation(),
    mapme.biodiversity::calc_humanfootprint(),
    mapme.biodiversity::calc_precipitation_wc(),
    mapme.biodiversity::calc_soilproperties()
  )

  filter_validation_time(portfolio, time_windows)
}

#' Prepare observation windows for temporal profiling
#'
#' @param x A validation dataset.
#' @param time_start,time_end Optional observation window endpoints. Supply both
#'   or neither. When both are omitted, matching columns in `x` are used if
#'   present; otherwise the profile is timeless.
#' @param time_zone Time zone name used to assign observations to calendar
#'   periods. Use `OlsonNames()` to list valid names.
#'
#' @returns Date-time vectors and their calendar time zone, or `NULL` for a
#'   timeless profile.

prepare_profile_time <- function(
  x,
  time_start = NULL,
  time_end = NULL,
  time_zone = "UTC"
) {
  # validate data
  if (is.null(time_start) && is.null(time_end)) {
    has_start <- "time_start" %in% names(x)
    has_end <- "time_end" %in% names(x)
    if (has_start != has_end) {
      cli::cli_abort("{.arg x} must contain both time_start and time_end")
    }
    if (!has_start) {
      return(NULL)
    }
    time_start <- x$time_start
    time_end <- x$time_end
  }

  if (is.null(time_start) || is.null(time_end)) {
    cli::cli_abort(
      "Both {.arg time_start} and {.arg time_end} must be supplied"
    )
  }
  if (length(time_start) != nrow(x) || length(time_end) != nrow(x)) {
    cli::cli_abort("Observation windows must match the number of datasets")
  }
  if (
    !inherits(time_start, c("Date", "POSIXct", "POSIXlt")) ||
      !inherits(time_end, c("Date", "POSIXct", "POSIXlt"))
  ) {
    cli::cli_abort("{.arg time_start} and {.arg time_end} must contain dates")
  }
  if (anyNA(time_start) || anyNA(time_end)) {
    cli::cli_abort("{.arg time_start} and {.arg time_end} must not be missing")
  }

  if (!is.character(time_zone) || length(time_zone) != 1L || is.na(time_zone)) {
    cli::cli_abort("{.arg time_zone} must be one time-zone name")
  }
  if (!time_zone %in% OlsonNames()) {
    cli::cli_abort(c(
      "{.arg time_zone} must be a valid time-zone name",
      "i" = "Use {.fn OlsonNames} to list valid names."
    ))
  }

  time_start <- as.POSIXct(time_start, tz = "UTC")
  time_end <- as.POSIXct(time_end, tz = "UTC")
  if (any(time_end <= time_start)) {
    cli::cli_abort("{.arg time_end} must be after {.arg time_start}")
  }

  list(
    time_start = time_start,
    time_end = time_end,
    time_zone = time_zone
  )
}

#' Select resource years for validation profiling
#'
#' @param years Optional requested years. If omitted, years are inferred from
#'   `time_windows`, or default to 2010--2020 for a timeless profile.
#' @param time_windows Output from [prepare_profile_time()], or `NULL`.
#'
#' @returns An integer vector of years.

prepare_profile_years <- function(years = NULL, time_windows = NULL) {
  # validate data
  if (is.null(years)) {
    if (is.null(time_windows)) {
      return(2010:2020)
    }
    first_year <- as.integer(format(
      min(time_windows$time_start),
      "%Y",
      tz = time_windows$time_zone
    ))
    last_year <- as.integer(format(
      max(time_windows$time_end) - 1,
      "%Y",
      tz = time_windows$time_zone
    ))
    return(seq(first_year, last_year))
  }

  if (
    !is.numeric(years) ||
      length(years) == 0L ||
      any(!is.finite(years)) ||
      any(years != floor(years))
  ) {
    cli::cli_abort("{.arg years} must contain whole numbers")
  }
  years <- sort(unique(as.integer(years)))
  if (!is.null(time_windows)) {
    window_start <- as.integer(format(
      time_windows$time_start,
      "%Y",
      tz = time_windows$time_zone
    ))
    window_end <- as.integer(format(
      time_windows$time_end - 1,
      "%Y",
      tz = time_windows$time_zone
    ))
    required_years <- Map(seq, window_start, window_end, USE.NAMES = FALSE)
    required_years <- unique(unlist(required_years, use.names = FALSE))
    if (any(!required_years %in% years)) {
      cli::cli_abort("{.arg years} must cover all observation windows")
    }
  }
  years
}

#' Restrict temporal portfolio indicators to observation windows
#'
#' @param portfolio A profiled validation portfolio.
#' @param time_windows Output from [prepare_profile_time()].
#'
#' @returns The portfolio with annual and monthly indicators filtered per asset.

filter_validation_time <- function(portfolio, time_windows = NULL) {
  if (is.null(time_windows)) {
    return(portfolio)
  }

  filter_rows <- function(indicators, start, end, period) {
    # Resource dates represent local calendar periods; UTC can shift boundaries.
    indicator_period <- format(indicators$datetime, period)
    start_period <- format(start, period, tz = time_windows$time_zone)
    end_period <- format(end - 1, period, tz = time_windows$time_zone)
    indicators[
      indicator_period >= start_period & indicator_period <= end_period,
    ]
  }

  if ("humanfootprint" %in% names(portfolio)) {
    portfolio$humanfootprint <- Map(
      filter_rows,
      portfolio$humanfootprint,
      time_windows$time_start,
      time_windows$time_end,
      MoreArgs = list(period = "%Y")
    )
  }
  if ("precipitation_wc" %in% names(portfolio)) {
    portfolio$precipitation_wc <- Map(
      filter_rows,
      portfolio$precipitation_wc,
      time_windows$time_start,
      time_windows$time_end,
      MoreArgs = list(period = "%Y-%m")
    )
  }

  portfolio
}

#' Prepare validation polygons for mapme.biodiversity
#'
#' Converts point coordinates or point geometries to polygon buffers in
#' EPSG:4326. Polygon datasets are retained and transformed to EPSG:4326.
#'
#' @param x An `sf` object containing point or polygon datasets.
#' @param longitude,latitude Matching numeric vectors in EPSG:4326. Use these
#'   instead of `x` when datasets are supplied as coordinates.
#' @param point_radius_m Radius in metres used to buffer point datasets.
#'
#' @returns An EPSG:4326 `sf` polygon dataset.

prepare_mapme_polygons <- function(
  x = NULL,
  longitude = NULL,
  latitude = NULL,
  point_radius_m = 1
) {
  # validate inputs
  has_longitude <- !is.null(longitude)
  has_latitude <- !is.null(latitude)

  if (has_longitude != has_latitude) {
    cli::cli_abort("{.arg longitude} and {.arg latitude} must both be supplied")
  }

  if (!is.null(x) && has_longitude) {
    cli::cli_abort("Supply either {.arg x} or coordinates, not both")
  }

  if (is.null(x)) {
    if (!has_longitude) {
      cli::cli_abort(
        "Supply either {.arg x} or {.arg longitude} and {.arg latitude}"
      )
    }
    if (!is.numeric(longitude) || !is.numeric(latitude)) {
      cli::cli_abort("{.arg longitude} and {.arg latitude} must be numeric")
    }
    if (length(longitude) != length(latitude) || length(longitude) == 0L) {
      cli::cli_abort(
        "{.arg longitude} and {.arg latitude} must have equal, positive lengths"
      )
    }
    if (any(!is.finite(longitude)) || any(!is.finite(latitude))) {
      cli::cli_abort("{.arg longitude} and {.arg latitude} must be finite")
    }
    if (any(longitude < -180 | longitude > 180)) {
      cli::cli_abort(
        "{.arg longitude} must be between {.val -180} and {.val 180}"
      )
    }
    if (any(latitude < -90 | latitude > 90)) {
      cli::cli_abort("{.arg latitude} must be between {.val -90} and {.val 90}")
    }

    x <- sf::st_as_sf(
      data.frame(longitude = longitude, latitude = latitude),
      coords = c("longitude", "latitude"),
      crs = 4326
    )
  }

  if (!inherits(x, "sf")) {
    cli::cli_abort("{.arg x} must be an {.cls sf} object")
  }
  if (is.na(sf::st_crs(x))) {
    cli::cli_abort("{.arg x} must have a coordinate reference system")
  }
  if (nrow(x) == 0L || any(sf::st_is_empty(x))) {
    cli::cli_abort("{.arg x} must contain non-empty datasets")
  }

  geometry_types <- as.character(sf::st_geometry_type(x))
  polygon_types <- c("POLYGON", "MULTIPOLYGON")
  point_types <- c("POINT", "MULTIPOINT")
  supported_types <- c(polygon_types, point_types)

  if (any(!geometry_types %in% supported_types)) {
    cli::cli_abort(
      "{.arg x} can contain only point, multipoint, polygon, or multipolygon datasets"
    )
  }

  datasets <- sf::st_transform(x, 4326)
  # Mixed datasets are handled row-wise: points are buffered; polygons stay as-is.
  point_rows <- geometry_types %in% point_types

  if (any(point_rows)) {
    if (
      !is.numeric(point_radius_m) ||
        length(point_radius_m) != 1L ||
        !is.finite(point_radius_m) ||
        point_radius_m <= 0
    ) {
      cli::cli_abort("{.arg point_radius_m} must be one positive number")
    }

    # buffer spatial points
    old_s2 <- sf::sf_use_s2(TRUE)
    on.exit(sf::sf_use_s2(old_s2), add = TRUE)
    sf::st_geometry(datasets)[point_rows] <- sf::st_buffer(
      sf::st_geometry(datasets)[point_rows],
      dist = point_radius_m
    )
  }

  datasets
}

#' Read a validation environment portfolio
#'
#' Loads a portfolio written by [mapme.biodiversity::write_portfolio()].
#'
#' @param path Path to the GeoPackage portfolio.
#'
#' @returns An `sf` object containing one feature per reference cell and nested
#'   indicator data.

read_validation_portfolio <- function(
  path = "data/derived/validation/maliau_portfolio.gpkg"
) {
  if (!file.exists(path)) {
    cli::cli_abort("Validation portfolio does not exist: {.file {path}}")
  }

  mapme.biodiversity::read_portfolio(path)
}
