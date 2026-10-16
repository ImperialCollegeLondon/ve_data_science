# Soil–Litter validation progress report

Lai, Hao Ran
2026-10-16

## Progress over the past few months

- I built a validation database pipeline, see docs
  [here](https://github.com/ImperialCollegeLondon/ve_data_science/blob/main/docs/validation_database.md).
- I screened, added and harmonised datasets using the database
  functions.
- I did not limit datasets to only Maliau or old growth. I included SAFE
  and disturbed forests since we will need them in future scenarios. The
  database has spatial coordinates, so I can filter to what we need (and
  combine them with any GIS layer, including SAFE layers).
- I also did a broader search using the OpenAlex website.
- Most of my effort went into harmonisation, including units and derived
  variables.

As VE is being developed, the results below will likely change
dramatically (we are already seeing this going from v0.2.1 to v0.2.3);
therefore I’ll focus on the overall findings.

``` r
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

``` r
out_dir <- here("data/scenarios/maliau/maliau_2/out")
invisible(summarise_ve_config(
  file.path(out_dir, "compiled_configuration.toml"),
  file.path(out_dir, "logfile.log")
))
```

- **VE version**: v0.2.3
- **Models**: AbioticSimple, Hydrology, Animal, Plants, Soil, Litter
- **Grid**: 10 x 10 cells
- **Resolution**: 100 m
- **Extent (bbox)**: xmin: 495559.3 ymin: 524298.8 xmax: 496559.3 ymax:
  525298.8
- **Time period**: start 2010-01-01, length 11 years, update interval 1
  month
- **Input files**:
  - `era5_maliau_10x10_2010_2020.nc`
  - `elevation_maliau_10x10.nc`
  - `plant_input_data_maliau_2.nc`
  - `soil_maliau.nc`
  - `litter_maliau.nc`
  - `animal_functional_groups_Maliau_level3.csv`
  - `plant_pft_definitions_maliau_2.csv`
  - `cohort_data_1_cm_maliau_2.csv`

## Datasets included

``` r
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

I screened a total of 103 datasets or literature sources, and 10 of them
could be included in the validation database. The included datasets
contain a total of 3750 data points. 100% of data points fall within the
simulation’s temporal range, but only 0.3% fall within the spatial
extent of Maliau 2. 100% of data points fall within the simulation’s
temporal range, but only 0.3% fall within the spatial extent of Maliau
2.

## Where datasets come from

``` r
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

<img src="validation-map-1.png" data-fig-alt="Map of unique validation data locations (black crosses) over a terrain basemap, with the Maliau 2 scenario site marked by a red square." />

Validation data locations relative to the Maliau 2 scenario site. The
Maliau 2 indicator is shown as a square marker greatly exaggerated and
is not to scale.

## Why many screened datasets are excluded / deferred

Of the remaining 93, I excluded **57** and deferred **35** for technical
or scope reasons, which I documented in the YAML `notes` field.

| Group | Reason | No. datasets | Descriptions |
| ---- | ---- | ---: | ---- |
| Excluded | No relevant variables | 45 | No soil or litter measurements match validation targets. Examples include taxonomic records without quantitative data, compositional data without C/N values, and measurements that cannot be converted to the needed pool or mass terms. |
| Excluded | Insufficient metadata | 2 | e.g., Litter biomass is present, but the record lacks enough context to derive a carbon pool. |
| Excluded | Duplicate source | 10 | The same data already used for input data. |
| Deferred | Outside module scope | 31 | Useful in principle, but the currently VE does not yet output them; or they belong to other modules, not soil / litter. Examples include soil temperature and moisture (abiotic), microbial diversity, and plant tissue nutrient data that need mass-per-area conversion. |
| Deferred | Needs second opinion | 4 | Needs a scope call or curation choice before inclusion; some belong to other modules. Examples include termite functional groups, deadwood conversion, litter biomass-to-carbon conversion, plant tissue nutrient upscaling, and system-level variables such as NPP or carbon balance. |

## Validation variables summary

In the final database, the empirical data that I could map to VE outputs
are:

``` r
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

| Variable | N | Unit | Min | Max | Orders of magnitude |
| :--- | ---: | :--- | ---: | ---: | ---: |
| soil_respiration_CO2_mass | 974 | kg m-2 day-1 | -0.0097649 | 1.805760e-02 | 2.7 |
| soil_nitrous_oxide_emission_N2O_mass | 973 | kg m-2 day-1 | -0.0000038 | 4.300000e-05 | 4.3 |
| total_soil_n_per_volume | 353 | kg m^-3 | 0.4771187 | 4.819000e+02 | 3.0 |
| soil_n_pool_ammonium_per_mass | 302 | kg kg^-1 | 0.0000000 | 4.584000e-04 | 5.1 |
| soil_n_pool_nitrate_per_mass | 302 | kg kg^-1 | 0.0000000 | 2.480000e-05 | 3.9 |
| soil_p_pool_labile_per_mass | 300 | kg kg^-1 | 0.0000017 | 3.290000e-05 | 1.3 |
| dissolved_phosphorus | 297 | kg m^-3 | 0.0009088 | 4.888383e-01 | 2.7 |
| total_soil_c_per_mass | 67 | kg kg^-1 | 0.0034059 | 4.764000e+01 | 4.1 |
| total_soil_n_per_mass | 67 | kg kg^-1 | 0.0002437 | 1.770000e+00 | 3.9 |
| total_soil_c_per_volume | 56 | kg m^-3 | 584.2000000 | 1.065060e+04 | 1.3 |
| total_soil_p_per_mass | 20 | kg kg^-1 | 0.0000064 | 8.912000e-04 | 2.1 |
| soil_respiration_CO2_molar | 14 | mol m-2 day-1 | 0.2090970 | 5.262030e-01 | 0.4 |
| soil_respiration | 11 | kg m-2 day-1 | 0.0028283 | 4.085000e-03 | 0.2 |
| total_soil_c_per_area | 11 | kg m^-2 | 2.6540000 | 2.052900e+01 | 0.9 |
| soil_n_pool_inorganic_per_area | 3 | kg m^-2 | 0.0003300 | 1.930000e-03 | 0.8 |

\*Orders of magnitude = $\log_{10}$(max / smallest positive value);
zeros are ignored.

## Model performance

### Visual comparison

Now the actual validation itself.

I plot predicted vs. observed values on the original scale and on a
log–log scale. (The log scale is actually `log1p`, or $\log(1+x)$, which
I use to accommodate zeros.)

``` r
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

<img src="predicted-observed-1.png" data-fig-alt="Two scatter plots of predicted versus observed values with a 1:1 line and grey 5th-95th percentile error bars: original scale (left) and log1p scale (right). Points inside Maliau 2 are filled black and larger; points outside are white." />

### Performance metrics

I avoid most raw-scale metrics for cross-variable comparison because
units and scales are not comparable. Our variables rarely conform to a
Normal distribution:

- Contains zeros
- Right skewed due to positive boundedness
- Vary widely in scale and unit of measurement
- *Rare but it happens*: some variable’s values are always the same (due
  to limited spatiotemporal range or the way they aggregate/marginalise
  outputs to match empirical data); these constant data cannot use some
  variance-based metrics such as $R^2$ or variance-based normalisation

I use `rmse_relative()` as the main cross-variable metric because it is
unitless. Caveats: the range denominator is set by the two most extreme
observations, so outliers shrink the score; it is `Inf` for constant
variables; and it is not comparable across variables with very different
range-to-spread ratios.

As a skew-robust sensitivity check, I also compute `mae()`, `rmse()` and
`ccc()` after a `log1p()` transform. Equations follow the `yardstick`
package, with $y_i$ = truth and $\hat{y}_i$ = estimate.

| Metric | Function | Unit | Transformation | Direction | Perfect score | Equation |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| Relative root mean squared error (range-normalised RMSE) | `rmse_relative()` | Unitless | Raw | Minimise | 0 | $\dfrac{\sqrt{\frac{1}{n}\sum_{i=1}^{n}(y_i-\hat{y}_i)^2}}{\max(y)-\min(y)}$ |
| Mean absolute error | `mae()` | `log1p` of original unit | `log1p` | Minimise | 0 | $\frac{1}{n}\sum_{i=1}^{n}\lvert y_i-\hat{y}_i\rvert$ |
| Root mean squared error | `rmse()` | `log1p` of original unit | `log1p` | Minimise | 0 | $\sqrt{\frac{1}{n}\sum_{i=1}^{n}(y_i-\hat{y}_i)^2}$ |
| Concordance correlation loss ($1 - \text{CCC}$) | `ccc()` | Unitless | `log1p` | Minimise | 0 | $1-\dfrac{2\,\text{cov}(y,\hat{y})}{\text{var}(y)+\text{var}(\hat{y})+(\bar{y}-\bar{\hat{y}})^2}$ |

Notes:

- `mae()` and `rmse()` are comparable across variables only loosely,
  because `log1p` values still depend on each variable’s original scale.
- `ccc()` ranges from -1 to 1 and penalises both poor correlation and
  bias. I report it as the loss `ccc_loss` $= 1 - \text{CCC}$ (range 0
  to 2) so that all metrics are minimised in the calibration objective.
- There are many more performance metrics, but I start with only a few
  to avoid cluttering this report.

``` r
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

| var_canonical | rmse_relative | mae | rmse | ccc_loss |
| :--- | :--- | :--- | :--- | :--- |
| dissolved_phosphorus | 7.57% | 0.0119 | 0.0321 | 1 |
| soil_n_pool_ammonium_per_mass | 8.56% | 8.33e-06 | 3.92e-05 | 1 |
| soil_n_pool_inorganic_per_area | 64.36% | 0.00079 | 0.00103 | 1 |
| soil_n_pool_nitrate_per_mass | 13.92% | 2.13e-06 | 3.45e-06 | 1.02 |
| soil_nitrous_oxide_emission_N2O_mass | 8.56% | 2.51e-06 | 4e-06 | 1 |
| soil_p_pool_labile_per_mass | 13.01% | 2.88e-06 | 4.06e-06 | 1 |
| soil_respiration | 293.88% | 0.00367 | 0.00369 | 1 |
| soil_respiration_CO2_mass | 13.95% | 0.00316 | 0.00387 | 1 |
| soil_respiration_CO2_molar | 136.51% | 0.345 | 0.355 | 1 |
| total_soil_c_per_area | 30.70% | 0.534 | 0.611 | 1 |
| total_soil_c_per_mass | 19.84% | 0.747 | 1.37 | 1 |
| total_soil_c_per_volume | 27.81% | 3.55 | 3.62 | 1 |
| total_soil_n_per_mass | 24.65% | 0.153 | 0.301 | 1 |
| total_soil_n_per_volume | 14.99% | 0.908 | 1.62 | 0.983 |
| total_soil_p_per_mass | 23.17% | 0.000152 | 0.000205 | 1 |

Metrics split by within Maliau vs. outside of Maliau (only some
variables included both spatial classes):

``` r
val_db_combined |>
  filter(n_distinct(spatial_join_class) == 2, .by = var_canonical) |>
  compute_metrics(by = c("var_canonical", "spatial_join_class")) |>
  kable_metrics()
```

| var_canonical | spatial_join_class | rmse_relative | mae | rmse | ccc_loss |
| :--- | :--- | :--- | :--- | :--- | :--- |
| dissolved_phosphorus | outside | 7.64% | 0.0121 | 0.0325 | 1 |
| dissolved_phosphorus | within | 149.64% | 0.00443 | 0.00456 | 1 |
| total_soil_n_per_volume | outside | 15.12% | 0.92 | 1.63 | 0.983 |
| total_soil_n_per_volume | within | 35.74% | 0.176 | 0.203 | 1 |

Best and worst performers by metric:

```text
# A tibble: 4 × 3
  Metric        Best                                    Worst                   
  <chr>         <chr>                                   <chr>                   
1 rmse_relative dissolved_phosphorus (0.0757)           soil_respiration (2.94) 
2 mae           soil_n_pool_nitrate_per_mass (2.13e-06) total_soil_c_per_volume…
3 rmse          soil_n_pool_nitrate_per_mass (3.45e-06) total_soil_c_per_volume…
4 ccc_loss      total_soil_n_per_volume (0.983)         soil_n_pool_nitrate_per…
```

## Thoughts

- Overall the predicted–observed plot looks **better than expected**.
  But:
  - Within-Maliau validation data fall closer to the 1:1 line, which is
    great, but I need to check if there is any self-fulling prophecy
    (e.g., input data already near correct and the variable was not
    dynamic during simulation.)
  - Although the log–log scale reigned in the small and large values, I
    think the relative ranking can still be misleading, because it is
    very hard for very large-valued variables to take very small values,
    so the positive correlation on a log–log plot is sort of expected. I
    have explored a few normalised or standardised comparisons, but each
    has its own quirks and I need more time to do some hard thinking.
- Performance is quite inconsistent across the chosen metrics,
  indicating that **metric choice is very crucial** to our conclusion.
- Within-Maliau data performed better than Outside-Maliau data in MAE
  and RMSE, but the opposite for normalised RMSE. I think the latter is
  an artefact of a lower value range in Within-Maliau data (because we
  have much fewer data points from within Maliau), so the
  range-normalisation demonitor was small, inflating the normalised
  RMSE.
- CCC loss just look weird all over the place. Need to investigate. But
  gut feeling is that **variance–covariance based metric may not work
  well** on our small-ish validation datasets. This indicates that $R^2$
  will also work poorly.
- Any metrics we use need to **include calibration in mind**.
  Calibration needs an objective function that aggregates unitless
  metrics across variables. Jacob and I have had some discussion on
  this.
- There is really not a lot of validation data exactly from the Maliau 2
  spatial extent. Not even the entire Maliau Basin. See extended
  thoughts
  [here](https://github.com/ImperialCollegeLondon/ve_data_science/blob/main/analysis/soil/validation/notes/marginal_validation.md).
- If we need more validation data, I could split the datasets used for
  input data into training and testing sets (reminder from Jacob).
