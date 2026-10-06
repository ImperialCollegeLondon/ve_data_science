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
#|   - name: model_data.nc
#|     path: data/scenarios/maliau/maliau_2/out
#|     description: VE cell IDs and projected cell-centre coordinates for the full grid.
#|   - name: tree_standing_carbon_mass_maliau.csv
#|     path: data/derived/plant/output_data/validation/observed_data_processing
#|     description: Observed plot data used for diagnostic figures only.
#|
#| output_files:
#|   - name: tree_standing_carbon_mass_maliau_2.csv
#|     path: data/derived/plant/output_data/validation/predicted_outputs_processing
#|     description: |
#|       Per-cell total and per-PFT standing stem and foliage carbon mass for
#|       each timestep. Total masses repeat across the PFT rows for each cell
#|       and timestep.
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
#|       - name: timestep_end_date
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Exact model timestep.
#|         description: End date of the model timestep.
#|       - name: timestep_start_date
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Start of the model timestep.
#|         description: Start date of the model timestep.
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
#|         description: Total standing stem carbon mass across PFTs, repeated on each PFT row.
#|       - name: foliage_c_mass_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Exact model timestep.
#|         description: Total standing foliage carbon mass across PFTs, repeated on each PFT row.
#|       - name: pft_name
#|         type: character
#|         units: dimensionless
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Exact model timestep.
#|         description: Plant functional type for the per-PFT mass fields.
#|       - name: stem_c_mass_per_pft_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Exact model timestep.
#|         description: Standing stem carbon mass per hectare for pft_name.
#|       - name: foliage_c_mass_per_pft_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Exact model timestep.
#|         description: Standing foliage carbon mass per hectare for pft_name.
#|       - name: units
#|         type: character
#|         units: dimensionless
#|         spatial_extent: All output rows.
#|         temporal_extent: null
#|         description: Units for the standing carbon mass fields.
#|   - name: stem_c_mass_by_pft_and_cell_all_time_indices_kg_ha.png
#|     path: data/derived/plant/output_data/validation/predicted_outputs_processing/predicted_outputs_processing_figures_maliau_2
#|     description: Stem carbon mass per PFT and cell, standardised to kg C ha-1.
#|   - name: foliage_c_mass_by_pft_and_cell_all_time_indices_kg_ha.png
#|     path: data/derived/plant/output_data/validation/predicted_outputs_processing/predicted_outputs_processing_figures_maliau_2
#|     description: Foliage carbon mass per PFT and cell, standardised to kg C ha-1.
#|   - name: stem_c_mass_by_pft_and_cell_from_time_index_4_kg_ha.png
#|     path: data/derived/plant/output_data/validation/predicted_outputs_processing/predicted_outputs_processing_figures_maliau_2
#|     description: Stem carbon mass per PFT and cell from timestep index 4 onward.
#|   - name: foliage_c_mass_by_pft_and_cell_from_time_index_4_kg_ha.png
#|     path: data/derived/plant/output_data/validation/predicted_outputs_processing/predicted_outputs_processing_figures_maliau_2
#|     description: Foliage carbon mass per PFT and cell from timestep index 4 onward.
#|   - name: stem_c_mass_mean_across_cells_all_time_indices_kg_ha.png
#|     path: data/derived/plant/output_data/validation/predicted_outputs_processing/predicted_outputs_processing_figures_maliau_2
#|     description: Mean total and PFT-specific stem carbon mass across grid cells for all timesteps.
#|   - name: foliage_c_mass_mean_across_cells_all_time_indices_kg_ha.png
#|     path: data/derived/plant/output_data/validation/predicted_outputs_processing/predicted_outputs_processing_figures_maliau_2
#|     description: Mean total and PFT-specific foliage carbon mass across grid cells for all timesteps.
#|   - name: stem_c_mass_mean_across_cells_from_time_index_4_kg_ha.png
#|     path: data/derived/plant/output_data/validation/predicted_outputs_processing/predicted_outputs_processing_figures_maliau_2
#|     description: Mean total and PFT-specific stem carbon mass across grid cells from timestep index 4 onward.
#|   - name: foliage_c_mass_mean_across_cells_from_time_index_4_kg_ha.png
#|     path: data/derived/plant/output_data/validation/predicted_outputs_processing/predicted_outputs_processing_figures_maliau_2
#|     description: Mean total and PFT-specific foliage carbon mass across grid cells from timestep index 4 onward.
#|
#| package_dependencies:
#|   - data.table
#|   - sf
#|   - toml
#|   - reticulate
#|   - xarray
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
model_data_path <-
  "../../../../../data/scenarios/maliau/maliau_2/out/model_data.nc"
figures_dir <-
  "../../../../../data/derived/plant/output_data/validation/predicted_outputs_processing/predicted_outputs_processing_figures_maliau_2"
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)
figures_dir <- normalizePath(
  figures_dir,
  winslash = "/",
  mustWork = TRUE
)

# Load and validate observed data used by diagnostic figures ----------------

observed_data <- fread(observed_data_path)
observed_data[, census_date_2011 := as.Date(census_date_2011)]
observed_data[, census_date_2014 := as.Date(census_date_2014)]

# Load grid definition and model timing ------------------------------------

grid_definition <- read_toml(grid_definition_path)
site_definition <- grid_definition$Scenario$maliau_2
cell_size_m <- site_definition$res
cell_area_ha <- cell_size_m^2 / 10000

# Use the Pint-based timestep duration calculation method (requires uv set up to
# access the VE Python environment)
# Note that this is currently always 1 month = 30.4375 days
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

# Use VE's own cell IDs and coordinates so this script does not recreate its
# cell ordering. These coordinates cover the full grid, including empty cells.
# Import xarray for reading model data using same VE Python environment as above.

xarray <- import("xarray")
model_data <- xarray$open_dataset(model_data_path)
grid_cells <- data.table(
  cell_id = as.integer(py_to_r(model_data$coords[["cell_id"]]$values)),
  cell_x = as.numeric(py_to_r(model_data$coords[["x"]]$values)),
  cell_y = as.numeric(py_to_r(model_data$coords[["y"]]$values))
)
model_data$close()

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
  "pft_name",
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
  timestep_end_date := simulation_start_date +
    (time_index + 1) * timestep_interval_in_days
]

# Calculate stem and foliage carbon mass per PFT, cell, and timestep. These
# values are for diagnostic plots because validation data are not PFT-resolved.
pft_cell_mass_kg <- plants_cohort_data[,
  .(
    stem_c_mass_kg_cell = sum(stem_c_biomass * n_individuals, na.rm = TRUE),
    foliage_c_mass_kg_cell = sum(
      foliage_c_biomass * n_individuals,
      na.rm = TRUE
    )
  ),
  by = .(pft_name, cell_id, timestep_end_date, time_index)
]
pft_cell_mass_kg_ha <- data.table::copy(pft_cell_mass_kg)
pft_cell_mass_kg_ha[, stem_c_mass_kg_ha := stem_c_mass_kg_cell / cell_area_ha]
pft_cell_mass_kg_ha[,
  foliage_c_mass_kg_ha := foliage_c_mass_kg_cell / cell_area_ha
]
pft_cell_mass_kg_ha[,
  c("stem_c_mass_kg_cell", "foliage_c_mass_kg_cell") := NULL
]

# Repeat for cell total
cell_mass_kg <- plants_cohort_data[,
  .(
    stem_c_mass_kg_cell = sum(stem_c_biomass * n_individuals, na.rm = TRUE),
    foliage_c_mass_kg_cell = sum(
      foliage_c_biomass * n_individuals,
      na.rm = TRUE
    )
  ),
  by = .(cell_id, timestep_end_date, time_index)
]
cell_mass_kg[,
  timestep_start_date := simulation_start_date +
    time_index * timestep_interval_in_days
]

# Standardise cell totals to kg C ha-1 ---------------------------------------
cell_mass_kg_ha <- data.table::copy(cell_mass_kg)
cell_mass_kg_ha[, stem_c_mass_kg_ha := stem_c_mass_kg_cell / cell_area_ha]
cell_mass_kg_ha[, foliage_c_mass_kg_ha := foliage_c_mass_kg_cell / cell_area_ha]
cell_mass_kg_ha[, c("stem_c_mass_kg_cell", "foliage_c_mass_kg_cell") := NULL]

# Diagnostic figures: inspect all 100 VE cell trajectories -------------------
plot_cell_ids <- grid_cells$cell_id

cell_colours <- hcl.colors(length(plot_cell_ids), palette = "Dark 3")
pft_names <- sort(unique(pft_cell_mass_kg_ha$pft_name))

tissue_plots <- c(
  stem_c_mass_kg_ha = "Stem carbon mass",
  foliage_c_mass_kg_ha = "Foliage carbon mass"
)
figure_file_names <- list(
  all_time_indices = c(
    stem_c_mass_kg_ha = "stem_c_mass_by_pft_and_cell_all_time_indices_kg_ha.png",
    foliage_c_mass_kg_ha = "foliage_c_mass_by_pft_and_cell_all_time_indices_kg_ha.png"
  ),
  from_time_index_4 = c(
    stem_c_mass_kg_ha = "stem_c_mass_by_pft_and_cell_from_time_index_4_kg_ha.png",
    foliage_c_mass_kg_ha = "foliage_c_mass_by_pft_and_cell_from_time_index_4_kg_ha.png"
  )
)

# Each PFT panel uses its own y-axis scale.
for (time_scope in names(figure_file_names)) {
  pft_plot_data <- if (time_scope == "all_time_indices") {
    pft_cell_mass_kg_ha
  } else {
    pft_cell_mass_kg_ha[time_index >= 4]
  }
  x_limits <- range(pft_plot_data$timestep_end_date)
  plot_rows <- ceiling(sqrt(length(pft_names)))
  plot_columns <- ceiling(length(pft_names) / plot_rows)

  for (tissue_column in names(tissue_plots)) {
    old_par <- par(
      mfrow = c(plot_rows, plot_columns),
      mar = c(3, 4, 2, 1),
      oma = c(0, 0, 2, 0)
    )
    for (pft in pft_names) {
      pft_data <- pft_plot_data[pft_name == pft][order(timestep_end_date)]
      pft_cell_ids <- intersect(plot_cell_ids, unique(pft_data$cell_id))
      first_cell <- pft_data[cell_id == pft_cell_ids[1]]

      plot(
        first_cell$timestep_end_date,
        first_cell[[tissue_column]],
        type = "n",
        xlim = x_limits,
        ylim = range(pft_data[[tissue_column]], na.rm = TRUE),
        xlab = "Timestep end date",
        ylab = "kg C ha-1",
        main = pft
      )
      for (cell_index in seq_along(pft_cell_ids)) {
        cell_data <- pft_data[cell_id == pft_cell_ids[cell_index]]
        lines(
          cell_data$timestep_end_date,
          cell_data[[tissue_column]],
          col = cell_colours[match(pft_cell_ids[cell_index], plot_cell_ids)],
          lwd = 0.6
        )
      }
    }
    mtext(tissue_plots[[tissue_column]], outer = TRUE, line = 0.5)
    par(old_par)
    dev.copy(
      png,
      filename = file.path(
        figures_dir,
        figure_file_names[[time_scope]][[tissue_column]]
      ),
      width = 1800,
      height = 1350,
      res = 150
    )
    dev.off()
  }
}

# Plot mean total and PFT-specific carbon mass across all grid cells.
time_steps <- unique(cell_mass_kg_ha[, .(time_index, timestep_end_date)])
pft_colours <- hcl.colors(length(pft_names), palette = "Dark 3")
mean_figure_file_names <- list(
  all_time_indices = c(
    stem_c_mass_kg_ha = "stem_c_mass_mean_across_cells_all_time_indices_kg_ha.png",
    foliage_c_mass_kg_ha = "foliage_c_mass_mean_across_cells_all_time_indices_kg_ha.png"
  ),
  from_time_index_4 = c(
    stem_c_mass_kg_ha = "stem_c_mass_mean_across_cells_from_time_index_4_kg_ha.png",
    foliage_c_mass_kg_ha = "foliage_c_mass_mean_across_cells_from_time_index_4_kg_ha.png"
  )
)

for (time_scope in names(mean_figure_file_names)) {
  scope_time_steps <- if (time_scope == "all_time_indices") {
    time_steps
  } else {
    time_steps[time_index >= 4]
  }
  cell_time_grid <- CJ(
    cell_id = grid_cells$cell_id,
    time_index = scope_time_steps$time_index,
    unique = TRUE
  )
  cell_time_grid <- merge(cell_time_grid, scope_time_steps, by = "time_index")
  pft_cell_time_grid <- CJ(
    pft_name = pft_names,
    cell_id = grid_cells$cell_id,
    time_index = scope_time_steps$time_index,
    unique = TRUE
  )
  pft_cell_time_grid <- merge(
    pft_cell_time_grid,
    scope_time_steps,
    by = "time_index"
  )

  for (tissue_column in names(tissue_plots)) {
    total_means <- merge(
      cell_time_grid,
      cell_mass_kg_ha[,
        c("cell_id", "time_index", tissue_column),
        with = FALSE
      ],
      by = c("cell_id", "time_index"),
      all.x = TRUE
    )
    total_means[is.na(get(tissue_column)), (tissue_column) := 0]
    total_means <- total_means[,
      .(
        mean_mass_kg_ha = mean(get(tissue_column))
      ),
      by = .(time_index, timestep_end_date)
    ]

    pft_means <- merge(
      pft_cell_time_grid,
      pft_cell_mass_kg_ha[,
        c("pft_name", "cell_id", "time_index", tissue_column),
        with = FALSE
      ],
      by = c("pft_name", "cell_id", "time_index"),
      all.x = TRUE
    )
    pft_means[is.na(get(tissue_column)), (tissue_column) := 0]
    pft_means <- pft_means[,
      .(
        mean_mass_kg_ha = mean(get(tissue_column))
      ),
      by = .(pft_name, time_index, timestep_end_date)
    ]

    plot(
      total_means$timestep_end_date,
      total_means$mean_mass_kg_ha,
      type = "l",
      col = "black",
      lwd = 2,
      ylim = range(
        c(total_means$mean_mass_kg_ha, pft_means$mean_mass_kg_ha),
        na.rm = TRUE
      ),
      xlab = "Timestep end date",
      ylab = paste(
        "Mean",
        tolower(tissue_plots[[tissue_column]]),
        "(kg C ha-1)"
      ),
      main = paste(
        "Mean",
        tolower(tissue_plots[[tissue_column]]),
        "across grid cells"
      )
    )
    for (pft_index in seq_along(pft_names)) {
      pft_data <- pft_means[pft_name == pft_names[pft_index]]
      setorder(pft_data, timestep_end_date)
      lines(
        pft_data$timestep_end_date,
        pft_data$mean_mass_kg_ha,
        col = pft_colours[pft_index],
        lwd = 2.5
      )
    }
    legend(
      "topright",
      legend = c("Total", pft_names),
      col = c("black", pft_colours),
      lty = 1,
      lwd = c(2, rep(2.5, length(pft_names))),
      ncol = 2,
      cex = 0.7,
      bty = "n"
    )
    dev.copy(
      png,
      filename = file.path(
        figures_dir,
        mean_figure_file_names[[time_scope]][[tissue_column]]
      ),
      width = 1800,
      height = 1350,
      res = 150
    )
    dev.off()
  }
}

# Write one row per VE cell, timestep, and PFT. Total mass values repeat for
# each PFT row; the per-PFT columns contain that PFT's contribution.
pft_mass_for_output <- pft_cell_mass_kg_ha[, .(
  cell_id,
  time_index,
  pft_name,
  stem_c_mass_per_pft_kg_ha = stem_c_mass_kg_ha,
  foliage_c_mass_per_pft_kg_ha = foliage_c_mass_kg_ha
)]
predicted_data <- merge(
  cell_mass_kg_ha,
  pft_mass_for_output,
  by = c("cell_id", "time_index"),
  all.x = TRUE,
  sort = FALSE
)
predicted_data <- merge(
  predicted_data,
  grid_cells[, .(cell_id, cell_x, cell_y)],
  by = "cell_id",
  all.x = TRUE,
  sort = FALSE
)
predicted_data[, units := "kg C ha-1"]
output_columns <- c(
  "cell_id",
  "cell_x",
  "cell_y",
  "timestep_end_date",
  "timestep_start_date",
  "time_index",
  "stem_c_mass_kg_ha",
  "foliage_c_mass_kg_ha",
  "pft_name",
  "stem_c_mass_per_pft_kg_ha",
  "foliage_c_mass_per_pft_kg_ha",
  "units"
)
predicted_data <- predicted_data[, output_columns, with = FALSE]

output_dir <-
  "../../../../../data/derived/plant/output_data/validation/predicted_outputs_processing"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
data.table::fwrite(
  predicted_data,
  file.path(output_dir, "tree_standing_carbon_mass_maliau_2.csv")
)
