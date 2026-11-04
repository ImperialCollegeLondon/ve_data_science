library(mirai)
library(tidyverse)
library(arrow)
source("tools/R/R/get_ve_variables.R")
source("tools/R/R/tidy_continuous_data.R")

project_root <- here::here()
out_path <- file.path(project_root, "data/sensitivity/soil_litter_inputs/out")
sobol_path <- file.path(
  project_root,
  "data/sensitivity/soil_litter_inputs/data/sobol_matrix.rds"
)
merged_output_path <- file.path(out_path, "all_continuous_data_merged.parquet")
parallel_daemons <- 128

if (!dir.exists(out_path)) {
  stop(sprintf("Output path does not exist: %s", out_path))
}
if (!file.exists(sobol_path)) {
  stop(sprintf("Sobol matrix does not exist: %s", sobol_path))
}

expected_scenarios <- nrow(readRDS(sobol_path))
zarr_paths <- list.dirs(out_path, recursive = TRUE, full.names = TRUE)
zarr_paths <- zarr_paths[basename(zarr_paths) == "model_data.zarr"]
if (length(zarr_paths) != expected_scenarios) {
  stop(sprintf(
    "Zarr output count mismatch: expected %s, got %s",
    expected_scenarios,
    length(zarr_paths)
  ))
}

scenario_ids <- as.integer(sub(
  "^array_subJob_",
  "",
  basename(dirname(zarr_paths))
))
if (anyNA(scenario_ids) || anyDuplicated(scenario_ids)) {
  stop("Zarr output directories must have unique array_subJob_<index> names.")
}
if (!setequal(scenario_ids, seq_len(expected_scenarios))) {
  stop("Zarr output directories do not match the Sobol scenario indices.")
}

first_output <- get_data_variables(zarr_paths[[1]], group = "outputs")
output_variables <- names(first_output)[
  purrr::map_lgl(
    first_output,
    \(x) "time_index" %in% names(dimnames(x))
  )
] |>
  setdiff(c("timestamp", "time_index", "x", "y"))
if (length(output_variables) == 0) {
  stop("No time-varying state variables found in the Zarr outputs.")
}

daemons(parallel_daemons)
merged <- map(
  zarr_paths,
  in_parallel(
    \(zarr_path) {
      require(tidyverse)
      source("tools/R/R/get_ve_variables.R")
      source("tools/R/R/tidy_continuous_data.R")

      tidy_continuous_data(
        path = zarr_path,
        variables = output_variables
      ) |>
        mutate(
          scenario = as.integer(sub(
            "^array_subJob_",
            "",
            basename(dirname(zarr_path))
          ))
        ) |>
        unite(
          "variable",
          variable,
          element,
          layers,
          groundwater_layers,
          pft,
          na.rm = TRUE,
          remove = TRUE
        )
    },
    output_variables = output_variables
  )
) |>
  list_rbind()
daemons(0)

if (!setequal(unique(merged$scenario), seq_len(expected_scenarios))) {
  stop("Merged Zarr data are missing one or more Sobol scenarios.")
}

write_parquet(merged, merged_output_path)
