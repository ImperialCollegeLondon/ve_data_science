#| ---
#| title: master_scenarios
#|
#| description: |
#|     This is the master script for the plant scenario workflows.
#|     It runs all scenario scripts sequentially and generates a metadata
#|     catalogue summarising the metadata from those scripts.
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
#|   - path: analysis/plant/input_data/scenarios/plant_cohort_data_maliau_2.R
#|   - path: analysis/plant/input_data/scenarios/plant_input_data_maliau_2.R
#|   - path: analysis/plant/input_data/scenarios/plant_pft_definitions_maliau_2.R
#|   - path: analysis/plant/input_data/scenarios/plant_constants_maliau_2.R
#|
#| output_files:
#|   - name: master_scenarios_metadata.yml
#|     path: analysis/plant/input_data/metadata
#|     description: |
#|       This YAML file contains the combined metadata from all scenario
#|       scripts listed in master_scenarios.R.
#|
#| package_dependencies:
#|   - yaml
#|
#| usage_notes: |
#|   Run this script to regenerate all plant scenario input files and the
#|   combined metadata catalogue. The scripts are run in the order listed
#|   above because later scenarios may depend on earlier outputs.
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

      if (!is.null(file$variables)) {
        summary_lines <- c(summary_lines, "       Variables:")
        for (variable in file$variables) {
          summary_lines <- c(
            summary_lines,
            sprintf(
              "         - %s (%s, %s): %s",
              variable$name,
              variable$type,
              variable$units,
              trimws(variable$description)
            )
          )

          if (!is.null(variable$references)) {
            for (reference in variable$references) {
              for (field in c(
                "citation",
                "doi",
                "url",
                "origin",
                "biome",
                "vegetation_type",
                "site_condition",
                "date"
              )) {
                if (!is.null(reference[[field]])) {
                  summary_lines <- c(
                    summary_lines,
                    sprintf(
                      "           %s: %s",
                      field,
                      trimws(as.character(reference[[field]]))
                    )
                  )
                }
              }
            }
          }

          if (!is.null(variable$assumptions)) {
            summary_lines <- c(
              summary_lines,
              sprintf(
                "           assumptions: %s",
                gsub(
                  "\n",
                  "\n             ",
                  trimws(variable$assumptions)
                )
              )
            )
          }
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
    generated_by = "analysis/plant/input_data/scenarios/master_scenarios.R",
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
  "plant_cohort_data_maliau_2.R",
  "plant_input_data_maliau_2.R",
  "plant_pft_definitions_maliau_2.R",
  "plant_constants_maliau_2.R"
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
      "All scenario scripts completed successfully.",
      "================================================================================"
    ),
    collapse = "\n"
  )
)
