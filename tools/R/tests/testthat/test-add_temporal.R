#| ---
#| title: Tests for temporal coordinate handling in the validation database
#|
#| description: |
#|     Unit tests for add_temporal(), the helper that attaches sampling times
#|     to each source dataset in the validation database. The emphasis is on
#|     the two failure modes that are silent rather than loud: time-zone
#|     handling, where flooring an instant in UTC rather than in the source
#|     zone widens it onto the wrong calendar day, and ambiguous date formats,
#|     where a day-first string such as "14/03/2015" is otherwise read as the
#|     year 2014 without complaint. Also covered are the half-open interval
#|     convention, blanket campaign windows, open-ended ranges, and the
#|     remaining guard rails.
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
#|     - lubridate
#|     - tibble
#|
#| usage_notes: |
#|     Run via: testthat::test_dir("tools/R/tests/testthat")
#|     Tests that touch time zones pin the session zone with
#|     withr::local_timezone(), so that they pass regardless of the machine
#|     they run on.
#| ---

# A source config mimicking one entry of sources.yaml.
make_source <- function(...) {
  utils::modifyList(
    list(source_id = "test_2015", dedup_key = "location_name"),
    list(...)
  )
}

test_data <- function(dates = c("2015-03-14", "2015-04-02")) {
  tibble::tibble(
    location_name = c("plot_a", "plot_b"),
    sampled = dates,
    soil_N = c(1, 2)
  )
}


# Time zones ---------------------------------------------------------------

test_that("a date-only value spans a full day in its own time zone", {
  # the bug this guards against: local midnight in Asia/Kuching is 16:00 UTC
  # the previous day, so flooring in UTC yields an 8-hour interval sitting on
  # the wrong calendar day
  withr::local_timezone("UTC")

  out <- add_temporal(
    test_data(),
    make_source(
      temporal = list(
        date_column = "sampled",
        timezone = "Asia/Kuching",
        precision = "day"
      )
    )
  )

  expect_equal(
    as.numeric(difftime(out$time_end, out$time_start, units = "hours")),
    c(24, 24)
  )
  # the interval must start at local midnight on the stated date
  local_start <- lubridate::with_tz(out$time_start, "Asia/Kuching")
  expect_equal(
    format(local_start, "%Y-%m-%d %H:%M"),
    c(
      "2015-03-14 00:00",
      "2015-04-02 00:00"
    )
  )
})


test_that("times are stored in UTC regardless of the session time zone", {
  # the build must not depend on the machine's locale
  run_in <- function(tz) {
    withr::local_timezone(tz)
    add_temporal(
      test_data("2015-03-14"[c(1, 1)]),
      make_source(
        temporal = list(
          date_column = "sampled",
          timezone = "Asia/Kuching"
        )
      )
    )$time_start
  }

  expect_equal(run_in("UTC"), run_in("America/New_York"))
  expect_equal(attr(run_in("America/New_York"), "tzone"), "UTC")
})


test_that("widening respects calendar days rather than fixed 24-hour spans", {
  # 8 March 2015 is a spring-forward day in America/New_York, so the local day
  # is only 23 hours long. Adding a fixed duration would overshoot midnight.
  withr::local_timezone("UTC")

  out <- add_temporal(
    test_data("2015-03-08"[c(1, 1)]),
    make_source(
      temporal = list(
        date_column = "sampled",
        timezone = "America/New_York",
        precision = "day"
      )
    )
  )

  expect_equal(
    as.numeric(difftime(out$time_end[1], out$time_start[1], units = "hours")),
    23
  )
  expect_equal(
    format(lubridate::with_tz(out$time_end[1], "America/New_York"), "%H:%M"),
    "00:00"
  )
})


test_that("a mid-day timestamp still widens to a clean granule boundary", {
  withr::local_timezone("UTC")

  out <- add_temporal(
    test_data("2015-03-14 08:30:00"[c(1, 1)]),
    make_source(temporal = list(date_column = "sampled", precision = "day"))
  )

  expect_equal(format(out$time_start[1], "%Y-%m-%d %H:%M"), "2015-03-14 08:30")
  expect_equal(format(out$time_end[1], "%Y-%m-%d %H:%M"), "2015-03-15 00:00")
})


# Ambiguous formats --------------------------------------------------------

test_that("a non-ISO date without a declared format aborts", {
  # left to guess, lubridate reads "14/03/2015" as the year 2014, which is
  # silent corruption rather than an error
  expect_error(
    add_temporal(
      test_data(c("14/03/2015", "02/04/2015")),
      make_source(temporal = list(date_column = "sampled"))
    ),
    "ISO"
  )
})


test_that("a declared format resolves an otherwise ambiguous date", {
  withr::local_timezone("UTC")

  day_first <- add_temporal(
    test_data(c("03/04/2015", "03/04/2015")),
    make_source(temporal = list(date_column = "sampled", format = "%d/%m/%Y"))
  )
  month_first <- add_temporal(
    test_data(c("03/04/2015", "03/04/2015")),
    make_source(temporal = list(date_column = "sampled", format = "%m/%d/%Y"))
  )

  expect_equal(lubridate::month(day_first$time_start[1]), 4)
  expect_equal(lubridate::month(month_first$time_start[1]), 3)
})


test_that("ISO dates are still parsed without a declared format", {
  withr::local_timezone("UTC")

  out <- add_temporal(
    test_data(),
    make_source(temporal = list(date_column = "sampled"))
  )

  expect_equal(
    format(out$time_start, "%Y-%m-%d"),
    c("2015-03-14", "2015-04-02")
  )
  expect_equal(out$time_source, c("data_column", "data_column"))
})


test_that("a wrong declared format aborts rather than yielding NA times", {
  expect_error(
    add_temporal(
      test_data(c("14/03/2015", "02/04/2015")),
      make_source(
        temporal = list(
          date_column = "sampled",
          format = "%Y-%m-%d"
        )
      )
    ),
    "parsed"
  )
})


test_that("a numeric date column is caught as an Excel serial number", {
  dat <- test_data()
  dat$sampled <- c(42430, 42431)

  expect_error(
    add_temporal(dat, make_source(temporal = list(date_column = "sampled"))),
    "numeric"
  )
})


test_that("an implausible year aborts", {
  # a two-digit year misread as the first century
  expect_error(
    add_temporal(
      test_data(c("0015-03-14", "0015-04-02")),
      make_source(temporal = list(date_column = "sampled"))
    ),
    "1900"
  )
})


# Intervals and blanket windows --------------------------------------------

test_that("a blanket campaign window is applied to every row", {
  withr::local_timezone("UTC")

  out <- add_temporal(
    test_data(),
    make_source(
      temporal = list(
        same_for_all_rows = list(
          start = "2011-01-01",
          end = "2014-12-01",
          precision = "month",
          note = "Paper states sampling ran 2011-2014"
        )
      )
    )
  )

  expect_true(all(out$time_source == "same_for_all_rows"))
  expect_true(all(out$time_type == "whole dataset"))
  # the YAML end is the last inclusive granule, stored as an exclusive bound
  expect_equal(format(out$time_end[1], "%Y-%m-%d"), "2015-01-01")
  expect_true(all(out$time_note == "Paper states sampling ran 2011-2014"))
})


test_that("a per-row start/end pair is stored half-open", {
  withr::local_timezone("UTC")

  dat <- tibble::tibble(s = "2015-03-01", e = "2015-03-05")
  out <- add_temporal(
    dat,
    make_source(
      temporal = list(
        start_column = "s",
        end_column = "e",
        precision = "day"
      )
    )
  )

  expect_equal(out$time_type, "interval")
  expect_equal(format(out$time_end, "%Y-%m-%d"), "2015-03-06")
  # the inclusive final day is inside the interval, the next day is not
  expect_true(as.POSIXct("2015-03-05 23:00", tz = "UTC") < out$time_end)
  expect_false(as.POSIXct("2015-03-06 00:00", tz = "UTC") < out$time_end)
})


test_that("an open-ended campaign leaves the end missing", {
  out <- add_temporal(
    test_data(),
    make_source(
      temporal = list(
        same_for_all_rows = list(
          start = "2011-01-01",
          end = "open"
        )
      )
    )
  )

  expect_true(all(is.na(out$time_end)))
  expect_true(all(!is.na(out$time_start)))
  expect_true(all(out$time_source == "same_for_all_rows"))
})


# Guard rails --------------------------------------------------------------

test_that("a source with no temporal block warns and yields missing times", {
  # this is the state of every currently configured source
  expect_warning(
    out <- add_temporal(test_data(), make_source()),
    "No sampling time"
  )

  expect_equal(nrow(out), 2)
  expect_true(all(is.na(out$time_start)))
  expect_true(all(out$time_source == "missing"))
  # the columns must still exist, and with the right types, because sources
  # are row-bound into one database
  expect_s3_class(out$time_start, "POSIXct")
  expect_type(out$time_type, "character")
})


test_that("template entries left as NA are treated as not supplied", {
  # this is the shape `add_schema()` writes before a curator edits it
  source_dat <- make_source(
    temporal = list(
      date_column = NA,
      start_column = NA,
      end_column = NA,
      format = NA,
      timezone = NA,
      precision = NA,
      same_for_all_rows = list(start = NA, end = NA, precision = NA, note = NA)
    )
  )

  expect_warning(
    out <- add_temporal(test_data(), source_dat),
    "No sampling time"
  )
  expect_true(all(out$time_source == "missing"))
})


test_that("an end before its start aborts", {
  expect_error(
    add_temporal(
      tibble::tibble(s = "2015-03-05", e = "2015-03-01"),
      make_source(temporal = list(start_column = "s", end_column = "e"))
    ),
    "start"
  )
})


test_that("a mistyped column name aborts", {
  expect_error(
    add_temporal(
      test_data(),
      make_source(temporal = list(date_column = "date"))
    ),
    "not in the dataset"
  )
})


test_that("mixing date_column with a start/end pair aborts", {
  expect_error(
    add_temporal(
      test_data(),
      make_source(
        temporal = list(
          date_column = "sampled",
          start_column = "sampled",
          end_column = "sampled"
        )
      )
    ),
    "sets both"
  )
})


test_that("a blanket window without a start aborts", {
  expect_error(
    add_temporal(
      test_data(),
      make_source(
        temporal = list(
          same_for_all_rows = list(note = "sometime in the 2010s")
        )
      )
    ),
    "needs at least"
  )
})


test_that("an unknown precision aborts", {
  expect_error(
    add_temporal(
      test_data(),
      make_source(
        temporal = list(
          date_column = "sampled",
          precision = "fortnight"
        )
      )
    ),
    "precision"
  )
})


test_that("partially missing dates are flagged, not dropped", {
  expect_warning(
    out <- add_temporal(
      test_data(c("2015-03-14", NA)),
      make_source(temporal = list(date_column = "sampled"))
    ),
    "1 of 2 rows"
  )

  expect_equal(nrow(out), 2)
  expect_equal(out$time_source, c("data_column", "missing"))
})


test_that("the row count is never changed", {
  dat <- test_data()

  expect_equal(
    nrow(add_temporal(
      dat,
      make_source(
        temporal = list(
          date_column = "sampled"
        )
      )
    )),
    nrow(dat)
  )
})
