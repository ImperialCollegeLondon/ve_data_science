#| ---
#| title: Validation database build pipeline (module aggregator)
#|
#| description: |
#|     Re-exports all functions from three submodules that implement the
#|     validation database pipeline:
#|     - valdb_screening.R: DOI screening and schema management
#|     - valdb_build.R: Database assembly and data harmonization
#|     - valdb_join_ve.R: Virtual Ecosystem output matching
#|
#|     This aggregator file enables backward compatibility with code that
#|     imports from `valdb`, while the implementation is split into focused
#|     thematic modules for maintainability.
#|
#|     Please refer to the individual module files and `docs/validation_database.md`
#|     for full documentation.
#|
#| virtual_ecosystem_module: [Soil, Litter]
#|
#| author:
#|   - Hao Ran Lai
#|   - Nicholas Wei Cheng Tan
#|
#| status: final
#|
#| package_dependencies:
#|   - arrow
#|   - cli
#|   - dplyr
#|   - lubridate
#|   - pizzarr
#|   - purrr
#|   - rcrossref
#|   - readr
#|   - reshape2
#|   - rlang
#|   - sf
#|   - stats
#|   - stringr
#|   - tibble
#|   - tidyr
#|   - toml
#|   - units
#|   - utils
#|   - yaml
#|
#| source_files:
#|   - name: valdb_screening.R
#|     path: tools/R/R/valdb_screening.R
#|     description: DOI and screening record management
#|   - name: valdb_build.R
#|     path: tools/R/R/valdb_build.R
#|     description: Database assembly and harmonization
#|   - name: valdb_join_ve.R
#|     path: tools/R/R/valdb_join_ve.R
#|     description: Virtual Ecosystem output joining
#|   - name: get_ve_variables.R
#|     path: tools/R/R/get_ve_variables.R
#|     description: |
#|       Provides `get_data_variables()` and `get_derived_variables()` used by
#|       `join_ve_outputs()`.
#| ---

# Import and re-export from submodules

source(here::here("tools/R/R/valdb_screening.R"))
source(here::here("tools/R/R/valdb_build.R"))
source(here::here("tools/R/R/valdb_join_ve.R"))
source(here::here("tools/R/R/get_ve_variables.R"))
