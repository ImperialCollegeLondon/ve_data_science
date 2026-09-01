#| ---
#| title: Tests for spatial coordinate handling in the validation database
#|
#| description: |
#|     Unit tests for add_coordinates(), the helper that attaches spatial
#|     coordinates to each source dataset in the validation database. Tests
#|     cover the default SAFE convention (a locations.csv exported from the
#|     Locations sheet), blanket coordinates that apply to a whole dataset,
#|     non-default column names, and the guard rails: duplicated location
#|     keys that would inflate the number of observations, coordinates
#|     outside the valid decimal-degree range, ambiguous multi-column dedup
#|     keys, and missing or unmatched locations.
#|
#| virtual_ecosystem_module: All
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|
#| output_files:
#|
#| source_files:
#|
#| package_dependencies:
#|     - testthat
#|     - withr
#|     - dplyr
#|     - readr
#|     - tibble
#|
#| usage_notes: |
#|     Run via: testthat::test_dir("tools/R/tests/testthat")
#|     All fixtures are written to temporary directories and cleaned up
#|     automatically by withr::local_tempdir().
#| ---

# A minimal stand-in for a SAFE `Locations` sheet exported to CSV.
write_locations <- function(dir, ...) {
  locations <- tibble::tibble(
    `Location name` = c("plot_a", "plot_b", "plot_c"),
    Latitude = c(4.71, 4.72, NA),
    Longitude = c(117.61, 117.62, NA),
    Type = "POINT"
  )
  locations <- dplyr::bind_rows(locations, ...)
  readr::write_csv(locations, file.path(dir, "locations.csv"))
  locations
}

# A source config pointing at `dir`, mimicking one entry of sources.yaml.
make_source <- function(dir, ...) {
  utils::modifyList(
    list(
      source_id = "test_2020",
      data_file = file.path(dir, "data.csv"),
      dedup_key = "location_name"
    ),
    list(...)
  )
}

test_data <- function() {
  tibble::tibble(
    location_name = c("plot_a", "plot_b"),
    soil_N = c(1, 2)
  )
}


test_that("coordinates are looked up from the default locations.csv", {
  dir <- withr::local_tempdir()
  write_locations(dir)

  out <- add_coordinates(test_data(), make_source(dir))

  expect_equal(nrow(out), 2)
  expect_equal(out$latitude, c(4.71, 4.72))
  expect_equal(out$longitude, c(117.61, 117.62))
  expect_equal(out$location_type, c("POINT", "POINT"))
  expect_equal(out$coordinate_source, c("locations_file", "locations_file"))
})


test_that("locations without coordinates are flagged, not dropped", {
  dir <- withr::local_tempdir()
  write_locations(dir)
  dat <- tibble::tibble(location_name = c("plot_a", "plot_c"), soil_N = 1:2)

  expect_warning(
    out <- add_coordinates(dat, make_source(dir)),
    "1 of 2 rows"
  )
  expect_equal(nrow(out), 2)
  expect_equal(out$coordinate_source, c("locations_file", "missing"))
})


test_that("a blanket coordinate is applied to every row", {
  dir <- withr::local_tempdir()
  source_dat <- make_source(
    dir,
    coordinates = list(
      same_for_all_rows = list(latitude = 4.74, longitude = 116.97)
    )
  )

  out <- add_coordinates(test_data(), source_dat)

  expect_true(all(out$latitude == 4.74))
  expect_true(all(out$longitude == 116.97))
  expect_true(all(out$coordinate_source == "same_for_all_rows"))
  expect_true(all(out$location_type == "whole dataset"))
})


test_that("template entries left as NA are treated as not supplied", {
  dir <- withr::local_tempdir()
  write_locations(dir)
  # this is the shape `add_schema()` writes before a curator edits it
  source_dat <- make_source(
    dir,
    coordinates = list(
      from_file = NA,
      match_data_column = NA,
      same_for_all_rows = list(latitude = NA, longitude = NA, note = NA)
    )
  )

  out <- add_coordinates(test_data(), source_dat)

  expect_equal(out$coordinate_source, c("locations_file", "locations_file"))
})


test_that("non-default column names are honoured", {
  dir <- withr::local_tempdir()
  tibble::tibble(plot_code = "plot_a", lat_dd = 4.71, lon_dd = 117.61) |>
    readr::write_csv(file.path(dir, "custom.csv"))

  source_dat <- make_source(
    dir,
    coordinates = list(
      from_file = file.path(dir, "custom.csv"),
      match_location_column = "plot_code",
      latitude_column = "lat_dd",
      longitude_column = "lon_dd"
    )
  )

  out <- add_coordinates(test_data()[1, ], source_dat)

  expect_equal(out$latitude, 4.71)
  # a locations file without a `Type` column still gets the column
  expect_true(is.na(out$location_type))
})


test_that("a duplicated location key aborts rather than inflating rows", {
  dir <- withr::local_tempdir()
  write_locations(
    dir,
    tibble::tibble(
      `Location name` = "plot_a",
      Latitude = 4.99,
      Longitude = 117.99,
      Type = "POINT"
    )
  )

  expect_error(
    add_coordinates(test_data(), make_source(dir)),
    "must match at most 1 row"
  )
})


test_that("out-of-range coordinates abort", {
  dir <- withr::local_tempdir()
  locations <- write_locations(dir)
  # a swapped latitude/longitude pair, or a projected coordinate system
  locations$Latitude <- locations$Longitude
  readr::write_csv(locations, file.path(dir, "locations.csv"))

  expect_error(add_coordinates(test_data(), make_source(dir)))
})


test_that("a multi-column dedup key must name the location column", {
  dir <- withr::local_tempdir()
  write_locations(dir)
  source_dat <- make_source(dir, dedup_key = c("location_name", "date"))

  expect_error(
    add_coordinates(test_data(), source_dat),
    "multi-column"
  )
})


test_that("a missing locations file warns and yields missing coordinates", {
  dir <- withr::local_tempdir()

  expect_warning(
    out <- add_coordinates(test_data(), make_source(dir)),
    "cannot find"
  )
  expect_equal(nrow(out), 2)
  expect_true(all(out$coordinate_source == "missing"))
  expect_true(all(is.na(out$latitude)))
})
