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
#|   - path: analysis/plant/input_data/data_library/pfts_maliau.R
#|   - path: analysis/plant/input_data/data_library/t_model_maliau.R
#|   - path: analysis/plant/input_data/data_library/pfts_maximum_height_maliau.R
#|
#| package_dependencies:
#|   - yaml
#|
#| usage_notes: |
#|   Run this script to regenerate all plant input data files.
#|   To update a single file, run the individual script directly.
#|   When adding a new script to the data library, add it to the scripts
#|   section above in the correct order. The scripts are run in the order they
#|   appear in that list.
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

  if (!is.null(meta$package_dependencies)) {
    cat("   Package dependencies:\n")
    for (p in meta$package_dependencies) {
      cat(sprintf("     - %s\n", p))
    }
  }

  if (!is.null(meta$input_files)) {
    cat("   Input files:\n")
    for (f in meta$input_files) {
      cat(sprintf("     - %s/%s\n", f$path, f$name))
      cat(sprintf("       %s\n", gsub("\n", "\n       ", trimws(f$description))))
    }
  }

  if (!is.null(meta$output_files)) {
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
  }

  if (!is.null(meta$usage_notes)) {
    cat("   Usage notes:\n")
    cat(sprintf("     %s\n", gsub("\n", "\n     ", trimws(meta$usage_notes))))
  }

  cat(
    "================================================================================\n"
  )
}

run_script_quietly <- function(script_path, order) {
  meta <- read_script_metadata(script_path)
  print_script_summary(meta, order = order, script_path = script_path)

  elapsed <- system.time({
    pdf(NULL)
    output_file <- tempfile()
    output_connection <- file(output_file, open = "wt")

    sink(output_connection)
    sink(output_connection, type = "message")

    on.exit({
      while (sink.number(type = "message") > 0) {
        sink(type = "message")
      }
      while (sink.number() > 0) {
        sink()
      }
      close(output_connection)
      if (dev.cur() > 1) {
        dev.off()
      }
      if (file.exists(output_file)) {
        unlink(output_file)
      }
    }, add = TRUE)

    suppressWarnings(
      suppressMessages(
        source(script_path, local = new.env())
      )
    )
  })["elapsed"]

  cat(sprintf("   Completed in %.1f seconds.\n", elapsed))
}

# ==============================================================================
# Run individual scripts
# ==============================================================================

scripts <- c(
  "pfts_maliau.R",
  "t_model_maliau.R",
  "pfts_maximum_height_maliau.R"
)

for (i in seq_along(scripts)) {
  run_script_quietly(scripts[i], order = i)
}

# ==============================================================================

cat(
  "================================================================================\n"
)
cat("All scripts completed successfully.\n")
cat(
  "================================================================================\n"
)
