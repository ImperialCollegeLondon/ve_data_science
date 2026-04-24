library(ve.utils)
library(tictoc)

# run with exports
tic()
ve_run(
  "data/scenarios/maliau/maliau_2/config",
  "data/scenarios/maliau/maliau_2/out",
  "data/scenarios/maliau/maliau_2/out/logfile.log",
  extra_args = c("--config", "core.debug.truncate_run_at_update=30"),
  "ve_develop/Scripts"
)
runtime_with_exports <- toc()

# run without exports
tic()
ve_run(
  "data/scenarios/maliau/maliau_2_no_export/config",
  "data/scenarios/maliau/maliau_2_no_export/out",
  "data/scenarios/maliau/maliau_2_no_export/out/logfile.log",
  extra_args = c("--config", "core.debug.truncate_run_at_update=30"),
  "ve_develop/Scripts"
)
runtime_without_exports <- toc()
