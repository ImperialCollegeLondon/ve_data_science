---
jupyter:
  jupytext:
    cell_metadata_filter: all,-trusted
    notebook_metadata_filter: settings,mystnb,language_info,ve_data_science,-jupytext.text_representation.jupytext_version
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
  kernelspec:
    display_name: Python 3 (ipykernel)
    language: python
    name: python3
    path: C:\Users\User\AppData\Local\Python\pythoncore-3.14-64\share\jupyter\kernels\python3
title: "Correlations between VE data variables over simulation time steps"
author: Lai, Hao Ran
date: last-modified
format: gfm
execute:
  warning: false
  message: false
---

I explored this topic to investigate the feasibility of pairwise correlation
between state variables as an emergent validation target (inspired by Dietze's
*Ecological Forecasting*). Variable correlation tells us about process coupling,
joint responses and dimensionality of ecosystem. The dimensionality aspect is
something that I've been pursuing for a while.

However, this quickly turned into an ugly exercise, mainly because a lot of the
state variables in VE are deterministic, placeholder or have unresolved code.
These led to quirky correlations due to near-static variables and distinct
spinup vs. post-spinup correlations. It'll become clearer if you read the
figures below.

## Is between-variable correlations stationary?

```text {r}
#| label: setup
library(tidyverse)

here::i_am("analysis/soil/validation/reports/correlation_emergent.qmd")

source(here::here("tools/R/R/summarise_ve_config.R"))
scenario <- "maliau_2"
if (dir.exists(scenario)) {
  out_dir <- scenario
} else if (dir.exists(here::here(scenario))) {
  out_dir <- here::here(scenario)
} else {
  scenario_dirs <- list.dirs(
    here::here("data/scenarios"),
    recursive = TRUE,
    full.names = TRUE
  )
  scenario_dirs <- scenario_dirs[basename(scenario_dirs) == scenario]
  if (length(scenario_dirs) != 1L) {
    stop("Supply a scenario name with one match or a full output path.")
  }
  out_dir <- file.path(scenario_dirs, "out")
}

config_path <- file.path(out_dir, "compiled_configuration.toml")
log_path <- file.path(out_dir, "logfile.log")
if (!all(file.exists(c(config_path, log_path)))) {
  stop("The selected output directory must contain both run files.")
}

correlations_path <- here::here(
  "data/derived/soil/validation/emergent/correlations.parquet"
)
```

```text {r}
#| label: prepare-state-correlations
source(here::here("tools/R/R/valdb_build.R"))
source(here::here("tools/R/R/get_ve_variables.R"))
source(here::here("tools/R/R/tidy_continuous_data.R"))

data_vars <- names(build_data_variables_table(variables_derived = NULL))

states <-
  tidy_continuous_data(
    here::here("data/scenarios/maliau/maliau_2/out/model_data.zarr"),
    variables = NULL,
    initial = TRUE
  ) |>
  filter(variable %in% data_vars) |>
  mutate(value = as.numeric(value)) |>
  unite(
    "full_name",
    variable,
    layers,
    pft,
    element,
    community_id,
    functional_group_id,
    groundwater_layers,
    na.rm = TRUE
  )

if (!file.exists(correlations_path)) {
  # Calculate each time step separately to track changing correlations.
  correlations <-
    states |>
    group_by(timestamp) |>
    group_modify(\(.x, .y) {
      values <-
        .x |>
        select(cell_id, full_name, value) |>
        pivot_wider(names_from = full_name, values_from = value) |>
        select(-cell_id) |>
        as.matrix()

      correlation <- cor(
        values,
        method = "spearman",
        use = "pairwise.complete.obs"
      )
      # Pairwise sample sizes vary when different variables have missing cells.
      pairwise_n <- crossprod(!is.na(values))

      as.data.frame(as.table(correlation)) |>
        as_tibble() |>
        rename(
          full_name_1 = Var1,
          full_name_2 = Var2,
          correlation = Freq
        ) |>
        mutate(n_cells = as.vector(pairwise_n)) |>
        # Keep one alphabetically ordered row per pair; drop self-correlations.
        filter(as.character(full_name_1) < as.character(full_name_2))
    }) |>
    ungroup()

  correlations |>
    filter(!is.na(correlation)) |>
    arrow::write_parquet(correlations_path)
}
```

```text {r}
#| label: plot-maom-cn-correlation
correlations <- arrow::read_parquet(correlations_path)

correlations |>
  filter(
    full_name_1 == "soil_cnp_pool_maom_C",
    full_name_2 == "soil_cnp_pool_maom_N"
  ) |>
  ggplot() +
  geom_line(aes(timestamp, correlation)) +
  theme_minimal()
```

```text {r}
#| label: summarize-correlation-variability
corr_sd <-
  correlations |>
  summarise(corr_sd = sd(correlation), .by = c(full_name_1, full_name_2))

corr_sd_top_bottom <-
  bind_rows(
    slice_max(corr_sd, order_by = corr_sd, n = 10, with_ties = FALSE) |>
      mutate(panel = "Highest correlation SD"),
    slice_min(corr_sd, order_by = corr_sd, n = 10, with_ties = FALSE) |>
      mutate(panel = "Lowest correlation SD")
  )

corr_sd_top_bottom
```

```text {r}
#| label: plot-extreme-correlation-series
#| fig-width: 14
#| fig-height: 10

correlation_series <-
  correlations |>
  inner_join(
    corr_sd_top_bottom |> select(full_name_1, full_name_2, panel),
    by = c("full_name_1", "full_name_2")
  ) |>
  mutate(pair = paste(full_name_1, full_name_2, sep = " vs."))

correlation_labels <-
  correlation_series |>
  slice_max(timestamp, n = 1, with_ties = FALSE, by = c(panel, pair))

correlation_series |>
  ggplot(aes(timestamp, correlation, colour = pair)) +
  geom_line() +
  ggrepel::geom_text_repel(
    data = correlation_labels,
    aes(label = pair),
    direction = "y",
    hjust = 0,
    nudge_x = diff(range(correlation_series$timestamp)) * 0.02,
    max.overlaps = Inf,
    seed = 1,
    size = 3
  ) +
  facet_wrap(~panel, ncol = 1, scales = "free_y") +
  scale_x_continuous(expand = expansion(mult = c(0.02, 1))) +
  labs(x = "Timestamp", y = "Spearman correlation") +
  theme_minimal() +
  theme(legend.position = "none")
```

View the same correlation series separately for each variable pair. Each panel
uses its own y-axis range to show changes within the pair.

```text {r}
#| label: plot-correlation-series-by-pair
#| fig-width: 14
#| fig-height: 20

correlation_series |>
  ggplot(aes(timestamp, correlation, colour = pair)) +
  geom_line() +
  facet_wrap(
    ~pair,
    ncol = 2,
    scales = "free_y",
    labeller = label_wrap_gen(width = 55)
  ) +
  labs(x = "Timestamp", y = "Spearman correlation") +
  theme_minimal() +
  theme(legend.position = "none")
```

```text {r}
#| label: plot-paired-state-values
#| fig-width: 14
#| fig-height: 20

phase_data <-
  correlation_series |>
  distinct(full_name_1, full_name_2, pair) |>
  inner_join(
    states |>
      select(timestamp, cell_id, full_name, value) |>
      rename(full_name_1 = full_name, value_1 = value),
    by = "full_name_1"
  ) |>
  inner_join(
    states |>
      select(timestamp, cell_id, full_name, value) |>
      rename(full_name_2 = full_name, value_2 = value),
    by = c("full_name_2", "timestamp", "cell_id")
  )

phase_data |>
  ggplot(aes(value_1, value_2, colour = timestamp)) +
  geom_point(alpha = 0.3, size = 0.5) +
  facet_wrap(
    ~pair,
    ncol = 5,
    scales = "free",
    labeller = label_wrap_gen(width = 55)
  ) +
  labs(x = "full_name_1 value", y = "full_name_2 value", colour = "Timestamp") +
  theme_minimal()
```

## Virtual Ecosystem configuration

```text {r}
#| label: ve-config
#| echo: false
#| results: asis

invisible(summarise_ve_config(config_path, log_path, dev = FALSE))
```
