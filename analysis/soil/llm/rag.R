#| ---
#| title: Build a soil-model RAG store for Virtual Ecosystem
#|
#| description: |
#|   Build a DuckDB-backed retrieval-augmented generation (RAG) store from the
#|   Virtual Ecosystem soil model source tree. The resulting store is used as a
#|   grounding layer for later analysis scripts that need code-level context
#|   about soil constants, processes, and implementation details.
#|
#| VE_module: Soil
#|
#| author: Hao Ran Lai
#|
#| status: wip
#|
#| input_files:
#|   - name: .py scripts in the soil module
#|     path: ../virtual_ecosystem/virtual_ecosystem/models/soil
#|     description: |
#|       Python source files, documentation, and related assets used to build
#|       the retrieval corpus for soil-model questions.
#|
#| output_files:
#|   - name: virtual_ecosystem_repo.ragnar.duckdb
#|     path: data/derived/soil/llm/
#|     description: |
#|       DuckDB RAG store containing chunked markdown representations of the
#|       soil-model repository content.
#|
#| package_dependencies:
#|   - ragnar
#|   - purrr
#|   - DBI
#|
#| usage_notes: |
#|   Run this script before any downstream analysis that connects to the RAG
#|   store. The output is a derived artifact and should be regenerated whenever
#|   the underlying Virtual Ecosystem source code changes.
#| ---

library(ragnar)

# Create RAG store
store_location <- "data/derived/soil/llm/virtual_ecosystem_repo.ragnar.duckdb"
store <- ragnar_store_create(
  store_location,
  embed = \(x) {
    embed_azure_openai(
      x,
      model = "embed-v-4-0",
      endpoint = "https://ellmer.services.ai.azure.com"
    )
  }
)

# Files to be inserted into the store
files <- c(
  # "../virtual_ecosystem/docs/source/api",
  # "../virtual_ecosystem/docs/source/development",
  # "../virtual_ecosystem/docs/source/glossary",
  # "../virtual_ecosystem/docs/source/using_the_ve",
  # "../virtual_ecosystem/docs/source/virtual_ecosystem",
  # "../virtual_ecosystem/virtual_ecosystem",
  ".venv/Lib/site-packages/virtual_ecosystem/models/soil"
) |>
  purrr::map(
    \(path) list.files(path, "\\.py$", recursive = TRUE, full.names = TRUE)
  ) |>
  purrr::list_c()

# Read the files into markdown format, chunk them, and then insert to the store
for (file in files) {
  message("ingesting: ", file)
  chunks <- file |> read_as_markdown() |> markdown_chunk()
  ragnar_store_insert(store, chunks)
}

# Finalise the store and build the index
ragnar_store_build_index(store)

# close the connection
DBI::dbDisconnect(store@con)
