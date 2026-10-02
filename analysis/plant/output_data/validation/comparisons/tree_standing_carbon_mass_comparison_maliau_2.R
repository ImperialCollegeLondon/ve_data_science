#| ---
#| title: tree_standing_carbon_mass_comparison_maliau_2
#|
#| description: |
#|   Compares observed plot-level tree standing carbon mass with Virtual
#|   Ecosystem cell-level stem and foliage carbon mass for Maliau-2. Each
#|   comparison row represents one observed plot, one overlapping VE cell,
#|   and one actual census date.
#|
#| virtual_ecosystem_module:
#|   - Plant
#|
#| author:
#|   - Arne Scheire
#|
#| status: wip
#|
#| input_files:
#|   - name: tree_standing_carbon_mass_maliau.csv
#|     path: data/derived/plant/output_data/validation/observed_data_processing
#|     description: Observed plot carbon mass, coordinates, and census dates.
#|   - name: tree_standing_carbon_mass_maliau_2.csv
#|     path: data/derived/plant/output_data/validation/predicted_outputs_processing
#|     description: VE cell-time standing carbon mass.
#|   - name: tree_standing_carbon_mass_mapping_maliau_2.yml
#|     path: analysis/plant/output_data/validation/variable_mapping
#|     description: Observed-to-predicted variable and date mappings.
#|   - name: maliau_grid_definition.toml
#|     path: data/derived/site/maliau
#|     description: Maliau-2 grid geometry and cell dimensions.
#|
#| output_files:
#|   - name: tree_standing_carbon_mass_comparison_maliau_2.csv
#|     path: data/derived/plant/output_data/validation/comparisons
#|     description: |
#|       Row-level observed and predicted stem and foliage carbon mass
#|       comparisons for each plot-cell-date combination.
#|
#| package_dependencies:
#|   - data.table
#|   - sf
#|   - toml
#|   - yaml
#|
#| usage_notes: |
#|   Observed plot values are repeated for every VE cell intersecting the plot
#|   footprint. These repeated comparison rows are not independent observations.
#| ---

library(data.table)
library(sf)
library(toml)
library(yaml)

observed_data_file <-
  "../../../../../data/derived/plant/output_data/validation/observed_data_processing/tree_standing_carbon_mass_maliau.csv"
predicted_data_file <-
  "../../../../../data/derived/plant/output_data/validation/predicted_outputs_processing/tree_standing_carbon_mass_maliau_2.csv"
mapping_file <-
  "../variable_mapping/tree_standing_carbon_mass_mapping_maliau_2.yml"
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

observed_data[, census_date_2011 := as.Date(census_date_2011)]
observed_data[, census_date_2014 := as.Date(census_date_2014)]
predicted_data[, exact_time := as.Date(exact_time)]
if (!"interval_start_time" %in% names(predicted_data)) {
  stop("Rerun predicted processing to export corrected timestep boundaries.")
}
predicted_data[, interval_start_time := as.Date(interval_start_time)]

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

# Recreate the plot-cell intersections used by the predicted processing.
grid_cells <- as.data.table(expand.grid(
  cell_x = site_definition$cell_x_centres,
  cell_y = site_definition$cell_y_centres
))
grid_cells[, cell_id := .I - 1L]
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
  coords = c("plot_x", "plot_y"),
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

# Build one observed row per plot, overlapping cell, and census date.
comparison_rows <- rbindlist(
  lapply(mapping, function(mapping_entry) {
    observed_variable <- mapping_entry$observed$variable
    observed_se_variable <- mapping_entry$observed$se_variable
    observed_date_variable <- mapping_entry$observed$date_variable
    predicted_variable <- mapping_entry$predicted$variable
    predicted_date_variable <- mapping_entry$predicted$date_variable

    observed_rows <- plot_cell_matches[,
      .(
        PlotID,
        plot_x,
        plot_y,
        cell_id,
        cell_x,
        cell_y,
        observed_date = get(observed_date_variable),
        observed_value = get(observed_variable),
        observed_se = get(observed_se_variable)
      )
    ]
    predicted_rows <- predicted_data[,
      .(
        cell_id,
        time_index,
        interval_start_time,
        predicted_date = get(predicted_date_variable),
        predicted_value = get(predicted_variable)
      )
    ]

    merged_rows <- merge(
      observed_rows,
      predicted_rows,
      by = "cell_id",
      allow.cartesian = TRUE
    )
    # Match the plot's representative date to the interval ending at predicted_date.
    # A date on the end boundary belongs to that completed timestep.
    merged_rows <- merged_rows[
      interval_start_time < observed_date & observed_date <= predicted_date
    ]
    if (nrow(merged_rows) != nrow(observed_rows)) {
      stop("Each plot-cell-date row must match exactly one predicted interval.")
    }
    merged_rows[, observed_variable := observed_variable]
    merged_rows[, predicted_variable := predicted_variable]
    merged_rows[, difference := predicted_value - observed_value]
    merged_rows[,
      relative_difference := fifelse(
        observed_value == 0,
        NA_real_,
        difference / observed_value
      )
    ]
    merged_rows[, units := "kg C ha-1"]
    merged_rows[, observed_period := as.character(observed_date)]
    merged_rows[, predicted_period := as.character(predicted_date)]
    merged_rows[, observed_spatial_extent := paste("Plot", PlotID)]
    merged_rows[, predicted_spatial_extent := paste("VE cell", cell_id)]
    merged_rows[,
      observed_temporal_extent := "Standing stock at the plot's representative census date."
    ]
    merged_rows[,
      predicted_temporal_extent := "Standing stock at the end of the timestep identified by time_index."
    ]
    merged_rows[, observed_units := units]
    merged_rows[, predicted_units := units]
    merged_rows[]
  }),
  fill = TRUE
)

if (anyNA(comparison_rows$predicted_value)) {
  stop("Some matched predicted intervals have missing biomass values.")
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
    "observed_date",
    "interval_start_time",
    "predicted_date",
    "time_index",
    "observed_variable",
    "predicted_variable",
    "observed_period",
    "predicted_period",
    "observed_spatial_extent",
    "predicted_spatial_extent",
    "observed_temporal_extent",
    "predicted_temporal_extent",
    "observed_units",
    "predicted_units",
    "observed_value",
    "observed_se",
    "predicted_value",
    "difference",
    "relative_difference",
    "units"
  )
)

fwrite(
  comparison_rows,
  file.path(output_dir, "tree_standing_carbon_mass_comparison_maliau_2.csv")
)
