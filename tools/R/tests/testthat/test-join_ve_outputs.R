#| ---
#| title: Tests for join_ve_outputs interval-based matching
#|
#| description: |
#|     Unit tests for temporal matching in join_ve_outputs_per_row().
#|     Verifies that observations are matched to nearest VE timestamps
#|     at both interval boundaries, then aggregated over the matched window.
#|
#| virtual_ecosystem_module: Soil
#|
#| author: Posit Assistant
#|
#| status: final
#|
#| package_dependencies:
#|     - testthat
#|     - dplyr
#|     - lubridate
#| ---

test_that("join_ve_outputs_per_row matches point observation to nearest timestamp", {
  # Simulate VE data with two output timesteps
  ve_data <- tibble::tibble(
    var_canonical = c("soil_carbon", "soil_carbon"),
    date = as.POSIXct(c("2016-09-01", "2016-10-01"), tz = "UTC"),
    lat_min = c(4.0, 4.0),
    lat_max = c(5.0, 5.0),
    lon_min = c(117.0, 117.0),
    lon_max = c(118.0, 118.0),
    value = c(100, 110)
  )

  # Point observation on 2016-09-15 (closer to 2016-09-01 than 2016-10-01)
  result <- join_ve_outputs_per_row(
    ve_data = ve_data,
    var_canonical = "soil_carbon",
    time_start = as.POSIXct("2016-09-15 12:00:00", tz = "UTC"),
    time_end = as.POSIXct(NA, tz = "UTC"),
    latitude = 4.5,
    longitude = 117.5,
    spatiotemporal_join_class = "spatial_within_temporal_within"
  )

  expect_equal(result["value_VE_q50"], c(value_VE_q50 = 100))
  expect_equal(result["value_VE_q05"], c(value_VE_q05 = 100))
  expect_equal(result["value_VE_q95"], c(value_VE_q95 = 100))
})

test_that("join_ve_outputs_per_row matches interval to nearest start and end timestamps", {
  # Simulate VE data with monthly outputs
  ve_data <- tibble::tibble(
    var_canonical = c("soil_carbon", "soil_carbon", "soil_carbon"),
    date = as.POSIXct(c("2016-08-01", "2016-09-01", "2016-10-01"), tz = "UTC"),
    lat_min = c(4.0, 4.0, 4.0),
    lat_max = c(5.0, 5.0, 5.0),
    lon_min = c(117.0, 117.0, 117.0),
    lon_max = c(118.0, 118.0, 118.0),
    value = c(90, 100, 110)
  )

  # Interval observation from 2016-09-10 to 2016-09-25
  # start (2016-09-10) is closest to 2016-09-01
  # end (2016-09-25) is closest to 2016-10-01
  # So aggregate over [2016-09-01, 2016-10-01], which is values 100 and 110
  result <- join_ve_outputs_per_row(
    ve_data = ve_data,
    var_canonical = "soil_carbon",
    time_start = as.POSIXct("2016-09-10", tz = "UTC"),
    time_end = as.POSIXct("2016-09-25", tz = "UTC"),
    latitude = 4.5,
    longitude = 117.5,
    spatiotemporal_join_class = "spatial_within_temporal_within"
  )

  # Quantiles should be computed from [100, 110]
  expect_equal(result["value_VE_q05"], c(value_VE_q05 = 100), tolerance = 1)
  expect_equal(result["value_VE_q50"], c(value_VE_q50 = 105), tolerance = 1)
  expect_equal(result["value_VE_q95"], c(value_VE_q95 = 110), tolerance = 1)
})

test_that("join_ve_outputs_per_row respects spatial bounds for spatial_within", {
  ve_data <- tibble::tibble(
    var_canonical = "soil_carbon",
    date = as.POSIXct("2016-09-01", tz = "UTC"),
    lat_min = c(4.0),
    lat_max = c(5.0),
    lon_min = c(117.0),
    lon_max = c(118.0),
    value = 100
  )

  # Observation outside spatial bounds
  result <- join_ve_outputs_per_row(
    ve_data = ve_data,
    var_canonical = "soil_carbon",
    time_start = as.POSIXct("2016-09-15", tz = "UTC"),
    time_end = as.POSIXct(NA, tz = "UTC"),
    latitude = 3.5, # outside [4.0, 5.0]
    longitude = 117.5,
    spatiotemporal_join_class = "spatial_within_temporal_within"
  )

  expect_true(all(is.na(result)))
})

test_that("join_ve_outputs_per_row ignores spatial bounds for spatial_outside", {
  ve_data <- tibble::tibble(
    var_canonical = "soil_carbon",
    date = as.POSIXct("2016-09-01", tz = "UTC"),
    lat_min = c(4.0),
    lat_max = c(5.0),
    lon_min = c(117.0),
    lon_max = c(118.0),
    value = 100
  )

  # Observation outside spatial bounds, but spatial_outside class ignores them
  result <- join_ve_outputs_per_row(
    ve_data = ve_data,
    var_canonical = "soil_carbon",
    time_start = as.POSIXct("2016-09-15", tz = "UTC"),
    time_end = as.POSIXct(NA, tz = "UTC"),
    latitude = 3.5, # outside [4.0, 5.0]
    longitude = 117.5,
    spatiotemporal_join_class = "spatial_outside_temporal_within"
  )

  expect_equal(result["value_VE_q50"], c(value_VE_q50 = 100))
})

test_that("join_ve_outputs_per_row returns NA for unimplemented spatiotemporal classes", {
  ve_data <- tibble::tibble(
    var_canonical = "soil_carbon",
    date = as.POSIXct("2016-09-01", tz = "UTC"),
    lat_min = c(4.0),
    lat_max = c(5.0),
    lon_min = c(117.0),
    lon_max = c(118.0),
    value = 100
  )

  result <- join_ve_outputs_per_row(
    ve_data = ve_data,
    var_canonical = "soil_carbon",
    time_start = as.POSIXct("2016-09-15", tz = "UTC"),
    time_end = as.POSIXct(NA, tz = "UTC"),
    latitude = 4.5,
    longitude = 117.5,
    spatiotemporal_join_class = "spatial_within_temporal_outside"
  )

  expect_true(all(is.na(result)))
})
