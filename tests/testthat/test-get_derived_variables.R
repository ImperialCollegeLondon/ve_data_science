# Tests for get_derived_variables
# Functions operate on tidync objects (tidync::tidync()) which return data arrays.
# get_data_variables() extracts specific named arrays from a tidync object.
# Tests mock get_data_variables() to provide controlled array data.

test_that("get_derived_variables returns a named list of arrays", {
  create_mock_nc()
  result <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_derived_variables(config = config)
  expect_type(result, "list")
  expect_named(result)
  expect_setequal(
    names(result),
    c(
      "total_soil_c_per_volume",
      "total_soil_c_per_mass",
      "total_soil_c_per_area",
      "soil_np_pool_microbial",
      "total_soil_n_per_volume",
      "total_soil_n_per_mass",
      "total_soil_n_per_area",
      "total_soil_p_per_volume",
      "total_soil_p_per_mass",
      "total_soil_p_per_area"
    )
  )
  expect_true(is.array(result[[1]]))
})

test_that("get_total_soil_c_per_volume sums all carbon pools", {
  create_mock_nc()
  result <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_c_per_volume()
  expect_equal(result[1, 1], sum(1:8))
})

test_that("get_total_soil_c_per_volume preserves spatiotemporal dimensions", {
  create_mock_nc()
  result <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_c_per_volume()
  expect_equal(dim(result), c(length(cell_id), length(time_index)))
})

test_that("get_total_soil_c_per_mass converts volume to mass basis correctly.", {
  create_mock_nc()
  result_volume_basis <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_c_per_volume()
  result_mass_basis <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_c_per_mass(config = config)
  bulk_density_VE <- 1175.0
  expect_equal(result_volume_basis / bulk_density_VE, result_mass_basis)
})
