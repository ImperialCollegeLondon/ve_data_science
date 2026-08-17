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

  expect_error(list_build_sources(sources_dir), "multiple source records")
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
