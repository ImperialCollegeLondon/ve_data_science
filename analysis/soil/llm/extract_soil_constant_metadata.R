library(tidyverse)
library(reticulate)

# Load soil constants and field descriptions from virtual_ecosystem
use_virtualenv(here::here(".venv"), required = TRUE)
soil_model_config <- import("virtual_ecosystem.models.soil.model_config")
soil_constants <- py_to_r(soil_model_config$SoilConstants()$model_dump())

soil_constants_fields <- soil_model_config$SoilConstants$model_fields
soil_constants_fields_names <- names(soil_constants_fields)
soil_constants_field_info <- tibble(
  constant = soil_constants_fields_names,
  description = map_chr(soil_constants_fields_names, \(name) {
    soil_constants_fields[[name]]$description
  })
)

# Candidate constants for current scoping pass
cand_vars <- c(
  "maom_desorption_rate",
  "lmwc_sorption_rate",
  "necromass_decay_rate",
  "necromass_sorption_rate"
)

constant_scoping_table <-
  soil_constants |>
  reshape2::melt() |>
  rename(constant = L1) |>
  filter(constant %in% cand_vars) |>
  left_join(soil_constants_field_info, by = "constant")

# Extract constant -> caller -> callee documentation from soil pools source
source_python(here::here("analysis/soil/llm/constant_call_doc_extractor.py"))

soil_pools_file <- normalizePath(
  here::here(".venv/Lib/site-packages/virtual_ecosystem/models/soil/pools.py"),
  winslash = "/",
  mustWork = TRUE
)

constant_caller_callee_docs <-
  py$extract_constant_call_doc_map(
    file_path = soil_pools_file,
    constants = as.list(cand_vars),
    caller_qualified_name = "SoilPools.calculate_all_pool_updates"
  ) |>
  py_to_r() |>
  as_tibble() |>
  mutate(across(everything(), as.character))

# Join-ready final table for downstream review
constant_scoping_with_docs <-
  constant_scoping_table |>
  left_join(constant_caller_callee_docs, by = "constant")
