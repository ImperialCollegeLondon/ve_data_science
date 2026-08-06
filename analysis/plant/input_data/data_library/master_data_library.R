#| ---
#| title: master_data_library
#|
#| description: |
#|     This is the master script for the plant data library.
#|     It runs all individual data library scripts sequentially and generates
#|     the full set of plant input data files for the data library.
#|     Each individual script is self-contained and can also be run independently.
#|
#| virtual_ecosystem_module:
#|   - Plants
#|
#| author:
#|   - Arne Scheire
#|
#| status: in progress
#|
#| scripts:
#|   - order: 1
#|     path: analysis/plant/input_data/data_library/pfts_maliau.R
#|   - order: 2
#|     path: analysis/plant/input_data/data_library/t_model_maliau.R
#|   - order: 3
#|     path: analysis/plant/input_data/data_library/pfts_maximum_height_maliau.R
#|
#| package_dependencies:
#|     - yaml
#|
#| usage_notes: |
#|   Run this script to regenerate all plant input data files.
#|   To update a single file, run the individual script directly.
#|   When adding a new script to the data library, add it to the scripts
#|   section above in the correct order, and add a corresponding source()
#|   call in the script body below.
#| ---

# ==============================================================================
# Master data library script
# Runs all individual data library scripts sequentially.
# Working directory is assumed to be the location of this script:
# analysis/plant/input_data/data_library/
# ==============================================================================

# Load packages

library(yaml)

# Helper functions to extract and parse metadata from an individual script

read_script_metadata <- function(script_path) {
  if (!file.exists(script_path)) {
    stop(sprintf("Script not found: %s", script_path))
  }
  lines <- readLines(script_path)
  yaml_lines <- lines[grepl("^#\\|", lines)]
  yaml_text <- gsub("^#\\| ?", "", yaml_lines)
  yaml::yaml.load(paste(yaml_text, collapse = "\n"))
}

print_script_summary <- function(meta, order, script_path) {
  cat(
    "================================================================================\n"
  )
  cat(sprintf("%d. %s\n", order, meta$title))
  cat(sprintf("   Script:      %s\n", script_path))
  cat(sprintf("   Status:      %s\n", meta$status))
  cat(sprintf("   Author:      %s\n", paste(meta$author, collapse = ", ")))
  cat(sprintf(
    "   Module:      %s\n",
    paste(meta$virtual_ecosystem_module, collapse = ", ")
  ))
  cat("   Description:\n")
  cat(sprintf("     %s\n", gsub("\n", "\n     ", trimws(meta$description))))
  cat("   Package dependencies:\n")
  for (p in meta$package_dependencies) {
    cat(sprintf("     - %s\n", p))
  }
  cat("   Input files:\n")
  for (f in meta$input_files) {
    cat(sprintf("     - %s/%s\n", f$path, f$name))
    cat(sprintf("       %s\n", gsub("\n", "\n       ", trimws(f$description))))
  }
  cat("   Output files:\n")
  for (f in meta$output_files) {
    cat(sprintf("     - %s/%s\n", f$path, f$name))
    cat(sprintf("       %s\n", gsub("\n", "\n       ", trimws(f$description))))
    if (!is.null(f$variables)) {
      cat("       Variables:\n")
      for (v in f$variables) {
        cat(sprintf(
          "         - %s (%s, %s): %s\n",
          v$name,
          v$type,
          v$units,
          trimws(v$description)
        ))
      }
    }
  }
  cat("   Usage notes:\n")
  cat(sprintf("     %s\n", gsub("\n", "\n     ", trimws(meta$usage_notes))))
  cat(
    "================================================================================\n"
  )
}

# ==============================================================================
# Run individual scripts
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Plant functional types (PFTs) - Maliau
# ------------------------------------------------------------------------------

script_1 <- "pfts_maliau.R"
print_script_summary(
  read_script_metadata(script_1),
  order = 1,
  script_path = script_1
)
t_start <- proc.time()
suppressMessages(source(script_1, local = new.env()))
t_end <- proc.time()
cat(sprintf("   Completed in %.1f seconds.\n", (t_end - t_start)["elapsed"]))

# ------------------------------------------------------------------------------
# 2. T model parameters - Maliau
# ------------------------------------------------------------------------------

script_2 <- "t_model_maliau.R"
print_script_summary(
  read_script_metadata(script_2),
  order = 2,
  script_path = script_2
)
t_start <- proc.time()
suppressMessages(source(script_2, local = new.env()))
t_end <- proc.time()
cat(sprintf("   Completed in %.1f seconds.\n", (t_end - t_start)["elapsed"]))

# ------------------------------------------------------------------------------
# 3. Plant functional types (PFTs) - Maliau maximum height
# ------------------------------------------------------------------------------

script_3 <- "pfts_maximum_height_maliau.R"
print_script_summary(
  read_script_metadata(script_3),
  order = 3,
  script_path = script_3
)
t_start <- proc.time()
suppressMessages(source(script_3, local = new.env()))
t_end <- proc.time()
cat(sprintf("   Completed in %.1f seconds.\n", (t_end - t_start)["elapsed"]))

# ==============================================================================

cat(
  "================================================================================\n"
)
cat("All scripts completed successfully.\n")
cat(
  "================================================================================\n"
)
