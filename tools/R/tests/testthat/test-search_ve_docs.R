source(here::here(
  ".github/skills/ve-constant-search/scripts/ve_docs_provenance.R"
))
withr::with_dir(
  here::here(),
  source(
    ".github/skills/ve-constant-search/scripts/search_ve_docs.R"
  )
)

testthat::test_that("documentation lookup validates input before opening store", {
  testthat::expect_error(search_ve_docs(character()), "Usage: Rscript")
  testthat::expect_error(search_ve_docs("  "), "Usage: Rscript")
})

testthat::test_that("provenance tracks changed and added docs", {
  ve_root <- tempfile()
  docs_root <- file.path(ve_root, "docs/source/virtual_ecosystem")
  dir.create(docs_root, recursive = TRUE)
  withr::defer(unlink(ve_root, recursive = TRUE))
  path <- file.path(docs_root, "one.md")
  writeLines("original", path)

  system2("git", c("-C", shQuote(ve_root), "init"), stdout = FALSE)
  system2(
    "git",
    c(
      "-C",
      shQuote(ve_root),
      "-c",
      "user.name=Test",
      "-c",
      "user.email=test@example.org",
      "commit",
      "--allow-empty",
      "-m",
      "init"
    ),
    stdout = FALSE
  )
  first <- ve_docs_provenance(ve_root)
  testthat::expect_equal(first$path, "docs/source/virtual_ecosystem/one.md")
  writeLines("changed", path)
  testthat::expect_false(identical(first$md5, ve_docs_provenance(ve_root)$md5))
  writeLines("new", file.path(docs_root, "two.md"))
  testthat::expect_length(ve_docs_provenance(ve_root)$path, 2L)
  system2(
    "git",
    c("-C", shQuote(ve_root), "commit", "--allow-empty", "-m", "next"),
    stdout = FALSE
  )
  testthat::expect_false(identical(
    first$commit,
    ve_docs_provenance(ve_root)$commit
  ))
})

testthat::test_that("legacy store without provenance cannot be searched", {
  testthat::skip_if_not_installed("ragnar")
  testthat::skip_if_not_installed("DBI")
  store_path <- here::here(
    "data/derived/soil/llm/virtual_ecosystem_repo.ragnar.duckdb"
  )
  if (!file.exists(store_path)) {
    testthat::skip("VE documentation store not available")
  }
  withr::with_dir(here::here(), {
    testthat::expect_error(
      search_ve_docs("soil carbon"),
      "store has no provenance"
    )
  })
})
