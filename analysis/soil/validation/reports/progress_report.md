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
---

Scenario is Maliau 2

```text {r}
library(tidyverse)
library(arrow)
library(sf)
library(toml)
library(tmap)
library(here)
source(here("tools/R/R/valdb.R"))

# Read the validation database
val_db_combined <-
  open_dataset(here("data/derived/soil/validation/database_combined")) |>
  collect()
```

```text {r}
#| label: screened-datasets
screened <- list_screening_records(here("data/derived/soil/validation/sources"))
n_screened <- length(screened)
n_datasets <- length(unique(val_db_combined$dataset))
n_data <- nrow(val_db_combined)
p_within_temporal <- val_db_combined$temporal_join_class |>
  table() |>
  proportions() |>
  pluck("within")
p_within_spatial <- val_db_combined$spatial_join_class |>
  table() |>
  proportions() |>
  pluck("within")
```

I screened a total of `r n_screened` datasets or literature, and obtained `r n_datasets` that can be included into the validation database. The included datasets contained a total of `r n_data` data points. `r round(p_within_temporal*100, 1)`% of data points fall within the simulation's temporal range, but only `r round(p_within_spatial*100, 1)`% fall within the spatial extent.

```text {r}
#| label: validation-map
#| fig-cap: "Validation data locations relative to the Maliau 2 scenario site. The Maliau 2 indicator is shown as a square marker greatly exaggerated and is not to scale."
# draw the map
unique_locations <-
  val_db_combined |>
  distinct(longitude, latitude) |>
  filter(!is.na(longitude), !is.na(latitude)) |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

maliau_2_extent <-
  toml::read_toml(here(
    "data/derived/site/maliau/maliau_grid_definition.toml"
  )) |>
  purrr::pluck("Scenario", "maliau_2", "wgs84_bounds") |>
  unlist()

maliau_2_bbox <- c(
  xmin = maliau_2_extent[1],
  ymin = maliau_2_extent[2],
  xmax = maliau_2_extent[3],
  ymax = maliau_2_extent[4]
)

maliau_2_polygon <-
  st_as_sfc(st_bbox(maliau_2_bbox, crs = st_crs(4326))) |>
  st_as_sf() |>
  mutate(name = "Maliau 2")

# Use the full data extent to set the map boundaries, while keeping the site
# marker visible as a point-like symbol rather than a real-scale box.
all_map_bbox <- st_bbox(
  st_union(
    st_geometry(unique_locations),
    st_geometry(maliau_2_polygon)
  )
)

all_x_pad <- diff(unname(all_map_bbox[c("xmin", "xmax")])) * 0.1
all_y_pad <- diff(unname(all_map_bbox[c("ymin", "ymax")])) * 0.1
all_map_bbox <- st_bbox(
  c(
    xmin = unname(all_map_bbox["xmin"]) - all_x_pad,
    ymin = unname(all_map_bbox["ymin"]) - all_y_pad,
    xmax = unname(all_map_bbox["xmax"]) + all_x_pad,
    ymax = unname(all_map_bbox["ymax"]) + all_y_pad
  ),
  crs = st_crs(4326)
)

maliau_2_point <-
  st_as_sf(
    data.frame(
      x = mean(c(maliau_2_bbox["xmin"], maliau_2_bbox["xmax"])),
      y = mean(c(maliau_2_bbox["ymin"], maliau_2_bbox["ymax"]))
    ),
    coords = c("x", "y"),
    crs = 4326
  )

tmap_mode("plot")

tm_basemap(server = "Esri.WorldImagery") +
  tm_shape(unique_locations) +
  tm_symbols(
    col = "#4DA3D9",
    border.col = "white",
    border.lwd = 0.1,
    size = 0.5,
    fill_alpha = 0.7
  ) +
  tm_shape(maliau_2_point) +
  tm_symbols(
    col = NA,
    border.col = "#d8e751",
    border.lwd = 2,
    size = 1.5,
    shape = 0
  ) +
  tm_layout(
    bg.color = "white",
    frame = FALSE,
    legend.outside = FALSE,
    legend.show = FALSE,
    inner.margins = c(0.02, 0.02, 0.02, 0.02)
  )
```

```text {r}
ggplot(val_db_combined) +
  geom_point(aes(value_canonical, value_VE_q50))
```
