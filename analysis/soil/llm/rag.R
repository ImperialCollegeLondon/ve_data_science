#| ---
#| title: Build a RAG store for Virtual Ecosystem
#|
#| description: |
#|   Build a DuckDB-backed retrieval-augmented generation (RAG) store from the
#|   Virtual Ecosystem model source code. This script prepares the
#|   module's Python source files for use in RAG by: (1) splitting code into
#|   logical chunks using LlamaIndex CodeSplitter, (2) enriching chunks with
#|   symbol context (function/class names and their module paths), (3) storing
#|   chunks with embeddings in a searchable DuckDB database via ragnar in R.
#|
#|   The workflow enables LLM-based tools to quickly find and retrieve relevant
#|   code snippets when answering questions about the Virtual Ecosystem.
#|
#| VE_module: All
#|
#| author: Hao Ran Lai
#|
#| status: wip
#|
#| input_files:
#|   - name: .py scripts in the soil module
#|     path: .venv/Lib/site-packages/virtual_ecosystem/models/soil
#|     description: |
#|       Installed Virtual Ecosystem soil-model source files used to build the
#|       retrieval corpus.
#|
#| output_files:
#|   - name: soil_code_chunks.jsonl
#|     path: data/derived/soil/llm/
#|     description: |
#|       Reviewable CodeSplitter output with source and qualified-symbol context.
#|       Each line is a JSON record containing a code chunk, its location in the
#|       source file, and metadata (symbols, module path, chunk position).
#|   - name: virtual_ecosystem_repo.ragnar.duckdb
#|     path: data/derived/soil/llm/
#|     description: |
#|       DuckDB RAG store containing context-enriched soil-model source chunks
#|       with computed embeddings. Ready for semantic search via LLM tools.
#|
#| source_files:
#|   - name: code_splitter.py
#|     path: tools/python/src/ve_data_tools/code_splitter.py
#|     description: |
#|       Python chunk exporter imported through reticulate. Splits source code
#|       and captures qualified-symbol metadata for enrichment.
#|
#| package_dependencies:
#|   - DBI
#|   - jsonlite
#|   - ragnar
#|   - reticulate
#|   - tibble
#|   - toml
#|
#| usage_notes: |
#|   Regenerate both outputs whenever the installed Virtual Ecosystem source
#|   changes. Python dependencies are declared in the project pyproject.toml.
#|   Azure OpenAI endpoint credentials must be available for embedding.
#| ---

# Load Python and R dependencies -------------------------------------------

# Parse project dependencies from pyproject.toml so reticulate can set up
# the correct Python environment before loading ragnar.
pyproject <- toml::read_toml("pyproject.toml")
project_deps <- pyproject$project$dependencies

# Helper: extract version spec for a given package name from the
# project dependencies list. Stops if the package is missing or duplicated.
resolve_dependency <- function(package_name, dependencies) {
  dependencies <- unlist(dependencies, use.names = FALSE)
  dependencies <- as.character(dependencies)

  matches <- dependencies[
    startsWith(dependencies, package_name) &
      (nchar(dependencies) == nchar(package_name) |
        substr(
          dependencies,
          nchar(package_name) + 1L,
          nchar(package_name) + 1L
        ) %in%
          c("<", ">", "=", "!", "~", "["))
  ]

  if (length(matches) == 0L) {
    stop("Missing Python dependency in pyproject.toml: ", package_name)
  }

  if (length(matches) > 1L) {
    stop("Multiple dependency entries found for: ", package_name)
  }

  matches[[1]]
}

# Ensure the code-splitting library (LlamaIndex) and tree-sitter language
# parsers are available in the Python environment.
reticulate::py_require(resolve_dependency("llama-index-core", project_deps))
reticulate::py_require(resolve_dependency(
  "tree-sitter-language-pack",
  project_deps
))

# Load Ragnar: an R wrapper for semantic indexing and embedding into DuckDB.
library(ragnar)

# llama_index is a namespace package, so check the distribution that ships
# CodeSplitter.
stopifnot(reticulate::py_module_available("llama_index.core"))


# Split VE source code into chunks -------------------------------------------

# Paths to the installed soil module and output locations.
# NB: source_root can be a cloned repo instead of an installed module
source_root <- ".venv/Lib/site-packages/virtual_ecosystem/models/soil"
chunk_location <- "data/derived/soil/llm/soil_code_chunks.jsonl"
store_location <- "data/derived/soil/llm/virtual_ecosystem_repo.ragnar.duckdb"

# Import the Python code splitter and run it on all Python files in the soil
# module. CodeSplitter uses syntax trees to split code logically (e.g., at
# function/class boundaries) and outputs a JSONL file with metadata about each
# chunk (source file, line numbers, qualified symbols).
# NB: the max_chars = 8000L is decided after some trial-and-error that resulted
#     in the least amount of codes split across chunks
code_splitter <- reticulate::import_from_path(
  "code_splitter",
  path = "tools/python/src/ve_data_tools"
)
code_splitter$export_code_chunks(
  source_root,
  chunk_location,
  max_chars = 8000L
)

# Read the chunks into memory. Each line is a JSON record with the code text,
# source file path, symbol metadata, and chunk indices.
chunk_connection <- file(chunk_location, open = "r", encoding = "UTF-8")
chunk_records <- jsonlite::stream_in(chunk_connection, verbose = FALSE)
close(chunk_connection)


# Initialize the RAG store --------------------------------------------------

# Create a new DuckDB database and configure it with an embedding function.
# Embeddings convert text into vectors; when searching, the RAG system will
# find chunks with similar embeddings to the query. Azure OpenAI is used here.
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

# Helper to retry insertion with exponential backoff
# The embedding service has rate limits (HTTP 429 errors). This function
# attempts insertion and retries with exponential backoff + jitter if rate
# limited. Other errors stop immediately.
insert_with_backoff <- function(
  store,
  chunks,
  max_attempts = 8L,
  base_wait_seconds = 2,
  max_wait_seconds = 60
) {
  attempt <- 1L

  repeat {
    result <- tryCatch(
      {
        ragnar_store_insert(store, chunks)
        TRUE
      },
      error = function(error) {
        message_text <- conditionMessage(error)
        is_rate_limited <- grepl("HTTP 429", message_text, fixed = TRUE) ||
          grepl("Too Many Requests", message_text, fixed = TRUE)

        if (!is_rate_limited || attempt >= max_attempts) {
          stop(error)
        }

        backoff <- min(max_wait_seconds, base_wait_seconds * 2^(attempt - 1L))
        jitter <- stats::runif(1, min = 0, max = 1)
        wait_seconds <- backoff + jitter

        message(
          "429 rate limit hit; retrying attempt ",
          attempt + 1L,
          " of ",
          max_attempts,
          " after ",
          sprintf("%.1f", wait_seconds),
          "s"
        )
        Sys.sleep(wait_seconds)
        attempt <<- attempt + 1L
        FALSE
      }
    )

    if (isTRUE(result)) {
      break
    }
  }
}


# Ingest chunks into the RAG store -------------------------------------------

# Iterate over each source file. For each file: (1) read the original source
# to locate exact character positions of each chunk, (2) wrap chunks with
# character positions and metadata in MarkdownDocumentChunks objects, and
# (3) insert into the store (which computes embeddings and stores in DuckDB).
for (source_path in unique(chunk_records$source_path)) {
  # Filter records for this source file and sort by chunk position.
  records <- chunk_records[chunk_records$source_path == source_path, ]
  records <- records[order(records$chunk_index), ]
  source_file <- file.path(source_root, source_path)

  # Read the original source file and wrap in a MarkdownDocument for Ragnar.
  document <- MarkdownDocument(
    paste(readLines(source_file, warn = FALSE), collapse = "\n"),
    origin = source_path
  )
  document_text <- as.character(document)

  # For each chunk, find its exact character position in the source file by
  # searching for the chunk text. This ensures ragnar can link embeddings back
  # to the original source.
  starts <- integer(nrow(records))
  ends <- integer(nrow(records))
  cursor <- 1L
  for (index in seq_len(nrow(records))) {
    location <- regexpr(
      records$text[[index]],
      substring(document_text, cursor),
      fixed = TRUE
    )
    if (location[[1]] < 0L) {
      stop(
        "Could not locate chunk ",
        records$chunk_id[[index]],
        " in ",
        source_path
      )
    }

    starts[[index]] <- cursor + location[[1]] - 1L
    ends[[index]] <- starts[[index]] + attr(location, "match.length") - 1L
    cursor <- ends[[index]] + 1L
  }

  # Assemble the chunks with their positions and metadata into a structure
  # that ragnar expects. This includes the chunk text, source location,
  # and all symbol/module metadata for filtering and context.
  chunks <- MarkdownDocumentChunks(
    tibble::tibble(
      start = as.integer(starts),
      end = as.integer(ends),
      context = as.character(records$context),
      text = as.character(records$text),
      source_chunk_id = as.character(records$chunk_id),
      module = as.character(records$module),
      symbol = as.character(records$symbol),
      qualified_symbol = as.character(records$qualified_symbol),
      symbol_kind = as.character(records$symbol_kind),
      start_line = as.integer(records$start_line),
      end_line = as.integer(records$end_line),
      chunk_index = as.integer(records$chunk_index),
      chunk_count = as.integer(records$chunk_count),
      symbol_fragment = as.character(records$symbol_fragment),
      symbol_fragments = as.character(records$symbol_fragments),
      language = as.character(records$language),
      max_chars = as.integer(records$max_chars)
    ),
    document
  )

  message("Ingesting: ", source_path)
  insert_with_backoff(store, chunks)
  # Small pause between files to avoid rate limiting.
  Sys.sleep(0.5)
}

# Finalize the store ------------------------------------------------------

# Build the vector index in DuckDB so queries can efficiently search by
# embedding similarity. Then close the connection.
ragnar_store_build_index(store)
DBI::dbDisconnect(store@con)
