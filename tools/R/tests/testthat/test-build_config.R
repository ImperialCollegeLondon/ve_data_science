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
  lines <- c(
    render_module("core", comment = "Core settings"),
    render_table("core.grid", core$grid),
    render_table("core.timing", core$timing),
    render_module("abiotic_simple", comment = "Abiotic config settings"),
    render_array_tables(
      "core.data.variable",
      core$data$variable$abiotic_simple,
      comment = "Abiotic array variables"
    ),
    render_module("hydrology", comment = "Hydrology config settings"),
    render_array_tables(
      "core.data.variable",
      core$data$variable$hydrology,
      comment = "Hydrology array variables"
    ),
    render_table(
      "animal",
      animal,
      comment = "Animal config settings",
      field_comments = list(
        functional_group_definitions_path = "Animal functional group definitions file path"
      )
    ),
    render_table("animal.cohort_data_export", animal$cohort_data_export),
    render_table("animal.resource_pool_export", animal$resource_pool_export),
    render_table(
      "plants",
      plants,
      comment = "Plant config settings",
      field_comments = list(
        pft_definitions_path = "Plant pft definitions file path",
        cohort_data_path = "Plant cohort data file path"
      )
    ),
    render_table(
      "plants.community_data_export",
      plants$community_data_export
    ),
    render_array_tables(
      "core.data.variable",
      core$data$variable$plants,
      comment = "Plant array variables"
    ),
    render_table(
      "plants.constants",
      plants$constants,
      comment = "Plant constants (non-defaults)"
    ),
    render_module("soil", comment = "Soil config settings"),
    render_array_tables(
      "core.data.variable",
      core$data$variable$soil,
      comment = "Soil array variables"
    ),
    render_module("litter", comment = "Litter config settings"),
    render_array_tables(
      "core.data.variable",
      core$data$variable$litter,
      comment = "Litter array variables"
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
  expect_true(any(
    output_text == "# Animal functional group definitions file path"
  ))
  expect_true(any(output_text == "[animal]"))
  expect_true(any(output_text == "[animal.cohort_data_export]"))
  expect_true(any(output_text == "[animal.resource_pool_export]"))
  expect_true(any(output_text == "# Plant config settings"))
  expect_true(any(output_text == "# Plant pft definitions file path"))
  expect_true(any(output_text == "# Plant cohort data file path"))
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

test_that("render_module renders a top-level module header", {
  rendered <- render_module("core", comment = "Core settings")

  expect_identical(
    rendered,
    c("# Core settings", "[core]", "")
  )
})


test_that("render_table places field comments with their fields", {
  rendered <- render_table(
    "plants",
    list(
      pft_definitions_path = "pft.csv",
      cohort_data_path = "cohort.csv"
    ),
    comment = "Plant config settings",
    field_comments = list(
      pft_definitions_path = "Plant pft definitions file path",
      cohort_data_path = "Plant cohort data file path"
    )
  )

  pft_comment_index <- match(
    "# Plant pft definitions file path",
    rendered
  )
  pft_field_index <- match('pft_definitions_path = "pft.csv"', rendered)
  cohort_comment_index <- match(
    "# Plant cohort data file path",
    rendered
  )
  cohort_field_index <- match('cohort_data_path = "cohort.csv"', rendered)

  expect_false(is.na(pft_comment_index))
  expect_false(is.na(pft_field_index))
  expect_false(is.na(cohort_comment_index))
  expect_false(is.na(cohort_field_index))
  expect_identical(pft_comment_index + 1L, pft_field_index)
  expect_identical(cohort_comment_index + 1L, cohort_field_index)
})


test_that("comment normalization supports plain text wrapping and multiline input", {
  wrapped_field_comment <- paste(
    "Animal functional group definitions file path\n",
    "Currently uses Maliau_level3, other levels are also available",
    "through Globus."
  )

  rendered <- render_table(
    "animal",
    list(functional_group_definitions_path = "animal.csv"),
    comment = paste(
      "Animal configuration settings for a very long heading that should wrap",
      "automatically to stay within the configured comment width."
    ),
    field_comments = list(
      functional_group_definitions_path = wrapped_field_comment
    ),
    comment_width = 50
  )

  comment_lines <- rendered[grepl("^#", rendered)]
  field_comment_lines <- normalize_comment_lines(
    wrapped_field_comment,
    width = 50
  )
  field_comment_index <- match(field_comment_lines[[1]], rendered)
  field_index <- match(
    'functional_group_definitions_path = "animal.csv"',
    rendered
  )

  expect_true(all(startsWith(comment_lines, "#")))
  expect_true(sum(grepl("^#", comment_lines[1:3])) == 3)
  expect_true(any(grepl(
    "Animal configuration settings",
    comment_lines,
    fixed = TRUE
  )))
  expect_true(any(
    comment_lines == "# Animal functional group definitions file path"
  ))
  expect_true(any(grepl("Maliau_level3", comment_lines, fixed = TRUE)))
  expect_true(any(grepl("through Globus\\.$", comment_lines)))
  expect_true(all(nchar(comment_lines) <= 50))
  expect_identical(
    field_comment_index + length(field_comment_lines),
    field_index
  )
})


test_that("render_table omits nested list and NULL scalar fields", {
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
    render_module("core"),
    render_table("core.grid", core$grid),
    render_table("core.timing", core$timing),
    render_module("abiotic_simple"),
    render_module("hydrology"),
    render_table("animal", animal),
    render_table("animal.cohort_data_export", animal$cohort_data_export),
    render_table("animal.resource_pool_export", animal$resource_pool_export),
    render_table("plants", plants),
    render_table("plants.community_data_export", plants$community_data_export),
    render_table("plants.constants", plants$constants),
    render_module("soil"),
    render_module("litter")
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
    render_module("core"),
    render_table("core.grid", core$grid),
    render_table("core.timing", core$timing),
    render_table("abiotic", list(option = "full")),
    render_array_tables("core.data.variable", core$data$variable$abiotic),
    render_module("hydrology"),
    render_table("animal", animal),
    render_table("animal.cohort_data_export", animal$cohort_data_export),
    render_table("animal.resource_pool_export", animal$resource_pool_export),
    render_table("plants", plants),
    render_table("plants.community_data_export", plants$community_data_export),
    render_table("plants.constants", plants$constants),
    render_module("soil"),
    render_module("litter")
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
