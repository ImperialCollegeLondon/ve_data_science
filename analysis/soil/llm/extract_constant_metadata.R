#| ---
#| title: Extract Virtual Ecosystem constant metadata using the jedi usage tool
#|
#| description: |
#|   Uses `tools/python/src/ve_data_tools/constant_usage_tool.py` to statically
#|   analyse every Virtual Ecosystem model configuration file and build a
#|   parameter database. Each configuration constant is recorded with its
#|   declaration, docstring, default expression, and every site in the codebase
#|   that references it, classified by how the constant is used.
#|
#|   Reference sites are classified as `computation` (used directly in an
#|   expression), `kwarg_forward` or `positional_forward` (passed unmodified to
#|   another function, whose identity is resolved and recorded as the consumer),
#|   `derived_forward` (a transformed value is passed on, so the consumer cannot
#|   be resolved and the site needs manual review), `validator`, or
#|   `instantiation`.
#|
#|   Function docstrings are stored once in a separate `functions` table and
#|   referenced by qualified name, keeping the database compact enough to pass
#|   to a language model.
#|
#|   The output is the grounding source for downstream LLM-assisted literature
#|   mining, replacing code-level retrieval with a deterministic lookup.
#|
#| VE_module: All
#|
#| author: Hao Ran Lai
#|
#| status: wip
#|
#| input_files:
#|   - name: model_config.py
#|     path: virtual_ecosystem/**/
#|     description: |
#|       All Virtual Ecosystem model configuration files, parsed to identify
#|       configuration classes and their constants. Reference sites are then
#|       resolved across the whole virtual_ecosystem project.
#|
#|       Only `model_config.py` files are parsed for declarations, but this is
#|       exhaustive rather than a convenience subset. Virtual Ecosystem
#|       requires each model to define its configuration in
#|       `model_name.model_config`, and an abstract syntax tree sweep of the
#|       package (following indirect inheritance) finds no `Configuration`
#|       subclass outside `model_config.py` other than the abstract base
#|       classes in `core/configuration.py`, which declare simulation controls
#|       (`static`, `run_at`) rather than parameters.
#|
#|       Other `.py` files need not be listed as inputs because they are
#|       already searched for reference sites: jedi resolves references
#|       project-wide, so constants used in files such as `pools.py` or
#|       `env_factors.py` are captured.
#|
#|       Two classes of parameter are outside the scope of this database. The
#|       tool only enumerates attributes of configuration classes, so numeric
#|       literals hardcoded in function signatures (for example
#|       `cell_area: float = 10000` in `core/grid.py`) are not recorded.
#|       Parameters held outside Python are also excluded, notably the trait
#|       tables in `virtual_ecosystem/example_data/data/` such as
#|       `animal_functional_groups.csv` and `plant_pfts.csv`.
#|
#| output_files:
#|   - name: ve_constant_usage.toml
#|     path: data/derived/soil/llm/
#|     description: |
#|       Parameter database mapping each constant to its metadata and classified
#|       reference sites, a shared function-docstring table, and a metadata
#|       table recording the analysed commit for reproducibility.
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
#|   - fs
#|   - cli
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

# set Python virtual environment and import functions
use_virtualenv(here(".venv"), required = TRUE)
cu <- import_from_path(
  "constant_usage_tool",
  path = here("tools/python/src/ve_data_tools")
)


# Map VE constants to the functions that use them ------------------------

# Root of the virtual_ecosystem clone, assumed to be a sibling of this repo
ve_project_root <- here("..", "virtual_ecosystem")

# Every model configuration file in the repository. Reference sites are
# searched project-wide, so cross-module usage is captured.
ve_config_files <-
  list.files(
    file.path(ve_project_root, "virtual_ecosystem"),
    pattern = "^model_config\\.py$",
    recursive = TRUE,
    full.names = TRUE
  ) |>
  fs::path_rel(ve_project_root)

# Build the constant database using the hybrid jedi approach
# This will take a while
ve_constants <-
  cu$get_constant_references(
    target_file_path = as.list(ve_config_files),
    out_path = "data/derived/soil/llm/ve_constant_usage.toml",
    project_root = ve_project_root,
    include_tests = FALSE
  )


# Inspect the results ----------------------------------------------------

# Provenance of the analysed source. A commit hash only identifies the source
# if the working tree was clean, so warn when it was not.
ve_metadata <- ve_constants$metadata
if (isTRUE(ve_metadata$project_dirty)) {
  cli::cli_warn(c(
    "The analysed {.pkg virtual_ecosystem} tree has uncommitted changes.",
    i = "Recorded as {.val {ve_metadata$project_describe}}.",
    i = "Results may not be reproducible from the commit hash alone."
  ))
}

# Function docstrings live in a shared table, keyed by qualified name
function_docs <- ve_constants$functions

# Flatten reference sites to one row per constant-reference pair
constant_references <-
  ve_constants$constants |>
  map(\(x) {
    tibble(
      qualified_name = x$qualified_name,
      name = x$name,
      module = x$module,
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
