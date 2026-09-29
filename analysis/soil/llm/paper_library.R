#| ---
#| title: Build the soil paper library and downloader-ready OpenAlex results
#|
#| description: |
#|   Reads a manually exported OpenAlex CSV for the soil literature search,
#|   normalises and deduplicates DOIs, and looks up open-access locations with
#|   Unpaywall.
#|
#|   The script writes a cached DOI lookup table to
#|   `data/derived/soil/llm/unpaywall_lookup_results.csv` and then prepares the
#|   full downloader input under
#|   `data/derived/soil/llm/full_text/openalex_results/`. If the cached
#|   Unpaywall lookup already exists, it is reused instead of repeating the API
#|   calls.
#|
#| VE_module: Soil
#|
#| author: Posit Assistant
#|
#| status: wip
#|
#| input_files:
#|   - name: works-csv-nXYzSd9BYzAXpV87UcTYPs.csv
#|     path: data/derived/soil/llm/
#|     description: |
#|       Manual OpenAlex export containing paper metadata such as title,
#|       author, year, DOI, and open-access status.
#|
#| output_files:
#|   - name: unpaywall_lookup_results.csv
#|     path: data/derived/soil/llm/
#|     description: |
#|       Cached DOI-level lookup results from Unpaywall, including preferred
#|       full-text URLs and open-access metadata.
#|   - name: full_text_openalex_results.csv
#|     path: data/derived/soil/llm/full_text/openalex_results/
#|     description: |
#|       Full downloader input with one row per retrievable paper.
#|
#| package_dependencies:
#|   - tidyverse
#|   - openalexR
#|   - roadoi
#|   - here
#|   - tictoc
#|
#| usage_notes: |
#|   Keep the commented OpenAlex query as provenance for the manual export.
#|
#|   Re-run the Unpaywall step by deleting
#|   `data/derived/soil/llm/unpaywall_lookup_results.csv` or changing the cache
#|   logic below.
#| ---

library(tidyverse)
library(openalexR)
library(roadoi)

# OpenAlex search term used for the manual export:
# (
#   soil OR litter OR microbial OR decomposition OR \"soil respiration\" OR mineralization OR nitrification OR denitrification OR necromass OR \"nitrogen fixation\" OR \"soil organic matter\" OR \"soil enzyme\" OR \"extracellular enzyme\"
# ) AND (
#   ecolog* OR ecosystem* OR forest OR grassland OR tropical OR temperate OR boreal OR wetland OR peatland OR agroecosystem* OR biogeochemistry
# )

papers <- read_csv(
  here::here("data/derived/soil/llm/works-csv-nXYzSd9BYzAXpV87UcTYPs.csv"),
  show_col_types = FALSE
)

extract_best_oa_field <- function(best_oa_location, field) {
  if (nrow(best_oa_location) == 0 || !field %in% names(best_oa_location)) {
    return(NA_character_)
  }

  value <- best_oa_location[[field]][[1]]
  if (length(value) == 0 || is.null(value)) {
    return(NA_character_)
  }

  value
}

safe_oadoi_fetch <- function(doi, email) {
  tryCatch(
    {
      result <- oadoi_fetch(dois = doi, email = email, .progress = "none")

      tibble(
        doi = doi,
        best_oa_url = extract_best_oa_field(
          result$best_oa_location[[1]],
          "url"
        ),
        best_oa_url_for_pdf = extract_best_oa_field(
          result$best_oa_location[[1]],
          "url_for_pdf"
        ),
        oa_status = as.character(result$oa_status[[1]]),
        is_oa = as.logical(result$is_oa[[1]]),
        has_repository_copy = as.logical(result$has_repository_copy[[1]]),
        journal_name = as.character(result$journal_name[[1]]),
        publisher = as.character(result$publisher[[1]]),
        published_date = as.character(result$published_date[[1]]),
        error = NA_character_
      )
    },
    error = function(e) {
      tibble(
        doi = doi,
        best_oa_url = NA_character_,
        best_oa_url_for_pdf = NA_character_,
        oa_status = NA_character_,
        is_oa = NA,
        has_repository_copy = NA,
        journal_name = NA_character_,
        publisher = NA_character_,
        published_date = NA_character_,
        error = conditionMessage(e)
      )
    }
  )
}

make_record_id <- function(doi) {
  doi |>
    str_to_lower() |>
    str_replace_all("[^a-z0-9]+", "_") |>
    str_remove("^_+") |>
    str_remove("_+$")
}

# Restrict to OpenAlex rows that already indicate OA availability, then
# normalise DOI URLs down to bare DOI strings for the Unpaywall lookup.
doi_input <- papers |>
  filter(`Open access` == "Open Access", !is.na(DOI), DOI != "") |>
  transmute(
    title_export = Title,
    author_export = Author,
    year_export = Year,
    doi = str_remove(DOI, "^https?://(dx\\.)?doi\\.org/")
  ) |>
  distinct(doi, .keep_all = TRUE)

# Reuse the cached Unpaywall table when present to avoid repeating a long,
# rate-limited DOI lookup step.
lookup_results_path <-
  here::here("data/derived/soil/llm/unpaywall_lookup_results.csv")

if (file.exists(lookup_results_path)) {
  lookup_results <- read_csv(lookup_results_path, show_col_types = FALSE)
} else {
  tictoc::tic()
  lookup_results <- doi_input |>
    pull(doi) |>
    purrr::map_dfr(safe_oadoi_fetch, email = "hrlai.ecology@gmail.com") |>
    left_join(doi_input, by = "doi") |>
    mutate(
      # Prefer a direct PDF when available, otherwise fall back to the OA page.
      preferred_full_text_url = coalesce(best_oa_url_for_pdf, best_oa_url)
    ) |>
    relocate(title_export, author_export, year_export, .after = doi)
  tictoc::toc()

  write_csv(
    lookup_results |>
      select(
        title_export,
        author_export,
        year_export,
        doi,
        preferred_full_text_url,
        best_oa_url,
        best_oa_url_for_pdf,
        oa_status,
        is_oa,
        has_repository_copy,
        journal_name,
        publisher,
        published_date,
        error
      ),
    lookup_results_path
  )
}

full_text_root <- here::here("data/derived/soil/llm/full_text")
openalex_results_dir <- file.path(full_text_root, "openalex_results")

dir.create(
  file.path(full_text_root, "raw", "pdf"),
  recursive = TRUE,
  showWarnings = FALSE
)
dir.create(
  file.path(full_text_root, "raw", "html"),
  recursive = TRUE,
  showWarnings = FALSE
)
dir.create(
  file.path(full_text_root, "markdown", "pdf"),
  recursive = TRUE,
  showWarnings = FALSE
)
dir.create(
  file.path(full_text_root, "markdown", "html"),
  recursive = TRUE,
  showWarnings = FALSE
)
dir.create(
  file.path(full_text_root, "logs"),
  recursive = TRUE,
  showWarnings = FALSE
)
dir.create(openalex_results_dir, recursive = TRUE, showWarnings = FALSE)

# Keep only rows with a usable retrieval target and tag whether the downloader
# should expect a direct PDF or an OA landing page.
full_text_openalex_results <- lookup_results |>
  filter(
    !is.na(preferred_full_text_url),
    preferred_full_text_url != ""
  ) |>
  mutate(
    source_type = case_when(
      !is.na(best_oa_url_for_pdf) & best_oa_url_for_pdf != "" ~ "pdf",
      TRUE ~ "landing_page"
    ),
    record_id = make_record_id(doi),
    year_export = as.integer(year_export),
    published_date = as.character(published_date),
    is_oa = as.logical(is_oa),
    has_repository_copy = as.logical(has_repository_copy)
  ) |>
  arrange(source_type, doi) |>
  select(
    record_id,
    doi,
    title_export,
    author_export,
    year_export,
    source_type,
    preferred_full_text_url,
    best_oa_url,
    best_oa_url_for_pdf,
    oa_status,
    is_oa,
    has_repository_copy,
    journal_name,
    publisher,
    published_date
  )

write_csv(
  full_text_openalex_results,
  file.path(openalex_results_dir, "full_text_openalex_results.csv")
)
