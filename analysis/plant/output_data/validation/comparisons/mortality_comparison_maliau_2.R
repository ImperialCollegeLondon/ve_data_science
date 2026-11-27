#| ---
#| title: mortality_comparison_maliau_2
#|
#| description: |
#|   Compares observed plot-level tree mortality with Virtual Ecosystem
#|   cell-level tree mortality for Maliau-2. Annualised mortality counts per
#|   hectare and annualised mortality fractions of the initial trees are
#|   compared for four census periods (2011-2014, 2014-2015, 2015-2017, and
#|   2017-2019). Each comparison row represents one observed plot, one
#|   overlapping VE cell, and one mapped variable for one census period.
#|
#| virtual_ecosystem_module:
#|   - Plant
#|
#| author:
#|   - Arne Scheire
#|
#| status: final
#|
#| input_files:
#|   - name: mortality_maliau.csv
#|     path: data/derived/plant/output_data/validation/observed_data_processing
#|     description: |
#|       Observed plot mortality counts and fractions per census period, plot
#|       coordinates, and census dates for 2011, 2014, 2015, 2017, and 2019.
#|   - name: mortality_maliau_2.csv
#|     path: data/derived/plant/output_data/validation/predicted_outputs_processing
#|     description: |
#|       VE initial-cohort records by cell and timestep. Census-period mortality
#|       counts and fractions are filled only on rows whose timestep falls
#|       within that period, and are reduced to one row per cell and plot for
#|       comparison.
#|   - name: mortality_mapping_maliau_2.yml
#|     path: analysis/plant/output_data/validation/variable_mapping
#|     description: Observed-to-predicted variable and date mappings.
#|   - name: maliau_grid_definition.toml
#|     path: data/derived/site/maliau
#|     description: Maliau-2 grid geometry and cell dimensions.
#|
#| output_files:
#|   - name: mortality_comparison_maliau_2.csv
#|     path: data/derived/plant/output_data/validation/comparisons
#|     description: |
#|       Row-level observed and predicted mortality count and fraction
#|       comparisons for each plot-cell-period combination, including the
#|       observed census dates, the predicted timestep span, and spatial and
#|       temporal aggregation status.
#|
#| package_dependencies:
#|   - data.table
#|   - sf
#|   - toml
#|   - yaml
#|
#| usage_notes: |
#|   Run the predicted processing script first so that mortality_maliau_2.csv
#|   contains timestep_start_date and period values filled only within each
#|   census period. Observed and predicted values are linked by PlotID; the
#|   census periods are matched in the predicted processing, not by date here.
#|   The census period and observed census date columns are derived from the
#|   mapped variable names. The predicted file links each cell to a single
#|   plot, so an observed plot without a predicted match is dropped.
#|   Spatial and temporal aggregation are exact because rows retain one plot,
#|   one cell and one census period. The observed SE and
#|   predicted SD columns are kept but empty, as neither input has an
#|   uncertainty variable for mortality.
#| ---

library(data.table)
library(sf)
library(toml)
library(yaml)

observed_data_file <-
  "../../../../../data/derived/plant/output_data/validation/observed_data_processing/mortality_maliau.csv"
predicted_data_file <-
  "../../../../../data/derived/plant/output_data/validation/predicted_outputs_processing/mortality_maliau_2.csv"
mapping_file <-
  "../variable_mapping/mortality_mapping_maliau_2.yml"
grid_definition_file <-
  "../../../../../data/derived/site/maliau/maliau_grid_definition.toml"

output_dir <-
  "../../../../../data/derived/plant/output_data/validation/comparisons"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

observed_data <- fread(observed_data_file)
predicted_data <- fread(predicted_data_file)
mapping <- yaml::yaml.load_file(mapping_file)$variable_mappings
grid_definition <- read_toml(grid_definition_file)
site_definition <- grid_definition$Scenario$maliau_2

observed_data[, Date_2011 := as.Date(Date_2011)]
observed_data[, Date_2014 := as.Date(Date_2014)]
observed_data[, Date_2015 := as.Date(Date_2015)]
observed_data[, Date_2017 := as.Date(Date_2017)]
observed_data[, Date_2019 := as.Date(Date_2019)]

names(predicted_data)

predicted_data <- unique(
  predicted_data[, .(
    cell_id,
    cell_x,
    cell_y,
    PlotID,
    time_index,
    timestep_start_date,
    timestep_end_date,
    mortality_count_11_14_ha_yr,
    mortality_count_14_15_ha_yr,
    mortality_count_15_17_ha_yr,
    mortality_count_17_19_ha_yr,
    mortality_fraction_11_14_yr,
    mortality_fraction_14_15_yr,
    mortality_fraction_15_17_yr,
    mortality_fraction_17_19_yr
  )],
  by = c("cell_id", "time_index")
)

# Subset predicted data to observed plots only
plot_cell_ids <- unique(observed_data$PlotID)
predicted_data <- predicted_data[predicted_data$PlotID %in% plot_cell_ids, ]

#####

# Add figure showing plots in maliau_2 grid
predicted_data[, timestep_end_date := as.Date(timestep_end_date)]
if (!"timestep_start_date" %in% names(predicted_data)) {
  stop("Rerun predicted processing to export corrected timestep boundaries.")
}
predicted_data[, timestep_start_date := as.Date(timestep_start_date)]

make_square <- function(x, y, side_length) {
  half_side <- side_length / 2
  st_polygon(list(rbind(
    c(x - half_side, y - half_side),
    c(x + half_side, y - half_side),
    c(x + half_side, y + half_side),
    c(x - half_side, y + half_side),
    c(x - half_side, y - half_side)
  )))
}

# Use the cell IDs and coordinates exported by the simulation.
grid_cells <- unique(predicted_data[, .(cell_id, cell_x, cell_y)])
cell_polygons <- st_sf(
  grid_cells,
  geometry = st_sfc(
    Map(
      make_square,
      grid_cells$cell_x,
      grid_cells$cell_y,
      MoreArgs = list(side_length = site_definition$res)
    ),
    crs = site_definition$epsg_code
  )
)
plot_points <- st_as_sf(
  observed_data,
  coords = c("centroid_x", "centroid_y"),
  crs = 4326,
  remove = FALSE
)
plot_points <- st_transform(plot_points, site_definition$epsg_code)
plot_coordinates <- st_coordinates(plot_points)
plot_polygons <- st_sf(
  st_drop_geometry(plot_points),
  geometry = st_sfc(
    Map(
      make_square,
      plot_coordinates[, 1],
      plot_coordinates[, 2],
      sqrt(plot_points$plot_area_m2)
    ),
    crs = site_definition$epsg_code
  )
)
plot_cell_matches <- as.data.table(st_drop_geometry(st_join(
  plot_polygons,
  cell_polygons[, c("cell_id", "cell_x", "cell_y")],
  join = st_intersects,
  left = FALSE
)))

# Diagnostic figure: verify the grid and plot-cell intersections.
plot(
  st_geometry(cell_polygons),
  col = NA,
  border = "grey70",
  lwd = 0.8,
  asp = 1,
  main = "Maliau-2 VE cells and observed OG plots",
  xlab = "Easting (m)",
  ylab = "Northing (m)"
)
text(
  grid_cells$cell_x,
  grid_cells$cell_y,
  labels = grid_cells$cell_id,
  cex = 0.65
)
plot(st_geometry(plot_polygons), add = TRUE, border = "red", lwd = 2)
plot_points_xy <- st_coordinates(plot_points)
points(plot_points_xy, pch = 19, col = "red")
text(
  plot_points_xy[, 1],
  plot_points_xy[, 2],
  labels = plot_points$PlotID,
  pos = 3,
  col = "red",
  cex = 0.75
)
dev.off()

#####

# Summarise the predicted data to one row per cell and plot, keeping the
# variable names used in the mapping file.
# In the predicted data, each period's mortality count and fraction are filled
# only on the rows whose timestep falls within that period, and are NA on all
# other rows.
# The timestep containing a census date is counted in full in both the period
# ending there and the period starting there, so those rows hold values for two
# periods at once. The start and end dates are therefore stored per period.
# For each period we keep the rows where that period has a value and take, per
# cell and plot:
# - the earliest timestep_start_date as the predicted start date of the period,
# - the latest timestep_end_date as the predicted end date of the period,
# - the period's mortality count and fraction, which are the same on every row.
# The four periods are then joined side by side into a single data frame.

period_11_14 <- predicted_data[
  !is.na(mortality_count_11_14_ha_yr),
  .(
    predicted_start_date_11_14 = min(timestep_start_date),
    predicted_end_date_11_14 = max(timestep_end_date),
    mortality_count_11_14_ha_yr = mortality_count_11_14_ha_yr[1],
    mortality_fraction_11_14_yr = mortality_fraction_11_14_yr[1]
  ),
  by = .(cell_id, cell_x, cell_y, PlotID)
]

period_14_15 <- predicted_data[
  !is.na(mortality_count_14_15_ha_yr),
  .(
    predicted_start_date_14_15 = min(timestep_start_date),
    predicted_end_date_14_15 = max(timestep_end_date),
    mortality_count_14_15_ha_yr = mortality_count_14_15_ha_yr[1],
    mortality_fraction_14_15_yr = mortality_fraction_14_15_yr[1]
  ),
  by = .(cell_id, cell_x, cell_y, PlotID)
]

period_15_17 <- predicted_data[
  !is.na(mortality_count_15_17_ha_yr),
  .(
    predicted_start_date_15_17 = min(timestep_start_date),
    predicted_end_date_15_17 = max(timestep_end_date),
    mortality_count_15_17_ha_yr = mortality_count_15_17_ha_yr[1],
    mortality_fraction_15_17_yr = mortality_fraction_15_17_yr[1]
  ),
  by = .(cell_id, cell_x, cell_y, PlotID)
]

period_17_19 <- predicted_data[
  !is.na(mortality_count_17_19_ha_yr),
  .(
    predicted_start_date_17_19 = min(timestep_start_date),
    predicted_end_date_17_19 = max(timestep_end_date),
    mortality_count_17_19_ha_yr = mortality_count_17_19_ha_yr[1],
    mortality_fraction_17_19_yr = mortality_fraction_17_19_yr[1]
  ),
  by = .(cell_id, cell_x, cell_y, PlotID)
]

# Keep every cell-plot combination, even if it is missing one of the periods.
predicted_data_plots <- Reduce(
  function(left, right) {
    merge(
      left,
      right,
      by = c("cell_id", "cell_x", "cell_y", "PlotID"),
      all = TRUE
    )
  },
  list(period_11_14, period_14_15, period_15_17, period_17_19)
)

#####

# Build one row per plot, overlapping cell, and mapped variable. The census
# periods are already matched in the predicted processing, so observed and
# predicted values are linked by plot rather than by date.
comparison_rows <- rbindlist(
  lapply(mapping, function(mapping_entry) {
    observed_variable <- mapping_entry$observed$variable
    predicted_variable <- mapping_entry$predicted$variable
    # The mapped variable names contain the census period as two-digit years,
    # for example "11_14" for the 2011 to 2014 censuses.
    period <- regmatches(
      predicted_variable,
      regexpr("[0-9]{2}_[0-9]{2}", predicted_variable)
    )
    census_years <- strsplit(period, "_")[[1]]
    observed_start_date_variable <- paste0("Date_20", census_years[1])
    observed_end_date_variable <- paste0("Date_20", census_years[2])
    predicted_start_date_variable <- paste0("predicted_start_date_", period)
    predicted_end_date_variable <- paste0("predicted_end_date_", period)
    variable_units <- if (grepl("^mortality_count", observed_variable)) {
      "count ha-1 year-1"
    } else {
      "year-1"
    }

    # The observed and predicted mortality data have no uncertainty variables,
    # so the SE and SD columns are kept but left empty.
    observed_rows <- observed_data[,
      .(
        PlotID,
        plot_x = centroid_x,
        plot_y = centroid_y,
        observed_start_date = get(observed_start_date_variable),
        observed_end_date = get(observed_end_date_variable),
        observed_value = get(observed_variable),
        observed_se = NA_real_
      )
    ]
    predicted_rows <- predicted_data_plots[,
      .(
        PlotID,
        cell_id,
        cell_x,
        cell_y,
        predicted_start_date = get(predicted_start_date_variable),
        predicted_end_date = get(predicted_end_date_variable),
        predicted_value = get(predicted_variable),
        predicted_spatial_sd = NA_real_
      )
    ]

    merged_rows <- merge(observed_rows, predicted_rows, by = "PlotID")
    merged_rows[, period := period]
    merged_rows[, observed_variable := observed_variable]
    merged_rows[, predicted_variable := predicted_variable]
    merged_rows[, observed_spatial_aggregation := "exact"]
    merged_rows[, predicted_spatial_aggregation := "exact"]
    merged_rows[, observed_temporal_aggregation := "exact"]
    merged_rows[, predicted_temporal_aggregation := "exact"]
    merged_rows[, observed_spatial_extent := PlotID]
    merged_rows[, predicted_spatial_extent := cell_id]
    merged_rows[,
      observed_temporal_extent := paste(
        observed_start_date,
        "to",
        observed_end_date
      )
    ]
    merged_rows[,
      predicted_temporal_extent := paste(
        predicted_start_date,
        "to",
        predicted_end_date
      )
    ]
    merged_rows[, observed_units := variable_units]
    merged_rows[, predicted_units := variable_units]
    merged_rows[]
  }),
  fill = TRUE
)

if (anyNA(comparison_rows$predicted_value)) {
  stop("Some plot-cell rows have no predicted mortality for a census period.")
}

setcolorder(
  comparison_rows,
  c(
    "PlotID",
    "cell_id",
    "plot_x",
    "plot_y",
    "cell_x",
    "cell_y",
    "period",
    "observed_start_date",
    "observed_end_date",
    "predicted_start_date",
    "predicted_end_date",
    "observed_variable",
    "predicted_variable",
    "observed_spatial_aggregation",
    "predicted_spatial_aggregation",
    "observed_temporal_aggregation",
    "predicted_temporal_aggregation",
    "observed_spatial_extent",
    "predicted_spatial_extent",
    "observed_temporal_extent",
    "predicted_temporal_extent",
    "observed_units",
    "predicted_units",
    "observed_value",
    "observed_se",
    "predicted_value",
    "predicted_spatial_sd"
  )
)

fwrite(
  comparison_rows,
  file.path(output_dir, "mortality_comparison_maliau_2.csv")
)
