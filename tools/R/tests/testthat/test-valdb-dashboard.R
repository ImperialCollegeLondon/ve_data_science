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
  complete <- new_dashboard_test_record("10.1000/complete", title = "Complete")
  complete$datasets <- list(new_schema_template())
  complete$datasets[[1]]$source_id <- "complete_2024"
  complete$datasets[[1]]$data_file <- "data/primary/soil/complete/data.csv"
  complete$datasets[[1]]$variables <- list(
    soil_carbon = list(
      var_canonical = "soil_c_pool_lmwc",
      unit = "kg C m-3",
      description = NULL
    )
  )
  complete$datasets[[1]]$dedup_key <- "sample_id"
  excluded <- new_dashboard_test_record(
    "10.1000/excluded",
    decision = "exclude",
    title = "Excluded"
  )

  result <- pending_schema_records(list(pending, complete, excluded))
  pending_row <- result[result$doi == pending$doi, , drop = FALSE]

  expect_identical(pending_row$doi, pending$doi)
  expect_identical(pending_row$title, "Pending")
  expect_identical(pending_row$year, 2024L)
  expect_identical(pending_row$notes, "Screening note")
  expect_identical(pending_row$source_id, "")
  expect_identical(pending_row$schema_status, "Not started")
  expect_identical(pending_row$screened_at, pending$screening$screened_at)
  expect_identical(pending_row$layout, "screening_only")
})


test_that("pending_schema_records returns an empty display table", {
  result <- pending_schema_records(list())

  expect_named(
    result,
    c(
      "doi",
      "title",
      "year",
      "notes",
      "source_id",
      "schema_status",
      "screened_at",
      "dataset_index",
      "layout"
    )
  )
  expect_equal(nrow(result), 0L)
})


test_that("pending_schema_records keeps initialised templates as drafts", {
  record <- new_dashboard_test_record("10.1000/draft")
  record$datasets <- list(new_schema_template())

  result <- pending_schema_records(list(record))

  expect_identical(result$doi, record$doi)
  expect_identical(result$schema_status, "Draft")
  expect_identical(result$layout, "nested")
})


test_that("pending_schema_records creates one row per nested dataset", {
  record <- new_dashboard_test_record("10.1000/two-datasets")
  record$datasets <- list(new_schema_template(), new_schema_template())
  record$datasets[[1]]$source_id <- "first_2024"
  record$datasets[[1]]$data_file <- "data/primary/soil/first/data.csv"
  record$datasets[[1]]$variables <- list(
    soil_carbon = list(
      var_canonical = "soil_c_pool_lmwc",
      unit = "kg C m-3",
      description = NULL
    )
  )
  record$datasets[[1]]$dedup_key <- "sample_id"

  result <- pending_schema_records(list(record))

  expect_equal(nrow(result), 2L)
  expect_identical(result$source_id, c("first_2024", "author_year"))
  expect_identical(result$schema_status, c("Complete", "Draft"))
  expect_identical(result$dataset_index, c(1L, 2L))
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
  expect_match(html, 'data-dataset-index="null"', fixed = TRUE)
  expect_match(html, 'Open record', fixed = TRUE)
})


test_that("dashboard UI includes refresh, dark mode, and table styling", {
  rendered <- htmltools::renderTags(schema_dashboard_ui())

  expect_match(rendered$html, 'id="refresh"', fixed = TRUE)
  expect_match(rendered$html, 'id="dark_mode"', fixed = TRUE)
  expect_match(rendered$head, ".pending-records-table th", fixed = TRUE)
  expect_match(rendered$head, ".pending-records-table td", fixed = TRUE)
  expect_match(rendered$head, ".pending-records-table .btn", fixed = TRUE)
  expect_match(rendered$head, "font-size: 12px !important", fixed = TRUE)
  expect_match(rendered$head, "#yaml_editor .pce-textarea", fixed = TRUE)
  expect_match(rendered$head, "#yaml_editor .pce-line *", fixed = TRUE)
  expect_match(
    rendered$head,
    "font-family: Consolas, 'Courier New', monospace !important",
    fixed = TRUE
  )
  expect_match(rendered$head, "font-variant-ligatures: none", fixed = TRUE)
  expect_match(rendered$head, "font-kerning: none", fixed = TRUE)
  expect_false(grepl(" header=", rendered$html, fixed = TRUE))
  expect_false(grepl('id="doi"', rendered$html, fixed = TRUE))
  expect_false(grepl('id="initialise"', rendered$html, fixed = TRUE))
})


test_that("save_yaml_record saves valid edits", {
  sources_dir <- withr::local_tempdir()
  record <- new_dashboard_test_record("10.1000/pending")
  path <- write_screening_record(record, sources_dir)
  updated <- record
  updated$datasets <- list(new_schema_template())
  updated$datasets[[1]]$source_id <- "example_2024"
  yaml_text <- yaml::as.yaml(updated)

  expect_invisible(result <- save_yaml_record(yaml_text, path))

  expect_identical(result, path)
  expect_identical(yaml::read_yaml(path), updated)
  expect_identical(
    list.files(sources_dir, all.files = TRUE),
    c(".", "..", basename(path))
  )
})


test_that("save_yaml_record rejects mixed nested and legacy layouts", {
  sources_dir <- withr::local_tempdir()
  record <- new_dashboard_test_record("10.1000/mixed")
  path <- write_screening_record(record, sources_dir)
  record$datasets <- list(new_schema_template())
  record$source_id <- "legacy_field"

  expect_error(
    save_yaml_record(yaml::as.yaml(record), path),
    "mixes legacy"
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

      session$setInputs(
        open_schema = list(
          doi = record$doi,
          dataset_index = NA_integer_,
          source_id = ""
        )
      )

      expect_identical(editor_path(), path)
      expect_identical(pending()$doi, record$doi)
      expect_identical(pending()$schema_status, "Draft")
      expect_identical(
        yaml::read_yaml(path)$datasets,
        list(new_schema_template())
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
      session$setInputs(
        open_schema = list(
          doi = record$doi,
          dataset_index = 1L,
          source_id = "author_year"
        )
      )

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
      session$setInputs(
        open_schema = list(
          doi = record$doi,
          dataset_index = NA_integer_,
          source_id = ""
        )
      )
      session$setInputs(open_editor = 1L)

      expect_identical(editor_calls$paths, path)
    }
  )
})
