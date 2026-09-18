#| ---
#| title: Tests for dataframe-to-netCDF conversion
#|
#| description: |
#|     Unit tests for convert_df_to_nc(), covering netCDF structure,
#|     non-CNP variable reshaping, and CNP variable element/x/y orientation.
#|     Includes a regression-style check designed to catch array fill/order
#|     mistakes when converting list-column triplets to a 3D array.
#|
#| virtual_ecosystem_module: Soil, Litter
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| package_dependencies:
#|     - testthat
#|     - withr
#|     - RNetCDF
#|
#| usage_notes: |
#|     Run via: testthat::test_dir("tools/R/tests/testthat")
#|     The `make_test_df_for_nc()` fixture intentionally mirrors the mixed-column
#|     shape of the scenario construction object `dat`: scalar/vector columns
#|     (e.g., spatial coordinates and single-pool variables) plus list columns
#|     where each row stores a C/N/P triplet for `_cnp` variables. This pattern
#|     follows the Maliau soil input pipeline in
#|     analysis/soil/initialisation/input_data_maliau_1.R
#| ---

make_test_df_for_nc <- function() {
  # mimic `dat` structure from soil and litter Maliau input data pipelines:
  # tibble with mixed vector and list columns
  tibble::tibble(
    cell_x = c(10, 10, 20, 20),
    cell_y = c(100, 200, 100, 200),
    temp = c(11, 12, 13, 14),
    pH = c(4.6, 4.7, 4.8, 4.9),
    clay_fraction = c(0.22, 0.24, 0.26, 0.28),
    soil_cnp_pool_pom = list(
      c(C = 101, N = 102, P = 103),
      c(C = 201, N = 202, P = 203),
      c(C = 301, N = 302, P = 303),
      c(C = 401, N = 402, P = 403)
    ),
    soil_cnp_pool_maom = list(
      c(C = 501, N = 502, P = 503),
      c(C = 601, N = 602, P = 603),
      c(C = 701, N = 702, P = 703),
      c(C = 801, N = 802, P = 803)
    )
  )
}


test_that("convert_df_to_nc writes expected dimensions, metadata, and only requested variables", {
  out <- withr::local_tempfile(fileext = ".nc")

  vars <- c(
    "temp",
    "pH",
    "clay_fraction",
    "soil_cnp_pool_pom",
    "soil_cnp_pool_maom"
  )
  units <- c("degC", "1", "1", "kg m-3", "kg m-3")

  convert_df_to_nc(
    data = make_test_df_for_nc(),
    filename = out,
    x = c(10, 20),
    y = c(100, 200),
    element = c("C", "N", "P"),
    variables = vars,
    units = units,
    description = "test file"
  )

  nc <- RNetCDF::open.nc(out)
  withr::defer(RNetCDF::close.nc(nc))

  expect_equal(RNetCDF::dim.inq.nc(nc, "x")$length, 2)
  expect_equal(RNetCDF::dim.inq.nc(nc, "y")$length, 2)
  expect_equal(RNetCDF::dim.inq.nc(nc, "element")$length, 3)

  expect_equal(as.vector(RNetCDF::var.get.nc(nc, "x")), c(10, 20))
  expect_equal(as.vector(RNetCDF::var.get.nc(nc, "y")), c(100, 200))
  expect_equal(as.vector(RNetCDF::var.get.nc(nc, "element")), c("C", "N", "P"))

  expect_equal(RNetCDF::att.get.nc(nc, "NC_GLOBAL", "description"), "test file")

  for (i in seq_along(vars)) {
    expect_equal(RNetCDF::att.get.nc(nc, vars[i], "units"), units[i])
  }

  nvars <- RNetCDF::file.inq.nc(nc)$nvars
  var_names <- vapply(
    X = seq_len(nvars) - 1,
    FUN = function(i) RNetCDF::var.inq.nc(nc, i)$name,
    FUN.VALUE = character(1)
  )

  expected_var_names <- c("x", "y", "element", vars)
  expect_setequal(var_names, expected_var_names)
  expect_false(any(c("cell_x", "cell_y") %in% var_names))
})


test_that("convert_df_to_nc preserves all non-CNP variable values on y-x grid", {
  out <- withr::local_tempfile(fileext = ".nc")

  convert_df_to_nc(
    data = make_test_df_for_nc(),
    filename = out,
    x = c(10, 20),
    y = c(100, 200),
    element = c("C", "N", "P"),
    variables = c("temp", "pH", "clay_fraction"),
    units = c("degC", "1", "1")
  )

  nc <- RNetCDF::open.nc(out)
  withr::defer(RNetCDF::close.nc(nc))

  expected_arrays <- list(
    temp = array(c(11, 12, 13, 14), dim = c(2, 2)),
    pH = array(c(4.6, 4.7, 4.8, 4.9), dim = c(2, 2)),
    clay_fraction = array(c(0.22, 0.24, 0.26, 0.28), dim = c(2, 2))
  )

  for (var_name in names(expected_arrays)) {
    arr <- RNetCDF::var.get.nc(nc, var_name)

    # var dim order is rev(c("x", "y")) -> c("y", "x")
    expect_equal(dim(arr), c(2, 2))
    expect_equal(arr, expected_arrays[[var_name]])
  }
})


test_that("convert_df_to_nc maps each CNP triplet to the correct element/y/x cell for all CNP vars", {
  out <- withr::local_tempfile(fileext = ".nc")

  convert_df_to_nc(
    data = make_test_df_for_nc(),
    filename = out,
    x = c(10, 20),
    y = c(100, 200),
    element = c("C", "N", "P"),
    variables = c("soil_cnp_pool_pom", "soil_cnp_pool_maom"),
    units = c("kg m-3", "kg m-3")
  )

  nc <- RNetCDF::open.nc(out)
  withr::defer(RNetCDF::close.nc(nc))

  check_cnp_var <- function(var_name, expected_triplets) {
    cnp_arr <- RNetCDF::var.get.nc(nc, var_name)

    # var dim order is rev(c("x", "y", "element")) -> c("element", "y", "x")
    expect_equal(dim(cnp_arr), c(3, 2, 2))

    expect_equal(cnp_arr[, 1, 1], expected_triplets[[1]])
    expect_equal(cnp_arr[, 2, 1], expected_triplets[[2]])
    expect_equal(cnp_arr[, 1, 2], expected_triplets[[3]])
    expect_equal(cnp_arr[, 2, 2], expected_triplets[[4]])
  }

  check_cnp_var(
    "soil_cnp_pool_pom",
    list(
      c(101, 102, 103),
      c(201, 202, 203),
      c(301, 302, 303),
      c(401, 402, 403)
    )
  )

  check_cnp_var(
    "soil_cnp_pool_maom",
    list(
      c(501, 502, 503),
      c(601, 602, 603),
      c(701, 702, 703),
      c(801, 802, 803)
    )
  )
})
