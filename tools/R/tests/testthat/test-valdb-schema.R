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
