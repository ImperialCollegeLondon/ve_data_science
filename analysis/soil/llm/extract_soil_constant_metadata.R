#| ---
#| title: Extract soil constant metadata using the jedi constant usage tool
#|
#| description: |
#|   Uses `tools/python/src/ve_data_tools/constant_usage_tool.py` to statically
#|   analyse Virtual Ecosystem model configuration files and build a parameter
#|   database. Each configuration constant is recorded with its declaration,
#|   docstring, default expression, and every site in the codebase that
#|   references it, classified by how the constant is used.
#|
#|   Reference sites are classified as `computation` (used directly in an
#|   expression), `kwarg_forward` or `positional_forward` (passed unmodified to
#|   another function, whose identity is resolved and recorded as the consumer),
#|   `derived_forward` (a transformed value is passed on, so the consumer cannot
#|   be resolved and the site needs manual review), `validator`, or
#|   `instantiation`.
#|
#|   The output is the grounding source for downstream LLM-assisted literature
#|   mining, replacing code-level retrieval with a deterministic lookup.
#|
#| VE_module: Soil
#|
#| author: Hao Ran Lai
#|
#| status: wip
#|
#| input_files:
#|   - name: model_config.py
#|     path: virtual_ecosystem/models/soil/
#|     description: |
#|       Virtual Ecosystem soil model configuration file, parsed to identify
#|       configuration classes and their constants. Reference sites are then
#|       resolved across the whole virtual_ecosystem project.
#|
#| output_files:
#|   - name: soil_constant_usage.toml
#|     path: data/derived/soil/llm/
#|     description: |
#|       Parameter database mapping each soil constant to its metadata and
#|       classified reference sites, with a metadata table recording the
#|       analysed commit for reproducibility.
#|
#| source_files:
#|   - name: constant_usage_tool.py
#|     path: tools/python/src/ve_data_tools/
#|     description: |
#|       Python tool imported via reticulate. Combines import-based class
#|       detection, AST-based attribute enumeration, and jedi reference
#|       resolution.
#|
#| package_dependencies:
#|   - tidyverse
#|   - reticulate
#|   - here
#|   - withr
#|
#| usage_notes: |
#|   Requires a Python virtual environment at the repository root (.venv) with
#|   jedi and tomli_w installed, and a clone of the virtual_ecosystem repository
#|   as a sibling directory of ve_data_science.
#|
#|   Re-run whenever the analysed virtual_ecosystem commit changes. The commit
#|   hash is recorded in the output metadata.
#| ---

library(tidyverse)
library(reticulate)
library(here)
library(withr)

# set Python virtual environment and import functions
# RETICULATE_PYTHON, if set (e.g. to "managed"), takes precedence over
# use_virtualenv() and would select a different interpreter, so clear it first.
withr::local_envvar(RETICULATE_PYTHON = NA, .local_envir = globalenv())
use_virtualenv(here(".venv"), required = TRUE)
cu <- import_from_path(
  "constant_usage_tool",
  path = here("tools/python/src/ve_data_tools")
)


# Map VE constants to the functions that use them ------------------------

# Root of the virtual_ecosystem clone, assumed to be a sibling of this repo
ve_project_root <- here("..", "virtual_ecosystem")

# Configuration files to parse. Reference sites are searched project-wide, so
# constants used outside the soil module are still captured.
ve_config_files <- c(
  "virtual_ecosystem/models/soil/model_config.py"
)

soil_constant_usage <-
  cu$get_constant_references(
    target_file_path = ve_config_files,
    out_path = here("data/derived/soil/llm/soil_constant_usage.toml"),
    project_root = ve_project_root,
    include_tests = FALSE
  )


# Inspect the results ----------------------------------------------------

# Flatten reference sites to one row per constant-reference pair
constant_references <-
  soil_constant_usage |>
  map(\(x) {
    tibble(
      qualified_name = x$qualified_name,
      name = x$name,
      class_name = x$class_name,
      default_expression = x$default_expression,
      docstring = x$docstring,
      reference = x$referenced_in
    )
  }) |>
  list_rbind() |>
  unnest_wider(reference)

# How are constants used across the codebase?
count(constant_references, usage_kind, sort = TRUE)

# Sites where a derived value is passed on cannot be resolved automatically
# and need manual inspection
filter(constant_references, usage_kind == "derived_forward") |>
  select(name, file, line, expression)
