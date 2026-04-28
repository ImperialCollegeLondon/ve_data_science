source("tools/R/ve_run.R")

config_path <- "data/scenarios/sensitivity_soil_litter/config"
out_path <- "data/scenarios/sensitivity_soil_litter/out"

if (!dir.exists(out_path)) {
  dir.create(out_path)
}

args <- c(
  config_path,
  "--out",
  out_path,
  "--logfile",
  paste0(out_path, "/logfile.log"),
  "--config",
  "core.debug.truncate_run_at_update=4"
)
ve_run(args, venv = "./ve_develop")
