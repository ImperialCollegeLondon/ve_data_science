#| ---
#| title: master_scenarios
#|
#| description: |
#|   This is the master script for plant validation scenario output workflows.
#|   It runs scenario output-processing scripts sequentially and generates a
#|   metadata catalogue summarising the scripts and their standardised outputs.
#|   These workflows process Virtual Ecosystem outputs; they do not perform the
#|   comparison with observational validation datasets.
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
#|   - path: analysis/plant/output_data/validation/scenarios/plants_cohort_data_maliau_2.R
#|
#| output_files:
#|   - name: master_scenarios_metadata.yml
#|     path: analysis/plant/output_data/validation/metadata
#|     description: |
#|       This YAML file contains the combined metadata from all scenario output
#|       processing scripts listed in master_scenarios.R.
#|
#| package_dependencies:
#|   - yaml
#|
#| usage_notes: |
#|   Run this script from its directory to regenerate all plant validation
#|   scenario outputs and the combined metadata catalogue. Add new
#|   scenario-specific output-processing scripts to the scripts vector below.
#|   Observational validation datasets remain managed by the separate
#|   data_library/master_data_library.R workflow.
#| ---

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
    for (file in meta$input_files) {
      summary_lines <- c(
        summary_lines,
        sprintf("     - %s/%s", file$path, file$name),
        sprintf("       %s", gsub("\n", "\n       ", trimws(file$description)))
      )
    }
  }

  if (!is.null(meta$output_files)) {
    summary_lines <- c(summary_lines, "   Output files:")
    for (file in meta$output_files) {
      summary_lines <- c(
        summary_lines,
        sprintf("     - %s/%s", file$path, file$name),
        sprintf("       %s", gsub("\n", "\n       ", trimws(file$description)))
      )
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
  print_script_summary(meta, index, total, script_path)

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
    title = "master_scenarios_metadata",
    generated_by = "analysis/plant/output_data/validation/scenarios/master_scenarios.R",
    generated_on = as.character(Sys.Date()),
    scripts = script_metadata
  )
}

write_metadata_summary <- function(metadata_summary) {
  output_path <- "../metadata/master_scenarios_metadata.yml"
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

scripts <- c(
  "plants_cohort_data_maliau_2.R"
)

n_scripts <- length(scripts)

for (i in seq_along(scripts)) {
  run_script(scripts[i], index = i, total = n_scripts)
}

metadata_summary <- build_metadata_summary(scripts)
write_metadata_summary(metadata_summary)

message(
  paste(
    c(
      "================================================================================",
      "All validation scenario scripts completed successfully.",
      "================================================================================"
    ),
    collapse = "\n"
  )
)
