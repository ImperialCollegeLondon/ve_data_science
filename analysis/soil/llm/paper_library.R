#| ---
#| title: Build the soil paper library and downloader-ready OpenAlex results
#|
#| description: |
#|   Reads a manually exported OpenAlex CSV for the soil literature search,
#|   normalises and deduplicates DOIs, and looks up direct PDF links with
#|   Unpaywall.
#|
#|   The script writes a cached DOI lookup table to
#|   `data/derived/soil/llm/unpaywall_lookup_results.csv` and then prepares the
#|   downloader input under `data/derived/soil/llm/full_text/openalex_results/`.
#|   If the cached Unpaywall lookup already exists, it is reused instead of
#|   repeating the API calls.
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
#|       Cached DOI-level lookup results from Unpaywall, including only the
#|       DOI and direct PDF URL.
#|   - name: full_text_openalex_results.csv
#|     path: data/derived/soil/llm/full_text/openalex_results/
#|     description: |
#|       Downloader input with one row per DOI that has a usable PDF URL.
#|
#| package_dependencies:
#|   - tidyverse
#|   - roadoi
#|   - here
#|
#| usage_notes: |
#|   Re-run the Unpaywall step by deleting
#|   `data/derived/soil/llm/unpaywall_lookup_results.csv` or changing the cache
#|   logic below.
#| ---

library(tidyverse)
library(roadoi)

# OpenAlex search term used for the manual export:
# (
#   soil OR litter OR microbial OR decomposition OR "soil respiration" OR mineralization OR nitrification OR denitrification OR necromass OR "nitrogen fixation" OR "soil organic matter" OR "soil enzyme" OR "extracellular enzyme"
# ) AND (
#   ecolog* OR ecosystem* OR forest OR grassland OR tropical OR temperate OR boreal OR wetland OR peatland OR agroecosystem* OR biogeochemistry
# )

papers <- read_csv(
  here::here("data/derived/soil/llm/works-csv-nXYzSd9BYzAXpV87UcTYPs.csv"),
  show_col_types = FALSE
)

make_record_id <- function(doi) {
  doi |>
    str_to_lower() |>
    str_replace_all("[^a-z0-9]+", "_") |>
    str_remove("^_+") |>
    str_remove("_+$")
}

extract_pdf_url <- function(result) {
  if (
    is.null(result$best_oa_location) || length(result$best_oa_location) == 0
  ) {
    return(NA_character_)
  }

  url <- result$best_oa_location[[1]]$url_for_pdf
  if (is.null(url) || length(url) == 0 || is.na(url) || url == "") {
    return(NA_character_)
  }

  as.character(url)
}

fetch_pdf_url <- function(doi, email) {
  tryCatch(
    {
      result <- oadoi_fetch(dois = doi, email = email, .progress = "none")
      tibble(
        doi = doi,
        preferred_full_text_url = extract_pdf_url(result)
      )
    },
    error = function(e) {
      tibble(
        doi = doi,
        preferred_full_text_url = NA_character_
      )
    }
  )
}

# Restrict to OpenAlex rows that already indicate OA availability, then
# normalise DOI URLs down to bare DOI strings for the Unpaywall lookup.
doi_input <- papers |>
  filter(`Open access` == "Open Access", !is.na(DOI), DOI != "") |>
  transmute(
    doi = str_remove(DOI, "^https?://(dx\\.)?doi\\.org/")
  ) |>
  distinct(doi)

# Reuse the cached Unpaywall table when present to avoid repeating a long,
# rate-limited DOI lookup step.
lookup_results_path <-
  here::here("data/derived/soil/llm/unpaywall_lookup_results.csv")

if (file.exists(lookup_results_path)) {
  lookup_results <- read_csv(lookup_results_path, show_col_types = FALSE) |>
    select(doi, preferred_full_text_url)
} else {
  lookup_results <- doi_input |>
    pull(doi) |>
    purrr::map_dfr(fetch_pdf_url, email = "hrlai.ecology@gmail.com")

  write_csv(lookup_results, lookup_results_path)
}

lookup_results <- lookup_results |>
  mutate(
    preferred_full_text_url = if_else(
      is.na(preferred_full_text_url) | preferred_full_text_url == "",
      NA_character_,
      preferred_full_text_url
    )
  )

full_text_root <- here::here("data/derived/soil/llm/full_text")
openalex_results_dir <- file.path(full_text_root, "openalex_results")

dir.create(openalex_results_dir, recursive = TRUE, showWarnings = FALSE)

# Keep only rows with a direct PDF target.
full_text_openalex_results <- lookup_results |>
  filter(!is.na(preferred_full_text_url)) |>
  mutate(
    record_id = make_record_id(doi),
    source_type = "pdf"
  ) |>
  select(
    record_id,
    doi,
    source_type,
    preferred_full_text_url
  ) |>
  arrange(doi)

write_csv(
  full_text_openalex_results,
  file.path(openalex_results_dir, "full_text_openalex_results.csv")
)
