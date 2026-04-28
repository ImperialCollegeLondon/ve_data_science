library(mirai)

source("tools/R/ve_run.R")

# file paths
config_path <- "data/scenarios/sensitivity_soil_litter/config"
out_path <- "data/scenarios/sensitivity_soil_litter/out"
if (!dir.exists(out_path)) {
  dir.create(out_path)
}

# argument string
args <- c(
  config_path,
  "--out",
  out_path,
  "--logfile",
  paste0(out_path, "/logfile.log"),
  "--config",
  "core.debug.truncate_run_at_update=24"
)

# run VE

daemons(4)

tictoc::tic()
ve_run(args, venv = "./ve_develop")
tictoc::toc()

daemons(0)
