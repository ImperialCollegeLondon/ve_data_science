#| ---
#| title: Tests for beta_median()
#|
#| description: |
#|     Unit tests for the beta-median helper used to compute med(beta)(F)
#|     (Gneiting 2011), the Bayes-optimal point prediction for the scoring
#|     function class S_beta(x, y) = |1 - (y / x)^beta|.
#|
#| virtual_ecosystem_module: Soil
#|
#| author: Posit Assistant
#|
#| status: final
#|
#| package_dependencies:
#|     - testthat
#| ---

test_that("beta_median with beta = 0 matches the ordinary median", {
  values <- c(1, 2, 10, 20, 100)
  expect_equal(beta_median(values, beta = 0), stats::median(values))
  expect_equal(beta_median(values[1:2], beta = 0), stats::median(values[1:2]))
})

test_that("beta_median with beta = -1 shifts toward smaller values", {
  # Weighting by 1 / value up-weights smaller observations, so med(-1)(F)
  # must be no larger than the ordinary median for a strictly positive sample.
  values <- c(1, 2, 10, 20, 100)
  result <- beta_median(values, beta = -1)
  expect_lte(result, stats::median(values))
})

test_that("beta_median is stable for extreme finite weights", {
  expect_equal(beta_median(c(1e-320, 1e-300), beta = -1), 1e-320)
  expect_equal(beta_median(c(1e200, 2e200), beta = 2), 2e200)
})

test_that("beta_median returns NA for an empty sample", {
  expect_equal(beta_median(numeric(0), beta = -1), NA_real_)
})

test_that("beta_median returns NA when beta != 0 and values are non-positive", {
  expect_equal(beta_median(c(-1, 2, 3), beta = -1), NA_real_)
  expect_equal(beta_median(c(0, 2, 3), beta = -1), NA_real_)
})

test_that("beta_median allows non-positive values when beta = 0", {
  values <- c(-5, 0, 5)
  expect_equal(beta_median(values, beta = 0), stats::median(values))
})
