#| ---
#| title: Profile and read validation dataset environments
#|
#| description: |
#|     Profiles validation dataset polygons or coordinates with global
#|     remote-sensing resources and loads saved environmental reference
#|     portfolios. Optional request deduplication and local SoilGrids extraction
#|     reduce runtime.
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
#|   - terra
#|   - tibble
#|
#| usage_notes: |
#|     Profiling requires internet access unless all requested resources are
#|     cached. Supply grid_rasters to avoid repeated extraction for matching
#|     raster cells and time periods. Supply soilgrids_path to use bulk local
#|     SoilGrids extraction after creating a crop. Missing grid caches disable
#|     deduplication, while a missing local crop retains remote SoilGrids
#|     extraction. The first crop can be slow; subsequent runs reuse it.
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
#' @param grid_rasters Optional named list of `SpatRaster` templates. Features
#'   with the same intersected cells and temporal periods are profiled once.
#' @param soilgrids_path Optional local SoilGrids raster. When supplied, mapme's
#'   global SoilGrids VRT is replaced by bulk extraction from this raster.
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
  verbose = TRUE,
  grid_rasters = NULL,
  soilgrids_path = NULL
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
  original_datasets <- datasets
  profile_requests <- NULL
  if (!is.null(grid_rasters)) {
    profile_requests <- prepare_profile_requests(
      datasets,
      time_windows,
      grid_rasters
    )
    datasets <- profile_requests$datasets
    time_windows <- profile_requests$time_windows
    if (verbose && profile_requests$request_count < nrow(original_datasets)) {
      cli::cli_inform(c(
        "i" = paste(
          "Grid deduplication reduced profiling from",
          nrow(original_datasets),
          "to",
          profile_requests$request_count,
          "requests"
        )
      ))
    }
  }
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
  if (is.null(soilgrids_path)) {
    resources <- mapme.biodiversity::get_resources(
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
    portfolio <- mapme.biodiversity::calc_indicators(
      resources,
      mapme.biodiversity::calc_elevation(),
      mapme.biodiversity::calc_humanfootprint(),
      mapme.biodiversity::calc_precipitation_wc(),
      mapme.biodiversity::calc_soilproperties()
    )
  } else {
    if (!file.exists(soilgrids_path)) {
      cli::cli_abort(
        "Local SoilGrids raster does not exist: {.file {soilgrids_path}}"
      )
    }
    resources <- mapme.biodiversity::get_resources(
      datasets,
      mapme.biodiversity::get_nasa_srtm(),
      mapme.biodiversity::get_humanfootprint(years = profile_years),
      mapme.biodiversity::get_worldclim_precipitation(
        years = profile_years,
        resolution = "10m"
      )
    )
    portfolio <- mapme.biodiversity::calc_indicators(
      resources,
      mapme.biodiversity::calc_elevation(),
      mapme.biodiversity::calc_humanfootprint(),
      mapme.biodiversity::calc_precipitation_wc()
    )
    portfolio$soilproperties <- extract_local_soilproperties(
      datasets,
      soilgrids_path
    )
  }

  portfolio <- filter_validation_time(portfolio, time_windows)
  if (!is.null(profile_requests)) {
    portfolio <- expand_profile_requests(
      portfolio,
      original_datasets,
      profile_requests$representative_rows
    )
  }
  portfolio
}

#' Prepare representative validation profiling requests
#'
#' Groups features that intersect the same cells in every resource grid and
#' cover the same annual and monthly periods.
#'
#' @param x Prepared `sf` polygons.
#' @param time_windows Output from [prepare_profile_time()].
#' @param grid_rasters Named list of `terra::SpatRaster` grid templates.
#'
#' @returns A list containing representative features, their time windows, and
#'   a vector mapping each original feature to a representative row.

prepare_profile_requests <- function(x, time_windows, grid_rasters) {
  if (!inherits(x, "sf") || nrow(x) == 0L) {
    cli::cli_abort("{.arg x} must be a non-empty {.cls sf} object")
  }
  if (
    !is.list(grid_rasters) ||
      length(grid_rasters) == 0L ||
      is.null(names(grid_rasters)) ||
      any(!nzchar(names(grid_rasters))) ||
      anyDuplicated(names(grid_rasters))
  ) {
    cli::cli_abort("{.arg grid_rasters} must be a named, non-empty list")
  }

  grid_keys <- lapply(grid_rasters, profile_grid_signatures, x = x)
  spatial_key <- do.call(paste, c(grid_keys, sep = "|"))
  time_key <- profile_period_signatures(time_windows, nrow(x))
  request_key <- paste(spatial_key, time_key, sep = "|")
  request_groups <- match(request_key, unique(request_key))
  representative_rows <- which(!duplicated(request_groups))

  representative_windows <- time_windows
  if (!is.null(representative_windows)) {
    representative_windows$time_start <-
      representative_windows$time_start[representative_rows]
    representative_windows$time_end <-
      representative_windows$time_end[representative_rows]
  }

  list(
    datasets = x[representative_rows, ],
    time_windows = representative_windows,
    representative_rows = request_groups,
    request_count = length(representative_rows)
  )
}

#' Identify raster-cell sets for polygon features
#'
#' @param raster A `terra::SpatRaster` grid template.
#' @param x An `sf` polygon dataset.
#'
#' @returns A character vector containing one cell-set signature per feature.

profile_grid_signatures <- function(raster, x) {
  if (!inherits(raster, "SpatRaster")) {
    cli::cli_abort("Every grid raster must be a {.cls SpatRaster}")
  }

  vector <- terra::vect(sf::st_transform(x, terra::crs(raster)))
  cell_pairs <- terra::cells(raster, vector)
  signatures <- paste0("outside:", seq_len(nrow(x)))
  if (length(cell_pairs) == 0L) {
    return(signatures)
  }

  ids <- as.integer(cell_pairs[, "ID"])
  cells <- as.numeric(cell_pairs[, "cell"])
  valid <- is.finite(cells)
  if (!any(valid)) {
    return(signatures)
  }
  ids <- ids[valid]
  cells <- cells[valid]
  cell_sets <- split(cells, ids)
  signatures[as.integer(names(cell_sets))] <- vapply(
    cell_sets,
    function(values) paste(sort(unique(values)), collapse = ","),
    character(1)
  )
  signatures
}

#' Identify annual and monthly periods required by observation windows
#'
#' @param time_windows Output from [prepare_profile_time()].
#' @param n Number of features.
#'
#' @returns A character vector containing one temporal signature per feature.

profile_period_signatures <- function(time_windows, n) {
  if (is.null(time_windows)) {
    return(rep("timeless", n))
  }

  start <- time_windows$time_start
  end <- time_windows$time_end - 1
  paste(
    format(start, "%Y", tz = time_windows$time_zone),
    format(end, "%Y", tz = time_windows$time_zone),
    format(start, "%Y-%m", tz = time_windows$time_zone),
    format(end, "%Y-%m", tz = time_windows$time_zone),
    sep = "|"
  )
}

#' Expand profiled representatives to the original feature set
#'
#' @param portfolio Profiled representative features.
#' @param datasets Original prepared features.
#' @param representative_rows Mapping from original rows to representative rows.
#'
#' @returns An `sf` portfolio with one row per original feature.

expand_profile_requests <- function(
  portfolio,
  datasets,
  representative_rows
) {
  if (length(representative_rows) != nrow(datasets)) {
    cli::cli_abort("Profile request mapping must match the original features")
  }
  if (max(representative_rows) != nrow(portfolio)) {
    cli::cli_abort("Profile request mapping does not match the portfolio")
  }

  result <- datasets
  result$assetid <- seq_len(nrow(result))
  geometry_column <- attr(portfolio, "sf_column")
  generated_columns <- setdiff(
    names(portfolio),
    c(names(datasets), geometry_column, "assetid")
  )
  for (column in generated_columns) {
    result[[column]] <- portfolio[[column]][representative_rows]
  }
  result
}

#' Load raster grids used for validation request deduplication
#'
#' @param mapme.outdir Directory containing mapme resource caches.
#' @param soilgrids_path Optional path to a local SoilGrids crop.
#'
#' @returns A named list of `SpatRaster` templates, or `NULL` if a cache resource
#'   is unavailable.

read_validation_profile_grids <- function(
  mapme.outdir = "data/primary/validation",
  soilgrids_path = NULL
) {
  first_matching <- function(path, pattern) {
    files <- list.files(path, pattern = pattern, full.names = TRUE)
    if (length(files) == 0L) NULL else sort(files)[1L]
  }

  srtm_files <- list.files(
    file.path(mapme.outdir, "nasa_srtm"),
    pattern = "\\.tif$",
    full.names = TRUE
  )
  humanfootprint <- first_matching(
    file.path(mapme.outdir, "humanfootprint"),
    "\\.tif$"
  )
  precipitation <- first_matching(
    file.path(mapme.outdir, "worldclim_precipitation"),
    "\\.tif$"
  )
  if (is.null(soilgrids_path)) {
    soilgrids_path <- file.path(
      mapme.outdir,
      "soilgrids/soc_0-5cm_mean.vrt"
    )
  }
  if (
    length(srtm_files) == 0L ||
      is.null(humanfootprint) ||
      is.null(precipitation) ||
      !file.exists(soilgrids_path)
  ) {
    cli::cli_warn("Grid deduplication disabled because a grid cache is missing")
    return(NULL)
  }

  list(
    elevation = terra::vrt(srtm_files),
    humanfootprint = terra::rast(humanfootprint),
    precipitation = terra::rast(precipitation),
    soilproperties = terra::rast(soilgrids_path)
  )
}

#' Materialise a local SoilGrids crop
#'
#' @param x Validation features used to define the crop extent.
#' @param source_path Path to the SoilGrids VRT.
#' @param destination_path Path for the local raster crop.
#' @param point_radius_m Buffer radius used when `x` contains points.
#'
#' @returns The destination path, or `NULL` when the source cache is missing.

prepare_local_validation_soilgrids <- function(
  x,
  source_path = "data/primary/validation/soilgrids/soc_0-5cm_mean.vrt",
  destination_path = "data/primary/validation/soilgrids/soc_0-5cm_mean_validation_crop.tif",
  point_radius_m = 5
) {
  datasets <- prepare_mapme_polygons(x, point_radius_m = point_radius_m)
  if (file.exists(destination_path)) {
    crop <- terra::rast(destination_path)
    crop_datasets <- sf::st_transform(datasets, terra::crs(crop))
    crop_extent <- terra::ext(crop)
    feature_extent <- terra::ext(terra::vect(crop_datasets))
    crop_covers_features <-
      feature_extent$xmin >= crop_extent$xmin &&
      feature_extent$xmax <= crop_extent$xmax &&
      feature_extent$ymin >= crop_extent$ymin &&
      feature_extent$ymax <= crop_extent$ymax
    if (crop_covers_features) {
      return(destination_path)
    }
    cli::cli_warn(
      "Existing SoilGrids crop does not cover all validation features"
    )
    return(NULL)
  }
  if (!file.exists(source_path)) {
    cli::cli_warn("Local SoilGrids crop skipped because its source is missing")
    return(NULL)
  }

  source <- terra::rast(source_path)
  datasets <- sf::st_transform(datasets, terra::crs(source))
  dir.create(dirname(destination_path), recursive = TRUE, showWarnings = FALSE)
  temporary_path <- paste0(
    tools::file_path_sans_ext(destination_path),
    "-",
    Sys.getpid(),
    ".tif"
  )
  on.exit(unlink(temporary_path), add = TRUE)
  terra::crop(
    source,
    terra::vect(datasets),
    snap = "out",
    filename = temporary_path,
    overwrite = TRUE
  )
  if (!file.rename(temporary_path, destination_path)) {
    cli::cli_abort("Could not move the completed SoilGrids crop into place")
  }
  destination_path
}

#' Extract SoilGrids properties from a local raster
#'
#' @param x Prepared validation polygons.
#' @param path Local SoilGrids SOC raster.
#'
#' @returns A list of indicator tibbles, one per feature.

extract_local_soilproperties <- function(x, path) {
  raster <- terra::rast(path)
  datasets <- sf::st_transform(x, terra::crs(raster))
  values <- terra::extract(
    raster,
    terra::vect(datasets),
    fun = mean,
    na.rm = TRUE,
    ID = FALSE
  )
  values <- as.numeric(values[[1L]]) / 10
  lapply(values, function(value) {
    tibble::tibble(
      datetime = as.POSIXct("2017-02-01T00:00:00Z", tz = "UTC"),
      variable = "soc_0_5cm_mean_mean",
      unit = "g/kg",
      value = value
    )
  })
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
