#| ---
#| title: Tests for soil derived variables functions
#|
#| description: |
#|     Unit tests for the get_derived_variables function and related
#|     functions that calculate total soil carbon, nitrogen, and
#|     phosphorus pools per volume, mass, and area bases. Tests verify
#|     correct summing of constituent pools, unit conversions, and
#|     stoichiometric calculations from microbial C to N and P pools.
#|
#| virtual_ecosystem_module: Soil
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| source_files:
#|   - name: get_derived_variables.R
#|     path: tools/R/
#|     description: |
#|       Functions to calculate derived soil CNP pool variables
#|   - name: get_data_variables.R
#|     path: tools/R/
#|     description: |
#|       Function to extract data variables from netCDF
#|
#| input_files:
#|   - name: mock_data.nc
#|     path: tests/testthat/ (temporary)
#|     description: |
#|       Temporary mock netCDF file with soil pool arrays,
#|       created by setup script
#|   - name: mock_config.TOML
#|     path: tests/testthat/ (temporary)
#|     description: |
#|       Temporary mock VE config file with stoichiometric
#|       ratios, created by setup script
#|
#| package_dependencies:
#|     - testthat
#|     - tidync
#|     - purrr
#|
#| usage_notes: |
#|     Run via: testthat::test_dir("tests/testthat")
#|     Requires setup.R to be executed first to define create_mock_nc(),
#|     create_mock_cfg(), and source helper functions (this is automatic upon
#|     running testthat::test_dir("tests/testthat"). All temporary files
#|     are cleaned up after tests complete.
#| ---
test_that("get_derived_variables returns a named list of arrays", {
  # Create temporary mock netCDF file
  create_mock_nc()
  # Create temporary mock config file
  config <- create_mock_cfg()
  result <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_derived_variables(config = config)
  # Result is a list
  expect_type(result, "list")
  # List has names
  expect_named(result)
  # Verify all expected derived variables are present
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
  # List elements are arrays
  expect_true(is.array(result[[1]]))
})

test_that("get_total_soil_c_per_volume sums all carbon pools", {
  create_mock_nc()
  result <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_c_per_volume()
  # Total C values should sums from all 8 pools in the mock data
  expect_equal(result[1, 1], sum(1:8))
})

test_that("get_total_soil_c_per_volume preserves spatiotemporal dimensions", {
  create_mock_nc()
  result <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_c_per_volume()
  # Output dims: [cell_id × time_index]
  expect_equal(dim(result), c(length(cell_id), length(time_index)))
})

test_that("get_total_soil_c_per_mass converts volume to mass and get_total_soil_c_per_area to area basis correctly.", {
  create_mock_nc()
  config <- create_mock_cfg()
  result_volume_basis <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_c_per_volume()
  result_mass_basis <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_c_per_mass(config = config)
  result_area_basis <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_c_per_area(config = config)
  # Extract conversion factors from config
  bulk_density_VE <- config$abiotic$constants$bulk_density_soil
  soil_layer_depth <- config$core$constants$max_depth_of_microbial_activity
  # Verify unit conversions: mass = volume / bulk_density; area = volume * depth
  expect_equal(result_volume_basis / bulk_density_VE, result_mass_basis)
  expect_equal(result_volume_basis * soil_layer_depth, result_area_basis)
})

test_that("get_soil_np_pool_microbial converts C to N and P pools correctly.", {
  create_mock_nc()
  config <- create_mock_cfg()
  # Extract C microbial pools
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
  # Extract stoichiometric ratios (C:N and C:P) for each microbial group
  stoich <-
    config$soil$microbial_group_definition |>
    purrr::map_vec(\(x) {
      as.data.frame(x[c("name", "c_n_ratio", "c_p_ratio")])
    })
  result <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_soil_np_pool_microbial(config = config)
  # Verify N pools: N = C / C:N ratio
  expect_equal(
    result$soil_n_pool_bacteria[1, 1],
    soil_c_microbial$soil_c_pool_bacteria[1, 1] /
      stoich$c_n_ratio[stoich$name == "bacteria"]
  )
  # Verify P pools: P = C / C:P ratio
  expect_equal(
    result$soil_p_pool_bacteria[1, 1],
    soil_c_microbial$soil_c_pool_bacteria[1, 1] /
      stoich$c_p_ratio[stoich$name == "bacteria"]
  )
  # Repeat verification for remaining microbial groups
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
  config <- create_mock_cfg()
  # Extract C:N ratios for all microbial groups (order: ectomycorrhiza, saprotrophic_fungi, arbuscular_mycorrhiza, bacteria)
  stoich <-
    config$soil$microbial_group_definition |>
    purrr::map_vec(\(x) {
      as.data.frame(x[c("name", "c_n_ratio")])
    })
  c_n_ratio <- stoich$c_n_ratio[c(3, 4, 2, 1)]
  result <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_n_per_volume(config = config)
  # Mock data pools: organic N (2:5) + microbial N (C pools 5:8 divided by C:N) + inorganic N (9:10)
  expect_equal(result[1, 1], sum(2:5) + sum((5:8) / c_n_ratio) + sum(9:10))
})

test_that("get_total_soil_n_per_volume preserves spatiotemporal dimensions", {
  create_mock_nc()
  config <- create_mock_cfg()
  result <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_n_per_volume(config = config)
  expect_equal(dim(result), c(length(cell_id), length(time_index)))
})

test_that("get_total_soil_n_per_mass converts volume to mass and get_total_soil_n_per_area to area basis correctly.", {
  create_mock_nc()
  config <- create_mock_cfg()
  result_volume_basis <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_n_per_volume(config = config)
  result_mass_basis <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_n_per_mass(config = config)
  result_area_basis <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_n_per_area(config = config)
  bulk_density_VE <- config$abiotic$constants$bulk_density_soil
  soil_layer_depth <- config$core$constants$max_depth_of_microbial_activity
  expect_equal(result_volume_basis / bulk_density_VE, result_mass_basis)
  expect_equal(result_volume_basis * soil_layer_depth, result_area_basis)
})

# Repeat soil N tests on soil P
test_that("get_total_soil_p_per_volume sums all phosphorous pools", {
  create_mock_nc()
  config <- create_mock_cfg()
  stoich <-
    config$soil$microbial_group_definition |>
    purrr::map_vec(\(x) {
      as.data.frame(x[c("name", "c_p_ratio")])
    })
  c_p_ratio <- stoich$c_p_ratio[c(3, 4, 2, 1)]
  result <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_p_per_volume(config = config)
  expect_equal(result[1, 1], sum(3:6) + sum((5:8) / c_p_ratio) + sum(11:13))
})

test_that("get_total_soil_p_per_volume preserves spatiotemporal dimensions", {
  create_mock_nc()
  config <- create_mock_cfg()
  result <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_p_per_volume(config = config)
  expect_equal(dim(result), c(length(cell_id), length(time_index)))
})

test_that("get_total_soil_p_per_mass converts volume to mass and get_total_soil_p_per_area to area basis correctly.", {
  create_mock_nc()
  config <- create_mock_cfg()
  result_volume_basis <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_p_per_volume(config = config)
  result_mass_basis <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_p_per_mass(config = config)
  result_area_basis <-
    tidync::tidync(test_path("mock_data.nc")) |>
    get_total_soil_p_per_area(config = config)
  bulk_density_VE <- config$abiotic$constants$bulk_density_soil
  soil_layer_depth <- config$core$constants$max_depth_of_microbial_activity
  expect_equal(result_volume_basis / bulk_density_VE, result_mass_basis)
  expect_equal(result_volume_basis * soil_layer_depth, result_area_basis)
})
