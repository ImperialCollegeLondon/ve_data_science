#| ---
#| title: Tests for continuous state data tidying
#|
#| description: |
#|     Regression tests for preserving initial time coordinates and timeless
#|     initial values in tidy_continuous_data().
#|
#| virtual_ecosystem_module: All
#|
#| status: final
#|
#| package_dependencies:
#|     - testthat
#|     - withr
#|     - pizzarr
#|     - dplyr
#| ---

source(here::here("tools/R/R/tidy_continuous_data.R"))

make_tidy_continuous_fixture <- function(path, time_metadata = TRUE) {
  root <- pizzarr::zarr_create_group(path, zarr_format = 2L)
  outputs <- root$create_group("outputs")
  init <- root$create_group("init")

  write_array <- function(group, name, values, dimensions) {
    shape <- if (is.null(dim(values))) length(values) else dim(values)
    array <- group$create_dataset(name, values, shape = shape)
    array$get_attrs()$set_item("_ARRAY_DIMENSIONS", dimensions)
    array
  }
  write_coordinates <- function(group) {
    write_array(group, "cell_id", c(0, 1), "cell_id")
    write_array(group, "time_index", c(0, 1), "time_index")
    write_array(group, "layers", c(1, 2), "layers")
    write_array(group, "element", c(1, 2), "element")
    write_array(group, "pft", c(1, 2), "pft")
  }
  write_coordinates(outputs)
  write_coordinates(init)

  variable_dims <- list(cell_id = c("0", "1"), time_index = c("0", "1"))
  output_series <- array(
    11:14,
    dim = c(2, 2),
    dimnames = variable_dims
  )
  write_array(
    outputs,
    "vapour_pressure_ref",
    output_series,
    names(variable_dims)
  )
  write_array(
    outputs,
    "vapour_pressure_deficit_ref",
    output_series + 100,
    names(variable_dims)
  )
  output_static <- array(
    31:34,
    dim = c(2, 2),
    dimnames = variable_dims
  )
  write_array(outputs, "timeless_state", output_static, names(variable_dims))
  extra_dims <- list(
    cell_id = c("0", "1"),
    time_index = c("0", "1"),
    layers = c("1", "2"),
    element = c("1", "2"),
    pft = c("1", "2")
  )
  extra_output <- array(1:32, dim = lengths(extra_dims), dimnames = extra_dims)
  write_array(outputs, "extra_state", extra_output, names(extra_dims))

  write_array(outputs, "x", c(10, 20), "cell_id")
  write_array(outputs, "y", c(30, 40), "cell_id")
  output_time <- write_array(outputs, "timestamp", c(1, 31), "time_index")
  output_time$get_attrs()$set_item("units", "days since 1999-12-31")
  output_time$get_attrs()$set_item("calendar", "proleptic_gregorian")

  write_array(
    init,
    "vapour_pressure_ref",
    array(
      1:4,
      dim = c(2, 2),
      dimnames = variable_dims
    ),
    names(variable_dims)
  )
  write_array(
    init,
    "vapour_pressure_deficit_ref",
    array(
      101:104,
      dim = c(2, 2),
      dimnames = variable_dims
    ),
    names(variable_dims)
  )
  write_array(init, "timeless_state", c(101, 102), "cell_id")
  write_array(init, "extra_state", extra_output, names(extra_dims))
  write_array(
    init,
    "init_only_state",
    array(201:204, dim = c(2, 2), dimnames = variable_dims),
    names(variable_dims)
  )
  init_time <- write_array(init, "valid_time", c(12, 36), "time_index")
  if (time_metadata) {
    init_time$get_attrs()$set_item("units", "hours since 2000-01-01")
    init_time$get_attrs()$set_item("calendar", "proleptic_gregorian")
  }

  invisible(path)
}

test_that("initial time series keep source indices and converted timestamps", {
  path <- withr::local_tempdir()
  make_tidy_continuous_fixture(path)

  result <- tidy_continuous_data(
    path,
    variables = c("vapour_pressure_ref", "vapour_pressure_deficit_ref"),
    initial = TRUE
  )
  initial <- result |>
    dplyr::filter(timestamp %in% c(1.5, 2.5)) |>
    dplyr::arrange(variable, cell_id, time_index)

  expect_equal(initial$time_index, rep(c(0, 1, 0, 1), 2))
  expect_equal(initial$timestamp, rep(c(1.5, 2.5, 1.5, 2.5), 2))
  expect_equal(initial$value, c(101, 103, 102, 104, 1, 3, 2, 4))
  expect_equal(
    anyDuplicated(initial |> dplyr::select(timestamp, cell_id, variable)),
    0L
  )
})

test_that("timeless initial values and additional dimensions are preserved", {
  path <- withr::local_tempdir()
  make_tidy_continuous_fixture(path)

  result <- tidy_continuous_data(
    path,
    variables = c("timeless_state", "extra_state"),
    initial = TRUE
  )
  timeless <- result |>
    dplyr::filter(variable == "timeless_state", time_index < 0)
  extra <- result |>
    dplyr::filter(variable == "extra_state", timestamp %in% c(1.5, 2.5))

  expect_equal(timeless$time_index, c(-1, -1))
  expect_equal(timeless$timestamp, c(-1, -1))
  expect_equal(timeless$value, c(101, 102))
  expect_equal(nrow(extra), 32L)
  expect_true(all(c("layers", "element", "pft") %in% names(extra)))
  expect_false(anyNA(extra |> dplyr::select(layers, element, pft)))
})

test_that("timeless-only init and output-only behavior need no init mapping", {
  path <- withr::local_tempdir()
  make_tidy_continuous_fixture(path, time_metadata = FALSE)

  initial <- tidy_continuous_data(
    path,
    variables = "timeless_state",
    initial = TRUE
  )
  output <- tidy_continuous_data(
    path,
    variables = "vapour_pressure_ref",
    initial = FALSE
  )

  expect_equal(initial$time_index[initial$value >= 100], c(-1, -1))
  expect_equal(initial$timestamp[initial$value >= 100], c(-1, -1))
  expect_equal(nrow(output), 4L)
  expect_equal(output$time_index, c(0, 0, 1, 1))
  expect_equal(output$timestamp, c(1, 1, 31, 31))
  expect_equal(output$value, c(11, 12, 13, 14))
})

test_that("time-varying init fails when its time mapping metadata is missing", {
  path <- withr::local_tempdir()
  make_tidy_continuous_fixture(path, time_metadata = FALSE)

  expect_error(
    tidy_continuous_data(
      path,
      variables = "vapour_pressure_ref",
      initial = TRUE
    ),
    "Could not identify one initial time coordinate"
  )
})


test_that("requested initial variables absent from outputs are returned", {
  path <- withr::local_tempdir()
  make_tidy_continuous_fixture(path)

  result <- tidy_continuous_data(
    path,
    variables = "init_only_state",
    initial = TRUE
  )

  expect_equal(nrow(result), 4L)
  expect_equal(result$value, c(201, 202, 203, 204))
  expect_equal(result$time_index, c(0, 0, 1, 1))
  expect_equal(result$timestamp, c(1.5, 1.5, 2.5, 2.5))
})
