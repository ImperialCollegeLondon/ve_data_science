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


make_variable_groups_fixture <- function(
  abiotic_name = "abiotic_simple",
  abiotic_entries = list(list(file_path = "a.nc", var_name = "x")),
  hydrology_entries = list(list(file_path = "b.nc", var_name = "y")),
  plants_entries = list(list(file_path = "c.nc", var_name = "z")),
  soil_entries = list(list(file_path = "d.nc", var_name = "s")),
  litter_entries = list(list(file_path = "e.nc", var_name = "l"))
) {
  c(
    stats::setNames(list(abiotic_entries), abiotic_name),
    list(
      hydrology = hydrology_entries,
      plants = plants_entries,
      soil = soil_entries,
      litter = litter_entries
    )
  )
}

make_core_fixture <- function(
  variable_groups = make_variable_groups_fixture()
) {
  list(
    grid = list(cell_nx = 2, cell_ny = 3),
    timing = list(
      start_date = "2010-01-01",
      update_interval = "1 month",
      run_length = "11 years"
    ),
    data = list(variable = variable_groups)
  )
}

make_plants_fixture <- function(
  cohort_data_path = "plant.csv",
  pft_definitions_path = "pft.csv",
  community_data_export = list(
    required_data = c("cohorts", "community_canopy"),
    cohort_attributes = list(),
    community_canopy_attributes = list(),
    stem_canopy_attributes = list()
  ),
  constants = list(subcanopy_specific_leaf_area = 10)
) {
  list(
    cohort_data_path = cohort_data_path,
    pft_definitions_path = pft_definitions_path,
    community_data_export = community_data_export,
    constants = constants
  )
}

make_animal_fixture <- function(
  functional_group_definitions_path = "animal.csv",
  cohort_data_export = list(enabled = TRUE),
  resource_pool_export = list(enabled = TRUE)
) {
  list(
    functional_group_definitions_path = functional_group_definitions_path,
    cohort_data_export = cohort_data_export,
    resource_pool_export = resource_pool_export
  )
}

render_test_config_lines <- function(
  core = make_core_fixture(),
  plants = make_plants_fixture(),
  animal = make_animal_fixture(),
  abiotic_module = names(core$data$variable)[[1]],
  abiotic_values = list(),
  hydrology = list(),
  soil = list(),
  litter = list()
) {
  c(
    render_comment("Core settings"),
    render_module("core"),
    render_table("core.grid", core$grid),
    render_table("core.timing", core$timing),
    render_comment("Abiotic config settings"),
    render_module(abiotic_module, values = abiotic_values),
    render_array_tables(
      "core.data.variable",
      core$data$variable[[abiotic_module]],
      comment = "Abiotic array variables"
    ),
    render_comment("Hydrology config settings"),
    render_module("hydrology", values = hydrology),
    render_array_tables(
      "core.data.variable",
      core$data$variable$hydrology,
      comment = "Hydrology array variables"
    ),
    render_comment("Animal config settings"),
    render_module(
      "animal",
      values = animal,
      field_comments = list(
        functional_group_definitions_path = "Animal functional group definitions file path"
      )
    ),
    render_table("animal.cohort_data_export", animal$cohort_data_export),
    render_table(
      "animal.resource_pool_export",
      animal$resource_pool_export
    ),
    render_comment("Plant config settings"),
    render_module(
      "plants",
      values = plants,
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
    render_comment("Soil config settings"),
    render_module("soil", values = soil),
    render_array_tables(
      "core.data.variable",
      core$data$variable$soil,
      comment = "Soil array variables"
    ),
    render_comment("Litter config settings"),
    render_module("litter", values = litter),
    render_array_tables(
      "core.data.variable",
      core$data$variable$litter,
      comment = "Litter array variables"
    )
  )
}

write_test_config <- function(lines) {
  dir <- tempfile(pattern = "build-config-test-", tmpdir = tempdir())

  build_config(lines = lines, path = dir)

  output_path <- file.path(dir, "config.toml")

  list(
    path = output_path,
    text = readLines(output_path),
    parsed = toml::read_toml(output_path)
  )
}


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
  result <- write_test_config(render_test_config_lines())

  required_lines <- c(
    "# Core settings",
    "[core]",
    "[core.grid]",
    "[core.timing]",
    "# Abiotic config settings",
    "[abiotic_simple]",
    "# Hydrology config settings",
    "[hydrology]",
    "# Animal config settings",
    "# Animal functional group definitions file path",
    "[animal]",
    "[animal.cohort_data_export]",
    "[animal.resource_pool_export]",
    "# Plant config settings",
    "# Plant pft definitions file path",
    "# Plant cohort data file path",
    "[plants]",
    "[plants.community_data_export]",
    "# Plant constants (non-defaults)",
    "[plants.constants]",
    "# Soil config settings",
    "[soil]",
    "# Litter config settings",
    "[litter]",
    "[[core.data.variable]]"
  )

  expect_true(file.exists(result$path))
  expect_true(all(required_lines %in% result$text))
  expect_false(any(grepl("variable = \\[", result$text)))
  expect_length(result$parsed$core$data$variable, 5)
  expect_identical(result$parsed$core$data$variable[[1]]$var_name, "x")
  expect_equal(
    result$parsed$plants$constants$subcanopy_specific_leaf_area,
    10
  )
})


test_that("render_module renders a top-level module with direct fields", {
  rendered <- c(
    render_comment("Animal config settings"),
    render_module(
      "animal",
      values = list(functional_group_definitions_path = "animal.csv"),
      field_comments = list(
        functional_group_definitions_path = "Animal functional group definitions file path"
      )
    )
  )

  expect_true(any(rendered == "# Animal config settings"))
  expect_true(any(rendered == "[animal]"))
  expect_true(any(
    rendered == "# Animal functional group definitions file path"
  ))
  expect_true(any(
    rendered == 'functional_group_definitions_path = "animal.csv"'
  ))
})


test_that("render_table places field comments with child-table fields", {
  rendered <- render_table(
    "plants.constants",
    list(subcanopy_specific_leaf_area = 10),
    comment = "Plant constants (non-defaults)",
    field_comments = list(
      subcanopy_specific_leaf_area = "Subcanopy specific leaf area"
    )
  )

  comment_index <- match(
    "# Subcanopy specific leaf area",
    rendered
  )
  field_index <- match("subcanopy_specific_leaf_area = 10", rendered)

  expect_false(is.na(comment_index))
  expect_false(is.na(field_index))
  expect_identical(comment_index + 1L, field_index)
})


test_that("render_comment normalizes plain text, wrapping, and multiline input", {
  wrapped_field_comment <- paste(
    "Animal functional group definitions file path\n",
    "Currently uses Maliau_level3, other levels are also available",
    "through Globus."
  )

  rendered <- c(
    render_comment(
      paste(
        "Animal configuration settings for a very long heading that",
        "should wrap automatically to stay within the configured",
        "comment width."
      ),
      comment_width = 50
    ),
    render_module(
      "animal",
      values = list(functional_group_definitions_path = "animal.csv"),
      field_comments = list(
        functional_group_definitions_path = wrapped_field_comment
      ),
      comment_width = 50
    )
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

  expect_identical(render_comment("Core settings"), "# Core settings")
  expect_true(all(startsWith(comment_lines, "#")))
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
  core <- make_core_fixture(
    variable_groups = make_variable_groups_fixture(
      abiotic_entries = list(),
      hydrology_entries = list(),
      plants_entries = list(),
      soil_entries = list(),
      litter_entries = list()
    )
  )
  plants <- make_plants_fixture(
    cohort_data_path = NULL,
    pft_definitions_path = NULL,
    community_data_export = list(required_data = c("cohorts")),
    constants = list()
  )
  animal <- make_animal_fixture(
    functional_group_definitions_path = NULL
  )

  result <- write_test_config(
    render_test_config_lines(
      core = core,
      plants = plants,
      animal = animal
    )
  )

  expect_false(any(grepl(
    "functional_group_definitions_path",
    result$text,
    fixed = TRUE
  )))
  expect_false(any(grepl("pft_definitions_path", result$text, fixed = TRUE)))
  expect_false(any(grepl("cohort_data_path", result$text, fixed = TRUE)))
  expect_false(
    "functional_group_definitions_path" %in% names(result$parsed$animal)
  )
  expect_false("pft_definitions_path" %in% names(result$parsed$plants))
  expect_false("cohort_data_path" %in% names(result$parsed$plants))
})


test_that("callers can choose the abiotic module name", {
  core <- make_core_fixture(
    variable_groups = make_variable_groups_fixture(
      abiotic_name = "abiotic",
      hydrology_entries = list(),
      plants_entries = list(),
      soil_entries = list(),
      litter_entries = list()
    )
  )
  plants <- make_plants_fixture(
    cohort_data_path = NULL,
    pft_definitions_path = NULL,
    community_data_export = list(required_data = c("cohorts")),
    constants = list()
  )
  animal <- make_animal_fixture(
    functional_group_definitions_path = NULL
  )

  result <- write_test_config(
    render_test_config_lines(
      core = core,
      plants = plants,
      animal = animal,
      abiotic_module = "abiotic",
      abiotic_values = list(option = "full")
    )
  )

  expect_true(any(result$text == "[abiotic]"))
  expect_false(any(result$text == "[abiotic_simple]"))
  expect_identical(result$parsed$abiotic$option, "full")
  expect_identical(result$parsed$core$data$variable[[1]]$var_name, "x")
})
