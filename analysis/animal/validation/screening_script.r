#| ---
#| title: SAFE database screening for validation database
#|
#| description: |
#|     Simple script for screening the SAFE database for validation datasets.
#|
#| virtual_ecosystem_module: [Animal]
#|
#| author: Nicholas Wei Cheng Tan
#|
#| status: wip
#|
#| input_files:
#|
#| output_files:
#|
#| package_dependencies:
#|   - arrow
#|   - box
#|   - cli
#|   - dplyr
#|   - here
#|   - lubridate
#|   - purrr
#|   - rcrossref
#|   - readr
#|   - reshape2
#|   - rlang
#|   - sf
#|   - stringr
#|   - tibble
#|   - tidyr
#|   - toml
#|   - units
#|   - yaml
#|   - shiny
#|   - bslib
#|
#| usage_notes: |
#|   Please refer to `docs/validation_database.md` for a step-by-step tutorial.
#| ---

module_name <- "animal"

validation_root <- here::here(
  "data",
  "derived",
  module_name,
  "validation"
)

# define sources_dir and data_path
sources_dir <- file.path(validation_root, "sources")

data_path <- file.path(validation_root, "database")

box::use(tools/R/R/valdb)
valdb$screen_dataset(sources_dir = sources_dir)

# add schema to the validation database
valdb$add_schema(
  doi = "https://doi.org/10.1111/2041-210X.13930",
  sources_dir = sources_dir
)

Sys.setenv(
  VE_MODULE = "animal",
  VE_SOURCES_DIR = sources_dir
)
shiny::runApp(
  "analysis/soil/validation/schema_dashboard"
)
