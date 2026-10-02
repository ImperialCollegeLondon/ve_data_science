#| ---
#| title: tree_standing_carbon_mass_maliau_2
#|
#| description: |
#|   This script calculates Virtual Ecosystem standing stem and foliage carbon
#|   mass for every Maliau-2 grid cell and model timestep. Cohort-level biomass
#|   is multiplied by cohort abundance, summed across cohorts, and standardised
#|   to kg C ha-1.
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
#|   - name: plants_cohort_data.csv
#|     path: data/scenarios/maliau/maliau_2/out
#|     description: |
#|       Virtual Ecosystem plant cohort biomass, abundance, cell identifiers,
#|       and timesteps.
#|   - name: maliau_grid_definition.toml
#|     path: data/derived/site/maliau
#|     description: Maliau-2 grid geometry, cell IDs, and cell resolution.
#|   - name: compiled_configuration.toml
#|     path: data/scenarios/maliau/maliau_2/out
#|     description: Simulation start date and update interval.
#|   - name: tree_standing_carbon_mass_maliau.csv
#|     path: data/derived/plant/output_data/validation/observed_data_processing
#|     description: Observed plot data used for diagnostic figures only.
#|
#| output_files:
#|   - name: tree_standing_carbon_mass_maliau_2.csv
#|     path: data/derived/plant/output_data/validation/predicted_outputs_processing
#|     description: |
#|       Cell-level Virtual Ecosystem standing stem and foliage carbon mass.
#|     variables:
#|       - name: cell_id
#|         type: integer
#|         units: dimensionless
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Each model timestep.
#|         description: Zero-based Virtual Ecosystem cell identifier.
#|       - name: cell_x
#|         type: numeric
#|         units: m
#|         spatial_extent: Cell centre.
#|         temporal_extent: null
#|         description: Cell centre easting in the grid CRS.
#|       - name: cell_y
#|         type: numeric
#|         units: m
#|         spatial_extent: Cell centre.
#|         temporal_extent: null
#|         description: Cell centre northing in the grid CRS.
#|       - name: exact_time
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Exact model timestep.
#|         description: Timestep end date; timestep zero ends after one interval.
#|       - name: interval_start_time
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Start of the model timestep.
#|         description: Model date at the start of the timestep.
#|       - name: time_index
#|         type: integer
#|         units: dimensionless
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Model timestep index.
#|         description: Zero-based Virtual Ecosystem timestep index.
#|       - name: stem_c_mass_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Exact model timestep.
#|         description: Standing stem carbon mass per hectare.
#|       - name: foliage_c_mass_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Exact model timestep.
#|         description: Standing foliage carbon mass per hectare.
#|       - name: units
#|         type: character
#|         units: dimensionless
#|         spatial_extent: All output rows.
#|         temporal_extent: null
#|         description: Units for the standing carbon mass fields.
#|
#| package_dependencies:
#|   - data.table
#|   - sf
#|   - toml
#|   - reticulate
#|
#| usage_notes: |
#|   Initialisation rows without whole_crown_gpp are excluded before cohort
#|   aggregation to avoid double-counting timestep zero.
#| ---

library(data.table)
library(sf)
library(toml)
library(reticulate)

# Input files and paths -----------------------------------------------------

observed_data_path <-
  "../../../../../data/derived/plant/output_data/validation/observed_data_processing/tree_standing_carbon_mass_maliau.csv"
grid_definition_path <-
  "../../../../../data/derived/site/maliau/maliau_grid_definition.toml"
plants_cohort_data_path <-
  "../../../../../data/scenarios/maliau/maliau_2/out/plants_cohort_data.csv"
compiled_configuration_path <-
  "../../../../../data/scenarios/maliau/maliau_2/out/compiled_configuration.toml"

# Load and validate observed data used by diagnostic figures ----------------

observed_data <- fread(observed_data_path)
observed_data[, census_date_2011 := as.Date(census_date_2011)]
observed_data[, census_date_2014 := as.Date(census_date_2014)]
required_observed_columns <- c(
  "PlotID",
  "plot_area_m2",
  "plot_x",
  "plot_y",
  "census_date_2011",
  "census_date_2014",
  "obs_stem_mass_2011_kg_ha",
  "obs_stem_mass_2014_kg_ha",
  "obs_leaf_mass_2011_kg_ha",
  "obs_leaf_mass_2014_kg_ha"
)
missing_observed_columns <- setdiff(
  required_observed_columns,
  names(observed_data)
)
if (length(missing_observed_columns) > 0) {
  stop(
    "Observed data are missing: ",
    paste(missing_observed_columns, collapse = ", ")
  )
}

# Load grid definition and model timing ------------------------------------

grid_definition <- read_toml(grid_definition_path)
site_definition <- grid_definition$Scenario$maliau_2
cell_size_m <- site_definition$res
cell_area_ha <- cell_size_m^2 / 10000

# Use the same Pint-based timestep conversion as the productivity workflow.
compiled_configuration <- read_toml(compiled_configuration_path)
simulation_start_date <- as.Date(
  compiled_configuration$core$timing$start_date
)
update_interval <- compiled_configuration$core$timing$update_interval
use_virtualenv("../../../../../.venv", required = TRUE)
pint <- import("pint")
ureg <- pint$UnitRegistry()
timestep_interval_in_days <-
  ureg(update_interval)$to("days")$magnitude

# Build the regular Maliau-2 cell grid --------------------------------------

# VE cell IDs start at zero and follow the same x-fastest ordering as the
# expand.grid() cell layout used to create the model input.
grid_cells <- as.data.table(expand.grid(
  cell_x = site_definition$cell_x_centres,
  cell_y = site_definition$cell_y_centres
))
grid_cells[, cell_id := .I - 1L]

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

cell_polygons <- st_sf(
  grid_cells,
  geometry = st_sfc(
    Map(
      make_square,
      grid_cells$cell_x,
      grid_cells$cell_y,
      MoreArgs = list(side_length = cell_size_m)
    ),
    crs = site_definition$epsg_code
  )
)

# Match observed plot footprints to overlapping VE cells --------------------

plot_points <- st_as_sf(
  observed_data,
  coords = c("plot_x", "plot_y"),
  crs = 4326,
  remove = FALSE
)
# Plot coordinates are stored in WGS84; cell geometry is built in the grid's
# projected CRS so distances and plot areas are measured in metres.
plot_points <- st_transform(plot_points, site_definition$epsg_code)

# Reconstruct each plot as a square centred on its observed coordinates. The
# square side is derived from the recorded plot area, normally 25 m.
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

# Keep every plot-cell intersection because one plot may overlap multiple cells.
# Each resulting row represents one observed plot and one corresponding VE cell.
plot_cell_matches <- st_join(
  plot_polygons,
  cell_polygons[, c("cell_id", "cell_x", "cell_y")],
  join = st_intersects,
  left = FALSE
)
plot_cell_matches <- as.data.table(st_drop_geometry(plot_cell_matches))

# Diagnostic figure: verify the grid and plot-cell intersections -------------
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

# Load and filter the large VE cohort output -------------------------------
# Only the fields needed for the standing-mass calculation are loaded. This
# avoids loading the full plants_cohort_data.csv into memory.
required_columns <- c(
  "cell_id",
  "time",
  "time_index",
  "n_individuals",
  "whole_crown_gpp",
  "stem_c_biomass",
  "foliage_c_biomass"
)
plants_cohort_data <- data.table::fread(
  plants_cohort_data_path,
  select = required_columns,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

# Exclude initialisation rows, which have no computed GPP and would otherwise
# duplicate the timestep-0 biomass.
plants_cohort_data <- plants_cohort_data[!is.na(whole_crown_gpp)]

# Aggregate cohort biomass to cell and exact timestep -----------------------
# Convert per-individual biomass to total cohort biomass before summing.
plants_cohort_data[, cell_id := as.integer(cell_id)]
plants_cohort_data[, time_index := as.numeric(time_index)]
plants_cohort_data[, n_individuals := as.numeric(n_individuals)]
plants_cohort_data[, stem_c_biomass := as.numeric(stem_c_biomass)]
plants_cohort_data[, foliage_c_biomass := as.numeric(foliage_c_biomass)]
plants_cohort_data[,
  exact_time := simulation_start_date +
    (time_index + 1) * timestep_interval_in_days
]

cell_mass <- plants_cohort_data[,
  .(
    stem_c_mass = sum(stem_c_biomass * n_individuals, na.rm = TRUE),
    foliage_c_mass = sum(foliage_c_biomass * n_individuals, na.rm = TRUE)
  ),
  by = .(cell_id, exact_time, time_index)
]
cell_mass[,
  interval_start_time := simulation_start_date +
    time_index * timestep_interval_in_days
]

# Standardise cell totals to kg C ha-1 ---------------------------------------
cell_mass[, stem_c_mass_kg_ha := stem_c_mass / cell_area_ha]
cell_mass[, foliage_c_mass_kg_ha := foliage_c_mass / cell_area_ha]

# Diagnostic figures: inspect all 100 VE cell trajectories -------------------
plot_cell_ids <- grid_cells$cell_id
plot_cell_mass <- cell_mass[
  cell_id %in% plot_cell_ids
][order(exact_time)]

cell_values <- lapply(
  plot_cell_ids,
  function(cell) plot_cell_mass[cell_id == cell]
)
cell_colours <- hcl.colors(length(plot_cell_ids), palette = "Dark 3")

tissue_plots <- c(
  stem_c_mass_kg_ha = "Stem carbon mass",
  foliage_c_mass_kg_ha = "Foliage carbon mass"
)

# Each loop iteration creates a separate figure for one tissue type.
old_par <- par(mfrow = c(1, 1), mar = c(3, 4, 2, 1))
for (tissue_column in names(tissue_plots)) {
  observed_prefix <- if (tissue_column == "stem_c_mass_kg_ha") {
    "obs_stem_mass"
  } else {
    "obs_leaf_mass"
  }
  observed_2011 <- observed_data[[paste0(observed_prefix, "_2011_kg_ha")]]
  observed_2014 <- observed_data[[paste0(observed_prefix, "_2014_kg_ha")]]
  plot(
    cell_values[[1]]$exact_time,
    cell_values[[1]][[tissue_column]],
    type = "l",
    ylim = range(
      c(plot_cell_mass[[tissue_column]], observed_2011, observed_2014),
      na.rm = TRUE
    ),
    col = cell_colours[1],
    lwd = 0.6,
    xlab = "Model date",
    ylab = "kg C ha-1",
    main = paste(tissue_plots[[tissue_column]], "for all 100 VE cells")
  )
  for (index in seq_along(cell_values)) {
    lines(
      cell_values[[index]]$exact_time,
      cell_values[[index]][[tissue_column]],
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
  points(
    observed_data$census_date_2014,
    observed_2014,
    pch = 17,
    col = "black"
  )
  legend(
    "topright",
    legend = c("Observed 2011", "Observed 2014"),
    pch = c(16, 17),
    col = "black",
    bty = "n"
  )
}
par(old_par)

# Additional simple diagnostic plots ----------------------------------------

plot(
  stem_c_mass_kg_ha ~ exact_time,
  data = cell_mass,
  ylim = range(
    c(
      cell_mass$stem_c_mass_kg_ha,
      observed_data$obs_stem_mass_2011_kg_ha,
      observed_data$obs_stem_mass_2014_kg_ha
    ),
    na.rm = TRUE
  )
)
points(
  observed_data$census_date_2011,
  observed_data$obs_stem_mass_2011_kg_ha,
  pch = 16,
  col = "black"
)
points(
  observed_data$census_date_2014,
  observed_data$obs_stem_mass_2014_kg_ha,
  pch = 17,
  col = "black"
)
#plot(stem_c_mass_kg_ha~exact_time, data=cell_mass[cell_mass$time_index>0])
#plot(stem_c_mass_kg_ha~exact_time, data=cell_mass[cell_mass$time_index>1])
#plot(stem_c_mass_kg_ha~exact_time, data=cell_mass[cell_mass$time_index>5])
#plot(stem_c_mass_kg_ha~exact_time, data=cell_mass[cell_mass$time_index>10])

plot(
  foliage_c_mass_kg_ha ~ exact_time,
  data = cell_mass,
  ylim = range(
    c(
      cell_mass$foliage_c_mass_kg_ha,
      observed_data$obs_leaf_mass_2011_kg_ha,
      observed_data$obs_leaf_mass_2014_kg_ha
    ),
    na.rm = TRUE
  )
)
points(
  observed_data$census_date_2011,
  observed_data$obs_leaf_mass_2011_kg_ha,
  pch = 16,
  col = "black"
)
points(
  observed_data$census_date_2014,
  observed_data$obs_leaf_mass_2014_kg_ha,
  pch = 17,
  col = "black"
)
#plot(foliage_c_mass_kg_ha~exact_time, data=cell_mass[cell_mass$time_index>0])
#plot(foliage_c_mass_kg_ha~exact_time, data=cell_mass[cell_mass$time_index>1])
#plot(foliage_c_mass_kg_ha~exact_time, data=cell_mass[cell_mass$time_index>5])
#plot(foliage_c_mass_kg_ha~exact_time, data=cell_mass[cell_mass$time_index>10])

# Plot for 3 consecutive timesteps to magnify the variability
plot(
  stem_c_mass_kg_ha ~ exact_time,
  data = cell_mass[cell_mass$time_index %in% c(50, 51, 52)]
)
plot(
  foliage_c_mass_kg_ha ~ exact_time,
  data = cell_mass[cell_mass$time_index %in% c(50, 51, 52)]
)

# Plot for 1 consecutive timesteps to magnify the variability
plot(
  stem_c_mass_kg_ha ~ exact_time,
  data = cell_mass[cell_mass$time_index %in% c(50)]
)
plot(
  foliage_c_mass_kg_ha ~ exact_time,
  data = cell_mass[cell_mass$time_index %in% c(50)]
)

# Write one row per VE cell and exact model timestep -------------------------
# Plot-specific observed
# values and comparison fields will be added by a separate script.
predicted_data <- merge(
  cell_mass,
  grid_cells[, .(cell_id, cell_x, cell_y)],
  by = "cell_id",
  all.x = TRUE,
  sort = FALSE
)
predicted_data[, units := "kg C ha-1"]
predicted_data <- predicted_data[, .(
  cell_id,
  cell_x,
  cell_y,
  exact_time,
  interval_start_time,
  time_index,
  stem_c_mass_kg_ha,
  foliage_c_mass_kg_ha,
  units
)]

output_dir <-
  "../../../../../data/derived/plant/output_data/validation/predicted_outputs_processing"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
data.table::fwrite(
  predicted_data,
  file.path(output_dir, "tree_standing_carbon_mass_maliau_2.csv")
)
