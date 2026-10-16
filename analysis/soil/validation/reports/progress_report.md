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
    path: C:\Users\User\Documents\ve_data_science\.venv\share\jupyter\kernels\python3
title: "Soil--Litter validation progress report"
author: Lai, Hao Ran
date: last-modified
format: gfm
execute:
  warning: false
  message: false
---

## Progress over the past few months

- I built a validation database pipeline, see docs
  [here](https://github.com/ImperialCollegeLondon/ve_data_science/blob/main/docs/validation_database.md).
- I screened, added and harmonised datasets using the database functions.
- I did not limit datasets to only Maliau or old growth. I included SAFE and
  disturbed forests since we will need them in future scenarios. The database
  has spatial coordinates, so I can filter to what we need (and combine them
  with any GIS layer, including SAFE layers).
- I also did a broader search using the OpenAlex website.
- Most of my effort went into harmonisation, including units and derived
  variables.

As VE is being developed, the results below will likely change dramatically (we
are already seeing this going from v0.2.1 to v0.2.3); therefore I'll focus on
the overall findings.

```text {r}
#| label: setup

library(knitr)
library(tidyverse)
library(patchwork)
library(arrow)
library(sf)
library(toml)
library(here)
library(yardstick)
source(here("tools/R/R/valdb.R"))
source(here("tools/R/R/summarise_ve_config.R"))

# Read the validation database
val_db_combined <-
  open_dataset(here("data/derived/soil/validation/database_combined")) |>
  collect()
```

## Simulation settings

```text {r}
#| label: ve-config
#| results: asis

out_dir <- here("data/scenarios/maliau/maliau_2/out")
invisible(summarise_ve_config(
  file.path(out_dir, "compiled_configuration.toml"),
  file.path(out_dir, "logfile.log")
))
```

## Datasets included

```text {r}
#| label: screened-datasets
screened <- list_screening_records(here("data/derived/soil/validation/sources"))
n_screened <- length(screened)
n_excluded <- sum(map_lgl(screened, ~ .x$screening$decision == "exclude"))
n_deferred <- sum(map_lgl(screened, ~ .x$screening$decision == "defer"))
n_datasets <- length(unique(val_db_combined$dataset))
n_data <- nrow(val_db_combined)
screened_summary <- screened |>
  map_dfr(
    \(x) {
      tibble(
        decision = x$screening$decision,
        reason = x$screening$reason,
        notes = x$screening$notes %||% ""
      )
    }
  )

n_excluded_no_relevant_variables <- sum(
  screened_summary$decision == "exclude" &
    screened_summary$reason == "no_relevant_variables"
)
n_excluded_insufficient_metadata <- sum(
  screened_summary$decision == "exclude" &
    screened_summary$reason == "insufficient_metadata"
)
n_excluded_duplicate_source <- sum(
  screened_summary$decision == "exclude" &
    screened_summary$reason == "duplicate_source"
)
n_excluded_not_relevant <- sum(
  screened_summary$decision == "exclude" &
    screened_summary$reason == "other"
)

n_deferred_outside_module_scope <- sum(
  screened_summary$decision == "defer" &
    screened_summary$reason == "outside_module_scope"
)
n_deferred_needs_second_opinion <- sum(
  screened_summary$decision == "defer" &
    screened_summary$reason == "needs_second_opinion"
)

n_screened_not_in_db <- n_screened - n_datasets
p_within_temporal <- val_db_combined$temporal_join_class |>
  table() |>
  proportions() |>
  pluck("within")
p_within_spatial <- val_db_combined$spatial_join_class |>
  table() |>
  proportions() |>
  pluck("within")
```

I screened a total of `r n_screened` datasets or literature sources, and
`r n_datasets` of them could be included in the validation database. The
included datasets contain a total of `r n_data` data points.
`r round(p_within_temporal*100, 1)`% of data points fall within the simulation's
temporal range, but only `r round(p_within_spatial*100, 1)`% fall within the
spatial extent of Maliau 2. `r round(p_within_temporal*100, 1)`% of data points
fall within the simulation's temporal range, but only
`r round(p_within_spatial*100, 1)`% fall within the spatial extent of Maliau 2.

## Where datasets come from

```text {r}
#| label: validation-map
#| fig-width: 8
#| fig-height: 3
#| fig-alt: >
#|   Map of unique validation data locations (black crosses) over a terrain
#|   basemap, with the Maliau 2 scenario site marked by a red square.

# draw the map
unique_locations <-
  val_db_combined |>
  distinct(longitude, latitude) |>
  filter(!is.na(longitude), !is.na(latitude)) |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

maliau_2_bbox <- toml::read_toml(here(
  "data/derived/site/maliau/maliau_grid_definition.toml"
)) |>
  purrr::pluck("Scenario", "maliau_2", "wgs84_bounds") |>
  unlist() |>
  (\(x) c(xmin = x[1], ymin = x[2], xmax = x[3], ymax = x[4]))()

maliau_2_polygon <-
  st_as_sfc(st_bbox(maliau_2_bbox, crs = st_crs(4326))) |>
  st_as_sf() |>
  mutate(name = "Maliau 2")

# Use the full data extent to set the map boundaries, while keeping the site
# marker visible as a point-like symbol rather than a real-scale box.
raw_bbox <- st_bbox(
  st_union(
    st_geometry(unique_locations),
    st_geometry(maliau_2_polygon)
  )
)

all_map_bbox <- raw_bbox |>
  st_as_sfc() |>
  st_buffer(
    dist = 0.1 *
      max(
        diff(unname(raw_bbox[c("xmin", "xmax")])),
        diff(unname(raw_bbox[c("ymin", "ymax")]))
      )
  ) |>
  st_bbox(crs = st_crs(4326))

maliau_2_point <- st_point(c(
  mean(c(maliau_2_bbox["xmin"], maliau_2_bbox["xmax"])),
  mean(c(maliau_2_bbox["ymin"], maliau_2_bbox["ymax"]))
)) |>
  st_sfc(crs = 4326) |>
  st_as_sf()

ggmap::register_stadiamaps(key = Sys.getenv("STADIA_API_KEY"), write = FALSE)
basemap <- ggmap::get_stadiamap(
  as.numeric(all_map_bbox),
  zoom = 8,
  maptype = "stamen_terrain"
)

ggmap::ggmap(basemap) +
  geom_sf(
    data = unique_locations,
    pch = 4,
    size = 2,
    inherit.aes = FALSE
  ) +
  geom_sf(
    data = maliau_2_point,
    color = "red",
    size = 4,
    shape = 0,
    stroke = 2,
    fill = NA,
    inherit.aes = FALSE
  ) +
  theme_minimal() +
  theme(axis.title = element_blank())
```

Validation data locations relative to the Maliau 2 scenario site. The Maliau 2
indicator is shown as a square marker greatly exaggerated and is not to scale.

## Why many screened datasets are excluded / deferred

Of the remaining `r n_screened_not_in_db`, I excluded **`r n_excluded`** and
deferred **`r n_deferred`** for technical or scope reasons, which I documented
in the YAML `notes` field.

| Group | Reason | No. datasets | Descriptions |
| --- | --- | ---: | --- |
| Excluded | No relevant variables | `r n_excluded_no_relevant_variables` | No soil or litter measurements match validation targets. Examples include taxonomic records without quantitative data, compositional data without C/N values, and measurements that cannot be converted to the needed pool or mass terms. |
| Excluded | Insufficient metadata | `r n_excluded_insufficient_metadata` | e.g., Litter biomass is present, but the record lacks enough context to derive a carbon pool. |
| Excluded | Duplicate source | `r n_excluded_duplicate_source` | The same data already used for input data. |
| Deferred | Outside module scope | `r n_deferred_outside_module_scope` | Useful in principle, but the currently VE does not yet output them; or they belong to other modules, not soil / litter. Examples include soil temperature and moisture (abiotic), microbial diversity, and plant tissue nutrient data that need mass-per-area conversion. |
| Deferred | Needs second opinion | `r n_deferred_needs_second_opinion` | Needs a scope call or curation choice before inclusion; some belong to other modules. Examples include termite functional groups, deadwood conversion, litter biomass-to-carbon conversion, plant tissue nutrient upscaling, and system-level variables such as NPP or carbon balance. |

## Validation variables summary

In the final database, the empirical data that I could map to VE outputs are:

```text {r}
#| label: validation-summary-table
val_db_combined |>
  group_by(var_canonical, unit_canonical) |>
  summarise(
    n_obs = n(),
    min_val = min(value_canonical, na.rm = TRUE),
    max_val = max(value_canonical, na.rm = TRUE),
    # Span uses positive values only, since zeros have no log
    oom_span = log10(max_val / min(value_canonical[value_canonical > 0])),
    .groups = "drop"
  ) |>
  arrange(desc(n_obs)) |>
  mutate(oom_span = round(oom_span, 1)) |>
  select(
    Variable = var_canonical,
    N = n_obs,
    Unit = unit_canonical,
    Min = min_val,
    Max = max_val,
    `Orders of magnitude` = oom_span
  ) |>
  kable()
```

*Orders of magnitude = $\log_{10}$(max / smallest positive value); zeros are
ignored.

## Model performance

### Visual comparison

Now the actual validation itself.

I plot predicted vs. observed values on the original scale and on a log--log
scale. (The log scale is actually `log1p`, or $\log(1+x)$, which I use to
accommodate zeros.)

```text {r}
#| label: predicted-observed
#| fig-width: 8
#| fig-height: 4
#| fig-alt: >
#|   Two scatter plots of predicted versus observed values with a 1:1 line and
#|   grey 5th-95th percentile error bars: original scale (left) and log1p
#|   scale (right). Points inside Maliau 2 are filled black and larger; points
#|   outside are white.

# Row order is draw order; "within" sorts after "outside", so it plots on top
p1 <- ggplot(
  arrange(val_db_combined, spatial_join_class),
  aes(value_canonical, value_VE_q50)
) +
  geom_abline(slope = 1) +
  # geom_function(fun = \(x) x) +
  # geom_function(fun = \(x) 10 * x, linetype = "dashed") +
  # geom_function(fun = \(x) x / 10, linetype = "dashed") +
  geom_errorbar(
    aes(ymin = value_VE_q05, ymax = value_VE_q95),
    colour = "grey",
    alpha = 0.5
  ) +
  geom_point(
    aes(fill = spatial_join_class, size = spatial_join_class),
    shape = 21
  ) +
  scale_fill_manual(values = c(within = "black", outside = "white")) +
  scale_size_manual(values = c(within = 2.5, outside = 1.5)) +
  labs(
    x = "Observed",
    y = "Predicted",
    fill = "Within Maliau 2",
    size = "Within Maliau 2"
  ) +
  theme_bw()

p2 <- p1 +
  scale_x_continuous(trans = scales::log1p_trans()) +
  scale_y_continuous(trans = scales::log1p_trans())

patchwork::wrap_plots(p1, p2, guides = "collect") &
  theme(legend.position = "bottom")
```

### Performance metrics

I avoid most raw-scale metrics for cross-variable comparison because units and
scales are not comparable. Our variables rarely conform to a Normal
distribution:

- Contains zeros
- Right skewed due to positive boundedness
- Vary widely in scale and unit of measurement
- *Rare but it happens*: some variable's values are always the same (due to
  limited spatiotemporal range or the way they aggregate/marginalise outputs to
  match empirical data); these constant data cannot use some variance-based
  metrics such as $R^2$ or variance-based normalisation

I use `rmse_relative()` as the main cross-variable metric because it is
unitless. Caveats: the range denominator is set by the two most extreme
observations, so outliers shrink the score; it is `Inf` for constant variables;
and it is not comparable across variables with very different range-to-spread
ratios.

As a skew-robust sensitivity check, I also compute `mae()`, `rmse()` and `ccc()`
after a `log1p()` transform. Equations follow the `yardstick` package, with
$y_i$ = truth and $\hat{y}_i$ = estimate.

| Metric | Function | Unit | Transformation | Direction | Perfect score | Equation |
| --- | --- | --- | --- | --- | --- | --- |
| Relative root mean squared error (range-normalised RMSE) | `rmse_relative()` | Unitless | Raw | Minimise | 0 | $\dfrac{\sqrt{\frac{1}{n}\sum_{i=1}^{n}(y_i-\hat{y}_i)^2}}{\max(y)-\min(y)}$ |
| Mean absolute error | `mae()` | `log1p` of original unit | `log1p` | Minimise | 0 | $\frac{1}{n}\sum_{i=1}^{n}\lvert y_i-\hat{y}_i\rvert$ |
| Root mean squared error | `rmse()` | `log1p` of original unit | `log1p` | Minimise | 0 | $\sqrt{\frac{1}{n}\sum_{i=1}^{n}(y_i-\hat{y}_i)^2}$ |
| Concordance correlation loss ($1 - \text{CCC}$) | `ccc()` | Unitless | `log1p` | Minimise | 0 | $1-\dfrac{2\,\text{cov}(y,\hat{y})}{\text{var}(y)+\text{var}(\hat{y})+(\bar{y}-\bar{\hat{y}})^2}$ |

Notes:

- `mae()` and `rmse()` are comparable across variables only loosely, because
  `log1p` values still depend on each variable's original scale.
- `ccc()` ranges from -1 to 1 and penalises both poor correlation and bias. I
  report it as the loss `ccc_loss` $= 1 - \text{CCC}$ (range 0 to 2) so that all
  metrics are minimised in the calibration objective.
- There are many more performance metrics, but I start with only a few to avoid
  cluttering this report.

```text {r}
#| label: performance-metrics

raw_scale_metrics <- metric_set(rmse_relative)
log_scale_metrics <- metric_set(mae, rmse, ccc)

compute_metrics <- function(data, by = "var_canonical") {
  raw <- data |>
    group_by(across(all_of(by))) |>
    raw_scale_metrics(truth = value_canonical, estimate = value_VE_q50)
  logged <- data |>
    mutate(across(c(value_canonical, value_VE_q50), log1p)) |>
    group_by(across(all_of(by))) |>
    log_scale_metrics(truth = value_canonical, estimate = value_VE_q50)

  bind_rows(raw, logged) |>
    select(-`.estimator`) |>
    pivot_wider(names_from = `.metric`, values_from = `.estimate`) |>
    # Loss form so every metric is minimised in the calibration objective
    mutate(ccc_loss = 1 - ccc, .keep = "unused")
}

kable_metrics <- function(metrics) {
  metrics |>
    mutate(
      rmse_relative = sprintf("%.2f%%", rmse_relative * 100),
      across(c(mae, rmse, ccc_loss), \(x) sprintf("%.3g", x))
    ) |>
    kable()
}

metrics_table <- compute_metrics(val_db_combined)
kable_metrics(metrics_table)
```

Metrics split by within Maliau vs. outside of Maliau (only some variables
included both spatial classes):

```text {r}
#| label: performance-metrics-by-class

val_db_combined |>
  filter(n_distinct(spatial_join_class) == 2, .by = var_canonical) |>
  compute_metrics(by = c("var_canonical", "spatial_join_class")) |>
  kable_metrics()
```

Best and worst performers by metric:

```text {r}
#| echo: false

metrics_table |>
  pivot_longer(-var_canonical, names_to = "Metric") |>
  summarise(
    Best = sprintf(
      "%s (%.3g)",
      var_canonical[which.min(value)],
      value[which.min(value)]
    ),
    Worst = sprintf(
      "%s (%.3g)",
      var_canonical[which.max(value)],
      value[which.max(value)]
    ),
    .by = Metric
  )
```

## Thoughts

- Overall the predicted--observed plot looks **better than expected**. But:
  - Within-Maliau validation data fall closer to the 1:1 line, which is great,
    but I need to check if there is any self-fulling prophecy (e.g., input data
    already near correct and the variable was not dynamic during simulation.)
  - Although the log--log scale reigned in the small and large values, I think
    the relative ranking can still be misleading, because it is very hard for
    very large-valued variables to take very small values, so the positive
    correlation on a log--log plot is sort of expected. I have explored a few
    normalised or standardised comparisons, but each has its own quirks and I
    need more time to do some hard thinking.
- Performance is quite inconsistent across the chosen metrics, indicating that
  **metric choice is very crucial** to our conclusion.
- Within-Maliau data performed better than Outside-Maliau data in MAE and RMSE,
  but the opposite for normalised RMSE. I think the latter is an artefact of a
  lower value range in Within-Maliau data (because we have much fewer data
  points from within Maliau), so the range-normalisation demonitor was small,
  inflating the normalised RMSE.
- CCC loss just look weird all over the place. Need to investigate. But gut
  feeling is that **variance--covariance based metric may not work well** on our
  small-ish validation datasets. This indicates that $R^2$ will also work
  poorly.
- Any metrics we use need to **include calibration in mind**. Calibration needs
  an objective function that aggregates unitless metrics across variables. Jacob
  and I have had some discussion on this.
- There is really not a lot of validation data exactly from the Maliau 2 spatial
  extent. Not even the entire Maliau Basin. See extended thoughts
  [here](https://github.com/ImperialCollegeLondon/ve_data_science/blob/main/analysis/soil/validation/notes/marginal_validation.md).
- If we need more validation data, I could split the datasets used for input
  data into training and testing sets (reminder from Jacob).
