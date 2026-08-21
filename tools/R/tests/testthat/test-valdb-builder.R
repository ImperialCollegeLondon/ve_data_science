#| ---
#| title: Tests for the validation database builder
#|
#| description: |
#|     Tests source discovery and classification for the validation database.
#|
#| virtual_ecosystem_module: Soil
#|
#| author: Hao Ran Lai
#|
#| status: draft
#|
#| source_files:
#|   - name: valdb.R
#|     path: tools/R/R/
#|     description: Validation database builder
#|
#| package_dependencies:
#|     - testthat
#|     - withr
#|     - yaml
#| ---
source(here::here("tools/R/R/valdb.R"))


new_builder_test_record <- function(
  doi,
  decision = "proceed",
  schema = TRUE
) {
  record <- new_screening_record(
    doi = doi,
    decision = decision,
    reason = if (decision == "proceed") {
      "relevant_validation_data"
    } else {
      "no_raw_data"
    },
    metadata = list(title = "Example dataset", year = 2024L),
    screened_at = as.POSIXct("2026-08-17 06:00:00", tz = "UTC")
  )

  if (!schema) {
    return(record)
  }

  record <- c(record, new_schema_template())
  record$source_id <- paste0("source_", stringr::str_extract(doi, "[^/]+$"))
  record$data_file <- paste0(
    "data/primary/soil/",
    record$source_id,
    "/data.csv"
  )
  record$variables <- list(
    soil_carbon = list(
      var_canonical = "soil_c_pool_lmwc",
      unit = "kg m-3",
      description = NULL
    )
  )
  record$dedup_key <- "sample_id"
  record
}


write_builder_test_record <- function(record, sources_dir, filename = NULL) {
  filename <- filename %||% paste0(record$record_id, ".yaml")
  path <- file.path(sources_dir, filename)
  yaml::write_yaml(record, path)
  path
}


test_that("list_build_sources discovers completed schemas deterministically", {
  sources_dir <- withr::local_tempdir()
  second <- new_builder_test_record("10.1000/second")
  first <- new_builder_test_record("10.1000/first")
  write_builder_test_record(second, sources_dir)
  write_builder_test_record(first, sources_dir)

  result <- list_build_sources(sources_dir)

  expect_identical(names(result), sort(c(first$record_id, second$record_id)))
  expect_identical(
    unname(purrr::map_chr(result, "source_id")),
    c(first$source_id, second$source_id)
  )
})


test_that("list_build_sources ignores screening-only records", {
  sources_dir <- withr::local_tempdir()
  screening_only <- new_builder_test_record("10.1000/screened", schema = FALSE)
  complete <- new_builder_test_record("10.1000/complete")
  write_builder_test_record(screening_only, sources_dir)
  write_builder_test_record(complete, sources_dir)

  result <- list_build_sources(sources_dir)

  expect_named(result, complete$record_id)
})


test_that("list_build_sources warns and skips draft schemas", {
  sources_dir <- withr::local_tempdir()
  draft <- c(
    new_builder_test_record("10.1000/draft", schema = FALSE),
    new_schema_template()
  )
  complete <- new_builder_test_record("10.1000/complete")
  draft_path <- write_builder_test_record(draft, sources_dir)
  write_builder_test_record(complete, sources_dir)

  expect_warning(
    result <- list_build_sources(sources_dir),
    basename(draft_path),
    fixed = TRUE
  )
  expect_named(result, complete$record_id)
})


test_that("list_build_sources errors when only screening records exist", {
  sources_dir <- withr::local_tempdir()
  record <- new_builder_test_record("10.1000/screened", schema = FALSE)
  write_builder_test_record(record, sources_dir)

  expect_error(
    list_build_sources(sources_dir),
    "No completed source schemas"
  )
})


test_that("list_build_sources errors when only draft schemas exist", {
  sources_dir <- withr::local_tempdir()
  draft <- c(
    new_builder_test_record("10.1000/draft", schema = FALSE),
    new_schema_template()
  )
  write_builder_test_record(draft, sources_dir)

  expect_warning(
    expect_error(
      list_build_sources(sources_dir),
      "No completed source schemas"
    ),
    "Skipping draft"
  )
})


test_that("list_build_sources recognises partial schemas as drafts", {
  sources_dir <- withr::local_tempdir()
  partial <- new_builder_test_record("10.1000/partial", schema = FALSE)
  partial$data_file <- "data/primary/soil/partial/data.csv"
  complete <- new_builder_test_record("10.1000/complete")
  partial_path <- write_builder_test_record(partial, sources_dir)
  write_builder_test_record(complete, sources_dir)

  expect_warning(
    result <- list_build_sources(sources_dir),
    basename(partial_path),
    fixed = TRUE
  )
  expect_named(result, complete$record_id)
})


test_that("list_build_sources errors for an absent or empty directory", {
  parent <- withr::local_tempdir()
  absent <- file.path(parent, "absent")
  empty <- file.path(parent, "empty")
  dir.create(empty)

  expect_error(list_build_sources(absent), "No completed source schemas")
  expect_error(list_build_sources(empty), "No completed source schemas")
})


test_that("list_build_sources reports malformed YAML with its path", {
  sources_dir <- withr::local_tempdir()
  path <- file.path(sources_dir, "broken.yaml")
  writeLines("doi: [", path)

  expect_error(
    list_build_sources(sources_dir),
    basename(path),
    fixed = TRUE
  )
})


test_that("list_build_sources rejects duplicate DOI records", {
  sources_dir <- withr::local_tempdir()
  record <- new_builder_test_record("10.1000/duplicate")
  write_builder_test_record(record, sources_dir, "first.yaml")
  write_builder_test_record(record, sources_dir, "second.yaml")

  expect_error(list_build_sources(sources_dir))
})


test_that("list_build_sources rejects schemas without a proceed decision", {
  sources_dir <- withr::local_tempdir()
  record <- new_builder_test_record("10.1000/excluded", decision = "exclude")
  path <- write_builder_test_record(record, sources_dir)

  expect_error(
    list_build_sources(sources_dir),
    basename(path),
    fixed = TRUE
  )
})


test_that("validate_source_schema checks required fields and source files", {
  directory <- withr::local_tempdir()
  data_path <- file.path(directory, "data.csv")
  readr::write_csv(tibble::tibble(sample_id = 1, soil_carbon = 2), data_path)
  source <- new_builder_test_record("10.1000/valid")
  source$data_file <- data_path
  schema_path <- file.path(directory, "source.yaml")

  expect_no_error(validate_source_schema(source, schema_path))

  missing_field <- source
  missing_field$variables <- NULL
  expect_error(
    validate_source_schema(missing_field, schema_path),
    "missing required field"
  )

  missing_file <- source
  missing_file$data_file <- file.path(directory, "missing.csv")
  expect_error(
    validate_source_schema(missing_file, schema_path),
    "does not exist"
  )
})


test_that("validate_source_schema checks scalar fields and collections", {
  directory <- withr::local_tempdir()
  data_path <- file.path(directory, "data.csv")
  readr::write_csv(tibble::tibble(sample_id = 1, soil_carbon = 2), data_path)
  source <- new_builder_test_record("10.1000/valid")
  source$data_file <- data_path
  schema_path <- file.path(directory, "source.yaml")

  invalid_id <- source
  invalid_id$source_id <- ""
  expect_error(validate_source_schema(invalid_id, schema_path), "source_id")

  invalid_skip <- source
  invalid_skip$skip_rows <- 1.5
  expect_error(validate_source_schema(invalid_skip, schema_path), "skip_rows")

  invalid_variables <- source
  invalid_variables$variables <- list(list(unit = "kg"))
  expect_error(
    validate_source_schema(invalid_variables, schema_path),
    "variables"
  )

  invalid_mapping <- source
  invalid_mapping$variables$soil_carbon$unit <- NULL
  expect_error(
    validate_source_schema(invalid_mapping, schema_path),
    "soil_carbon"
  )

  invalid_key <- source
  invalid_key$dedup_key <- c("sample_id", "sample_id")
  expect_error(validate_source_schema(invalid_key, schema_path), "dedup_key")
})


test_that("validate_build_sources rejects duplicate source IDs", {
  directory <- withr::local_tempdir()
  data_path <- file.path(directory, "data.csv")
  readr::write_csv(tibble::tibble(sample_id = 1, soil_carbon = 2), data_path)
  first <- new_builder_test_record("10.1000/first")
  second <- new_builder_test_record("10.1000/second")
  first$data_file <- data_path
  second$data_file <- data_path
  second$source_id <- first$source_id

  expect_error(
    validate_build_sources(list(first = first, second = second), directory),
    "Duplicate source ID"
  )
})


test_that("prepare_source_data rejects missing deduplication columns", {
  source <- new_builder_test_record("10.1000/missing-key")
  data <- tibble::tibble(soil_carbon = 2)

  expect_error(prepare_source_data(data, source), "sample_id")
})


test_that("prepare_source_data warns and skips missing measurements", {
  source <- new_builder_test_record("10.1000/missing-measurement")
  source$variables$soil_nitrogen <- source$variables$soil_carbon
  data <- tibble::tibble(sample_id = 1:2, soil_carbon = c(2, 3))

  expect_warning(
    result <- prepare_source_data(data, source),
    "soil_nitrogen"
  )
  expect_named(result, c("sample_id", "soil_carbon"))
  expect_identical(attr(result, "measurement_columns"), "soil_carbon")
})


test_that("prepare_source_data skips sources without measurements", {
  source <- new_builder_test_record("10.1000/no-measurements")
  data <- tibble::tibble(sample_id = 1:2)

  expect_warning(
    result <- prepare_source_data(data, source),
    "Skipping source"
  )
  expect_null(result)
})


test_that("prepare_source_data rejects missing and duplicate keys", {
  source <- new_builder_test_record("10.1000/invalid-keys")

  missing <- tibble::tibble(
    sample_id = c("a", NA_character_),
    soil_carbon = c(2, 3)
  )
  expect_error(prepare_source_data(missing, source), "missing values")

  duplicated <- tibble::tibble(
    sample_id = c("a", "a"),
    soil_carbon = c(2, 3)
  )
  expect_error(prepare_source_data(duplicated, source), "duplicate observation")
})


test_that("add_observation_id rejects concatenation collisions", {
  source <- new_builder_test_record("10.1000/collision")
  source$dedup_key <- c("plot", "sample")
  data <- tibble::tibble(
    plot = c("a_b", "a"),
    sample = c("c", "b_c"),
    soil_carbon = c(2, 3)
  )
  data <- prepare_source_data(data, source)

  expect_error(add_observation_id(data, source), "collide")
})


test_that("canonical metadata retrieval supports an injected downloader", {
  directory <- withr::local_tempdir()
  fixture <- file.path(directory, "variables.toml")
  writeLines(
    c(
      "[[variable]]",
      'name = "known_variable"',
      'unit = "kg{C} m^-3"'
    ),
    fixture
  )
  requested <- NULL
  downloader <- function(url, destination, ...) {
    requested <<- url
    file.copy(fixture, destination)
  }

  result <- build_canonical_units_table(
    variables_ve = "https://example.test/variables.toml",
    variables_derived = NULL,
    downloader = downloader
  )

  expect_identical(requested, "https://example.test/variables.toml")
  expect_identical(result$var_canonical, "known_variable")
  expect_identical(result$unit_canonical, "kg m^-3")
})


test_that("canonical metadata includes local derived variables", {
  directory <- withr::local_tempdir()
  ve <- file.path(directory, "ve.toml")
  derived <- file.path(directory, "derived.toml")
  writeLines(
    c("[[variable]]", 'name = "ve_variable"', 'unit = "kg"'),
    ve
  )
  writeLines(
    c("[[variable]]", 'name = "derived_variable"', 'unit = "g"'),
    derived
  )

  result <- build_canonical_units_table(ve, derived)

  expect_identical(
    result$var_canonical,
    c("ve_variable", "derived_variable")
  )
  expect_identical(result$unit_canonical, c("kg", "g"))
})


test_that("canonical conversion handles known and unknown mappings", {
  expect_equal(
    convert_canonical_value(
      1000,
      "g",
      "kg",
      "source_a",
      "mass",
      "mass_canonical"
    ),
    1
  )
  expect_identical(
    convert_canonical_value(
      1000,
      "not parsed",
      NA_character_,
      "source_a",
      "unknown",
      "not_in_metadata"
    ),
    NA_real_
  )
})


test_that("canonical conversion errors include source and variable context", {
  expect_error(
    convert_canonical_value(
      1,
      "not a unit",
      "kg",
      "source_a",
      "raw_mass",
      "canonical_mass"
    ),
    "source_a"
  )
  expect_error(
    convert_canonical_value(
      1,
      "m",
      "kg",
      "source_b",
      "raw_length",
      "canonical_mass"
    ),
    "raw_length"
  )
})


test_that("configured spatial and temporal values survive a database build", {
  directory <- withr::local_tempdir()
  sources_dir <- file.path(directory, "sources")
  db_path <- file.path(directory, "database")
  dir.create(sources_dir)

  data_path <- file.path(directory, "data.csv")
  readr::write_csv(
    tibble::tibble(sample_id = c("a", "b"), soil_carbon = c(2, 3)),
    data_path
  )
  source <- new_builder_test_record("10.1000/spatiotemporal")
  source$data_file <- data_path
  source$variables$soil_carbon$var_canonical <- "known_variable"
  source$variables$soil_carbon$unit <- "kg"
  source$coordinates$same_for_all_rows <- list(
    latitude = 4.74,
    longitude = 116.97
  )
  source$temporal$same_for_all_rows <- list(
    start = "2011-01-01",
    end = "2011-12-31",
    precision = "day",
    note = "Sampling campaign"
  )
  write_builder_test_record(source, sources_dir)

  original_builder <- build_canonical_units_table
  withr::defer(
    assign(
      "build_canonical_units_table",
      original_builder,
      envir = globalenv()
    )
  )
  assign(
    "build_canonical_units_table",
    function(...) {
      tibble::tibble(
        var_canonical = "known_variable",
        unit_canonical = "kg"
      )
    },
    envir = globalenv()
  )

  build_validation_database(
    config_dir = directory,
    sources_dir = sources_dir,
    db_path = db_path
  )
  result <- arrow::open_dataset(db_path) |>
    dplyr::collect()

  expect_equal(result$latitude, c(4.74, 4.74))
  expect_equal(result$longitude, c(116.97, 116.97))
  expect_identical(
    result$coordinate_source,
    c("same_for_all_rows", "same_for_all_rows")
  )
  expect_equal(
    format(result$time_start, "%Y-%m-%d", tz = "UTC"),
    c("2011-01-01", "2011-01-01")
  )
  expect_equal(
    format(result$time_end, "%Y-%m-%d", tz = "UTC"),
    c("2012-01-01", "2012-01-01")
  )
  expect_identical(result$time_precision, c("day", "day"))
  expect_identical(
    result$time_source,
    c("same_for_all_rows", "same_for_all_rows")
  )
  expect_identical(
    result$time_note,
    c("Sampling campaign", "Sampling campaign")
  )
})


test_that("harmonisation retains unknown canonical mappings", {
  directory <- withr::local_tempdir()
  data_path <- file.path(directory, "data.csv")
  readr::write_csv(
    tibble::tibble(sample_id = c("a", "b"), unknown = c(2, 3)),
    data_path
  )
  source <- new_builder_test_record("10.1000/unknown")
  source$data_file <- data_path
  source$variables <- list(
    unknown = list(
      var_canonical = "not_in_metadata",
      unit = "m",
      description = NULL
    )
  )
  source$coordinates$same_for_all_rows <- list(
    latitude = 4.74,
    longitude = 116.97
  )
  source$temporal$same_for_all_rows <- list(
    start = "2011-01-01",
    end = "2011-12-31",
    precision = "day",
    note = NULL
  )
  canonical_units <- tibble::tibble(
    var_canonical = "known_variable",
    unit_canonical = "kg"
  )

  expect_warning(
    result <- harmonise_source_data(source, canonical_units),
    "Unknown canonical variable mapping"
  )

  expect_equal(nrow(result), 2L)
  expect_identical(result$value, c(2, 3))
  expect_identical(result$unit_original, c("m", "m"))
  expect_identical(result$unit_canonical, c(NA_character_, NA_character_))
  expect_identical(result$value_canonical, c(NA_real_, NA_real_))
})
