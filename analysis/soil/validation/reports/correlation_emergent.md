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

```text {r}
#| label: libraries
library(tidyverse)
library(here)
library(arrow)
library(ggrepel)
```

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

So I don't think any of these will make it into the near-term validation
deliveries, but some findings may benefit long-term thinking.

NB: I will be printing VE settings and version at the *bottom* of reports from
now on.

This report addresses
[Issue #776](https://github.com/ImperialCollegeLondon/ve_data_science/issues/776).

## Is between-variable correlations stationary?

First I wanted to know if the correlation between any two state variables $X_1$
and $X_2$ change over simulation time steps. This helps to set expectation on
whether these correlations (or covariances) are universal or local emergent
properties. Jacob helpfully pointed out that these correlations are probably
non-stationary:

> ...these types of validation targets breakdown in extreme scenarios. e.g. even
> in the soil temperature microbial activity case (which is a strong correlation
> as there's a direct mechanical link) we would expect the correlation to break
> down in El Niño droughts (because the soil becomes both hot and dry), which
> should occur a couple of times in our Maliau simulation period.
> 
> There's a similar problem with soil C and N. Generally the ratio of these two
> is a good heuristic for characterising soils. So we would expect them to be
> correlated, provided the soil doesn't change much. This probably makes it a
> viable validation target for the Maliau simulation (2010--2020), but not for
> longer simulations (because of climate change) or at SAFE (where there is a
> massive logging event mid simulation).

I agree, but let's take a look. The code below is long but basically it:

1. Extract initial and continuous data variables from a VE run
2. Compute pairwise correlation between variables across grids
   *for each time step*
3. Select the top-10 and bottom-10 pairs by temporal variability in correlation
   (showing all pairs would give illegible plot)

I opted for Spearman's correlation because many data variables are skewed and
fat-tailed. Spearman's correlation is rank-ordered and less prone to extreme
values.

```text {r}
#| label: setup

i_am("analysis/soil/validation/reports/correlation_emergent.qmd")
source(here("tools/R/R/summarise_ve_config.R"))
out_dir <- here("data/scenarios/maliau/maliau_2/out")
config_path <- file.path(out_dir, "compiled_configuration.toml")
log_path <- file.path(out_dir, "logfile.log")
if (!all(file.exists(c(config_path, log_path)))) {
  stop("The selected output directory must contain both run files.")
}
correlations_path <- here(
  "data/derived/soil/validation/emergent/correlations.parquet"
)
states_path <- here(
  "data/derived/soil/validation/emergent/states.parquet"
)
```

```text {r}
#| label: prepare-state-correlations
if (!file.exists(states_path)) {
  source(here("tools/R/R/valdb_build.R"))
  source(here("tools/R/R/get_ve_variables.R"))
  source(here("tools/R/R/tidy_continuous_data.R"))

  data_vars <- names(build_data_variables_table(variables_derived = NULL))

  states <-
    tidy_continuous_data(
      here("data/scenarios/maliau/maliau_2/out/model_data.zarr"),
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

  write_parquet(states, states_path)
}

states <- read_parquet(states_path)

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
    write_parquet(correlations_path)
}

correlations <- read_parquet(correlations_path)
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
  geom_text_repel(
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

Immediately I see something unexpected. I expected many pairwise correlations to
be stably fluctuating around a mean, and some showing direction drift over time.
On one hand, for the low-variability ten, we see them having constant Spearman's
correlation (constant at 1; but this is a property of Spearman's correlation not
because we are correlating two static or perfectly correlated variables.) On the
other hand, the top-variability pairs not only exhibited lots of change but such
a change spanned -1 to 1. This flipping behaviour prompted me to take a closer
look at the actual scatter plots.

```text {r}
#| label: plot-paired-state-values
#| fig-width: 14
#| fig-height: 34

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

phase_plots <-
  phase_data |>
  group_split(pair) |>
  map(\(pair_data) {
    ggplot(pair_data, aes(value_1, value_2, colour = timestamp)) +
      geom_point(alpha = 0.3, size = 0.5) +
      scale_colour_viridis_c() +
      labs(
        x = first(pair_data$full_name_1),
        y = first(pair_data$full_name_2),
        colour = "Timestamp"
      ) +
      theme_minimal() +
      theme(axis.title = element_text(size = 8))
  })

patchwork::wrap_plots(phase_plots, ncol = 4, guides = "collect") &
  theme(legend.position = "bottom")
```

In the phase diagram, each point is a grid--time datum, coloured by time step.
In many of the phase panels, the initial conditions were uncorrelated (fuzzy
cloud) but the variable pairs converged to usually both having low values.
There, quirky but possibly biologically-meaningless cloud can give either very
positive or very negative correlations.

A lot of these are plant (and hence litter) related variables. The plants are
still dying off in the recent and latest simulation. Until the plant module is
ironed out, I'm afraid this direction is not worth our time.

## Extra note on dimensionality

If we can meaningfully extract information from state-variable correlations, it
may lead to a useful exploration of ecosystem dimensionality. For example, how
many dimensions do we need to describe an ecosystem? Does this dimensionality
change with productivity or latitude or network complexity? Do disturbance
reduce dimensionality? Are high-dimensional ecosystem more stable or resilient?

I certainly expect an ecosystem's dimensionality to be much lower than its total
number of components or state variables. Thinking along this line can be helpful
for calibration (which suffers from high dimensionality, but perhaps
unnecessarily).

## Virtual Ecosystem configuration

```text {r}
#| label: ve-config
#| echo: false
#| results: asis

invisible(summarise_ve_config(config_path, log_path, dev = FALSE))
```
