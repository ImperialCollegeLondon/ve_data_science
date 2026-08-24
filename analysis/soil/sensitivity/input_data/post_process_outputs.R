library(mirai)
library(tidyverse)
library(arrow)

out_path <- "data/scenarios/sensitivity_soil_litter/out"
parallel_daemons <- 128
expected_scenarios <- 4800
continuous_output_filename <- "all_continuous_data.nc"
merged_output_filename <- "all_continuous_data_merged.parquet"

if (!dir.exists(out_path)) {
  stop(sprintf("Output path does not exist: %s", out_path))
}
if (!file.exists("tools/R/get_data_variables.R")) {
  stop("Required helper script is missing: tools/R/get_data_variables.R")
}

out_files <- list.files(
  out_path,
  pattern = continuous_output_filename,
  recursive = TRUE
)
if (length(out_files) == 0) {
  stop("No model output files found for post-processing.")
}
if (length(out_files) != expected_scenarios) {
  stop(sprintf(
    "Output file count mismatch: expected %s, got %s",
    expected_scenarios,
    length(out_files)
  ))
}

daemons(parallel_daemons)
merged <- map(
  out_files,
  in_parallel(
    \(out_file) {
      require(tidyverse)
      require(reshape2)
      require(tidync)
      source("tools/R/get_data_variables.R")

      tidync(file.path(out_path, out_file)) |>
        get_data_variables() |>
        melt() |>
        mutate(
          scenario = sub("/.*", "", out_file),
          value = as.numeric(value)
        ) |>
        filter(!is.na(value)) |>
        unite(
          "variable",
          L1,
          element,
          layers,
          groundwater_layers,
          pft,
          na.rm = TRUE,
          remove = TRUE
        ) |>
        select(-cell_id)
    },
    out_path = out_path
  )
) |>
  list_rbind()
daemons(0)

if (!"scenario" %in% names(merged)) {
  stop("Merged output is missing required scenario column.")
}

expected_scenarios <- as.character(seq_len(expected_scenarios))
actual_scenarios <- unique(merged$scenario)
missing_scenarios <- setdiff(expected_scenarios, actual_scenarios)
if (length(missing_scenarios) > 0) {
  stop(sprintf(
    "Merged output is missing scenario(s): %s",
    paste(missing_scenarios, collapse = ", ")
  ))
}

write_parquet(merged, file.path(out_path, merged_output_filename))
