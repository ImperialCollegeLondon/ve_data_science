#| ---
#| title: Build a RAG store for Virtual Ecosystem docs
#|
#| description: |
#|   Build a DuckDB-backed retrieval-augmented generation (RAG) store from the
#|   Virtual Ecosystem model docs. The workflow enables LLM-based tools to
#|   quickly find and retrieve relevant documentation snippets when answering
#|   questions about the Virtual Ecosystem.
#|
#| VE_module: All
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|
#| output_files:
#|   - name: virtual_ecosystem_repo.ragnar.duckdb
#|     path: data/derived/soil/llm/
#|     description: |
#|       DuckDB RAG store containing documentation chunks with computed
#|       embeddings. Ready for semantic search via LLM tools.
#|
#| source_files:
#|   - name: ve_docs_provenance.R
#|     path: .github/skills/ve-constant-search/scripts/
#|     description: Records the clone commit and Markdown checksums in the store.
#|
#| package_dependencies:
#|   - tidyverse
#|   - ragnar
#|   - DBI
#|
#| usage_notes: |
#|   Run from the repository root. Build from the sibling Virtual Ecosystem docs.
#|   Move an existing store aside before rebuilding. The store records the VE
#|   commit and Markdown checksums. Azure credentials are needed for embedding.
#|   The old remote-develop store has no provenance and cannot pass lookup checks.
#| ---

library(tidyverse)
library(ragnar)


# Split VE documentation into chunks -----------------------------------------
source(".github/skills/ve-constant-search/scripts/ve_docs_provenance.R")
ve_root <- normalizePath("../virtual_ecosystem", mustWork = TRUE)
provenance <- ve_docs_provenance(ve_root)
ve_md_paths <- file.path(ve_root, provenance$path)
ve_docs_chunks <- ve_md_paths |>
  map(read_as_markdown) |>
  map(markdown_chunk)


# Initialize the RAG store --------------------------------------------------

if (file.exists("data/derived/soil/llm/virtual_ecosystem_repo.ragnar.duckdb")) {
  stop("Store exists; move it aside before rebuilding", call. = FALSE)
}

# Create a new DuckDB database and configure it with an embedding function.
# Embeddings convert text into vectors; when searching, the RAG system will
# find chunks with similar embeddings to the query. Azure OpenAI is used here.
store_location <- "data/derived/soil/llm/virtual_ecosystem_repo.ragnar.duckdb"
store <- ragnar_store_create(
  store_location,
  embed = \(x) {
    ragnar::embed_azure_openai(
      x,
      model = "text-embedding-3-large",
      endpoint = "https://ellmer.services.ai.azure.com"
    )
  }
)


# Ingest chunks into the RAG store -------------------------------------------

ve_docs_chunks |> map(\(x) ragnar_store_insert(store, x))


# Finalize the store ------------------------------------------------------

ragnar_store_build_index(store)
if (!identical(provenance, ve_docs_provenance(ve_root))) {
  stop("VE docs changed during indexing; discard the new store", call. = FALSE)
}
DBI::dbWriteTable(store@con, "ve_docs_provenance", provenance)
DBI::dbDisconnect(store@con)
