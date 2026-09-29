#| ---
#| title: Download and convert full text for the soil paper library
#|
#| description: |
#|   Reads a prepared OpenAlex results CSV, downloads the corresponding
#|   full text for rows assigned to direct-download retrieval methods, and
#|   converts it to Markdown. PDF sources are converted with `pymupdf4llm`
#|   and HTML landing pages are converted with `trafilatura`, both called
#|   directly from R through `reticulate`.
#|
#|   The script writes raw source files under
#|   `data/derived/soil/llm/full_text/raw/` and Markdown outputs under
#|   `data/derived/soil/llm/full_text/markdown/`. Rows assigned to
#|   publisher-specific API methods are skipped here and reserved for separate
#|   API-aware download scripts. It also writes a timestamped run log to
#|   `data/derived/soil/llm/full_text/logs/`.
#|
#| VE_module: Soil
#|
#| author: Posit Assistant
#|
#| status: wip
#|
#| input_files:
#|   - name: full_text_openalex_results.csv
#|     path: data/derived/soil/llm/full_text/openalex_results/
#|     description: |
#|       Prepared OpenAlex results with preferred open-access URLs and paper
#|       metadata.
#|
#| output_files:
#|   - name: Markdown full-text files
#|     path: data/derived/soil/llm/full_text/markdown/
#|     description: |
#|       One Markdown file per successfully converted paper.
#|   - name: raw source files
#|     path: data/derived/soil/llm/full_text/raw/
#|     description: |
#|       Downloaded PDFs or HTML pages saved for provenance and reprocessing.
#|   - name: run log CSV
#|     path: data/derived/soil/llm/full_text/logs/
#|     description: |
#|       Timestamped status log recording success, skip, and failure outcomes.
#|
#| package_dependencies:
#|   - tidyverse
#|   - httr2
#|   - reticulate
#|   - here
#|
#| usage_notes: |
#|   Edit the parameter block near the top of this script, then run the script
#|   from the editor in chunks or top-to-bottom. The main outputs left in the
#|   workspace are `results_tbl`, `download_summary`, `log_path`, and
#|   `python_config`.
#|
#|   The script uses `reticulate::py_require()` to declare Python dependencies
#|   and sets `RETICULATE_PYTHON = "managed"` for the session before importing
#|   the Python modules.
#| ---

library(tidyverse)
library(httr2)
library(reticulate)
Sys.setenv(RETICULATE_PYTHON = "managed")
py_require(
  packages = c(
    "pymupdf4llm>=0.0.27,<0.1",
    "trafilatura>=2.0.0,<3"
  ),
  python_version = ">=3.12,<3.15"
)
pymupdf4llm <- import("pymupdf4llm")
trafilatura <- import("trafilatura")
python_config <- py_config()


# User parameters ---------------------------------------------------------

openalex_results_path <- here::here(
  "data/derived/soil/llm/full_text/openalex_results/full_text_openalex_results.csv"
)
overwrite <- TRUE
pause_seconds <- 0.5

# Setup -------------------------------------------------------------------

full_text_root <- here::here("data/derived/soil/llm/full_text")
raw_root <- file.path(full_text_root, "raw")
markdown_root <- file.path(full_text_root, "markdown")
log_root <- file.path(full_text_root, "logs")

dir.create(file.path(raw_root, "pdf"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(raw_root, "html"), recursive = TRUE, showWarnings = FALSE)
dir.create(
  file.path(markdown_root, "pdf"),
  recursive = TRUE,
  showWarnings = FALSE
)
dir.create(
  file.path(markdown_root, "html"),
  recursive = TRUE,
  showWarnings = FALSE
)
dir.create(log_root, recursive = TRUE, showWarnings = FALSE)

clean_yaml_value <- function(value) {
  if (is.null(value) || length(value) == 0 || is.na(value) || value == "") {
    return("")
  }

  value |>
    as.character() |>
    str_replace_all("\n", " ") |>
    str_replace_all('"', "'")
}

response_error_details <- function(response) {
  details <- character()

  content_type <- resp_header(response, "content-type")
  if (
    !is.null(content_type) && length(content_type) > 0 && !is.na(content_type)
  ) {
    details <- c(details, paste("Content type:", content_type))
  }

  mitigation <- resp_header(response, "cf-mitigated")
  if (identical(mitigation, "challenge")) {
    details <- c(
      details,
      "Cloudflare challenge page returned instead of full text."
    )
  }

  body_text <- tryCatch(
    resp_body_string(response),
    error = function(e) ""
  )

  if (nzchar(body_text)) {
    html_title <- str_match(body_text, "<title>([^<]+)</title>")[, 2]

    if (!is.na(html_title) && nzchar(html_title)) {
      details <- c(details, paste("HTML title:", html_title))
    }

    if (
      str_detect(body_text, fixed("Enable JavaScript and cookies to continue"))
    ) {
      details <- c(
        details,
        "Page requires JavaScript and cookies, so it is not directly downloadable by this script."
      )
    }
  }

  details
}

# OpenAlex results --------------------------------------------------------

openalex_results <- read_csv(openalex_results_path, show_col_types = FALSE)

openalex_results <- openalex_results |>
  filter(retrieval_method == "generic_direct")

if (nrow(openalex_results) == 0) {
  stop("OpenAlex results file is empty; nothing to do.", call. = FALSE)
}

results <- vector("list", nrow(openalex_results))

# Download and convert ----------------------------------------------------

for (i in seq_len(nrow(openalex_results))) {
  row <- openalex_results[i, ]
  record_id <- row$record_id[[1]]
  doi <- row$doi[[1]]
  requested_url <- row$preferred_full_text_url[[1]]
  source_type <- row$source_type[[1]]
  retrieval_method <- row$retrieval_method[[1]]

  markdown_path <- file.path(
    markdown_root,
    if (source_type == "pdf") "pdf" else "html",
    paste0(record_id, ".md")
  )

  if (!retrieval_method %in% c("generic_direct", "repository_direct")) {
    results[[i]] <- tibble(
      record_id = record_id,
      doi = doi,
      source_type = source_type,
      requested_url = requested_url,
      final_url = NA_character_,
      detected_format = NA_character_,
      status = "skipped_requires_publisher_api",
      http_status = NA_integer_,
      raw_path = NA_character_,
      markdown_path = NA_character_,
      error = paste(
        "Retrieval method",
        shQuote(retrieval_method),
        "is reserved for a publisher-specific API workflow."
      )
    )

    message(sprintf(
      "[%s/%s] %s: skipped_requires_publisher_api",
      i,
      nrow(openalex_results),
      record_id
    ))
    Sys.sleep(pause_seconds)
    next
  }

  if (file.exists(markdown_path) && !overwrite) {
    results[[i]] <- tibble(
      record_id = record_id,
      doi = doi,
      source_type = source_type,
      requested_url = requested_url,
      final_url = NA_character_,
      detected_format = NA_character_,
      status = "skipped_existing",
      http_status = NA_integer_,
      raw_path = NA_character_,
      markdown_path = markdown_path,
      error = NA_character_
    )

    message(sprintf(
      "[%s/%s] %s: skipped_existing",
      i,
      nrow(openalex_results),
      record_id
    ))
    Sys.sleep(pause_seconds)
    next
  }

  results[[i]] <- tryCatch(
    {
      response <- request(requested_url) |>
        req_user_agent(
          paste(
            "ve-data-science-full-text/0.1",
            "(open-access retrieval for local text conversion)"
          )
        ) |>
        req_error(body = response_error_details) |>
        req_retry(max_tries = 3) |>
        req_timeout(60) |>
        req_perform()

      final_url <- response$url
      if (is.null(final_url) || length(final_url) == 0 || is.na(final_url)) {
        final_url <- requested_url
      }
      final_url <- as.character(final_url)

      content_type <- resp_header(response, "content-type")
      if (
        is.null(content_type) ||
          length(content_type) == 0 ||
          is.na(content_type)
      ) {
        content_type <- ""
      }

      detected_format <- if (
        str_ends(str_to_lower(final_url), fixed(".pdf")) ||
          str_detect(str_to_lower(content_type), fixed("application/pdf"))
      ) {
        "pdf"
      } else {
        "html"
      }

      if (detected_format == "pdf") {
        raw_path <- file.path(raw_root, "pdf", paste0(record_id, ".pdf"))
        markdown_path <- file.path(
          markdown_root,
          "pdf",
          paste0(record_id, ".md")
        )

        writeBin(resp_body_raw(response), raw_path)

        body <- pymupdf4llm$to_markdown(normalizePath(raw_path, winslash = "/"))

        if (is.null(body) || !nzchar(trimws(body))) {
          stop("PDF conversion produced empty Markdown", call. = FALSE)
        }
      } else {
        raw_path <- file.path(raw_root, "html", paste0(record_id, ".html"))
        markdown_path <- file.path(
          markdown_root,
          "html",
          paste0(record_id, ".md")
        )

        body_text <- resp_body_string(response)
        write_file(body_text, raw_path)

        body <- trafilatura$extract(
          body_text,
          url = final_url,
          output_format = "markdown",
          include_tables = TRUE,
          include_comments = FALSE,
          favor_precision = TRUE
        )

        if (is.null(body) || !nzchar(trimws(body))) {
          stop("HTML conversion produced empty Markdown", call. = FALSE)
        }
      }

      header <- paste0(
        "---\n",
        'title: "',
        clean_yaml_value(row$title_export[[1]]),
        '"\n',
        'doi: "',
        clean_yaml_value(doi),
        '"\n',
        'source_type: "',
        clean_yaml_value(source_type),
        '"\n',
        'detected_format: "',
        clean_yaml_value(detected_format),
        '"\n',
        'requested_url: "',
        clean_yaml_value(requested_url),
        '"\n',
        'final_url: "',
        clean_yaml_value(final_url),
        '"\n',
        "---\n\n"
      )

      write_file(paste0(header, body), markdown_path)

      tibble(
        record_id = record_id,
        doi = doi,
        source_type = source_type,
        requested_url = requested_url,
        final_url = final_url,
        detected_format = detected_format,
        status = "success",
        http_status = resp_status(response),
        raw_path = raw_path,
        markdown_path = markdown_path,
        error = NA_character_
      )
    },
    error = function(e) {
      response <- tryCatch(last_response(), error = function(...) NULL)
      final_url <- NA_character_
      http_status <- NA_integer_

      if (!is.null(response)) {
        final_url <- tryCatch(
          as.character(response$url),
          error = function(...) NA_character_
        )
        http_status <- tryCatch(resp_status(response), error = function(...) {
          NA_integer_
        })
      }

      tibble(
        record_id = if (is.null(record_id) || is.na(record_id)) {
          paste0("row_", i)
        } else {
          record_id
        },
        doi = if (is.null(doi) || is.na(doi)) NA_character_ else doi,
        source_type = if (is.null(source_type) || is.na(source_type)) {
          "unknown"
        } else {
          source_type
        },
        requested_url = if (is.null(requested_url) || is.na(requested_url)) {
          ""
        } else {
          requested_url
        },
        final_url = final_url,
        detected_format = NA_character_,
        status = "failed",
        http_status = http_status,
        raw_path = NA_character_,
        markdown_path = NA_character_,
        error = conditionMessage(e)
      )
    }
  )

  message(sprintf(
    "[%s/%s] %s: %s",
    i,
    nrow(openalex_results),
    results[[i]]$record_id,
    results[[i]]$status
  ))
  Sys.sleep(pause_seconds)
}

# Outputs -----------------------------------------------------------------

results_tbl <- bind_rows(results)

timestamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
log_path <- file.path(log_root, paste0("download_log_", timestamp, ".csv"))
write_csv(results_tbl, log_path)

download_summary <- results_tbl |>
  summarise(
    n_rows = n(),
    n_success = sum(status == "success"),
    n_failed = sum(status == "failed"),
    n_skipped_existing = sum(status == "skipped_existing"),
    n_skipped_requires_publisher_api = sum(
      status == "skipped_requires_publisher_api"
    )
  )

download_summary
log_path
