library(tidyverse)
library(openalexR)
library(roadoi)

# # OpenAlex search term used for the manual export:
# search_term <- "(
#   soil OR litter OR microbial OR decomposition OR \"soil respiration\" OR mineralization OR nitrification OR denitrification OR necromass OR \"nitrogen fixation\" OR \"soil organic matter\" OR \"soil enzyme\" OR \"extracellular enzyme\"
# ) AND (
#   ecolog* OR ecosystem* OR forest OR grassland OR tropical OR temperate OR boreal OR wetland OR peatland OR agroecosystem* OR biogeochemistry
# ) AND (
#   parameter OR parameters OR constant OR constants OR coefficient OR coefficients OR rate OR rates OR turnover OR trait OR traits OR kinetic OR kinetics OR \"temperature response\" OR Q10 OR Arrhenius OR \"activation energy\" OR \"first-order\" OR \"half-life\" OR review OR synthesis OR \"meta-analysis\" OR \"systematic review\"
# )"

# results <- oa_fetch(
#   entity = "works",
#   title_and_abstract.search.exact = search_term,
#   abstract = FALSE
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

doi_input <- papers |>
  filter(`Open access` == "Open Access", !is.na(DOI), DOI != "") |>
  transmute(
    title_export = Title,
    author_export = Author,
    year_export = Year,
    doi = str_remove(DOI, "^https?://(dx\\.)?doi\\.org/")
  ) |>
  distinct(doi, .keep_all = TRUE)

tictoc::tic()
lookup_results <- doi_input |>
  select(doi) |>
  pull(doi) |>
  purrr::map_dfr(safe_oadoi_fetch, email = "hrlai.ecology@gmail.com") |>
  left_join(doi_input, by = "doi") |>
  mutate(
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
  here::here("data/derived/soil/llm/unpaywall_lookup_results.csv")
)

lookup_summary <- lookup_results |>
  summarise(
    n_total = n(),
    n_errors = sum(!is.na(error)),
    n_preferred_full_text_url = sum(!is.na(preferred_full_text_url)),
    n_pdf_url = sum(!is.na(best_oa_url_for_pdf)),
    n_landing_page_only = sum(
      is.na(best_oa_url_for_pdf) & !is.na(best_oa_url)
    )
  )

lookup_summary
