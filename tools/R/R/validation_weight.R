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
#'
#' @param x An `sf` object containing polygon or point datasets.
#' @param longitude,latitude Matching numeric vectors in EPSG:4326. Use these
#'   instead of `x` when datasets are supplied as coordinates.
#' @param point_radius_m Radius in metres used to convert points to polygons.
#'   This is an extraction adapter, not an inferred sampling footprint. Defaults
#'   to 5 m as this is a common GPS error range.
#' @param years Years used for the human-footprint and precipitation resources.
#' @param outdir Directory used to cache remote-sensing resources.
#' @param verbose Whether mapme should print progress information.
#'
#' @returns An `sf` object containing nested indicator data.

profile_validation_environment <- function(
  x = NULL,
  longitude = NULL,
  latitude = NULL,
  point_radius_m = 5,
  years = 2010:2020,
  mapme.outdir = "data/primary/validation",
  verbose = TRUE
) {
  datasets <- prepare_mapme_polygons(
    x = x,
    longitude = longitude,
    latitude = latitude,
    point_radius_m = point_radius_m
  )

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
      mapme.biodiversity::get_humanfootprint(years = years),
      mapme.biodiversity::get_worldclim_precipitation(
        years = years,
        resolution = "10m"
      ),
      mapme.biodiversity::get_soilgrids(
        layers = "soc",
        depths = "0-5cm",
        stats = "mean"
      )
    )

  # Calculate zonal statistics
  mapme.biodiversity::calc_indicators(
    resources,
    mapme.biodiversity::calc_elevation(),
    mapme.biodiversity::calc_humanfootprint(),
    mapme.biodiversity::calc_precipitation_wc(),
    mapme.biodiversity::calc_soilproperties()
  )
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
