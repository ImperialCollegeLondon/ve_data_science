source(here::here("tools/R/R/validation_weight.R"))

test_that("read_validation_portfolio requires a generated portfolio", {
  path <- file.path(tempdir(), "missing_validation_portfolio.gpkg")

  expect_error(
    read_validation_portfolio(path),
    "Validation portfolio does not exist"
  )
})


test_that("validation coordinates become polygon datasets", {
  datasets <- prepare_mapme_polygons(
    longitude = c(116.96, 116.97),
    latitude = c(4.75, 4.76)
  )

  expect_s3_class(datasets, "sf")
  expect_equal(sf::st_crs(datasets), sf::st_crs(4326))
  expect_equal(as.character(unique(sf::st_geometry_type(datasets))), "POLYGON")
  expect_true(all(as.numeric(sf::st_area(datasets)) > 0))
})


test_that("validation points use the requested extraction radius", {
  points <- sf::st_as_sf(
    data.frame(longitude = 116.96, latitude = 4.75),
    coords = c("longitude", "latitude"),
    crs = 4326
  )

  small <- prepare_mapme_polygons(points, point_radius_m = 1)
  large <- prepare_mapme_polygons(points, point_radius_m = 10)

  expect_true(sf::st_area(large) > sf::st_area(small))
})


test_that("validation polygons preserve their identity", {
  polygons <- sf::st_as_sf(
    data.frame(location = "plot_7"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(
        c(0, 0, 1, 1, 0, 0, 1, 1, 0, 0),
        ncol = 2
      ))),
      crs = 4326
    )
  )

  datasets <- prepare_mapme_polygons(polygons)

  expect_equal(datasets$location, "plot_7")
  expect_equal(as.character(sf::st_geometry_type(datasets)), "POLYGON")
})


test_that("mixed point and polygon datasets become polygons", {
  mixed <- sf::st_as_sf(
    data.frame(location = c("tower", "plot")),
    geometry = sf::st_sfc(
      sf::st_point(c(0, 0)),
      sf::st_polygon(list(matrix(
        c(0, 0, 1, 1, 0, 0, 1, 1, 0, 0),
        ncol = 2
      ))),
      crs = 4326
    )
  )

  datasets <- prepare_mapme_polygons(mixed)

  expect_equal(nrow(datasets), 2L)
  expect_equal(datasets$location, mixed$location)
  expect_true(all(sf::st_geometry_type(datasets) == "POLYGON"))
})


test_that("validation time windows are read from datasets", {
  datasets <- sf::st_as_sf(
    data.frame(
      time_start = as.Date(c("2018-02-01", "2020-06-15")),
      time_end = as.Date(c("2018-04-30", "2020-07-01")),
      longitude = 116.96,
      latitude = 4.75
    ),
    coords = c("longitude", "latitude"),
    crs = 4326
  )

  windows <- prepare_profile_time(datasets)

  expect_length(windows$time_start, 2L)
  expect_s3_class(windows$time_start, "POSIXct")
  expect_equal(
    prepare_profile_years(time_windows = windows),
    2018:2020
  )

  local_windows <- prepare_profile_time(
    data.frame(assetid = 1L),
    as.POSIXct("2019-12-31 16:00:00", tz = "UTC"),
    as.POSIXct("2020-12-31 16:00:00", tz = "UTC"),
    time_zone = "Asia/Kuching"
  )
  expect_equal(prepare_profile_years(time_windows = local_windows), 2020L)
})


test_that("temporal indicators are filtered per observation window", {
  annual <- data.frame(
    datetime = as.POSIXct(
      c("2018-01-01", "2019-01-01", "2020-01-01"),
      tz = "Asia/Kuala_Lumpur"
    ),
    variable = "humanfootprint_mean",
    unit = "unitless",
    value = 1:3
  )
  monthly <- data.frame(
    datetime = as.POSIXct(
      c("2019-01-01", "2019-03-01", "2019-05-01"),
      tz = "Asia/Kuala_Lumpur"
    ),
    variable = "worldclim_prec_mean",
    unit = "mm",
    value = 4:6
  )
  static <- data.frame(
    datetime = as.POSIXct("2017-01-01", tz = "UTC"),
    variable = "soc_0_5cm_mean_mean",
    unit = "g/kg",
    value = 7
  )
  portfolio <- data.frame(assetid = 1:2)
  portfolio$humanfootprint <- list(annual, annual)
  portfolio$precipitation_wc <- list(monthly, monthly)
  portfolio$soilproperties <- list(static, static)
  windows <- list(
    time_start = as.POSIXct(c("2018-06-01", "2019-03-10"), tz = "UTC"),
    time_end = as.POSIXct(c("2018-12-31", "2019-05-01"), tz = "UTC"),
    time_zone = "UTC"
  )

  filtered <- filter_validation_time(portfolio, windows)

  expect_equal(
    format(filtered$humanfootprint[[1]]$datetime, "%Y"),
    "2018"
  )
  expect_equal(
    format(filtered$humanfootprint[[2]]$datetime, "%Y"),
    "2019"
  )
  expect_equal(nrow(filtered$precipitation_wc[[1]]), 0L)
  expect_equal(nrow(filtered$precipitation_wc[[2]]), 1L)
  expect_identical(filtered$soilproperties, portfolio$soilproperties)
})


test_that("validation time windows are checked", {
  datasets <- data.frame(assetid = 1L)

  expect_error(
    prepare_profile_time(datasets, as.Date("2020-01-01")),
    "Both.*time_start.*time_end"
  )
  expect_error(
    prepare_profile_time(
      datasets,
      as.Date("2020-02-01"),
      as.Date("2020-01-01")
    ),
    "time_end.*be after"
  )
  expect_error(
    prepare_profile_time(
      datasets,
      as.Date("2020-01-01"),
      as.Date("2020-02-01"),
      time_zone = "Not/A_Time_Zone"
    ),
    "OlsonNames"
  )
  expect_error(
    prepare_profile_years(
      years = 2020,
      time_windows = list(
        time_start = as.POSIXct("2019-01-01", tz = "UTC"),
        time_end = as.POSIXct("2020-12-31", tz = "UTC"),
        time_zone = "UTC"
      )
    ),
    "must cover all observation windows"
  )
})


test_that("validation dataset inputs are checked", {
  expect_error(
    prepare_mapme_polygons(longitude = 1),
    "`longitude` and `latitude` must both be supplied"
  )
  expect_error(
    prepare_mapme_polygons(longitude = c(1, 2), latitude = 1),
    "must have equal, positive"
  )
  expect_error(
    prepare_mapme_polygons(longitude = 181, latitude = 0),
    "`longitude` must be between"
  )
  expect_error(
    prepare_mapme_polygons(longitude = 1, latitude = NA_real_),
    "must be finite"
  )
  expect_error(
    prepare_mapme_polygons(
      longitude = 1,
      latitude = 1,
      point_radius_m = 0
    ),
    "positive number"
  )
  expect_error(
    prepare_mapme_polygons(data.frame(x = 1)),
    "`x` must be an <sf> object"
  )
})

test_that("profile requests deduplicate matching cells and periods", {
  grid <- terra::rast(
    ncols = 2,
    nrows = 1,
    xmin = 0,
    xmax = 2,
    ymin = 0,
    ymax = 1,
    crs = "EPSG:4326"
  )
  terra::values(grid) <- 1:2
  square <- function(xmin, xmax) {
    sf::st_polygon(list(rbind(
      c(xmin, 0.1),
      c(xmax, 0.1),
      c(xmax, 0.9),
      c(xmin, 0.9),
      c(xmin, 0.1)
    )))
  }
  datasets <- sf::st_as_sf(
    data.frame(
      time_start = as.POSIXct(
        c("2018-01-01", "2018-01-10", "2018-01-01"),
        tz = "UTC"
      ),
      time_end = as.POSIXct(
        c("2018-01-31", "2018-02-01", "2018-01-31"),
        tz = "UTC"
      ),
      feature = c("first", "same", "crossing")
    ),
    geometry = sf::st_sfc(
      square(0.1, 0.2),
      square(0.2, 0.3),
      square(0.4, 1.6),
      crs = 4326
    )
  )

  requests <- prepare_profile_requests(
    datasets,
    prepare_profile_time(datasets),
    list(test = grid)
  )
  expect_equal(requests$request_count, 2L)
  expect_equal(requests$representative_rows, c(1L, 1L, 2L))

  portfolio <- requests$datasets
  portfolio$indicator <- list(
    data.frame(value = 10),
    data.frame(value = 20)
  )
  expanded <- expand_profile_requests(
    portfolio,
    datasets,
    requests$representative_rows
  )
  expect_equal(nrow(expanded), nrow(datasets))
  expect_equal(expanded$feature, datasets$feature)
  expect_equal(
    vapply(expanded$indicator, function(x) x$value, numeric(1)),
    c(10, 10, 20)
  )
})


test_that("profile requests keep outside features separate", {
  grid <- terra::rast(
    ncols = 1,
    nrows = 1,
    xmin = 0,
    xmax = 1,
    ymin = 0,
    ymax = 1,
    crs = "EPSG:4326"
  )
  terra::values(grid) <- 1
  datasets <- sf::st_as_sf(
    data.frame(label = c("one", "two")),
    geometry = sf::st_sfc(
      sf::st_point(c(2, 2)),
      sf::st_point(c(2, 2)),
      crs = 4326
    ) |>
      sf::st_buffer(0.01)
  )

  requests <- prepare_profile_requests(
    datasets,
    time_windows = NULL,
    grid_rasters = list(test = grid)
  )

  expect_equal(requests$request_count, 2L)
})


test_that("local SoilGrids extraction preserves portfolio shape", {
  directory <- withr::local_tempdir()
  source_path <- file.path(directory, "source.tif")
  destination_path <- file.path(directory, "crop.tif")
  source <- terra::rast(
    ncols = 2,
    nrows = 1,
    xmin = 0,
    xmax = 2,
    ymin = 0,
    ymax = 1,
    crs = "EPSG:4326"
  )
  terra::values(source) <- c(100, 200)
  terra::writeRaster(source, source_path, overwrite = TRUE)
  datasets <- sf::st_as_sf(
    data.frame(label = "feature"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(
        c(0.1, 0.1),
        c(0.2, 0.1),
        c(0.2, 0.2),
        c(0.1, 0.2),
        c(0.1, 0.1)
      ))),
      crs = 4326
    )
  )

  crop_path <- prepare_local_validation_soilgrids(
    datasets,
    source_path,
    destination_path
  )
  indicators <- extract_local_soilproperties(datasets, crop_path)

  expect_equal(crop_path, destination_path)
  expect_equal(
    prepare_local_validation_soilgrids(
      datasets,
      source_path,
      destination_path
    ),
    destination_path
  )
  expect_length(indicators, 1L)
  expect_equal(
    names(indicators[[1L]]),
    c("datetime", "variable", "unit", "value")
  )
  expect_equal(indicators[[1L]]$variable, "soc_0_5cm_mean_mean")
  expect_equal(indicators[[1L]]$value, 10)
})
