library(tidyverse)
box::use(tools/R/R/valdb)


# Literature search on OpenAlex ------------------------------------------

results_path <- "data/derived/soil/validation/literature_search/results.csv"

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

sources_dir <- here::here("data/derived/soil/validation/sources")

valdb$screen_dataset(sources_dir = sources_dir)
