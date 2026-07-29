#| ---
#| title: Tests for DOI normalisation utility function
#|
#| description: |
#|     Unit tests for the normalise_doi function that standardises
#|     Digital Object Identifier (DOI) inputs across the validation database.
#|     Tests verify correct normalisation of DOI prefixes (https://doi.org,
#|     http://dx.doi.org, http://doi.org, doi:), case conversion to uppercase,
#|     whitespace trimming, vectorised input handling, and edge cases including
#|     NA values, empty strings, and invalid input types.
#|
#| virtual_ecosystem_module: All
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| package_dependencies:
#|     - testthat
#|     - stringr
#|
#| usage_notes: |
#|     Run via: testthat::test_dir("tools/R/tests/testthat")
#|     Tests verify uppercase output format, idempotent normalisation,
#|     and deduplication capabilities. All test cases validate the
#|     consistency and robustness of DOI handling for duplicate detection
#|     and database lookups.
#| ---
test_that("normalise_doi: basic DOI suffix converted to uppercase", {
  expect_equal(normalise_doi("10.1038/nphys1170"), "10.1038/NPHYS1170")
  expect_equal(
    normalise_doi("10.5281/zenodo.8158810"),
    "10.5281/ZENODO.8158810"
  )
})

test_that("normalise_doi: uppercase remains uppercase", {
  expect_equal(normalise_doi("10.1038/NPHYS1170"), "10.1038/NPHYS1170")
  expect_equal(
    normalise_doi("10.5281/ZENODO.8158810"),
    "10.5281/ZENODO.8158810"
  )
})

test_that("normalise_doi: mixed case converted to uppercase", {
  expect_equal(normalise_doi("10.1038/NPhys1170"), "10.1038/NPHYS1170")
  expect_equal(
    normalise_doi("10.5281/ZeNoDo.8158810"),
    "10.5281/ZENODO.8158810"
  )
})

test_that("normalise_doi: whitespace trimmed", {
  expect_equal(normalise_doi(" 10.1038/nphys1170"), "10.1038/NPHYS1170")
  expect_equal(normalise_doi("10.1038/nphys1170 "), "10.1038/NPHYS1170")
  expect_equal(normalise_doi("  10.1038/nphys1170  "), "10.1038/NPHYS1170")
  expect_equal(normalise_doi("\t10.1038/nphys1170\n"), "10.1038/NPHYS1170")
})

test_that("normalise_doi: https://doi.org prefix removed", {
  expect_equal(
    normalise_doi("https://doi.org/10.1038/nphys1170"),
    "10.1038/NPHYS1170"
  )
  expect_equal(
    normalise_doi("HTTPS://DOI.ORG/10.1038/NPHYS1170"),
    "10.1038/NPHYS1170"
  )
})

test_that("normalise_doi: http://dx.doi.org prefix removed", {
  expect_equal(
    normalise_doi("http://dx.doi.org/10.1038/nphys1170"),
    "10.1038/NPHYS1170"
  )
  expect_equal(
    normalise_doi("HTTP://DX.DOI.ORG/10.5281/ZENODO.8158810"),
    "10.5281/ZENODO.8158810"
  )
})

test_that("normalise_doi: http://doi.org prefix removed", {
  expect_equal(
    normalise_doi("http://doi.org/10.1038/nphys1170"),
    "10.1038/NPHYS1170"
  )
})

test_that("normalise_doi: doi: prefix removed", {
  expect_equal(normalise_doi("doi:10.1038/nphys1170"), "10.1038/NPHYS1170")
  expect_equal(normalise_doi("DOI:10.1038/NPHYS1170"), "10.1038/NPHYS1170")
})

test_that("normalise_doi: combined prefix + whitespace + case", {
  expect_equal(
    normalise_doi("  https://doi.org/10.1038/NPHYS1170  "),
    "10.1038/NPHYS1170"
  )
  expect_equal(
    normalise_doi(" DOI:10.5281/ZENODO.8158810 "),
    "10.5281/ZENODO.8158810"
  )
  expect_equal(
    normalise_doi("\n HTTP://DX.DOI.ORG/10.1038/NPhys1170 \t"),
    "10.1038/NPHYS1170"
  )
})

test_that("normalise_doi: vector input", {
  input <- c(
    "10.1038/nphys1170",
    "https://doi.org/10.5281/zenodo.8158810",
    "DOI:10.1038/NPHYS1170",
    " 10.7554/eLife.12345 "
  )
  expected <- c(
    "10.1038/NPHYS1170",
    "10.5281/ZENODO.8158810",
    "10.1038/NPHYS1170",
    "10.7554/ELIFE.12345"
  )
  expect_equal(normalise_doi(input), expected)
})

test_that("normalise_doi: empty string", {
  expect_equal(normalise_doi(""), "")
})

test_that("normalise_doi: uppercase consistency across formats", {
  # All these variants should normalise to the same uppercase format
  expected_output <- "10.1038/NPHYS1170"

  variants <- c(
    "10.1038/nphys1170",
    "10.1038/NPHYS1170",
    "https://doi.org/10.1038/nphys1170",
    "http://dx.doi.org/10.1038/nphys1170",
    "doi:10.1038/nphys1170",
    " 10.1038/nphys1170 "
  )

  expect_true(all(normalise_doi(variants) == expected_output))
})

test_that("normalise_doi: invalid input type rejected", {
  expect_error(normalise_doi(123), class = "rlang_error")
  expect_error(normalise_doi(list("10.1038/nphys1170")), class = "rlang_error")
  expect_error(normalise_doi(NULL), class = "rlang_error")
})

test_that("normalise_doi: NA handling", {
  expect_equal(normalise_doi(NA_character_), NA_character_)
  expect_equal(
    normalise_doi(c(
      "10.1038/nphys1170",
      NA_character_,
      "10.5281/zenodo.8158810"
    )),
    c("10.1038/NPHYS1170", NA_character_, "10.5281/ZENODO.8158810")
  )
})

test_that("normalise_doi: idempotent normalisation", {
  # Normalising an already-normalised DOI should return the same result
  normalised_once <- normalise_doi("https://doi.org/10.1038/NPHYS1170")
  normalised_twice <- normalise_doi(normalised_once)
  expect_equal(normalised_once, normalised_twice)
})

test_that("normalise_doi: comparison for deduplication", {
  # Two different input variants should be equal after normalisation
  variant1 <- "10.1038/nphys1170"
  variant2 <- "https://doi.org/10.1038/NPHYS1170"

  expect_equal(normalise_doi(variant1), normalise_doi(variant2))
})
