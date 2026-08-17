#| ---
#| title: Tests for validation dataset screening records
#|
#| description: |
#|     Tests the language-neutral contract used to represent Step 1 dataset
#|     screening decisions.
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
#|     description: Validation database screening helpers
#|
#| package_dependencies:
#|     - testthat
#| ---
source(here::here("tools/R/R/valdb.R"))

new_test_metadata <- function() {
  list(
    title = "Example dataset",
    authors = "Example, Alice",
    year = 2023L,
    journal = NULL,
    publisher = "Example repository",
    url = "https://doi.org/10.5281/zenodo.8158810",
    keywords = "soil",
    provider = "doi_content_search",
    retrieved_at = "2026-08-13T12:00:00Z"
  )
}

new_test_doi_response <- function() {
  list(
    type = "dataset",
    categories = c("soil", "nutrients"),
    author = data.frame(
      family = c("Example", "Researcher"),
      given = c("Alice", "Ben")
    ),
    issued = list("date-parts" = matrix(c(2023L, 7L, 18L), nrow = 1L)),
    DOI = "10.5281/ZENODO.8158810",
    publisher = "Example repository",
    title = "Example dataset",
    URL = "https://doi.org/10.5281/zenodo.8158810"
  )
}

new_test_record <- function(
  decision = "proceed",
  reason = "relevant_validation_data",
  notes = "",
  screened_at = as.POSIXct("2026-08-13 12:05:00", tz = "UTC")
) {
  new_screening_record(
    doi = "10.5281/zenodo.8158810",
    decision = decision,
    reason = reason,
    notes = notes,
    metadata = new_test_metadata(),
    screened_at = screened_at
  )
}


test_that("normalise_doi canonicalises common DOI forms", {
  expect_identical(
    normalise_doi(" DOI: 10.5281/ZENODO.8158810 "),
    "10.5281/zenodo.8158810"
  )
  expect_identical(
    normalise_doi("https://doi.org/10.5281/ZENODO.8158810"),
    "10.5281/zenodo.8158810"
  )
  expect_identical(
    normalise_doi("http://dx.doi.org/10.5281/ZENODO.8158810"),
    "10.5281/zenodo.8158810"
  )
})


test_that("normalise_doi rejects invalid inputs", {
  expect_error(normalise_doi(""), "not a valid DOI")
  expect_error(normalise_doi("zenodo.8158810"), "not a valid DOI")
  expect_error(normalise_doi(c("10.1000/a", "10.1000/b")), "one non-missing")
  expect_error(normalise_doi(NA_character_), "one non-missing")
})


test_that("doi_to_record_id returns a stable file-safe identifier", {
  expect_identical(
    doi_to_record_id("https://doi.org/10.5281/ZENODO.8158810"),
    "doi-10-5281-zenodo-8158810"
  )
})


test_that("normalise_doi_metadata returns the metadata contract", {
  metadata <- normalise_doi_metadata(
    new_test_doi_response(),
    retrieved_at = as.POSIXct("2026-08-13 12:00:00", tz = "UTC")
  )

  expect_identical(
    metadata,
    new_test_metadata() |>
      within({
        authors <- c("Example, Alice", "Researcher, Ben")
        keywords <- c("soil", "nutrients")
      })
  )
})


test_that("normalise_doi_metadata handles absent optional metadata", {
  response <- new_test_doi_response()
  response$author <- NULL
  response$issued <- NULL
  response[["container-title"]] <- NULL
  response$categories <- NULL

  metadata <- normalise_doi_metadata(
    response,
    retrieved_at = as.POSIXct("2026-08-13 12:00:00", tz = "UTC")
  )

  expect_null(metadata$authors)
  expect_null(metadata$year)
  expect_null(metadata$journal)
  expect_null(metadata$keywords)
})


test_that("fetch_doi_metadata normalises DOI and retrieved metadata", {
  fake_fetcher <- function(doi, format) {
    expect_identical(doi, "10.5281/zenodo.8158810")
    expect_identical(format, "citeproc-json-ish")
    new_test_doi_response()
  }

  metadata <- fetch_doi_metadata(
    "https://doi.org/10.5281/ZENODO.8158810",
    retrieved_at = as.POSIXct("2026-08-13 12:00:00", tz = "UTC"),
    .fetcher = fake_fetcher
  )

  expect_identical(metadata$title, "Example dataset")
  expect_identical(metadata$provider, "doi_content_search")
})


test_that("fetch_doi_metadata reports retrieval failures", {
  failing_fetcher <- function(...) {
    stop("Network unavailable")
  }
  empty_fetcher <- function(...) {
    NULL
  }

  expect_error(
    fetch_doi_metadata("10.5281/zenodo.8158810", .fetcher = failing_fetcher),
    "Could not retrieve metadata"
  )
  expect_error(
    fetch_doi_metadata("10.5281/zenodo.8158810", .fetcher = empty_fetcher),
    "No metadata were returned"
  )
})


test_that("new_screening_record constructs the versioned contract", {
  record <- new_test_record()

  expect_named(
    record,
    c("schema_version", "record_id", "doi", "screening", "metadata")
  )
  expect_identical(record$schema_version, 1L)
  expect_identical(record$record_id, "doi-10-5281-zenodo-8158810")
  expect_identical(record$doi, "10.5281/zenodo.8158810")
  expect_identical(record$screening$decision, "proceed")
  expect_identical(record$screening$screened_at, "2026-08-13T12:05:00Z")
  expect_identical(record$metadata, new_test_metadata())
})


test_that("new_screening_record stamps the screening time by default", {
  record <- new_screening_record(
    doi = "10.5281/zenodo.8158810",
    decision = "proceed",
    reason = "relevant_validation_data",
    metadata = new_test_metadata()
  )

  expect_match(
    record$screening$screened_at,
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"
  )
})


test_that("new_screening_record accepts the screening contract choices", {
  expect_no_error(new_test_record())
  expect_no_error(new_test_record("exclude", "no_raw_data"))
  expect_no_error(
    new_test_record(
      "defer",
      "needs_second_opinion",
      "A domain expert needs to review the variables."
    )
  )
})


test_that("new_screening_record rejects unsupported choices", {
  expect_error(
    new_test_record("included", "relevant_validation_data"),
    "should be one of"
  )
  expect_error(
    new_test_record("proceed", "no_raw_data"),
    "should be"
  )
})


test_that("deferred and other screening outcomes require notes", {
  expect_error(
    new_test_record("defer", "outside_module_scope"),
    "notes.*required"
  )
  expect_error(
    new_test_record("exclude", "other"),
    "notes.*required"
  )
  expect_no_error(
    new_test_record("exclude", "other", "Dataset cannot be interpreted.")
  )
})


test_that("new_screening_record requires list metadata", {
  expect_error(
    new_screening_record(
      doi = "10.5281/zenodo.8158810",
      decision = "proceed",
      reason = "relevant_validation_data",
      metadata = "Example metadata"
    ),
    "metadata.*list"
  )
})


test_that("list_screening_records handles absent and populated directories", {
  sources_dir <- withr::local_tempdir()

  expect_identical(
    list_screening_records(file.path(sources_dir, "absent")),
    list()
  )

  record <- new_test_record()
  yaml::write_yaml(record, file.path(sources_dir, "example.yaml"))
  yaml::write_yaml(record, file.path(sources_dir, "ignored.yml"))
  writeLines("not a source", file.path(sources_dir, "README.txt"))

  records <- list_screening_records(sources_dir)

  expect_named(records, "example")
  expect_identical(records[[1L]], record)
})


test_that("find_screening_record matches normalised DOI forms", {
  sources_dir <- withr::local_tempdir()
  yaml::write_yaml(new_test_record(), file.path(sources_dir, "example.yaml"))

  found <- find_screening_record(
    "https://doi.org/10.5281/ZENODO.8158810",
    sources_dir
  )

  expect_identical(found, new_test_record())
  expect_null(find_screening_record("10.1000/not-screened", sources_dir))
})


test_that("find_screening_record rejects duplicate DOI records", {
  sources_dir <- withr::local_tempdir()
  record <- new_test_record()
  yaml::write_yaml(record, file.path(sources_dir, "first.yaml"))
  yaml::write_yaml(record, file.path(sources_dir, "second.yaml"))

  expect_error(
    find_screening_record(record$doi, sources_dir),
    "multiple\\s+screening records"
  )
})


test_that("write_screening_record creates one round-trippable YAML file", {
  sources_dir <- file.path(withr::local_tempdir(), "sources")
  record <- new_test_record()

  path <- write_screening_record(record, sources_dir)

  expect_identical(
    path,
    file.path(sources_dir, "doi-10-5281-zenodo-8158810.yaml")
  )
  expect_true(file.exists(path))
  expect_identical(yaml::read_yaml(path), record)
  expect_identical(
    list.files(sources_dir, all.files = TRUE),
    c(
      ".",
      "..",
      "doi-10-5281-zenodo-8158810.yaml"
    )
  )
})


test_that("write_screening_record rejects duplicate DOI records", {
  sources_dir <- withr::local_tempdir()
  record <- new_test_record()
  write_screening_record(record, sources_dir)

  expect_error(
    write_screening_record(record, sources_dir),
    "delete the existing YAML file"
  )
  expect_length(list.files(sources_dir, pattern = "\\.yaml$"), 1L)
})


test_that("write_screening_record rejects inconsistent identities", {
  sources_dir <- withr::local_tempdir()
  record <- new_test_record()
  record$record_id <- "doi-wrong"

  expect_error(
    write_screening_record(record, sources_dir),
    "DOI and record ID are inconsistent"
  )
  expect_length(list.files(sources_dir), 0L)
})


test_that("list_screening_records reports malformed YAML", {
  sources_dir <- withr::local_tempdir()
  writeLines("screening: [", file.path(sources_dir, "broken.yaml"))

  expect_error(
    list_screening_records(sources_dir),
    "Could not read screening record"
  )
})


test_that("screen_dataset collects and saves a screening record", {
  sources_dir <- withr::local_tempdir()
  responses <- c("DOI: 10.5281/ZENODO.8158810", "Reviewed against soil scope.")
  readline_index <- 0L
  fake_readline <- function(prompt) {
    readline_index <<- readline_index + 1L
    responses[[readline_index]]
  }
  selections <- list()
  fake_select <- function(choices, title, graphics) {
    selections[[length(selections) + 1L]] <<- list(
      choices = choices,
      title = title,
      graphics = graphics
    )
    if (length(selections) == 1L) "exclude" else "no_raw_data"
  }
  fake_metadata_fetcher <- function(doi) {
    expect_identical(doi, "10.5281/zenodo.8158810")
    new_test_metadata()
  }

  path <- suppressMessages(screen_dataset(
    sources_dir = sources_dir,
    .metadata_fetcher = fake_metadata_fetcher,
    .readline = fake_readline,
    .select = fake_select
  ))
  record <- yaml::read_yaml(path)

  expect_identical(
    path,
    file.path(sources_dir, "doi-10-5281-zenodo-8158810.yaml")
  )
  expect_identical(selections[[1L]]$choices, screening_decisions)
  expect_identical(selections[[2L]]$choices, screening_reasons$exclude)
  expect_identical(record$screening$decision, "exclude")
  expect_identical(record$screening$reason, "no_raw_data")
  expect_identical(
    record$screening$notes,
    "Reviewed against soil scope."
  )
  expect_identical(record$metadata, new_test_metadata())
})


test_that("screen_dataset requires a decision and reason", {
  sources_dir <- withr::local_tempdir()
  fake_metadata_fetcher <- function(...) new_test_metadata()
  fake_readline <- function(...) "10.5281/zenodo.8158810"
  empty_select <- function(...) ""

  expect_error(
    suppressMessages(screen_dataset(
      sources_dir = sources_dir,
      .metadata_fetcher = fake_metadata_fetcher,
      .readline = fake_readline,
      .select = empty_select
    )),
    "screening decision is required"
  )

  select_index <- 0L
  missing_reason <- function(...) {
    select_index <<- select_index + 1L
    if (select_index == 1L) "proceed" else ""
  }
  expect_error(
    suppressMessages(screen_dataset(
      sources_dir = sources_dir,
      .metadata_fetcher = fake_metadata_fetcher,
      .readline = fake_readline,
      .select = missing_reason
    )),
    "reason.*required"
  )
})


test_that("screen_dataset rejects duplicates before metadata retrieval", {
  sources_dir <- withr::local_tempdir()
  write_screening_record(new_test_record(), sources_dir)
  metadata_requested <- FALSE
  fake_metadata_fetcher <- function(...) {
    metadata_requested <<- TRUE
    new_test_metadata()
  }

  expect_error(
    screen_dataset(
      sources_dir = sources_dir,
      .metadata_fetcher = fake_metadata_fetcher,
      .readline = function(...) "https://doi.org/10.5281/ZENODO.8158810"
    ),
    "already been screened"
  )
  expect_identical(metadata_requested, FALSE)
  expect_length(list.files(sources_dir, pattern = "\\.yaml$"), 1L)
})
