library(tidyverse)
library(ve.utils)
library(tictoc)
library(foreach)
library(ggpubr)


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
      cfg_paths = paste0(config_dir, "/", config),
      outpath = out,
      logfile = paste0(out, "/logfile.log"),
      env = "ve_develop/Scripts"
    )
    toc()
  }
write_rds(runtime, "data/derived/troubleshoot/runtime_per_cell/runtime.rds")

runtime <- read_rds("data/derived/troubleshoot/runtime_per_cell/runtime.rds")

runtime_df <- data.frame(
  time = sapply(runtime, \(x) {
    as.numeric(str_remove(x$callback_msg, " sec elapsed"))
  }),
  grid = str_remove(configs, "config_")
) |>
  mutate(
    ny = as.numeric(str_extract(grid, "^\\d+")),
    n_cell = ny * 10,
    time_per_cell = time / n_cell
  )

p_total <-
  ggplot(runtime_df) +
  geom_line(aes(n_cell, time)) +
  geom_point(aes(n_cell, time)) +
  labs(y = "Total time elapsed (s)", x = "Number of grids") +
  scale_x_continuous(breaks = runtime_df$n_cell, labels = runtime_df$grid) +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 90))
p_per_cell <-
  ggplot(runtime_df) +
  geom_line(aes(n_cell, time_per_cell)) +
  geom_point(aes(n_cell, time_per_cell)) +
  labs(y = "Time elapsed per grid (s per grid)", x = "Number of grids") +
  scale_x_continuous(breaks = runtime_df$n_cell, labels = runtime_df$grid) +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 90))

png(
  "data/derived/troubleshoot/runtime_per_cell/runtime.png",
  res = 300,
  width = 6,
  height = 3,
  units = "in"
)
ggarrange(p_total, p_per_cell)
dev.off()
