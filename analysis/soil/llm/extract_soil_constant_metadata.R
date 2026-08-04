#| ---
#| title: Extract soil constant metadata using LLM constant usage tool
#|
#| description: |
#|   DEPRECATED. Uses the deprecated Python tool
#|   `tools/python/src/ve_data_tools/constant_usage_tool.py` to parse Virtual
#|   Ecosystem soil model source files and map each constant to the caller
#|   functions that reference it. The resulting usage data is written to a TOML
#|   file for downstream LLM-assisted metadata extraction.
#|
#|   A candidate subset of constants is also filtered from the full usage
#|   output for use in scoping or testing passes.
#|
#|   This script and its Python dependency are retained because the approach
#|   may be revisited in future work.
#|
#| VE_module: Soil
#|
#| author: Hao Ran Lai
#|
#| status: deprecated
#|
#| input_files:
#|   - name: uptake.py, env_factors.py, microbial_groups.py, model_config.py,
#|       pools.py, soil_model.py
#|     path: virtual_ecosystem/models/soil/
#|     description: |
#|       Virtual Ecosystem soil model source files. Parsed by
#|       constant_usage_tool to identify where each constant is used.
#|
#| output_files:
#|   - name: soil_constant_usage.toml
#|     path: data/derived/soil/llm/
#|     description: |
#|       TOML file mapping each soil constant to the caller functions that
#|       reference it, intended for LLM-assisted metadata extraction.
#|
#| source_files:
#|   - name: constant_usage_tool.py
#|     path: tools/python/src/ve_data_tools/
#|     description: |
#|       DEPRECATED Python tool imported via reticulate. Parses model source
#|       files and returns constant-to-caller mappings. Retained alongside
#|       this script in case the approach is revisited.
#|
#| package_dependencies:
#|   - tidyverse
#|   - reticulate
#|   - here
#|
#| usage_notes: |
#|   DEPRECATED: Do not use this script in active workflows. Both this script
#|   and constant_usage_tool.py are deprecated and no longer maintained. They
#|   are retained solely because the LLM-based constant metadata extraction
#|   approach may be revisited in future.
#|
#|   Requires a Python virtual environment at the repository root (.venv) with
#|   the ve_data_tools package installed.
#| ---

library(tidyverse)
library(reticulate)
library(here)

# set Python virtual environment and import functions
use_virtualenv(here(".venv"), required = TRUE)
cu <- import_from_path(
  "constant_usage_tool",
  path = "tools/python/src/ve_data_tools"
)


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

# Candidate constants for current scoping pass
candidates <- c(
  "reference_cue_logit",
  "cue_reference_temp",
  "logit_cue_with_temperature",
  "maom_desorption_rate",
  "lmwc_sorption_rate",
  "necromass_decay_rate",
  "necromass_sorption_rate",
  "cue_metabolic"
)

# Find references to the functions that call each constant
# may need to trim uninformative docstring to save context window
soil_constant_usage <-
  cu$get_constant_references(
    target_file_path = ve_model_files,
    out_path = "data/derived/soil/llm/soil_constant_usage.toml",
    include_tests = FALSE
  )

# Subset a smaller test metadata, using only the candidate constants
soil_constant_usage_test <-
  keep(soil_constant_usage, \(x) {
    pluck(x, "name") %in% candidates
  })
