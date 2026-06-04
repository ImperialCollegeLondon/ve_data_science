library(tidyverse)
library(arrow)


# job array settings
n_runs <- 4800
job_id <- "2891288"
log_dir <- "../hpc_logs/logs"
tail_n <- 5

# retrieve the index of successful runs from the merged dataset
successful_runs <-
  open_dataset(
    "data/scenarios/sensitivity_soil_litter/out/all_continuous_data_merged.parquet"
  ) |>
  distinct(scenario) |>
  pull(scenario, as_vector = TRUE) |>
  as.numeric()

# get a list of failed runs
failed_runs <- setdiff(seq_len(n_runs), successful_runs)

errors <-
  map(
    failed_runs,
    \(run_id) {
      logfile <- file.path(log_dir, paste0(job_id, "[", run_id, "].pbs-7.ER"))
      if (file.exists(logfile)) {
        tail(read_lines(logfile), tail_n)
      } else {
        NA_character_
      }
    },
    .progress = TRUE
  )

# Remove NA elements
errors2 <- discard(errors, \(x) all(is.na(x)))
