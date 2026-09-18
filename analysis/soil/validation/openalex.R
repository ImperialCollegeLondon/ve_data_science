library(tidyverse)
library(openalexR)
library(yaml)

results <- oa_fetch(
  title_and_abstract.search.exact = "('Maliau Basin' OR Sabah) AND (soil OR litter OR microb* OR bacteri* OR fungi OR fungal OR decompos* OR necromass OR deadwood OR 'dead wood' OR carbon OR nitrogen OR phosphorus)",
  verbose = TRUE
)
