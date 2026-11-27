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
