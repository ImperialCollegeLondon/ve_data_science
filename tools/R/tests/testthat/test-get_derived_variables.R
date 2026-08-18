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
#|   - name: get_ve_variables.R
#|     path: tools/R/R/
#|     description: |
#|       Functions to retrieve and calculate derived Virtual Ecosystem variables
#|       from Zarr output datasets
#|
#| input_files:
#|   - name: mock_data.zarr
#|     path: tests/testthat/ (temporary)
#|     description: |
#|       Temporary mock Zarr dataset with soil pool arrays,
#|       created by setup script
#|   - name: mock_config.TOML
#|     path: tests/testthat/ (temporary)
#|     description: |
#|       Temporary mock VE config file with stoichiometric
#|       ratios, created by setup script
#|
#| package_dependencies:
#|     - testthat
#|     - pizzarr
#|     - purrr
#|
#| usage_notes: |
#|     Run via: testthat::test_dir("tools/R/tests/testthat")
#|     Requires setup.R to be executed first to define create_mock_zarr(),
#|     create_mock_cfg(), and source helper functions (this is automatic upon
#|     running testthat::test_dir("tools/R/tests/testthat"). All temporary files
#|     are cleaned up after tests complete.
#| ---

test_that("get_derived_variables returns the expected top-level names", {
  # Create temporary mock Zarr and config file
  dir <- withr::local_tempdir()
  mock_zarr <- create_mock_zarr(dir)
  mock_config <- create_mock_cfg(dir)
  config <- toml::read_toml(mock_config)

  result <- get_derived_variables(mock_zarr, mock_config, group = "outputs")

  expect_type(result, "list")
  expect_named(result)
  expect_setequal(
    names(result),
    c(
      "total_soil_c_per_volume",
      "total_soil_c_per_mass",
      "total_soil_c_per_area",
      "total_soil_n_per_volume",
      "total_soil_n_per_mass",
      "total_soil_n_per_area",
      "total_soil_p_per_volume",
      "total_soil_p_per_mass",
      "total_soil_p_per_area",
      "soil_n_pool_bacteria",
      "soil_n_pool_arbuscular_mycorrhiza",
      "soil_n_pool_ectomycorrhiza",
      "soil_n_pool_saprotrophic_fungi",
      "soil_p_pool_bacteria",
      "soil_p_pool_arbuscular_mycorrhiza",
      "soil_p_pool_ectomycorrhiza",
      "soil_p_pool_saprotrophic_fungi"
    )
  )
})

test_that("get_derived_variables returns a flat list of arrays", {
  dir <- withr::local_tempdir()
  mock_zarr <- create_mock_zarr(dir)
  mock_config <- create_mock_cfg(dir)

  result <- get_derived_variables(mock_zarr, mock_config, group = "outputs")

  expect_true(all(vapply(result, is.array, logical(1))))
  expect_false(any(vapply(result, is.list, logical(1))))
})

test_that("get_total_soil_c_per_volume sums all carbon pools", {
  dir <- withr::local_tempdir()
  mock_zarr <- create_mock_zarr(dir)
  result <- get_total_soil_c_per_volume(mock_zarr)
  # Total C values should sums from all 8 pools in the mock data
  expect_equal(result[1, 1], sum(1:8))
})

test_that("get_total_soil_c_per_volume preserves spatiotemporal dimensions", {
  dir <- withr::local_tempdir()
  mock_zarr <- create_mock_zarr(dir)
  result <- get_total_soil_c_per_volume(mock_zarr)
  # Output dims: [cell_id × time_index]
  expect_equal(dim(result), c(length(time_index), length(cell_id)))
})

test_that("get_total_soil_c_per_mass converts volume to mass and get_total_soil_c_per_area to area basis correctly.", {
  dir <- withr::local_tempdir()
  mock_zarr <- create_mock_zarr(dir)
  mock_config <- create_mock_cfg(dir)
  config <- toml::read_toml(mock_config)

  result_volume_basis <- get_total_soil_c_per_volume(mock_zarr)
  result_mass_basis <- get_total_soil_c_per_mass(mock_zarr, config = config)
  result_area_basis <- get_total_soil_c_per_area(mock_zarr, config = config)

  # Extract conversion factors from config
  bulk_density_VE <- config$abiotic$constants$bulk_density_soil
  soil_layer_depth <- config$core$constants$microbial_simulation_depth
  # Verify unit conversions: mass = volume / bulk_density; area = volume * depth
  expect_equal(result_volume_basis / bulk_density_VE, result_mass_basis)
  expect_equal(result_volume_basis * soil_layer_depth, result_area_basis)
})

test_that("get_soil_np_pool_microbial converts C to N and P pools correctly.", {
  dir <- withr::local_tempdir()
  mock_zarr <- create_mock_zarr(dir)
  mock_config <- create_mock_cfg(dir)
  config <- toml::read_toml(mock_config)

  # Extract C microbial pools
  soil_c_microbial <- get_data_variables(
    mock_zarr,
    group = "outputs",
    variables = c(
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
  result <- get_soil_np_pool_microbial(mock_zarr, config = config)
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
  dir <- withr::local_tempdir()
  mock_zarr <- create_mock_zarr(dir)
  mock_config <- create_mock_cfg(dir)
  config <- toml::read_toml(mock_config)

  # Extract C:N ratios for all microbial groups (order: ectomycorrhiza, saprotrophic_fungi, arbuscular_mycorrhiza, bacteria)
  stoich <-
    config$soil$microbial_group_definition |>
    purrr::map_vec(\(x) {
      as.data.frame(x[c("name", "c_n_ratio")])
    })
  c_n_ratio <- stoich$c_n_ratio[c(3, 4, 2, 1)]
  result <- get_total_soil_n_per_volume(mock_zarr, config = config)
  # Mock data pools: organic N (element slice "N") +
  # microbial N (C pools 5:8 divided by C:N) + inorganic N (9:10)
  organic_n <- sum(c(
    mock_arrays$soil_cnp_pool_lmwc[1, 1, "N"],
    mock_arrays$soil_cnp_pool_maom[1, 1, "N"],
    mock_arrays$soil_cnp_pool_necromass[1, 1, "N"],
    mock_arrays$soil_cnp_pool_pom[1, 1, "N"]
  ))
  expect_equal(result[1, 1], organic_n + sum((5:8) / c_n_ratio) + sum(9:10))
})

test_that("get_total_soil_n_per_volume preserves spatiotemporal dimensions", {
  dir <- withr::local_tempdir()
  mock_zarr <- create_mock_zarr(dir)
  mock_config <- create_mock_cfg(dir)
  config <- toml::read_toml(mock_config)

  result <- get_total_soil_n_per_volume(mock_zarr, config = config)
  expect_equal(dim(result), c(length(time_index), length(cell_id)))
})

test_that("get_total_soil_n_per_mass converts volume to mass and get_total_soil_n_per_area to area basis correctly.", {
  dir <- withr::local_tempdir()
  mock_zarr <- create_mock_zarr(dir)
  mock_config <- create_mock_cfg(dir)
  config <- toml::read_toml(mock_config)

  result_volume_basis <- get_total_soil_n_per_volume(mock_zarr, config = config)
  result_mass_basis <- get_total_soil_n_per_mass(mock_zarr, config = config)
  result_area_basis <- get_total_soil_n_per_area(mock_zarr, config = config)

  bulk_density_VE <- config$abiotic$constants$bulk_density_soil
  soil_layer_depth <- config$core$constants$microbial_simulation_depth
  expect_equal(result_volume_basis / bulk_density_VE, result_mass_basis)
  expect_equal(result_volume_basis * soil_layer_depth, result_area_basis)
})

# Repeat soil N tests on soil P
test_that("get_total_soil_p_per_volume sums all phosphorous pools", {
  dir <- withr::local_tempdir()
  mock_zarr <- create_mock_zarr(dir)
  mock_config <- create_mock_cfg(dir)
  config <- toml::read_toml(mock_config)

  stoich <-
    config$soil$microbial_group_definition |>
    purrr::map_vec(\(x) {
      as.data.frame(x[c("name", "c_p_ratio")])
    })
  c_p_ratio <- stoich$c_p_ratio[c(3, 4, 2, 1)]
  result <- get_total_soil_p_per_volume(mock_zarr, config = config)
  organic_p <- sum(c(
    mock_arrays$soil_cnp_pool_lmwc[1, 1, "P"],
    mock_arrays$soil_cnp_pool_maom[1, 1, "P"],
    mock_arrays$soil_cnp_pool_necromass[1, 1, "P"],
    mock_arrays$soil_cnp_pool_pom[1, 1, "P"]
  ))
  expect_equal(result[1, 1], organic_p + sum((5:8) / c_p_ratio) + sum(11:13))
})

test_that("get_total_soil_p_per_volume preserves spatiotemporal dimensions", {
  dir <- withr::local_tempdir()
  mock_zarr <- create_mock_zarr(dir)
  mock_config <- create_mock_cfg(dir)
  config <- toml::read_toml(mock_config)

  result <- get_total_soil_p_per_volume(mock_zarr, config = config)
  expect_equal(dim(result), c(length(time_index), length(cell_id)))
})

test_that("get_total_soil_p_per_mass converts volume to mass and get_total_soil_p_per_area to area basis correctly.", {
  dir <- withr::local_tempdir()
  mock_zarr <- create_mock_zarr(dir)
  mock_config <- create_mock_cfg(dir)
  config <- toml::read_toml(mock_config)

  result_volume_basis <- get_total_soil_p_per_volume(mock_zarr, config = config)
  result_mass_basis <- get_total_soil_p_per_mass(mock_zarr, config = config)
  result_area_basis <- get_total_soil_p_per_area(mock_zarr, config = config)

  bulk_density_VE <- config$abiotic$constants$bulk_density_soil
  soil_layer_depth <- config$core$constants$microbial_simulation_depth
  expect_equal(result_volume_basis / bulk_density_VE, result_mass_basis)
  expect_equal(result_volume_basis * soil_layer_depth, result_area_basis)
})
