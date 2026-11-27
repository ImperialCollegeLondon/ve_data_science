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

  windows <- prepare_validation_time(datasets)

  expect_length(windows$time_start, 2L)
  expect_s3_class(windows$time_start, "POSIXct")
  expect_equal(
    prepare_profile_years(time_windows = windows),
    2018:2020
  )

  local_windows <- prepare_validation_time(
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
    prepare_validation_time(datasets, as.Date("2020-01-01")),
    "Both.*time_start.*time_end"
  )
  expect_error(
    prepare_validation_time(
      datasets,
      as.Date("2020-02-01"),
      as.Date("2020-01-01")
    ),
    "time_end.*be after"
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
