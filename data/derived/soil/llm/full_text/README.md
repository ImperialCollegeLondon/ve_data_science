# Full-text retrieval pipeline

This directory stores downloader inputs, raw full-text retrieval outputs,
Markdown conversions, and run logs for the soil literature library.

## Layout

- `openalex_results/` stores the prepared retrieval table written by
  [analysis/soil/llm/paper_library.R](../../../../../analysis/soil/llm/paper_library.R).
  The maintained file is `full_text_openalex_results.csv`.
- `raw/pdf/` stores downloaded PDFs.
- `raw/html/` stores downloaded article landing pages as HTML when a requested
  PDF URL resolves to HTML content instead.
- `markdown/pdf/` stores Markdown converted from PDFs.
- `markdown/html/` stores Markdown converted from HTML landing pages.
- `logs/` stores timestamped downloader run logs such as
  `download_log_YYYYMMDDTHHMMSSZ.csv`.

## Current workflow

1. Run
   [analysis/soil/llm/paper_library.R](../../../../../analysis/soil/llm/paper_library.R).
   This refreshes the DOI-level Unpaywall cache at
   `data/derived/soil/llm/unpaywall_lookup_results.csv` when needed and writes
   `openalex_results/full_text_openalex_results.csv`.
2. Run
   [analysis/soil/llm/download_full_text.R](../../../../../analysis/soil/llm/download_full_text.R).
   This reads `openalex_results/full_text_openalex_results.csv`, downloads only
   rows routed to `generic_direct`, converts successful retrievals to Markdown,
   and writes a timestamped log to `logs/`.
3. Run
   [analysis/soil/llm/rag_literature.R](../../../../../analysis/soil/llm/rag_literature.R)
   after downloads complete. It ingests Markdown files directly from
   `markdown/` and reads document metadata from each file's YAML front matter.

## Important notes

There is currently **no manifest layer** under this directory. The maintained
inputs for downstream ingestion are:

- `openalex_results/full_text_openalex_results.csv` for retrieval routing, and
- the Markdown files under `markdown/` for literature ingestion.

`rag_literature.R` does not read raw files and does not depend on any
`manifests/` directory or `full_text_manifest.csv`.

The downloader can legitimately write HTML outputs for records that began as
nominal PDF targets in `full_text_openalex_results.csv`, because the final
response format is detected from the returned content type or URL.

## Python environment behavior

The downloader uses `reticulate::py_require()` to request `pymupdf4llm` and
`trafilatura`. If `RETICULATE_PYTHON` is not already set, the script defaults
to `RETICULATE_PYTHON = "managed"`, which tells reticulate to prefer its
uv-managed Python environment instead of binding accidentally to some other
installed Python.

If a user wants a specific local Python or virtual environment instead, they
should set `RETICULATE_PYTHON` or `RETICULATE_PYTHON_ENV` before running the R
script. If R was started from an already activated virtual environment,
reticulate may also discover that through `VIRTUAL_ENV`.
