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
cand_vars <- soil_constants_fields_names

source_python(here::here("analysis/soil/llm/constant_call_doc_extractor.py"))

soil_module_dir <- normalizePath(
  here::here(".venv/Lib/site-packages/virtual_ecosystem/models/soil"),
  winslash = "/",
  mustWork = TRUE
)

soil_files <- list.files(
  soil_module_dir,
  pattern = "\\.py$",
  full.names = TRUE
)

entrypoints <- c(
  "SoilPools.calculate_all_pool_updates",
  "SoilPools.to_per_volume"
)

extract_constant_map_one <- function(
  file_path,
  caller_qualified_name,
  constants,
  max_depth = 10L
) {
  out <- py$extract_constant_call_doc_map(
    file_path = file_path,
    constants = as.list(constants),
    caller_qualified_name = caller_qualified_name,
    max_depth = max_depth
  ) |>
    py_to_r()

  tibble(
    file = basename(file_path),
    source_entrypoint = caller_qualified_name,
    constant = as.character(out$constant),
    caller = as.character(out$caller),
    callee = as.character(out$callee),
    callee_param = as.character(out$callee_param),
    depth = as.integer(out$depth),
    callee_doc = as.character(out$callee_doc),
    callee_param_doc = as.character(out$callee_param_doc)
  )
}

constant_caller_map <-
  expand_grid(
    file_path = soil_files,
    caller_qualified_name = entrypoints
  ) |>
  mutate(
    extracted = map2(
      file_path,
      caller_qualified_name,
      \(file_path, caller_qualified_name) {
        extract_constant_map_one(
          file_path = file_path,
          caller_qualified_name = caller_qualified_name,
          constants = cand_vars,
          max_depth = 10L
        )
      }
    )
  ) |>
  pull(extracted) |>
  list_rbind() |>
  distinct()

constant_scoping_table <-
  soil_constants |>
  reshape2::melt() |>
  select(constant = L1, value) |>
  filter(constant %in% cand_vars) |>
  left_join(soil_constants_field_info, by = "constant") |>
  left_join(constant_caller_map, by = "constant")
