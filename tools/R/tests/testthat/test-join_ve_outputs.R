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
  expect_equal(result["value_VE_med_neg1"], c(value_VE_med_neg1 = 100))
  expect_equal(result["value_VE_mean"], c(value_VE_mean = 100))
})

test_that("join_ve_outputs_per_row computes value_VE_med_neg1 as the beta = -1 median", {
  # beta_median() with beta = -1 weights values by 1 / value, so smaller
  # values get relatively more weight than in the ordinary median.
  ve_data <- tibble::tibble(
    var_canonical = "soil_carbon",
    date = as.POSIXct("2016-09-01", tz = "UTC"),
    lat_min = 4.0,
    lat_max = 5.0,
    lon_min = 117.0,
    lon_max = 118.0,
    value = c(1, 2, 10, 20, 100)
  )

  result <- join_ve_outputs_per_row(
    ve_data = ve_data,
    var_canonical = "soil_carbon",
    time_start = as.POSIXct("2016-09-01", tz = "UTC"),
    time_end = as.POSIXct(NA, tz = "UTC"),
    latitude = 4.5,
    longitude = 117.5,
    spatiotemporal_join_class = "spatial_within_temporal_within"
  )

  expect_equal(result["value_VE_q50"], c(value_VE_q50 = 10))
  expect_equal(result["value_VE_med_neg1"], c(value_VE_med_neg1 = 1))
  expect_equal(
    result["value_VE_mean"],
    c(value_VE_mean = mean(c(1, 2, 10, 20, 100)))
  )
})

test_that("join_ve_outputs warns about unavailable beta-medians once", {
  join_env <- new.env(parent = globalenv())
  source(here::here("tools/R/R/valdb_join_ve.R"), local = join_env)
  join_env$read_scenario_definition <- function(...) {
    list(
      grid_res = 100,
      start_date = as.Date("2016-09-01"),
      spatial_bounds = c(-1, -1, 1, 1),
      temporal_bounds = as.Date(c("2016-08-31", "2016-09-10"))
    )
  }
  join_env$get_data_variables <- function(zarr_path, group, variables) {
    if ("x" %in% variables) {
      return(list(
        x = array(500000, dim = 1, dimnames = list(cell_id = "1")),
        y = array(500000, dim = 1, dimnames = list(cell_id = "1"))
      ))
    }
    list(
      timestamp = array(
        c(0, 1),
        dim = 2,
        dimnames = list(time_index = c("0", "1"))
      )
    )
  }
  join_env$get_derived_variables <- function(...) {
    list(
      soil_carbon = array(
        c(0, 1),
        dim = c(2, 1),
        dimnames = list(time_index = c("0", "1"), cell_id = "1")
      )
    )
  }
  local_mocked_bindings(
    zarr_open = function(...) {
      list(get_item = function(...) {
        list(get_store = function() list(listdir = function(...) character()))
      })
    },
    .package = "pizzarr"
  )

  db <- tibble::tibble(
    var_canonical = c("soil_carbon", "soil_carbon", "soil_carbon", "missing"),
    time_start = as.POSIXct(
      c("2016-09-01", "2016-09-01", "2016-09-02", "2016-09-01"),
      tz = "UTC"
    ),
    time_end = as.POSIXct(
      c("2016-09-02", "2016-09-02", NA, NA),
      tz = "UTC"
    ),
    latitude = 10,
    longitude = 10
  )

  expect_warning(
    result <- join_env$join_ve_outputs(db, "unused", "unused"),
    "2 matched rows without a beta-median prediction"
  )
  expect_equal(result$value_VE_med_neg1, c(NA_real_, NA_real_, 1, NA_real_))
  expect_equal(result$value_VE_q50, c(0.5, 0.5, 1, NA_real_))
  expect_warning(
    join_env$join_ve_outputs(db[1, ], "unused", "unused"),
    "1 matched row without a beta-median prediction"
  )
  expect_no_warning(join_env$join_ve_outputs(db[3:4, ], "unused", "unused"))
  expect_true(is.na(join_env$beta_median(c(-1, 1), beta = -1)))
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

test_that("join_ve_outputs_per_row matches landscape density without coordinates", {
  ve_data <- tibble::tibble(
    var_canonical = "density_carnivorous_aquatic_mammal_L5",
    spatial_scope = "landscape",
    date = as.POSIXct("2016-09-01", tz = "UTC"),
    value = 100
  )

  result <-
    join_ve_outputs_per_row(
      ve_data = ve_data,
      var_canonical = "density_carnivorous_aquatic_mammal_L5",
      time_start = as.POSIXct("2016-09-15", tz = "UTC"),
      time_end = as.POSIXct(NA, tz = "UTC"),
      latitude = NA_real_,
      longitude = NA_real_,
      spatiotemporal_join_class = "spatial_within_temporal_within"
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
