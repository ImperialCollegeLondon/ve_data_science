#| ---
#| title: Tests for build_config
#|
#| description: |
#|     Unit tests for the compiled TOML configuration builder.
#|
#| virtual_ecosystem_module: All
#|
#| author: Hao Ran Lai
#| status: draft
#|
#| source_files:
#|   - name: build_config.R
#|     path: tools/R/R/
#|     description: Builder for compiled TOML configuration files
#|
#| package_dependencies:
#|     - testthat
#|     - withr
#| ---

source(here::here("tools/R/R/build_config.R"))


test_that("build_config writes the human-readable module order", {
  dir <- withr::local_tempdir()

  build_config(
    core = list(
      grid = list(cell_nx = 2, cell_ny = 3),
      timing = list(
        start_date = "2010-01-01",
        update_interval = "1 month",
        run_length = "11 years"
      ),
      data = list(
        variable = list(
          abiotic_simple = list(list(file_path = "a.nc", var_name = "x")),
          hydrology = list(list(file_path = "b.nc", var_name = "y")),
          plants = list(list(file_path = "c.nc", var_name = "z")),
          soil = list(list(file_path = "d.nc", var_name = "s")),
          litter = list(list(file_path = "e.nc", var_name = "l"))
        )
      )
    ),
    abiotic_simple = list(),
    hydrology = list(),
    plants = list(
      cohort_data_path = "plant.csv",
      pft_definitions_path = "pft.csv",
      community_data_export = list(
        required_data = c("cohorts", "community_canopy"),
        cohort_attributes = list(),
        community_canopy_attributes = list(),
        stem_canopy_attributes = list()
      ),
      constants = list(subcanopy_specific_leaf_area = 10)
    ),
    animal = list(
      functional_group_definitions_path = "animal.csv",
      cohort_data_export = list(enabled = TRUE),
      resource_pool_export = list(enabled = TRUE)
    ),
    soil = list(),
    litter = list(),
    path = dir
  )

  output_path <- file.path(dir, "config.toml")
  output_text <- readLines(output_path)

  expect_true(file.exists(output_path))
  expect_true(any(output_text == "# Core settings"))
  expect_true(any(output_text == "[core.grid]"))
  expect_true(any(output_text == "[core.timing]"))
  expect_true(any(output_text == "# Abiotic config settings"))
  expect_true(any(output_text == "[abiotic_simple]"))
  expect_true(any(output_text == "# Hydrology config settings"))
  expect_true(any(output_text == "[hydrology]"))
  expect_true(any(output_text == "# Animal config settings"))
  expect_true(any(output_text == "[animal]"))
  expect_true(any(output_text == "[animal.cohort_data_export]"))
  expect_true(any(output_text == "[animal.resource_pool_export]"))
  expect_true(any(output_text == "# Plant config settings"))
  expect_true(any(output_text == "[plants]"))
  expect_true(any(output_text == "[plants.community_data_export]"))
  expect_true(any(output_text == "[plants.constants]"))
  expect_true(any(output_text == "# Soil config settings"))
  expect_true(any(output_text == "[soil]"))
  expect_true(any(output_text == "# Litter config settings"))
  expect_true(any(output_text == "[litter]"))
  expect_true(any(output_text == "[[core.data.variable]]"))
  expect_false(any(grepl("variable = [", output_text, fixed = TRUE)))
  expect_true(any(output_text == "# Plant constants (non-defaults)"))
})
