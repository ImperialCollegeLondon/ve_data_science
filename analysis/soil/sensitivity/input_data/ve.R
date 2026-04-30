library(tidyverse)
library(mirai)


# file paths
config_paths <-
  list.dirs("data/scenarios/sensitivity_soil_litter/config", recursive = FALSE)
out_paths <- str_replace(config_paths, "config", "out")
walk(out_paths, \(path) {
  if (!dir.exists(path)) {
    dir.create(path)
  }
})

paths <- data.frame(config = config_paths, out = out_paths)
path_list <- split(paths, 1:nrow(paths))

# run VE
daemons(5)

ve_runs <- map(
  path_list,
  # in_parallel(
  \(path) {
    # argument string
    args <- c(
      path$config,
      "--out",
      path$out,
      "--logfile",
      paste0(path$out, "/logfile.log"),
      "--config",
      "core.debug.truncate_run_at_update=24"
    )

    source("tools/R/ve_run.R")

    tictoc::tic()
    ve_run(args, venv = "./ve_develop")
    tictoc::toc()
  }
  # )
)

daemons(0)
