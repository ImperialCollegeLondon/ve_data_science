library(ragnar)

# Create RAG store
store_location <- "data/derived/soil/llm/virtual_ecosystem_repo.ragnar.duckdb"
store <- ragnar_store_create(
  store_location,
  embed = embed_ollama(model = "embeddinggemma")
)

# Files to be inserted into the store
files <- c(
  # "../virtual_ecosystem/docs/source/api",
  # "../virtual_ecosystem/docs/source/development",
  # "../virtual_ecosystem/docs/source/glossary",
  # "../virtual_ecosystem/docs/source/using_the_ve",
  # "../virtual_ecosystem/docs/source/virtual_ecosystem",
  # "../virtual_ecosystem/virtual_ecosystem",
  "../virtual_ecosystem/virtual_ecosystem/models/soil"
) |>
  purrr::map(
    \(path) list.files(path, recursive = TRUE, full.names = TRUE)
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
