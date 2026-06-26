# Tests for get_derived_variables
# Functions operate on tidync objects (tidync::tidync()) which return data arrays.
# get_data_variables() extracts specific named arrays from a tidync object.
# Tests mock get_data_variables() to provide controlled array data.

test_that("get_derived_variables returns a named list of arrays", {
  create_mock_nc()
  create_mock_cfg()
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

test_that("get_total_soil_c_per_mass converts volume to mass and area basis correctly.", {
  create_mock_nc()
  create_mock_cfg()
  result_volume_basis <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_c_per_volume()
  result_mass_basis <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_c_per_mass(config = config)
  result_area_basis <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_c_per_area(config = config)
  bulk_density_VE <- config$abiotic$constants$bulk_density_soil
  soil_layer_depth <- config$core$constants$max_depth_of_microbial_activity
  expect_equal(result_volume_basis / bulk_density_VE, result_mass_basis)
  expect_equal(result_volume_basis * soil_layer_depth, result_area_basis)
})

test_that("get_soil_np_pool_microbial converts C to N and P pools correctly.", {
  create_mock_nc()
  create_mock_cfg()
  soil_c_microbial <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_data_variables(
      c(
        "soil_c_pool_bacteria",
        "soil_c_pool_arbuscular_mycorrhiza",
        "soil_c_pool_ectomycorrhiza",
        "soil_c_pool_saprotrophic_fungi"
      )
    )
  stoich <-
    config$soil$microbial_group_definition |>
    purrr::map_vec(\(x) {
      as.data.frame(x[c("name", "c_n_ratio", "c_p_ratio")])
    })
  result <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_soil_np_pool_microbial(config = config)
  expect_equal(
    result$soil_n_pool_bacteria[1, 1],
    soil_c_microbial$soil_c_pool_bacteria[1, 1] /
      stoich$c_n_ratio[stoich$name == "bacteria"]
  )
  expect_equal(
    result$soil_p_pool_bacteria[1, 1],
    soil_c_microbial$soil_c_pool_bacteria[1, 1] /
      stoich$c_p_ratio[stoich$name == "bacteria"]
  )
  expect_equal(
    result$soil_n_pool_arbuscular_mycorrhiza[1, 1],
    soil_c_microbial$soil_c_pool_arbuscular_mycorrhiza[1, 1] /
      stoich$c_n_ratio[stoich$name == "arbuscular_mycorrhiza"]
  )
  expect_equal(
    result$soil_p_pool_arbuscular_mycorrhiza[1, 1],
    soil_c_microbial$soil_c_pool_arbuscular_mycorrhiza[1, 1] /
      stoich$c_p_ratio[stoich$name == "arbuscular_mycorrhiza"]
  )
  expect_equal(
    result$soil_n_pool_ectomycorrhiza[1, 1],
    soil_c_microbial$soil_c_pool_ectomycorrhiza[1, 1] /
      stoich$c_n_ratio[stoich$name == "ectomycorrhiza"]
  )
  expect_equal(
    result$soil_p_pool_ectomycorrhiza[1, 1],
    soil_c_microbial$soil_c_pool_ectomycorrhiza[1, 1] /
      stoich$c_p_ratio[stoich$name == "ectomycorrhiza"]
  )
  expect_equal(
    result$soil_n_pool_saprotrophic_fungi[1, 1],
    soil_c_microbial$soil_c_pool_saprotrophic_fungi[1, 1] /
      stoich$c_n_ratio[stoich$name == "saprotrophic_fungi"]
  )
  expect_equal(
    result$soil_p_pool_saprotrophic_fungi[1, 1],
    soil_c_microbial$soil_c_pool_saprotrophic_fungi[1, 1] /
      stoich$c_p_ratio[stoich$name == "saprotrophic_fungi"]
  )
})

test_that("get_total_soil_n_per_volume sums all nitrogen pools", {
  create_mock_nc()
  create_mock_cfg()
  stoich <-
    config$soil$microbial_group_definition |>
    purrr::map_vec(\(x) {
      as.data.frame(x[c("name", "c_n_ratio")])
    })
  c_n_ratio <- stoich$c_n_ratio[c(3, 4, 2, 1)]
  result <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_n_per_volume(config = config)
  expect_equal(result[1, 1], sum(2:5) + sum((5:8) / c_n_ratio) + sum(9:10))
})

test_that("get_total_soil_n_per_volume preserves spatiotemporal dimensions", {
  create_mock_nc()
  create_mock_cfg()
  result <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_n_per_volume(config = config)
  expect_equal(dim(result), c(length(cell_id), length(time_index)))
})
