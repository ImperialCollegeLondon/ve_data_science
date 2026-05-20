library(tidyverse)
source("tools/R/ve_run.R")

# Capture command line arguments
job_index <- as.integer(Sys.getenv("PBS_ARRAY_INDEX"))

# file paths
config_path <- "data/scenarios/sensitivity_soil_litter/config"
out_path <- paste0(
  "data/scenarios/sensitivity_soil_litter/out/",
  job_index
)
if (!dir.exists(out_path)) {
  dir.create(out_path)
}

# run VE
args <- c(
  config_path,
  "--out",
  out_path,
  "--logfile",
  paste0(out_path, "/logfile.log"),
  "--config",
  "core.debug.truncate_run_at_update=24"
)

tryCatch(
  {
    ve_run(args, condaenv = "hpc_jobs/virtual_ecosystem_py314")
  },
  error = function(e) {
    message("Error encountered during a run, see log.")
  }
)

# clear unused memory
gc()
