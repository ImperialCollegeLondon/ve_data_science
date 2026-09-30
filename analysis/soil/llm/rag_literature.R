#| ---
#| title: Build a RAG store for soil literature full text
#|
#| description: |
#|   Build a DuckDB-backed retrieval-augmented generation (RAG) store from the
#|   Markdown full text downloaded for the soil literature library. The workflow
#|   enables LLM-based tools to retrieve relevant literature snippets together
#|   with source metadata for downstream constant review.
#|
#| VE_module: Soil
#|
#| author: Posit Assistant
#|
#| status: wip
#|
#| input_files:
#|   - name: Markdown full-text files
#|     path: data/derived/soil/llm/full_text/markdown/
#|     description: |
#|       Markdown files converted from successfully downloaded full-text
#|       sources.
#|
#| output_files:
#|   - name: soil_literature.ragnar.duckdb
#|     path: data/derived/soil/llm/
#|     description: |
#|       DuckDB RAG store containing chunked soil literature full text with
#|       citation metadata attached to each chunk.
#|
#| source_files:
#|
#| package_dependencies:
#|   - tidyverse
#|   - ragnar
#|   - ellmer
#|   - here
#|   - DBI
#|
#| usage_notes: |
#|   Run analysis/soil/llm/download_full_text.R first. This script ingests only
#|   successfully converted Markdown files and reads metadata from the YAML
#|   header written into each Markdown file. Azure OpenAI endpoint credentials
#|   must be available for embedding.
#| ---

library(tidyverse)
library(ragnar)


# Read Markdown full text ----------------------------------------------------
# Recover per-paper metadata from the YAML front matter written by
# download_full_text.R, then keep the Markdown body for chunking.
markdown_root <- here::here("data/derived/soil/llm/full_text/markdown")

read_yaml_field <- function(lines, field) {
  pattern <- paste0("^", field, ':\\s*"?(.*?)"?$')
  match <- stringr::str_match(lines, pattern)
  value <- match[, 2]
  value <- value[!is.na(value)]

  if (length(value) == 0) {
    return(NA_character_)
  }

  value[[1]]
}

read_markdown_metadata <- function(path) {
  lines <- readr::read_lines(path)
  header_end <- which(lines == "---")[2]
  header_lines <- if (length(header_end) == 1) {
    lines[2:(header_end - 1)]
  } else {
    character()
  }
  body_lines <- if (length(header_end) == 1) {
    lines[(header_end + 1):length(lines)]
  } else {
    lines
  }

  heading_lines <- body_lines[stringr::str_detect(body_lines, "^#\\s+")]
  first_heading <- if (length(heading_lines) == 0) {
    NA_character_
  } else {
    heading_lines[[1]]
  }
  title <- read_yaml_field(header_lines, "title")

  tibble(
    markdown_path = path,
    record_id = tools::file_path_sans_ext(basename(path)),
    title = dplyr::coalesce(
      dplyr::na_if(title, ""),
      stringr::str_remove(first_heading, "^#\\s+")
    ),
    doi = read_yaml_field(header_lines, "doi"),
    source_type = read_yaml_field(header_lines, "source_type"),
    detected_format = read_yaml_field(header_lines, "detected_format"),
    requested_url = read_yaml_field(header_lines, "requested_url"),
    final_url = read_yaml_field(header_lines, "final_url")
  )
}

literature_docs <-
  c(
    list.files(
      file.path(markdown_root, "pdf"),
      pattern = "\\.md$",
      full.names = TRUE
    ),
    list.files(
      file.path(markdown_root, "html"),
      pattern = "\\.md$",
      full.names = TRUE
    )
  ) |>
  map_dfr(read_markdown_metadata) |>
  arrange(record_id)


# Split literature full text into chunks -------------------------------------
literature_chunks <-
  pmap(
    literature_docs,
    \(
      markdown_path,
      record_id,
      title,
      doi,
      source_type,
      detected_format,
      requested_url,
      final_url
    ) {
      chunks <- read_as_markdown(markdown_path, origin = record_id) |>
        markdown_chunk()

      chunks$record_id <- record_id
      chunks$doi <- doi %||% NA_character_
      chunks$title <- title %||% NA_character_
      chunks$source_type <- source_type %||% NA_character_
      chunks$detected_format <- detected_format %||% NA_character_
      chunks$requested_url <- requested_url %||% NA_character_
      chunks$final_url <- final_url %||% NA_character_
      chunks
    }
  )


# Initialize the RAG store --------------------------------------------------

# Create a new DuckDB database and configure it with an embedding function.
# Embeddings convert text into vectors; when searching, the RAG system will
# find chunks with similar embeddings to the query. Azure OpenAI is used here.
store_location <- "data/derived/soil/llm/soil_literature.ragnar.duckdb"
store <- ragnar_store_create(
  store_location,
  embed = \(x) {
    embed_azure_openai(
      x,
      model = "text-embedding-3-large",
      endpoint = "https://ellmer.services.ai.azure.com"
    )
  },
  extra_cols = tibble::tibble(
    record_id = character(),
    doi = character(),
    title = character(),
    source_type = character(),
    detected_format = character(),
    requested_url = character(),
    final_url = character()
  )
)


# Ingest chunks into the RAG store -------------------------------------------

literature_chunks |> map(\(x) ragnar_store_insert(store, x))


# Finalize the store ------------------------------------------------------

# Build the vector index in DuckDB so queries can efficiently search by
# embedding similarity. Then close the connection.
ragnar_store_build_index(store)
DBI::dbDisconnect(store@con)
