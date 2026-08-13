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
    provider = "crossref",
    retrieved_at = "2026-08-13T12:00:00Z"
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
    "should be one of"
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
