#| ---
#| title: Search OpenAlex for soil-litter validation literature
#|
#| description: |
#|   Query OpenAlex for literature relevant to the soil validation workflow
#|   and save the results for later screening.
#|
#| virtual_ecosystem_module: Soil, Litter
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| output_files:
#|   - name: results.csv
#|     path: data/derived/soil/validation/literature_search/
#|     description: |
#|       Search results from OpenAlex used for downstream screening. This is
#|       gitignored.
#|
#| source_files:
#|   - name: valdb.R
#|     path: tools/R/R/
#|     description: |
#|       Provides screen_dataset() used to screen validation sources.
#|
#| package_dependencies:
#|   - tidyverse
#|   - box
#|   - openalexR
#|
#| usage_notes: |
#|   Re-run when updating the literature search strategy or when a fresh
#|   OpenAlex export is needed for screening.
#| ---

library(tidyverse)
box::use(tools/R/R/valdb)


# Literature search on OpenAlex ------------------------------------------

results_path <- "data/derived/soil/validation/literature_search/results.csv"

# Reuse a saved search when available.
if (file.exists(results_path)) {
  results <- read_csv(results_path, show_col_types = FALSE)
} else {
  results <- openalexR::oa_fetch(
    title_and_abstract.search.exact = "('Maliau Basin' OR Sabah) AND (soil OR litter OR microb* OR bacteri* OR fungi OR fungal OR decompos* OR necromass OR deadwood OR 'dead wood' OR carbon OR nitrogen OR phosphorus)",
    verbose = TRUE
  )

  write_csv(results, results_path)
}

# Screen OpenAlex search results -----------------------------------------

valdb$screen_dataset(sources_dir = "data/derived/soil/validation/sources")
