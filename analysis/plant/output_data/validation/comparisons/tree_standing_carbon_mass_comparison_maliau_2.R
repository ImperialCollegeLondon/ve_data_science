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
#|     description: |
#|       VE cell-time total and per-PFT standing carbon mass. Repeated total
#|       values are reduced to one cell-time row for comparison.
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
#|   - name: maliau_2_cells_and_observed_plots.png
#|     path: data/derived/plant/output_data/validation/comparisons/comparisons_figures_maliau_2
#|     description: VE cell IDs and observed plot footprints and centroids.
#|   - name: stem_c_mass_summed_across_pfts_by_cell.png
#|     path: data/derived/plant/output_data/validation/comparisons/comparisons_figures_maliau_2
#|     description: Stem carbon mass trajectories for cells overlapping observed plots, with census observations.
#|   - name: foliage_c_mass_summed_across_pfts_by_cell.png
#|     path: data/derived/plant/output_data/validation/comparisons/comparisons_figures_maliau_2
#|     description: Foliage carbon mass trajectories for cells overlapping observed plots, with census observations.
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
figures_dir <- file.path(output_dir, "comparisons_figures_maliau_2")
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)
figures_dir <- normalizePath(figures_dir, winslash = "/", mustWork = TRUE)
figure_file_names <- c(
  grid_and_observed_plots = "maliau_2_cells_and_observed_plots.png",
  stem_c_mass_kg_ha = "stem_c_mass_summed_across_pfts_by_cell.png",
  foliage_c_mass_kg_ha = "foliage_c_mass_summed_across_pfts_by_cell.png"
)

observed_data <- fread(observed_data_file)
predicted_data <- fread(predicted_data_file)
mapping <- yaml::yaml.load_file(mapping_file)$variable_mappings
grid_definition <- read_toml(grid_definition_file)
site_definition <- grid_definition$Scenario$maliau_2

observed_data[, census_date_2011 := as.Date(census_date_2011)]
observed_data[, census_date_2014 := as.Date(census_date_2014)]
predicted_data <- unique(
  predicted_data[, .(
    cell_id,
    cell_x,
    cell_y,
    timestep_end_date,
    timestep_start_date,
    time_index,
    stem_c_mass_kg_ha,
    foliage_c_mass_kg_ha
  )],
  by = c("cell_id", "time_index")
)
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
dev.copy(
  png,
  filename = file.path(
    figures_dir,
    figure_file_names[["grid_and_observed_plots"]]
  ),
  width = 1800,
  height = 1350,
  res = 150
)
dev.off()

# Compare observed plot masses with totals for overlapping cells.
plot_cell_ids <- unique(plot_cell_matches$cell_id)
plot_cell_mass_kg_ha <- predicted_data[cell_id %in% plot_cell_ids][
  order(timestep_end_date)
]
cell_colours <- hcl.colors(length(plot_cell_ids), palette = "Dark 3")
tissue_plots <- c(
  stem_c_mass_kg_ha = "Stem carbon mass",
  foliage_c_mass_kg_ha = "Foliage carbon mass"
)

old_par <- par(mfrow = c(1, 1), mar = c(3, 4, 2, 1))
for (tissue_column in names(tissue_plots)) {
  observed_prefix <- if (tissue_column == "stem_c_mass_kg_ha") {
    "obs_stem_mass"
  } else {
    "obs_leaf_mass"
  }
  observed_2011 <- observed_data[[paste0(observed_prefix, "_2011_kg_ha")]]
  observed_2014 <- observed_data[[paste0(observed_prefix, "_2014_kg_ha")]]
  first_cell_mass_kg_ha <-
    plot_cell_mass_kg_ha[cell_id == plot_cell_ids[1]]
  plot(
    first_cell_mass_kg_ha$timestep_end_date,
    first_cell_mass_kg_ha[[tissue_column]],
    type = "l",
    ylim = range(
      c(plot_cell_mass_kg_ha[[tissue_column]], observed_2011, observed_2014),
      na.rm = TRUE
    ),
    col = cell_colours[1],
    lwd = 0.6,
    xlab = "Model date",
    ylab = "kg C ha-1",
    main = paste(tissue_plots[[tissue_column]], "per overlapping cell")
  )
  for (index in seq_along(plot_cell_ids)) {
    cell_mass_kg_ha_for_plot <-
      plot_cell_mass_kg_ha[cell_id == plot_cell_ids[index]]
    lines(
      cell_mass_kg_ha_for_plot$timestep_end_date,
      cell_mass_kg_ha_for_plot[[tissue_column]],
      col = cell_colours[index],
      lwd = 0.6
    )
  }
  points(
    observed_data$census_date_2011,
    observed_2011,
    pch = 16,
    col = "black"
  )
  text(
    observed_data$census_date_2011,
    observed_2011,
    labels = observed_data$PlotID,
    pos = 4,
    cex = 0.65
  )
  points(
    observed_data$census_date_2014,
    observed_2014,
    pch = 17,
    col = "black"
  )
  text(
    observed_data$census_date_2014,
    observed_2014,
    labels = observed_data$PlotID,
    pos = 4,
    cex = 0.65
  )
  legend(
    "topright",
    legend = c("Observed 2011", "Observed 2014"),
    pch = c(16, 17),
    col = "black",
    bty = "n"
  )
  dev.copy(
    png,
    filename = file.path(figures_dir, figure_file_names[[tissue_column]]),
    width = 1800,
    height = 1350,
    res = 150
  )
  dev.off()
}
par(old_par)

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
        timestep_start_date,
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
      timestep_start_date < observed_date & observed_date <= predicted_date
    ]
    if (nrow(merged_rows) != nrow(observed_rows)) {
      stop("Each plot-cell-date row must match exactly one predicted interval.")
    }
    merged_rows[, observed_variable := observed_variable]
    merged_rows[, predicted_variable := predicted_variable]
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
    merged_rows[, observed_units := "kg C ha-1"]
    merged_rows[, predicted_units := "kg C ha-1"]
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
    "timestep_start_date",
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
    "predicted_value"
  )
)

fwrite(
  comparison_rows,
  file.path(output_dir, "tree_standing_carbon_mass_comparison_maliau_2.csv")
)
