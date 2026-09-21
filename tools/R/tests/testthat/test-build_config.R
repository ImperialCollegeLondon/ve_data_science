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


test_that("build_variable_groups returns TOML-ready variable groups", {
  variable_groups <- build_variable_groups(
    plants_path = "plants.nc",
    climate_path = "climate.nc",
    elevation_path = "elevation.nc",
    soil_path = "soil.nc",
    litter_path = "litter.nc"
  )

  expect_identical(
    names(variable_groups),
    c("abiotic_simple", "hydrology", "plants", "soil", "litter")
  )
  expect_identical(variable_groups$abiotic_simple[[1]]$file_path, "climate.nc")
  expect_identical(
    variable_groups$abiotic_simple[[1]]$var_name,
    "air_temperature_ref"
  )
  expect_identical(variable_groups$hydrology[[1]]$var_name, "precipitation")
  expect_identical(variable_groups$hydrology[[1]]$file_path, "climate.nc")
  expect_identical(variable_groups$hydrology[[2]]$var_name, "elevation")
  expect_identical(variable_groups$hydrology[[2]]$file_path, "elevation.nc")
  expect_identical(
    variable_groups$plants[[4]]$var_name,
    "downward_shortwave_radiation"
  )
  expect_identical(variable_groups$plants[[4]]$file_path, "climate.nc")
  expect_identical(variable_groups$soil[[1]]$var_name, "pH")
  expect_identical(
    variable_groups$litter[[length(variable_groups$litter)]]$var_name,
    "lignin_below_structural"
  )
})


test_that("build_config writes the provided rendered lines", {
  dir <- withr::local_tempdir()

  core <- list(
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
  )
  hydrology <- list()
  plants <- list(
    cohort_data_path = "plant.csv",
    pft_definitions_path = "pft.csv",
    community_data_export = list(
      required_data = c("cohorts", "community_canopy"),
      cohort_attributes = list(),
      community_canopy_attributes = list(),
      stem_canopy_attributes = list()
    ),
    constants = list(subcanopy_specific_leaf_area = 10)
  )
  animal <- list(
    functional_group_definitions_path = "animal.csv",
    cohort_data_export = list(enabled = TRUE),
    resource_pool_export = list(enabled = TRUE)
  )
  soil <- list()
  litter <- list()
  comments <- list(
    core = "# Core settings",
    abiotic = "# Abiotic config settings",
    abiotic_variables = "# Abiotic array variables",
    hydrology = "# Hydrology config settings",
    hydrology_variables = "# Hydrology array variables",
    animal = "# Animal config settings",
    plants = "# Plant config settings",
    plants_constants = "# Plant constants (non-defaults)",
    soil = "# Soil config settings",
    soil_variables = "# Soil array variables",
    litter = "# Litter config settings",
    litter_variables = "# Litter array variables"
  )

  lines <- c(
    render_table("core", remove_nested_list_fields(core), comments$core),
    render_table("core.grid", core$grid),
    render_table("core.timing", core$timing),
    render_table("abiotic_simple", list(), comments$abiotic),
    render_array_tables(
      "core.data.variable",
      core$data$variable$abiotic_simple,
      comments$abiotic_variables
    ),
    render_table("hydrology", hydrology, comments$hydrology),
    render_array_tables(
      "core.data.variable",
      core$data$variable$hydrology,
      comments$hydrology_variables
    ),
    render_table_with_body_comments(
      "animal",
      remove_nested_list_fields(animal),
      comments$animal
    ),
    render_table("animal.cohort_data_export", animal$cohort_data_export),
    render_table("animal.resource_pool_export", animal$resource_pool_export),
    render_table_with_body_comments(
      "plants",
      remove_nested_list_fields(plants),
      comments$plants
    ),
    render_table("plants.community_data_export", plants$community_data_export),
    render_array_tables(
      "core.data.variable",
      core$data$variable$plants,
      comments$plants_variables
    ),
    render_table(
      "plants.constants",
      plants$constants,
      comments$plants_constants
    ),
    render_table("soil", soil, comments$soil),
    render_array_tables(
      "core.data.variable",
      core$data$variable$soil,
      comments$soil_variables
    ),
    render_table("litter", litter, comments$litter),
    render_array_tables(
      "core.data.variable",
      core$data$variable$litter,
      comments$litter_variables
    )
  )

  build_config(lines = lines, path = dir)

  output_path <- file.path(dir, "config.toml")
  output_text <- readLines(output_path)

  expect_true(file.exists(output_path))
  parsed <- toml::read_toml(output_path)

  expect_true(any(output_text == "# Core settings"))
  expect_true(any(output_text == "[core]"))
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
  expect_false(any(grepl("variable = \\[", output_text)))
  expect_true(any(output_text == "# Plant constants (non-defaults)"))
  expect_length(parsed$core$data$variable, 5)
  expect_identical(parsed$core$data$variable[[1]]$var_name, "x")
  expect_equal(parsed$plants$constants$subcanopy_specific_leaf_area, 10)
})

test_that("render helpers omit optional NULL scalar fields", {
  dir <- withr::local_tempdir()

  core <- list(
    grid = list(cell_nx = 2, cell_ny = 3),
    timing = list(
      start_date = "2010-01-01",
      update_interval = "1 month",
      run_length = "11 years"
    ),
    data = list(
      variable = list(
        abiotic_simple = list(),
        hydrology = list(),
        plants = list(),
        soil = list(),
        litter = list()
      )
    )
  )
  plants <- list(
    cohort_data_path = NULL,
    pft_definitions_path = NULL,
    community_data_export = list(required_data = c("cohorts")),
    constants = list()
  )
  animal <- list(
    functional_group_definitions_path = NULL,
    cohort_data_export = list(enabled = TRUE),
    resource_pool_export = list(enabled = TRUE)
  )

  lines <- c(
    render_table("core", remove_nested_list_fields(core)),
    render_table("core.grid", core$grid),
    render_table("core.timing", core$timing),
    render_table("abiotic_simple", list()),
    render_table("hydrology", list()),
    render_table("animal", remove_nested_list_fields(animal)),
    render_table("animal.cohort_data_export", animal$cohort_data_export),
    render_table("animal.resource_pool_export", animal$resource_pool_export),
    render_table("plants", remove_nested_list_fields(plants)),
    render_table("plants.community_data_export", plants$community_data_export),
    render_table("plants.constants", plants$constants),
    render_table("soil", list()),
    render_table("litter", list())
  )

  build_config(lines = lines, path = dir)

  output_path <- file.path(dir, "config.toml")
  output_text <- readLines(output_path)
  parsed <- toml::read_toml(output_path)

  expect_false(any(grepl(
    "functional_group_definitions_path",
    output_text,
    fixed = TRUE
  )))
  expect_false(any(grepl("pft_definitions_path", output_text, fixed = TRUE)))
  expect_false(any(grepl("cohort_data_path", output_text, fixed = TRUE)))
  expect_false("functional_group_definitions_path" %in% names(parsed$animal))
  expect_false("pft_definitions_path" %in% names(parsed$plants))
  expect_false("cohort_data_path" %in% names(parsed$plants))
})

test_that("callers can choose the abiotic module name", {
  dir <- withr::local_tempdir()

  core <- list(
    grid = list(cell_nx = 2, cell_ny = 3),
    timing = list(
      start_date = "2010-01-01",
      update_interval = "1 month",
      run_length = "11 years"
    ),
    data = list(
      variable = list(
        abiotic = list(list(file_path = "a.nc", var_name = "x")),
        hydrology = list(),
        plants = list(),
        soil = list(),
        litter = list()
      )
    )
  )
  plants <- list(
    community_data_export = list(required_data = c("cohorts")),
    constants = list()
  )
  animal <- list(
    cohort_data_export = list(enabled = TRUE),
    resource_pool_export = list(enabled = TRUE)
  )

  lines <- c(
    render_table("core", remove_nested_list_fields(core)),
    render_table("core.grid", core$grid),
    render_table("core.timing", core$timing),
    render_table("abiotic", list(option = "full")),
    render_array_tables("core.data.variable", core$data$variable$abiotic),
    render_table("hydrology", list()),
    render_table("animal", remove_nested_list_fields(animal)),
    render_table("animal.cohort_data_export", animal$cohort_data_export),
    render_table("animal.resource_pool_export", animal$resource_pool_export),
    render_table("plants", remove_nested_list_fields(plants)),
    render_table("plants.community_data_export", plants$community_data_export),
    render_table("plants.constants", plants$constants),
    render_table("soil", list()),
    render_table("litter", list())
  )

  build_config(lines = lines, path = dir)

  output_path <- file.path(dir, "config.toml")
  output_text <- readLines(output_path)
  parsed <- toml::read_toml(output_path)

  expect_true(any(output_text == "[abiotic]"))
  expect_false(any(output_text == "[abiotic_simple]"))
  expect_identical(parsed$abiotic$option, "full")
  expect_identical(parsed$core$data$variable[[1]]$var_name, "x")
})
