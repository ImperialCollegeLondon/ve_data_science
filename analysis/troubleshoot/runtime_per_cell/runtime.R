#| ---
#| title: Subset maliau_2 scenario datasets to examine runtime per grid
#|
#| description: |
#|     Subset the maliau_2 scenario datasets into 1x10, 2x10, ... 10x10 grids
#|     to examine the amount of runtime per grid. The output data and configs
#|     are analysed in analysis/troubleshoot/runtime_per_cell/runtime.R
#|
#| virtual_ecosystem_module: All
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|
#| output_files:
#|   - name: runtime.rds
#|     path: data/derived/troubleshoot/runtime_per_cell
#|     description: |
#          Results of total runtime and runtime per grid against grid number
#|   - name: runtime.png
#|     path: data/derived/troubleshoot/runtime_per_cell
#|     description: |
#          Plot of total runtime and runtime per grid against grid number
#|
#| package_dependencies:
#|     - tidyverse
#|     - ve.utils
#|     - tictoc
#|     - foreach
#|     - ggpubr
#|
#| usage_notes:
#| ---

library(tidyverse)
library(ve.utils)
library(tictoc)
library(foreach)
library(ggpubr)


# Set up config and output directories -----------------------------------

config_dir <- "data/scenarios/runtime_per_cell/config"
configs <- list.dirs(config_dir, full.names = FALSE, recursive = FALSE)

out_dir <- "data/scenarios/runtime_per_cell/out/"
outs <- paste0(out_dir, str_replace(configs, "config", "out"))


# Run each grid-size scenario --------------------------------------------

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

# save output once
write_rds(runtime, "data/derived/troubleshoot/runtime_per_cell/runtime.rds")

# read output again (to skip having to re-run VE next time)
runtime <- read_rds("data/derived/troubleshoot/runtime_per_cell/runtime.rds")

# tidy up results
runtime_df <- data.frame(
  # collect total time elapsed
  time = sapply(runtime, \(x) {
    as.numeric(str_remove(x$callback_msg, " sec elapsed"))
  }),
  grid = str_remove(configs, "config_")
) |>
  # calculate time elapsed per grid
  mutate(
    ny = as.numeric(str_extract(grid, "^\\d+")),
    n_cell = ny * 10,
    time_per_cell = time / n_cell
  )

# Visualise
# total runtime
p_total <-
  ggplot(runtime_df) +
  geom_line(aes(n_cell, time)) +
  geom_point(aes(n_cell, time)) +
  labs(y = "Total time elapsed (s)", x = "Number of grids") +
  scale_x_continuous(breaks = runtime_df$n_cell, labels = runtime_df$grid) +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 90))
# runtime per grid
p_per_cell <-
  ggplot(runtime_df) +
  geom_line(aes(n_cell, time_per_cell)) +
  geom_point(aes(n_cell, time_per_cell)) +
  labs(y = "Time elapsed per grid (s per grid)", x = "Number of grids") +
  scale_x_continuous(breaks = runtime_df$n_cell, labels = runtime_df$grid) +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 90))

# save plot
png(
  "data/derived/troubleshoot/runtime_per_cell/runtime.png",
  res = 300,
  width = 6,
  height = 3,
  units = "in"
)
ggarrange(p_total, p_per_cell)
dev.off()
