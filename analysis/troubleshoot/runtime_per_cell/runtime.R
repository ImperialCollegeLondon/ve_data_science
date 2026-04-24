library(tidyverse)
library(ve.utils)
library(tictoc)
library(foreach)
library(futurize)
plan(multisession)


config_dir <- "data/scenarios/runtime_per_cell/config"
configs <- list.dirs(config_dir, full.names = FALSE, recursive = FALSE)

out_dir <- "data/scenarios/runtime_per_cell/out/"
outs <- paste0(out_dir, str_replace(configs, "config", "out"))

runtime <- foreach(out = outs, config = configs) %do%
  {
    if (!dir.exists(out)) {
      dir.create(out)
    }

    tic()
    ve_run(
      paste0(config_dir, "/", config),
      out,
      paste0(out, "/logfile.log"),
      "ve_develop/Scripts"
    )
    toc()
  } |>
  futurize()
