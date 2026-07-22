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

# Parse the docstrings to
# - extract unit
# - remove citation (to reduce self-confirmation bias)
# -

# RAGs
