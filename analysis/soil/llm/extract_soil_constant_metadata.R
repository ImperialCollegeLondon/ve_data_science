library(tidyverse)
library(reticulate)
library(here)

# set Python virtual environment and import functions
use_virtualenv(here(".venv"), required = TRUE)
cu <- import_from_path("constant_usage_tool", path = "tools/python")


# Map VE constants to the caller functions -------------------------------

# A list of model files containing constants to parse
ve_model_files <- c(
  "virtual_ecosystem/models/soil/uptake.py",
  "virtual_ecosystem/models/soil/env_factors.py",
  "virtual_ecosystem/models/soil/microbial_groups.py",
  "virtual_ecosystem/models/soil/model_config.py",
  "virtual_ecosystem/models/soil/pools.py",
  "virtual_ecosystem/models/soil/soil_model.py"
)

# Find references to the functions that call each constant
soil_constant_usage <-
  cu$get_constant_references(
    target_file_path = ve_model_files,
    out_path = "data/derived/soil/llm/soil_constant_usage.toml"
  )

soil_constant_usage_df <-
  soil_constant_usage |>
  map(\(entry) {
    refs <- entry$referenced_in
    if (length(refs) == 0) {
      tibble(
        name = entry$name,
        desc = entry$description,
        doc = entry$docstring,
        caller = NA_character_,
        caller_doc = NA_character_
      )
    } else {
      tibble(
        name = entry$name,
        desc = entry$description,
        doc = entry$docstring,
        caller = map_chr(refs, \(r) r$caller),
        caller_doc = map_chr(refs, \(r) r$docstring)
      )
    }
  }) |>
  list_rbind()

# Load soil constants and field descriptions from virtual_ecosystem
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
