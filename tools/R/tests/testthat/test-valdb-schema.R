#| ---
#| title: Tests for validation dataset schema records
#|
#| description: |
#|     Tests the contract used to initialise Step 2 dataset schemas.
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
#|     description: Validation database schema helpers
#|
#| package_dependencies:
#|     - testthat
#| ---
source(here::here("tools/R/R/valdb.R"))

new_schema_test_record <- function(
  doi = "10.5281/zenodo.8158810",
  decision = "proceed"
) {
  new_screening_record(
    doi = doi,
    decision = decision,
    reason = if (decision == "proceed") {
      "relevant_validation_data"
    } else {
      "no_raw_data"
    },
    metadata = list(
      title = "Example dataset",
      authors = "Example, Alice",
      year = 2023L
    ),
    screened_at = as.POSIXct("2026-08-13 12:05:00", tz = "UTC")
  )
}


test_that("new_schema_template returns the builder contract", {
  template <- new_schema_template()

  expect_named(
    template,
    c(
      "source_id",
      "data_file",
      "skip_rows",
      "variables",
      "dedup_key",
      "coordinates",
      "temporal"
    )
  )
  expect_identical(template$source_id, "author_year")
  expect_identical(
    template$data_file,
    "data/primary/<module>/author_year/*.csv"
  )
  expect_identical(template$skip_rows, 0L)
  expect_named(template$variables, "var_original_1")
  expect_named(
    template$variables$var_original_1,
    c("var_canonical", "unit", "description")
  )
  expect_identical(
    template$variables$var_original_1$var_canonical,
    "var_ve_1"
  )
  expect_identical(template$variables$var_original_1$unit, "unit")
  expect_null(template$variables$var_original_1$description)
  expect_identical(template$dedup_key, c("sample_id", "date", "site_id"))
  expect_named(
    template$coordinates,
    c(
      "from_file",
      "match_data_column",
      "match_location_column",
      "latitude_column",
      "longitude_column",
      "same_for_all_rows"
    )
  )
  expect_named(
    template$coordinates$same_for_all_rows,
    c("latitude", "longitude")
  )
  expect_named(
    template$temporal,
    c(
      "date_column",
      "start_column",
      "end_column",
      "format",
      "timezone",
      "precision",
      "same_for_all_rows"
    )
  )
  expect_named(
    template$temporal$same_for_all_rows,
    c("start", "end", "precision", "note")
  )
  expect_true(all(purrr::map_lgl(template$coordinates[1:5], is.null)))
  expect_true(all(purrr::map_lgl(
    template$coordinates$same_for_all_rows,
    is.null
  )))
  expect_true(all(purrr::map_lgl(template$temporal[1:6], is.null)))
  expect_true(all(purrr::map_lgl(template$temporal$same_for_all_rows, is.null)))
})


test_that("new_schema_template returns an independent object", {
  first <- new_schema_template()
  first$source_id <- "changed"
  first$variables$var_original_1$unit <- "changed"
  first$coordinates$same_for_all_rows$latitude <- 4.7
  first$temporal$same_for_all_rows$start <- "2011-01-01"

  expect_identical(new_schema_template()$source_id, "author_year")
  expect_identical(
    new_schema_template()$variables$var_original_1$unit,
    "unit"
  )
  expect_null(new_schema_template()$coordinates$same_for_all_rows$latitude)
  expect_null(new_schema_template()$temporal$same_for_all_rows$start)
})


test_that("new_schema_template round trips through YAML", {
  path <- withr::local_tempfile(fileext = ".yaml")
  template <- new_schema_template()

  yaml::write_yaml(template, path)

  expect_identical(yaml::read_yaml(path), template)
})


test_that("configured optional schema blocks round trip through YAML", {
  path <- withr::local_tempfile(fileext = ".yaml")
  template <- new_schema_template()
  template$coordinates$same_for_all_rows <- list(
    latitude = 4.74,
    longitude = 116.97
  )
  template$temporal$same_for_all_rows <- list(
    start = "2011-01-01",
    end = "2014-12-01",
    precision = "month",
    note = "Sampling campaign"
  )

  yaml::write_yaml(template, path)

  expect_identical(yaml::read_yaml(path), template)
})


test_that("initialise_source_schema adds schema and preserves screening fields", {
  sources_dir <- withr::local_tempdir()
  record <- new_schema_test_record()
  path <- write_screening_record(record, sources_dir)

  result <- initialise_source_schema(record$doi, sources_dir)
  updated <- yaml::read_yaml(path)

  expect_identical(result, path)
  expect_identical(updated[names(record)], record)
  expect_identical(
    updated[names(new_schema_template())],
    new_schema_template()
  )
  expect_named(updated, c(names(record), names(new_schema_template())))
  expect_identical(
    list.files(sources_dir, all.files = TRUE),
    c(".", "..", basename(path))
  )
})


test_that("initialise_source_schema normalises common DOI forms", {
  sources_dir <- withr::local_tempdir()
  record <- new_schema_test_record()
  path <- write_screening_record(record, sources_dir)

  expect_identical(
    initialise_source_schema(
      " https://doi.org/10.5281/ZENODO.8158810 ",
      sources_dir
    ),
    path
  )
})


test_that("schema helpers require explicit sources_dir", {
  expect_error(
    initialise_source_schema("10.5281/zenodo.8158810"),
    "argument .*sources_dir.*missing"
  )

  expect_error(
    add_schema("10.5281/zenodo.8158810"),
    "argument .*sources_dir.*missing"
  )
})


test_that("initialise_source_schema rejects an unscreened DOI", {
  sources_dir <- withr::local_tempdir()

  expect_error(
    initialise_source_schema("10.1000/not-screened", sources_dir),
    "has not been screened"
  )
  expect_length(list.files(sources_dir), 0L)
})


test_that("initialise_source_schema rejects duplicate DOI records", {
  sources_dir <- withr::local_tempdir()
  record <- new_schema_test_record()
  yaml::write_yaml(record, file.path(sources_dir, "first.yaml"))
  yaml::write_yaml(record, file.path(sources_dir, "second.yaml"))

  expect_error(
    initialise_source_schema(record$doi, sources_dir),
    "multiple\\s+screening records"
  )
})


test_that("initialise_source_schema requires a proceed decision", {
  sources_dir <- withr::local_tempdir()
  record <- new_schema_test_record(decision = "exclude")
  path <- write_screening_record(record, sources_dir)

  expect_error(
    initialise_source_schema(record$doi, sources_dir),
    "must have a.*proceed.*screening decision"
  )
  expect_identical(yaml::read_yaml(path), record)
})


test_that("initialise_source_schema does not replace an existing schema", {
  sources_dir <- withr::local_tempdir()
  record <- c(new_schema_test_record(), new_schema_template())
  path <- file.path(sources_dir, paste0(record$record_id, ".yaml"))
  yaml::write_yaml(record, path)

  expect_error(
    initialise_source_schema(record$doi, sources_dir),
    "already has a schema"
  )
  expect_identical(yaml::read_yaml(path), record)
})


test_that("initialise_source_schema requires the canonical record path", {
  sources_dir <- withr::local_tempdir()
  record <- new_schema_test_record()
  path <- file.path(sources_dir, "unexpected.yaml")
  yaml::write_yaml(record, path)

  expect_error(initialise_source_schema(record$doi, sources_dir))
  expect_identical(yaml::read_yaml(path), record)
})


test_that("add_schema initialises and opens only the target record", {
  sources_dir <- withr::local_tempdir()
  target <- new_schema_test_record()
  target_path <- write_screening_record(target, sources_dir)
  other <- new_schema_test_record(doi = "10.1000/other-dataset")
  other_path <- write_screening_record(other, sources_dir)
  editor_calls <- new.env(parent = emptyenv())
  editor_calls$paths <- character()
  editor <- function(path) {
    editor_calls$paths <- c(editor_calls$paths, path)
  }

  expect_invisible(result <- add_schema(target$doi, sources_dir, editor))
  updated <- yaml::read_yaml(target_path)

  expect_identical(result, target_path)
  expect_identical(editor_calls$paths, target_path)
  expect_identical(updated[names(target)], target)
  expect_identical(
    updated[names(new_schema_template())],
    new_schema_template()
  )
  expect_identical(yaml::read_yaml(other_path), other)
  expect_identical(yaml::read_yaml(target_path), updated)
})


test_that("add_schema normalises common DOI forms", {
  sources_dir <- withr::local_tempdir()
  record <- new_schema_test_record()
  path <- write_screening_record(record, sources_dir)
  editor_calls <- new.env(parent = emptyenv())
  editor_calls$paths <- character()
  editor <- function(path) {
    editor_calls$paths <- c(editor_calls$paths, path)
  }

  result <- add_schema(
    " https://doi.org/10.5281/ZENODO.8158810 ",
    sources_dir,
    editor
  )

  expect_identical(result, path)
  expect_identical(editor_calls$paths, path)
})


test_that("add_schema rejects an unscreened DOI without opening an editor", {
  sources_dir <- withr::local_tempdir()
  editor_called <- FALSE
  editor <- function(path) {
    editor_called <<- TRUE
  }

  expect_error(
    add_schema("10.1000/not-screened", sources_dir, editor),
    "has not been screened"
  )
  expect_false(editor_called)
  expect_length(list.files(sources_dir), 0L)
})


test_that("add_schema rejects duplicate DOI records without opening an editor", {
  sources_dir <- withr::local_tempdir()
  record <- new_schema_test_record()
  yaml::write_yaml(record, file.path(sources_dir, "first.yaml"))
  yaml::write_yaml(record, file.path(sources_dir, "second.yaml"))
  editor_called <- FALSE
  editor <- function(path) {
    editor_called <<- TRUE
  }

  expect_error(
    add_schema(record$doi, sources_dir, editor),
    "multiple\\s+screening records"
  )
  expect_false(editor_called)
})


test_that("add_schema requires a proceed decision", {
  sources_dir <- withr::local_tempdir()
  record <- new_schema_test_record(decision = "exclude")
  path <- write_screening_record(record, sources_dir)
  editor_called <- FALSE
  editor <- function(path) {
    editor_called <<- TRUE
  }

  expect_error(
    add_schema(record$doi, sources_dir, editor),
    "must have a.*proceed.*screening decision"
  )
  expect_false(editor_called)
  expect_identical(yaml::read_yaml(path), record)
})


test_that("add_schema does not replace an existing schema", {
  sources_dir <- withr::local_tempdir()
  record <- c(new_schema_test_record(), new_schema_template())
  path <- file.path(sources_dir, paste0(record$record_id, ".yaml"))
  yaml::write_yaml(record, path)
  editor_called <- FALSE
  editor <- function(path) {
    editor_called <<- TRUE
  }

  expect_error(
    add_schema(record$doi, sources_dir, editor),
    "already has a schema"
  )
  expect_false(editor_called)
  expect_identical(yaml::read_yaml(path), record)
})
