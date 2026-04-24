library(tidyverse)
library(ve.utils)
library(tictoc)


config_dir <- "data/scenarios/runtime_per_cell/config"
configs <- list.dirs(config_dir, full.names = FALSE, recursive = FALSE)

out_dir <- "data/scenarios/runtime_per_cell/out"
outs <- paste0(out_dir, str_replace(configs, "config", "out"))

runtime <- numeric(length(configs))
names(runtime) <- str_remove(configs, "config_")

for (i in seq_along(outs)) {
  if (!dir.exists(outs[i])) {
    dir.create(outs[i])
  }

  tic()
  ve_run(
    paste0(config_dir, "/", configs[i]),
    outs[i],
    paste0(outs[i], "/logfile.log"),
    "ve_release/Scripts"
  )
  runtime[i] <- toc()
}
