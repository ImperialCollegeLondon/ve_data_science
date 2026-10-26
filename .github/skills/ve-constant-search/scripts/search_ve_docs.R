#| ---
#| title: Search the indexed Virtual Ecosystem documentation
#|
#| description: |
#|   Retrieve BM25 snippets from the local VE documentation store after
#|   checking its recorded commit and Markdown checksums against the clone.
#|
#| virtual_ecosystem_module: All
#| status: final
#| input_files:
#|   - name: virtual_ecosystem_repo.ragnar.duckdb
#|     path: data/derived/soil/llm/
#|     description: Existing indexed VE documentation and provenance table.
#|   - name: Virtual Ecosystem Markdown documentation
#|     path: ../virtual_ecosystem/docs/source/virtual_ecosystem/
#|     description: Source files checked against the store's provenance.
#| output_files: []
#| source_files:
#|   - name: ve_docs_provenance.R
#|     path: .github/skills/ve-constant-search/scripts/
#|     description: Computes the current clone's commit and checksums.
#| package_dependencies:
#|   - ragnar
#|   - DBI
#| usage_notes: |
#|   Run from the repository root with one quoted query. Snippets go to
#|   stdout; the read-only lookup needs no embedding credentials. Missing,
#|   legacy or stale stores fail; rebuild with analysis/soil/llm/rag_ve.R.
#|   Retrieved model docs provide context, not empirical evidence.
#| ---
source(".github/skills/ve-constant-search/scripts/ve_docs_provenance.R")

search_ve_docs <- function(args = commandArgs(trailingOnly = TRUE)) {
  if (length(args) != 1L || !nzchar(trimws(args[[1]]))) {
    stop("Usage: Rscript search_ve_docs.R 'QUERY'", call. = FALSE)
  }

  store_path <- "data/derived/soil/llm/virtual_ecosystem_repo.ragnar.duckdb"
  if (!file.exists(store_path)) {
    stop("VE documentation store not found: ", store_path, call. = FALSE)
  }

  store <- ragnar::ragnar_store_connect(store_path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(store@con), add = TRUE)

  if (!DBI::dbExistsTable(store@con, "ve_docs_provenance")) {
    stop(
      "VE documentation store has no provenance; rebuild with rag_ve.R",
      call. = FALSE
    )
  }
  indexed <- DBI::dbReadTable(store@con, "ve_docs_provenance")
  ve_root <- normalizePath("../virtual_ecosystem", mustWork = TRUE)
  current <- ve_docs_provenance(ve_root)
  if (
    !all(c("path", "md5", "commit") %in% names(indexed)) ||
      !identical(indexed[, c("path", "md5", "commit")], current)
  ) {
    stop(
      "VE documentation store is stale; rebuild with rag_ve.R",
      call. = FALSE
    )
  }

  results <- ragnar::ragnar_retrieve_bm25(store, args[[1]], top_k = 5L)
  if (nrow(results) == 0L) {
    cat("No matching documentation chunks.\n")
  } else {
    for (i in seq_len(nrow(results))) {
      cat(
        "\n--- Result ",
        i,
        " ---\n",
        "Source: ",
        results$origin[[i]],
        "\n",
        results$text[[i]],
        "\n",
        sep = ""
      )
    }
  }
}

if (sys.nframe() == 0L) {
  search_ve_docs()
}
