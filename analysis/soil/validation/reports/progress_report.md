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
title: "Soil--Litter validation progress report"
author: Lai, Hao Ran
date: last-modified
format: gfm
execute:
  warning: false
  message: false
---

## Overview

- Ran the `maliau_2` scenario with VE version v0.2.1
- Built a validation database pipeline, see docs [here](https://github.com/ImperialCollegeLondon/ve_data_science/blob/main/docs/validation_database.md).
- Screened, add and harmonise datasets using the database functions.

```text {r}
library(tidyverse)
library(arrow)
library(sf)
library(toml)
library(here)
source(here("tools/R/R/valdb.R"))

# Read the validation database
val_db_combined <-
  open_dataset(here("data/derived/soil/validation/database_combined")) |>
  collect()
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

I screened a total of `r n_screened` datasets or literature, and obtained `r n_datasets` that can be included into the validation database. The included datasets contained a total of `r n_data` data points. `r round(p_within_temporal*100, 1)`% of data points fall within the simulation's temporal range, but only `r round(p_within_spatial*100, 1)`% fall within the spatial extent of Maliau 2.

## Where datasets come from

```text {r}
#| label: validation-map
#| fig-cap: "Validation data locations relative to the Maliau 2 scenario site. The Maliau 2 indicator is shown as a square marker greatly exaggerated and is not to scale."
#| fig-width: 6
#| fig-height: 2

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

## Why many screened datasets are excluded / deferred

The remaining `r n_screened_not_in_db` are split into **`r n_excluded` excluded** and **`r n_deferred` deferred**
due to technical or scope reasons documented in the YAML `notes` field.

| Group | Reason | No. datasets | Descriptions |
|---|---|---:|---|
| Excluded | No relevant variables | `r n_excluded_no_relevant_variables` | No soil or litter measurements match validation targets. Examples include taxonomic records without quantitative data, compositional data without C/N values, keyword matches that are off-topic, and measurements that cannot be converted to the needed pool or mass terms. |
| Excluded | Insufficient metadata | `r n_excluded_insufficient_metadata` | Litter mass is present, but the record lacks enough context to derive a carbon pool or scale the sample reliably. |
| Excluded | Duplicate source | `r n_excluded_duplicate_source` | The same data already appear in published SAFE datasets in the validation pipeline, so keeping them would add redundancy. |
| Deferred | Outside module scope | `r n_deferred_outside_module_scope` | Useful in principle, but the current build does not yet target them. Examples include soil temperature and moisture, microbial diversity, decomposition, and tissue nutrient data that need mass-per-area conversion. |
| Deferred | Needs second opinion | `r n_deferred_needs_second_opinion` | Needs a scope call or curation choice before inclusion. Examples include termite functional groups, deadwood conversion, litter biomass-to-carbon conversion, plant tissue nutrient upscaling, and system-level variables such as NPP or carbon balance. |

## Validation variables summary

```text {r}
#| label: validation-summary-table
val_db_combined |>
  group_by(var_canonical, unit_canonical) |>
  summarise(
    n_obs = n(),
    min_val = min(value_canonical, na.rm = TRUE),
    max_val = max(value_canonical, na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(desc(n_obs)) |>
  select(
    Variable = var_canonical,
    N = n_obs,
    Unit = unit_canonical,
    Min = min_val,
    Max = max_val
  )
```




```text {r}
ggplot(val_db_combined) +
  geom_point(aes(value_canonical, value_VE_q50))
```
