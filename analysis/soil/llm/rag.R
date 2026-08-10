#| ---
#| title: Build a soil-model RAG store for Virtual Ecosystem
#|
#| description: |
#|   Build a DuckDB-backed retrieval-augmented generation (RAG) store from the
#|   Virtual Ecosystem soil model source tree. Python source is split with
#|   LlamaIndex CodeSplitter and enriched with qualified-symbol context before
#|   insertion into Ragnar.
#|
#| VE_module: Soil
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
#|   - name: virtual_ecosystem_repo.ragnar.duckdb
#|     path: data/derived/soil/llm/
#|     description: |
#|       DuckDB RAG store containing context-enriched soil-model source chunks.
#|
#| source_files:
#|   - name: code_splitter.py
#|     path: tools/python/src/ve_data_tools/code_splitter.py
#|     description: |
#|       Python chunk exporter imported through reticulate.
#|
#| package_dependencies:
#|   - DBI
#|   - jsonlite
#|   - ragnar
#|   - reticulate
#|   - tibble
#|
#| usage_notes: |
#|   Regenerate both outputs whenever the installed Virtual Ecosystem source
#|   changes. Python dependencies are declared in the project pyproject.toml.
#| ---

# Pin the uv-managed project interpreter before loading packages that may
# initialise Python through py_require(). Positron may pre-set
# RETICULATE_PYTHON = "managed", which must be overridden here.
project_python <- if (.Platform$OS.type == "windows") {
  here::here(".venv/Scripts/python.exe")
} else {
  here::here(".venv/bin/python")
}
stopifnot(file.exists(project_python))
Sys.setenv(RETICULATE_PYTHON = project_python)
reticulate::use_python(project_python, required = TRUE)

library(ragnar)

# llama_index is a namespace package, so check the distribution that ships
# CodeSplitter.
stopifnot(reticulate::py_module_available("llama_index.core"))

source_root <- ".venv/Lib/site-packages/virtual_ecosystem/models/soil"
chunk_location <- "data/derived/soil/llm/soil_code_chunks.jsonl"
store_location <- "data/derived/soil/llm/virtual_ecosystem_repo.ragnar.duckdb"

code_splitter <- reticulate::import_from_path(
  "code_splitter",
  path = "tools/python/src/ve_data_tools"
)
code_splitter$export_code_chunks(
  source_root,
  chunk_location,
  max_chars = 8000L
)

chunk_connection <- file(chunk_location, open = "r", encoding = "UTF-8")
chunk_records <- jsonlite::stream_in(chunk_connection, verbose = FALSE)
close(chunk_connection)

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

for (source_path in unique(chunk_records$source_path)) {
  records <- chunk_records[chunk_records$source_path == source_path, ]
  records <- records[order(records$chunk_index), ]
  source_file <- file.path(source_root, source_path)
  document <- MarkdownDocument(
    paste(readLines(source_file, warn = FALSE), collapse = "\n"),
    origin = source_path
  )
  document_text <- as.character(document)

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

  chunks <- MarkdownDocumentChunks(
    tibble::tibble(
      start = starts,
      end = ends,
      context = records$context,
      text = records$text,
      chunk_id = records$chunk_id,
      module = records$module,
      symbol = records$symbol,
      qualified_symbol = records$qualified_symbol,
      symbol_kind = records$symbol_kind,
      start_line = records$start_line,
      end_line = records$end_line,
      chunk_index = records$chunk_index,
      chunk_count = records$chunk_count,
      symbol_fragment = records$symbol_fragment,
      symbol_fragments = records$symbol_fragments,
      language = records$language,
      max_chars = records$max_chars
    ),
    document
  )

  message("ingesting: ", source_path)
  ragnar_store_insert(store, chunks)
}

ragnar_store_build_index(store)
DBI::dbDisconnect(store@con)
