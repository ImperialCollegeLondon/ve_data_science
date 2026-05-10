library(tidyverse)
library(mirai)
source("tools/R/ve_run.R")


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
daemons(128)

ve_runs <- map(
  path_list,
  in_parallel(
    \(path) {
      # argument string
      args <- c(
        path$config,
        "--out",
        path$out,
        "--logfile",
        paste0(path$out, "/logfile.log")
      )

      tryCatch(
        {
          ve_run(args, condaenv = "hpc_jobs/virtual_ecosystem_py314")
        },
        error = function(e) {
          message("Error encountered during a run, see log.")
        }
      )
    },
    ve_run = ve_run
  )
)

daemons(0)
