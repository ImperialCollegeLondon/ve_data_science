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
      extra_args = c("--config", "core.debug.truncate_run_at_update=30"),
      "ve_develop/Scripts"
    )
    toc()
  } |>
  futurize()

runtime_cli <- c(
  "24:23",
  "03:40",
  "06:39",
  "10:19",
  "14:07",
  "15:54",
  "17:48",
  "20:26",
  "22:07",
  "23:22"
)
runtime_cli <-
  sapply(runtime_cli, \(x) {
    parts <- as.numeric(strsplit(x, ":")[[1]])
    parts[1] * 60 + parts[2]
  })

write_rds(runtime, "data/derived/troubleshoot/runtime_per_cell/runtime.rds")
write_rds(
  runtime_cli,
  "data/derived/troubleshoot/runtime_per_cell/runtime_cli.rds"
)

runtime_df <- data.frame(
  time = sapply(runtime, \(x) {
    as.numeric(str_remove(x$callback_msg, " sec elapsed"))
  }),
  time_cli = runtime_cli,
  grid = str_remove(configs, "config_")
) |>
  mutate(
    ny = as.numeric(str_extract(grid, "^\\d+")),
    n_cell = ny * 10,
    time_per_cell = time / n_cell
  )

png(
  "data/derived/troubleshoot/runtime_per_cell/runtime.png",
  res = 300,
  width = 6,
  height = 4,
  units = "in"
)
ggplot(runtime_df) +
  geom_line(aes(n_cell, time_per_cell)) +
  geom_point(aes(n_cell, time_per_cell)) +
  labs(y = "Time elapsed per grid (s per grid)", x = "Number of grids") +
  scale_x_continuous(breaks = runtime_df$n_cell, labels = runtime_df$grid) +
  theme_bw()
dev.off()
