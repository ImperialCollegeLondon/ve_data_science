#| ---
#| title: Tests for the validation schema dashboard
#|
#| description: |
#|     Tests record filtering and schema editing in the local dashboard.
#|
#| virtual_ecosystem_module: Soil
#|
#| status: draft
#|
#| source_files:
#|   - name: dashboard.R
#|     path: analysis/soil/validation/schema_dashboard/
#|     description: Local validation schema dashboard
#|
#| package_dependencies:
#|     - shiny
#|     - testthat
#| ---
source(here::here("tools/R/R/valdb.R"))
source(here::here(
  "analysis/soil/validation/schema_dashboard/dashboard.R"
))

new_dashboard_test_record <- function(
  doi,
  decision = "proceed",
  title = "Example dataset",
  notes = "Screening note"
) {
  new_screening_record(
    doi = doi,
    decision = decision,
    reason = if (decision == "proceed") {
      "relevant_validation_data"
    } else {
      "no_raw_data"
    },
    notes = notes,
    metadata = list(title = title, year = 2024L),
    screened_at = as.POSIXct("2026-08-13 12:05:00", tz = "UTC")
  )
}


test_that("pending_schema_records keeps proceed records without schemas", {
  pending <- new_dashboard_test_record("10.1000/pending", title = "Pending")
  complete <- c(
    new_dashboard_test_record("10.1000/complete", title = "Complete"),
    new_schema_template()
  )
  excluded <- new_dashboard_test_record(
    "10.1000/excluded",
    decision = "exclude",
    title = "Excluded"
  )

  complete$source_id <- "complete_2024"
  complete$data_file <- "data/primary/soil/complete/data.csv"
  complete$variables <- list(
    soil_carbon = list(
      var_canonical = "soil_c_pool_lmwc",
      unit = "kg C m-3",
      description = NULL
    )
  )
  complete$dedup_key <- "sample_id"

  result <- pending_schema_records(list(pending, complete, excluded))

  expect_identical(result$doi, pending$doi)
  expect_identical(result$title, "Pending")
  expect_identical(result$year, 2024L)
  expect_identical(result$notes, "Screening note")
  expect_identical(result$schema_status, "Not started")
  expect_identical(result$screened_at, pending$screening$screened_at)
})


test_that("pending_schema_records returns an empty display table", {
  result <- pending_schema_records(list())

  expect_named(
    result,
    c("doi", "title", "year", "notes", "schema_status", "screened_at")
  )
  expect_equal(nrow(result), 0L)
})


test_that("pending_schema_records keeps initialised templates as drafts", {
  record <- c(
    new_dashboard_test_record("10.1000/draft"),
    new_schema_template()
  )

  result <- pending_schema_records(list(record))

  expect_identical(result$doi, record$doi)
  expect_identical(result$schema_status, "Draft")
})


test_that("pending_records_table adds one action for each source", {
  records <- pending_schema_records(list(
    new_dashboard_test_record("10.1000/first", title = "First"),
    new_dashboard_test_record("10.1000/second", title = "Second")
  ))

  html <- as.character(pending_records_table(records))

  expect_length(stringr::str_extract_all(html, "open-schema")[[1]], 2L)
  expect_match(html, 'data-doi="10.1000/first"', fixed = TRUE)
  expect_match(html, 'data-doi="10.1000/second"', fixed = TRUE)
  expect_length(stringr::str_extract_all(html, "Shiny.setInputValue")[[1]], 2L)
  expect_match(html, "{priority: &#39;event&#39;}", fixed = TRUE)
})


test_that("dashboard UI includes refresh and optional dark mode controls", {
  html <- as.character(schema_dashboard_ui())

  expect_match(html, 'id="refresh"', fixed = TRUE)
  expect_match(html, 'id="dark_mode"', fixed = TRUE)
  expect_match(html, "font-size: 0.875rem", fixed = TRUE)
  expect_false(grepl('id="doi"', html, fixed = TRUE))
  expect_false(grepl('id="initialise"', html, fixed = TRUE))
})


test_that("save_yaml_record saves valid edits", {
  sources_dir <- withr::local_tempdir()
  record <- new_dashboard_test_record("10.1000/pending")
  path <- write_screening_record(record, sources_dir)
  updated <- c(record, new_schema_template())
  updated$source_id <- "example_2024"
  yaml_text <- yaml::as.yaml(updated)

  expect_invisible(result <- save_yaml_record(yaml_text, path))

  expect_identical(result, path)
  expect_identical(yaml::read_yaml(path), updated)
  expect_identical(
    list.files(sources_dir, all.files = TRUE),
    c(".", "..", basename(path))
  )
})


test_that("save_yaml_record rejects invalid YAML without changing the file", {
  sources_dir <- withr::local_tempdir()
  record <- new_dashboard_test_record("10.1000/pending")
  path <- write_screening_record(record, sources_dir)

  expect_error(save_yaml_record("doi: [", path), "not valid YAML")
  expect_identical(yaml::read_yaml(path), record)
})


test_that("save_yaml_record rejects changed record identity", {
  sources_dir <- withr::local_tempdir()
  record <- new_dashboard_test_record("10.1000/pending")
  path <- write_screening_record(record, sources_dir)
  record$doi <- "10.1000/other"

  expect_error(
    save_yaml_record(yaml::as.yaml(record), path),
    "inconsistent"
  )
  expect_identical(yaml::read_yaml(path)$doi, "10.1000/pending")
})


test_that("dashboard initialises and loads the selected record", {
  sources_dir <- withr::local_tempdir()
  record <- new_dashboard_test_record("10.1000/pending")
  path <- write_screening_record(record, sources_dir)

  shiny::testServer(
    schema_dashboard_server(sources_dir),
    {
      expect_identical(pending()$doi, record$doi)

      session$setInputs(open_schema = record$doi)

      expect_identical(editor_path(), path)
      expect_identical(pending()$doi, record$doi)
      expect_identical(pending()$schema_status, "Draft")
      expect_identical(
        yaml::read_yaml(path)[names(new_schema_template())],
        new_schema_template()
      )
    }
  )
})


test_that("dashboard reopens an initialised draft without changing it", {
  sources_dir <- withr::local_tempdir()
  record <- new_dashboard_test_record("10.1000/draft")
  path <- write_screening_record(record, sources_dir)
  initialise_source_schema(record$doi, sources_dir)
  before <- yaml::read_yaml(path)

  shiny::testServer(
    schema_dashboard_server(sources_dir),
    {
      session$setInputs(open_schema = record$doi)

      expect_identical(editor_path(), path)
      expect_identical(yaml::read_yaml(path), before)
      expect_identical(pending()$schema_status, "Draft")
    }
  )
})


test_that("dashboard opens the loaded record in the desktop editor", {
  sources_dir <- withr::local_tempdir()
  record <- new_dashboard_test_record("10.1000/pending")
  path <- write_screening_record(record, sources_dir)
  editor_calls <- new.env(parent = emptyenv())
  editor_calls$paths <- character()
  editor <- function(path) {
    editor_calls$paths <- c(editor_calls$paths, path)
  }

  shiny::testServer(
    schema_dashboard_server(sources_dir, editor),
    {
      session$setInputs(open_schema = record$doi)
      session$setInputs(open_editor = 1L)

      expect_identical(editor_calls$paths, path)
    }
  )
})
