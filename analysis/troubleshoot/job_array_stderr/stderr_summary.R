library(tidyverse)
library(arrow)


# job array settings
n_runs <- 4800
job_id <- "2891288"
log_dir <- "/rds/general/user/hlai1/home/logs"
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

# retrieve the last few lines from the stderr file of failed runs
errors <-
  map(
    failed_runs,
    \(run_id) {
      logfile <- file.path(log_dir, paste0(job_id, "[", run_id, "].pbs-7.ER"))
      tail(read_lines(logfile), tail_n)
    }
  )

# save stderr summary
summary_dir <- "data/derived/troubleshoot/job_array_stderr"
if (!dir.exists(summary_dir)) {
  dir.create(summary_dir, recursive = TRUE)
}
write_rds(errors, "data/derived/troubleshoot/job_array_stderr/errors.rds")
