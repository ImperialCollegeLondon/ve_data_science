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
    c("source_id", "data_file", "skip_rows", "variables", "dedup_key")
  )
  expect_identical(template$source_id, "author_year")
  expect_identical(
    template$data_file,
    "data/primary/soil/author_year/*.csv"
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
})


test_that("new_schema_template returns an independent object", {
  first <- new_schema_template()
  first$source_id <- "changed"
  first$variables$var_original_1$unit <- "changed"

  expect_identical(new_schema_template()$source_id, "author_year")
  expect_identical(
    new_schema_template()$variables$var_original_1$unit,
    "unit"
  )
})


test_that("new_schema_template round trips through YAML", {
  path <- withr::local_tempfile(fileext = ".yaml")
  template <- new_schema_template()

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

  expect_error(
    initialise_source_schema(record$doi, sources_dir),
    "not at the expected path"
  )
  expect_identical(yaml::read_yaml(path), record)
})
