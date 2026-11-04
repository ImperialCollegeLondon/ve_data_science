#| ---
#| title: master_all_validation
#|
#| description: |
#|   This is the master orchestrator for the entire plant validation pipeline.
#|   It runs the individual master scripts in the correct order to ensure the
#|   validation data, variable mappings, comparisons, and documentation are
#|   fully refreshed and synchronized.
#|
#| virtual_ecosystem_module:
#|   - Plant
#|
#| author:
#|   - Arne Scheire
#|
#| status: wip
#|
#| usage_notes: |
#|   Run this script to regenerate the entire plant validation pipeline.
#|   It assumes the working directory is the location of this script.
#|   Individual master scripts are sourced in the following order:
#|   1. Observed data processing
#|   2. Predicted output processing
#|   3. Variable mapping registration
#|   4. Comparison generation
#|   5. Documentation/tracker update
#| ---

# List of all validation master scripts in execution order
master_scripts <- c(
  "observed_data_processing/master_observed_data_processing.R",
  "predicted_outputs_processing/master_predicted_outputs_processing.R",
  "variable_mapping/master_variable_mapping.R",
  "comparisons/master_comparisons.R",
  "metadata/master_validation_tracker.R"
)

# Run each master script
for (script_path in master_scripts) {
  # Extract the directory of the script
  script_dir <- dirname(script_path)
  script_name <- basename(script_path)

  # Save original directory
  old_dir <- getwd()

  # Change to script directory
  setwd(script_dir)

  message(sprintf(
    "================================================================================"
  ))
  message(sprintf("Orchestrator: Running %s", script_path))
  message(sprintf(
    "================================================================================"
  ))

  # Source in a new environment
  source(script_name, local = new.env())

  # Return to original directory
  setwd(old_dir)
}

message(
  paste(
    c(
      "================================================================================",
      "Full plant validation pipeline completed successfully.",
      "================================================================================"
    ),
    collapse = "\n"
  )
)
