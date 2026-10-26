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
#|
#| package_dependencies:
#|   - tidyverse
#|   - jsonlite
#|   - ragnar
#|   - ellmer
#|
#| usage_notes: |
#|   Regenerate both outputs whenever the installed Virtual Ecosystem source
#|   changes. Azure OpenAI endpoint credentials must be available for embedding.
#| ---

library(tidyverse)
library(ragnar)


# Split VE source code into chunks -------------------------------------------
# List Markdown docs under docs/source/virtual_ecosystem in develop branch.
ve_md_paths <-
  jsonlite::fromJSON(
    "https://api.github.com/repos/ImperialCollegeLondon/virtual_ecosystem/git/trees/develop?recursive=1"
  ) |>
  pluck("tree", "path") |>
  (\(x) x[grepl("^docs/source/virtual_ecosystem/.*\\.md$", x)])() |>
  sort()

# Compile raw GitHub URLs and read each file as MarkdownDocument.
ve_docs_md <-
  paste0(
    "https://raw.githubusercontent.com/ImperialCollegeLondon/",
    "virtual_ecosystem/develop/",
    ve_md_paths
  ) |>
  map(read_as_markdown)

# Chunk the documents
ve_docs_chunks <- ve_docs_md |> map(markdown_chunk)


# Initialize the RAG store --------------------------------------------------

# Create a new DuckDB database and configure it with an embedding function.
# Embeddings convert text into vectors; when searching, the RAG system will
# find chunks with similar embeddings to the query. Azure OpenAI is used here.
store_location <- "data/derived/soil/llm/virtual_ecosystem_repo.ragnar.duckdb"
store <- ragnar_store_create(
  store_location,
  embed = \(x) {
    embed_azure_openai(
      x,
      model = "text-embedding-3-large",
      endpoint = "https://ellmer.services.ai.azure.com"
    )
  }
)


# Ingest chunks into the RAG store -------------------------------------------

ve_docs_chunks |> map(\(x) ragnar_store_insert(store, x))


# Finalize the store ------------------------------------------------------

# Build the vector index in DuckDB so queries can efficiently search by
# embedding similarity. Then close the connection.
ragnar_store_build_index(store)
DBI::dbDisconnect(store@con)

# Testing (NOT RUN normally)
chat <- ellmer::chat_openai(
  base_url = "https://ellmer.openai.azure.com/openai/v1",
  model = "gpt-5.6-terra",
  system_prompt = "You are an expert on the Virtual Ecosystem process model. Answer the user questions using the RAG store of embedded documentation."
)
ragnar_register_tool_retrieve(
  chat,
  store,
  top_k = 10,
  description = "Virtual Ecosystem documentation"
)
chat$chat("How does the soil module work?")
chat$chat("How is carbon cycle in the soil captured?")
