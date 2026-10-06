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

box::use(
  ./valdb_screening[
    normalise_doi,
    doi_to_record_id,
    normalise_doi_metadata,
    fetch_doi_metadata,
    new_screening_record,
    list_screening_records,
    find_screening_record,
    write_screening_record,
    screen_dataset,
    new_schema_template,
    initialise_source_schema,
    add_schema
  ],
  ./valdb_build[
    build_validation_database
  ],
  ./valdb_join_ve[
    join_ve_outputs
  ]
)
