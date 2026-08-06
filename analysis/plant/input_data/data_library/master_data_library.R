#| ---
#| title: master_data_library
#|
#| description: |
#|     This is the master script for the plant data library.
#|     It runs all individual data library scripts sequentially and generates
#|     the full set of plant input data files for the data library.
#|     Each individual script is self-contained and can also be run independently.
#|     In addition, this script generates a metadata catalogue summarising the
#|     metadata from all scripts in the data library workflow.
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
#| output_files:
#|   - name: master_data_library_metadata.yml
#|     path: analysis/plant/input_data/metadata
#|     description: |
#|       This YAML file contains the combined metadata from all scripts listed
#|       in master_data_library.R.
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

library(yaml)

read_script_metadata <- function(script_path) {
  if (!file.exists(script_path)) {
    stop(sprintf("Script not found: %s", script_path))
  }

  lines <- readLines(script_path)
  yaml_lines <- lines[grepl("^#\\|", lines)]
  yaml_text <- gsub("^#\\| ?", "", yaml_lines)

  yaml::yaml.load(paste(yaml_text, collapse = "\n"))
}

print_script_summary <- function(meta, index, total, script_path) {
  summary_lines <- c(
    "================================================================================",
    sprintf("Script %d/%d: %s", index, total, meta$title),
    sprintf("   Script:      %s", script_path),
    sprintf("   Status:      %s", meta$status),
    sprintf("   Author:      %s", paste(meta$author, collapse = ", ")),
    sprintf(
      "   Module:      %s",
      paste(meta$virtual_ecosystem_module, collapse = ", ")
    ),
    "   Description:",
    sprintf("     %s", gsub("\n", "\n     ", trimws(meta$description)))
  )

  if (!is.null(meta$package_dependencies)) {
    summary_lines <- c(
      summary_lines,
      "   Package dependencies:",
      sprintf("     - %s", meta$package_dependencies)
    )
  }

  if (!is.null(meta$input_files)) {
    summary_lines <- c(summary_lines, "   Input files:")
    for (f in meta$input_files) {
      summary_lines <- c(
        summary_lines,
        sprintf("     - %s/%s", f$path, f$name),
        sprintf("       %s", gsub("\n", "\n       ", trimws(f$description)))
      )
    }
  }

  if (!is.null(meta$output_files)) {
    summary_lines <- c(summary_lines, "   Output files:")
    for (f in meta$output_files) {
      summary_lines <- c(
        summary_lines,
        sprintf("     - %s/%s", f$path, f$name),
        sprintf("       %s", gsub("\n", "\n       ", trimws(f$description)))
      )

      if (!is.null(f$variables)) {
        summary_lines <- c(summary_lines, "       Variables:")
        for (v in f$variables) {
          summary_lines <- c(
            summary_lines,
            sprintf(
              "         - %s (%s, %s): %s",
              v$name,
              v$type,
              v$units,
              trimws(v$description)
            )
          )
        }
      }
    }
  }

  if (!is.null(meta$usage_notes)) {
    summary_lines <- c(
      summary_lines,
      "   Usage notes:",
      sprintf("     %s", gsub("\n", "\n     ", trimws(meta$usage_notes)))
    )
  }

  summary_lines <- c(
    summary_lines,
    "================================================================================"
  )

  message(paste(summary_lines, collapse = "\n"))
}

run_script <- function(script_path, index, total) {
  meta <- read_script_metadata(script_path)

  print_script_summary(
    meta = meta,
    index = index,
    total = total,
    script_path = script_path
  )

  pdf(NULL)
  on.exit(
    {
      if (dev.cur() > 1) {
        dev.off()
      }
    },
    add = TRUE
  )

  invisible(
    capture.output(
      suppressMessages(
        suppressPackageStartupMessages(
          source(script_path, local = new.env())
        )
      ),
      type = "output"
    )
  )
}

build_metadata_summary <- function(script_paths) {
  script_metadata <- lapply(script_paths, function(script_path) {
    meta <- read_script_metadata(script_path)
    c(list(script_path = script_path), meta)
  })

  list(
    title = "master_data_library_metadata",
    generated_by = "analysis/plant/input_data/data_library/master_data_library.R",
    generated_on = as.character(Sys.Date()),
    scripts = script_metadata
  )
}

write_metadata_summary <- function(metadata_summary) {
  output_path <- "../metadata/master_data_library_metadata.yml"
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
# Run individual scripts
# ==============================================================================

scripts <- c(
  "pfts_maliau.R",
  "t_model_maliau.R",
  "pfts_maximum_height_maliau.R"
)

n_scripts <- length(scripts)

for (i in seq_along(scripts)) {
  run_script(scripts[i], index = i, total = n_scripts)
}

metadata_summary <- build_metadata_summary(scripts)
write_metadata_summary(metadata_summary)

# ==============================================================================

message(
  paste(
    c(
      "================================================================================",
      "All scripts completed successfully.",
      "================================================================================"
    ),
    collapse = "\n"
  )
)
