#| ---
#| title: Build the soil paper library and downloader-ready OpenAlex results
#|
#| description: |
#|   Reads a manually exported OpenAlex CSV for the soil literature search,
#|   normalises and deduplicates DOIs, and uses Unpaywall to look up preferred
#|   direct-download URLs.
#|
#|   The script writes a cached DOI lookup table to
#|   `data/derived/soil/llm/unpaywall_lookup_results.csv` and then prepares a
#|   publisher-aware retrieval table under
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
#|       Cached DOI-level lookup results from Unpaywall, including the DOI and
#|       preferred full-text URL used for route classification.
#|   - name: full_text_openalex_results.csv
#|     path: data/derived/soil/llm/full_text/openalex_results/
#|     description: |
#|       Retrieval table with one row per DOI, including host classification,
#|       publisher group, and retrieval method.
#|
#| package_dependencies:
#|   - tidyverse
#|   - roadoi
#|   - here
#|
#| usage_notes: |
#|   Re-run the Unpaywall step by deleting
#|   `data/derived/soil/llm/unpaywall_lookup_results.csv` or changing the cache
#|   logic below. The resulting retrieval table is intended to drive different
#|   downstream paths for generic direct download, repository download, and
#|   publisher-specific TDM APIs.
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


# Restrict to OpenAlex rows that already indicate OA availability, then
# normalise DOI URLs down to bare DOI strings for the Unpaywall lookup.
doi_input <- papers |>
  filter(`Open access` == "Open Access", !is.na(DOI), DOI != "") |>
  transmute(
    doi = str_remove(DOI, "^https?://(dx\\.)?doi\\.org/")
  ) |>
  distinct(doi)

# Reuse the cached Unpaywall table when present to avoid repeating a long,
# rate-limited DOI lookup step against the Unpaywall API.
lookup_results_path <-
  here::here("data/derived/soil/llm/unpaywall_lookup_results.csv")

if (file.exists(lookup_results_path)) {
  lookup_results <- read_csv(lookup_results_path, show_col_types = FALSE) |>
    select(doi, preferred_full_text_url)
} else {
  lookup_results <- doi_input |>
    pull(doi) |>
    purrr::map_dfr(
      \(doi) {
        preferred_full_text_url <- tryCatch(
          {
            result <- oadoi_fetch(
              dois = doi,
              email = "hrlai.ecology@gmail.com",
              .progress = "none"
            )

            # Keep only direct PDF targets for the downloader.
            if (
              is.null(result$best_oa_location) ||
                length(result$best_oa_location) == 0
            ) {
              NA_character_
            } else {
              url <- result$best_oa_location[[1]]$url_for_pdf

              if (is.null(url) || length(url) == 0 || is.na(url) || url == "") {
                NA_character_
              } else {
                as.character(url)
              }
            }
          },
          # Treat lookup failures as missing URLs so the batch can complete.
          error = \(e) NA_character_
        )

        tibble(
          doi = doi,
          preferred_full_text_url = preferred_full_text_url
        )
      }
    )

  write_csv(lookup_results, lookup_results_path)
}

# Standardise empty strings to missing values before classifying routes.
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

full_text_openalex_results <- lookup_results |>
  filter(!is.na(preferred_full_text_url)) |>
  mutate(
    host = str_to_lower(str_match(
      preferred_full_text_url,
      "^https?://([^/]+)"
    )[, 2]),
    publisher_group = case_when(
      str_detect(host, "(^|\\.)wiley\\.com$") ~ "wiley",
      str_detect(host, "(^|\\.)sciencedirect\\.com$") |
        str_detect(host, "(^|\\.)elsevier\\.com$") |
        str_detect(host, "(^|\\.)els-cdn\\.com$") ~ "elsevier",
      str_detect(host, "(^|\\.)link\\.springer\\.com$") ~ "springer",
      str_detect(host, "(^|\\.)nature\\.com$") |
        str_detect(host, "(^|\\.)springernature\\.com$") |
        str_detect(host, "(^|\\.)biomedcentral\\.com$") |
        str_detect(host, "(^|\\.)springeropen\\.com$") ~ "springer_nature",
      str_detect(host, "pmc\\.ncbi\\.nlm\\.nih\\.gov$") |
        str_detect(host, "(^|\\.)europepmc\\.org$") |
        str_detect(host, "(^|\\.)zenodo\\.org$") |
        str_detect(host, "(^|\\.)osf\\.io$") |
        str_detect(host, "(^|\\.)figshare\\.com$") |
        str_detect(host, "(^|\\.)handle\\.net$") |
        str_detect(host, "(^|\\.)osti\\.gov$") |
        str_detect(host, "(^|\\.)escholarship\\.org$") |
        str_detect(host, "(^|\\.)hal\\.science$") |
        str_detect(host, "repository") ~ "repository",
      is.na(host) ~ "unknown",
      TRUE ~ "other_direct"
    ),
    retrieval_method = case_when(
      publisher_group == "wiley" ~ "wiley_tdm_api",
      publisher_group == "elsevier" ~ "elsevier_tdm_api",
      publisher_group %in% c("springer", "springer_nature") ~
        "springer_tdm_review",
      publisher_group == "repository" ~ "repository_direct",
      TRUE ~ "generic_direct"
    ),
    source_type = "pdf",
    # Build a filesystem-safe ID from the DOI for downstream filenames.
    record_id = doi |>
      str_to_lower() |>
      str_replace_all("[^a-z0-9]+", "_") |>
      str_remove("^_+") |>
      str_remove("_+$")
  ) |>
  select(
    record_id,
    doi,
    source_type,
    preferred_full_text_url,
    host,
    publisher_group,
    retrieval_method
  ) |>
  arrange(doi)

write_csv(
  full_text_openalex_results,
  file.path(openalex_results_dir, "full_text_openalex_results.csv")
)
