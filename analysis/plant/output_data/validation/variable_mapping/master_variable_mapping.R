#| ---
#| title: master_variable_mapping
#|
#| description: |
#|     This is the master script for the plant validation variable mapping library.
#|     It catalogues all variable mapping files used to link observational data
#|     with model-predicted outputs and generates a consolidated metadata
#|     catalogue for these mappings.
#|
#| virtual_ecosystem_module:
#|   - Plant
#|
#| author:
#|   - Arne Scheire
#|
#| status: wip
#|
#| scripts:
#|   - path: analysis/plant/output_data/validation/variable_mapping/realised_tissue_productivity_mapping_maliau_2.yml
#|
#| output_files:
#|   - name: master_variable_mapping_metadata.yml
#|     path: analysis/plant/output_data/validation/metadata
#|     description: |
#|       This YAML file contains the combined metadata/configuration from all
#|       mapping files listed in master_variable_mapping.R.
#|
#| package_dependencies:
#|   - yaml
#|
#| usage_notes: |
#|   Run this script to regenerate the master variable mapping metadata.
#|   When adding a new mapping file, add it to the scripts section above
#|   and to the scripts vector below.
#| ---

library(yaml)

read_mapping_metadata <- function(mapping_path) {
  if (!file.exists(mapping_path)) {
    stop(sprintf("Mapping file not found: %s", mapping_path))
  }
  yaml::yaml.load_file(mapping_path)
}

build_metadata_summary <- function(mapping_paths) {
  mapping_metadata <- lapply(mapping_paths, function(mapping_path) {
    data <- read_mapping_metadata(mapping_path)
    c(list(mapping_path = mapping_path), data)
  })

  list(
    title = "master_variable_mapping_metadata",
    generated_by = "analysis/plant/output_data/validation/variable_mapping/master_variable_mapping.R",
    generated_on = as.character(Sys.Date()),
    mappings = mapping_metadata
  )
}

write_metadata_summary <- function(metadata_summary) {
  output_path <- "../metadata/master_variable_mapping_metadata.yml"
  output_dir <- dirname(output_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  writeLines(
    yaml::as.yaml(metadata_summary),
    con = output_path
  )

  message(sprintf("Metadata catalogue written to: %s", output_path))
}

# ==============================================================================
# Run mapping library registration
# ==============================================================================

mapping_files <- c(
  "realised_tissue_productivity_mapping_maliau_2.yml"
)

metadata_summary <- build_metadata_summary(mapping_files)
write_metadata_summary(metadata_summary)

message(
  paste(
    c(
      "================================================================================",
      "Master variable mapping metadata generated successfully.",
      "================================================================================"
    ),
    collapse = "\n"
  )
)
