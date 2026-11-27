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
#| status: final
#|
#| input_files:
#|
#| output_files:
#|
#| source_files:
#|
#| package_dependencies:
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
  datasets <- .prepare_validation_datasets(
    x = x,
    longitude = longitude,
    latitude = latitude,
    point_radius_m = point_radius_m
  )

  options_before <- mapme.biodiversity::mapme_options()
  on.exit(
    do.call(mapme.biodiversity::mapme_options, options_before),
    add = TRUE
  )
  mapme.biodiversity::mapme_options(outdir = mapme.outdir, verbose = verbose)

  resources <- mapme.biodiversity::get_resources(
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

  mapme.biodiversity::calc_indicators(
    resources,
    mapme.biodiversity::calc_elevation(),
    mapme.biodiversity::calc_humanfootprint(),
    mapme.biodiversity::calc_precipitation_wc(),
    mapme.biodiversity::calc_soilproperties()
  )
}

.prepare_validation_datasets <- function(
  x = NULL,
  longitude = NULL,
  latitude = NULL,
  point_radius_m = 1
) {
  has_longitude <- !is.null(longitude)
  has_latitude <- !is.null(latitude)

  if (has_longitude != has_latitude) {
    stop("longitude and latitude must both be supplied", call. = FALSE)
  }

  if (!is.null(x) && has_longitude) {
    stop("supply either x or coordinates, not both", call. = FALSE)
  }

  if (is.null(x)) {
    if (!has_longitude) {
      stop("supply either x or longitude and latitude", call. = FALSE)
    }
    if (!is.numeric(longitude) || !is.numeric(latitude)) {
      stop("longitude and latitude must be numeric", call. = FALSE)
    }
    if (length(longitude) != length(latitude) || length(longitude) == 0L) {
      stop("longitude and latitude must have equal, positive lengths")
    }
    if (any(!is.finite(longitude)) || any(!is.finite(latitude))) {
      stop("longitude and latitude must be finite", call. = FALSE)
    }
    if (any(longitude < -180 | longitude > 180)) {
      stop("longitude must be between -180 and 180", call. = FALSE)
    }
    if (any(latitude < -90 | latitude > 90)) {
      stop("latitude must be between -90 and 90", call. = FALSE)
    }

    x <- sf::st_as_sf(
      data.frame(longitude = longitude, latitude = latitude),
      coords = c("longitude", "latitude"),
      crs = 4326
    )
  }

  if (!inherits(x, "sf")) {
    stop("x must be an sf object", call. = FALSE)
  }
  if (is.na(sf::st_crs(x))) {
    stop("x must have a coordinate reference system", call. = FALSE)
  }
  if (nrow(x) == 0L || any(sf::st_is_empty(x))) {
    stop("x must contain non-empty datasets", call. = FALSE)
  }

  geometry_types <- unique(as.character(sf::st_geometry_type(x)))
  polygon_types <- c("POLYGON", "MULTIPOLYGON")
  point_types <- c("POINT", "MULTIPOINT")

  if (all(geometry_types %in% polygon_types)) {
    datasets <- sf::st_transform(x, 4326)
  } else if (all(geometry_types %in% point_types)) {
    if (
      !is.numeric(point_radius_m) ||
        length(point_radius_m) != 1L ||
        !is.finite(point_radius_m) ||
        point_radius_m <= 0
    ) {
      stop("point_radius_m must be one positive number", call. = FALSE)
    }

    points <- sf::st_transform(x, 4326)
    old_s2 <- sf::sf_use_s2(TRUE)
    on.exit(sf::sf_use_s2(old_s2), add = TRUE)
    datasets <- sf::st_buffer(points, dist = point_radius_m)
  } else {
    stop(
      "x must contain only points or only polygon datasets",
      call. = FALSE
    )
  }

  if (
    !"assetid" %in% names(datasets) ||
      anyNA(datasets[["assetid"]]) ||
      anyDuplicated(datasets[["assetid"]])
  ) {
    datasets[["assetid"]] <- seq_len(nrow(datasets))
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
    stop("Validation portfolio does not exist: ", path, call. = FALSE)
  }

  mapme.biodiversity::read_portfolio(path)
}
