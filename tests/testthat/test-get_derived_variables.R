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

# test_that("get_total_soil_c_per_volume sums all carbon pools", {
#   result <- get_total_soil_c_per_volume(NULL)
#   expect_equal(as.numeric(result[1, 1]), 8 * c_value)
# })

# test_that("get_total_soil_c_per_volume preserves spatial dimensions", {
#   result <- get_total_soil_c_per_volume(NULL)
#   # Dimensions should be (4, 5) after selecting C from CNP pools
#   expect_equal(dim(result), c(4, 5))
# })
