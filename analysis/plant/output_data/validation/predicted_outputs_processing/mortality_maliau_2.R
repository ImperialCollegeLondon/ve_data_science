#| ---
#| title: mortality_maliau_2
#|
#| description: |
#|   This script calculates Virtual Ecosystem tree mortality for every Maliau-2
#|   grid cell and model timestep for initial cohorts only (trees present at
#|   simulation start, dbh > 0.002 m). Cohort-level mortality (count and
#|   fraction of initial trees) is standardised to per hectare and per year.
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
#|   - name: plants_cohort_data.csv
#|     path: data/scenarios/maliau/maliau_2/out
#|     description: |
#|       Virtual Ecosystem plant cohort data including cohort identifiers, cell
#|       coordinates (cell_x, cell_y), plant functional types, DBH values,
#|       abundance, crown GPP, and timesteps.
#|   - name: maliau_grid_definition.toml
#|     path: data/derived/site/maliau
#|     description: Maliau-2 grid geometry, cell IDs, and cell resolution.
#|   - name: compiled_configuration.toml
#|     path: data/scenarios/maliau/maliau_2/out
#|     description: Simulation start date and update interval.
#|   - name: mortality_maliau.csv
#|     path: data/derived/plant/output_data/validation/observed_data_processing
#|     description: |
#|       One summary record per selected OG plot in Maliau-2, including
#|       interval mortality counts, annualised counts per hectare, and
#|       annualised fractions of the initial 2011 tree cohort.
#|
#| output_files:
#|   - name: mortality_maliau_2.csv
#|     path: data/derived/plant/output_data/validation/predicted_outputs_processing
#|     description: |
#|       Initial-cohort records by cell and model timestep, including annualised
#|       mortality counts and fractions. Cell- and plot-level summaries are
#|       repeated across the relevant cohort rows; plot fields are missing for
#|       cells without a matched observed plot.
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
#|       - name: cohort_id
#|         type: character
#|         units: dimensionless
#|         spatial_extent: Individual cohort within a cell.
#|         temporal_extent: null
#|         description: Virtual Ecosystem identifier for the plant cohort.
#|       - name: timestep_end_date
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Exact model timestep.
#|         description: End date of the model timestep.
#|       - name: time_index
#|         type: integer
#|         units: dimensionless
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Model timestep index.
#|         description: Zero-based Virtual Ecosystem timestep index.
#|       - name: pft_name
#|         type: character
#|         units: dimensionless
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Exact model timestep.
#|         description: Plant functional type for the per-PFT mass fields.
#|       - name: time
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Exact model timestep.
#|         description: Source model time value for this cohort record.
#|       - name: n_individuals
#|         type: numeric
#|         units: count
#|         spatial_extent: Individual cohort within a cell.
#|         temporal_extent: Exact model timestep.
#|         description: Number of individuals represented by the cohort.
#|       - name: whole_crown_gpp
#|         type: numeric
#|         units: null
#|         spatial_extent: Individual cohort within a cell.
#|         temporal_extent: Exact model timestep.
#|         description: Whole-crown gross primary productivity from the source data.
#|       - name: dbh_value
#|         type: numeric
#|         units: m
#|         spatial_extent: Individual cohort within a cell.
#|         temporal_extent: Exact model timestep.
#|         description: DBH value used to identify initial cohorts.
#|       - name: dbh
#|         type: numeric
#|         units: null
#|         spatial_extent: Individual cohort within a cell.
#|         temporal_extent: Exact model timestep.
#|         description: DBH field from the source cohort data.
#|       - name: cohort_mortality_count
#|         type: numeric
#|         units: count
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Exact model timestep.
#|         description: Mortality count for each of the initial cohorts (new
#|         recruits are excluded), for each cell and each timestep.
#|       - name: mortality_count
#|         type: numeric
#|         units: count
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Exact model timestep.
#|         description: Total mortality count across PFTs, for each cell and each
#|         timestep.
#|       - name: mortality_count_per_pft
#|         type: numeric
#|         units: count
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Exact model timestep.
#|         description: Mortality count per pft_name, for each cell and each
#|         timestep.
#|       - name: mortality_count_ha_yr
#|         type: numeric
#|         units: count ha-1 year-1
#|         spatial_extent: Single Maliau-2 grid cell, standardised to one hectare.
#|         temporal_extent: Annualised model timestep.
#|         description: Total annualised mortality count across PFTs,
#|         standardised to per hectare, for each cell and each timestep.
#|       - name: mortality_fraction_yr
#|         type: numeric
#|         units: year-1
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Annualised model timestep.
#|         description: Total annualised mortality fraction across PFTs,
#|         for each cell and each timestep.
#|       - name: PlotID
#|         type: character
#|         units: dimensionless
#|         spatial_extent: Matched observed plot, if present.
#|         temporal_extent: null
#|         description: Observed plot matched to the cell; NA when unmatched.
#|       - name: Date_2011
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: Matched observed plot, if present.
#|         temporal_extent: 2011 census date.
#|         description: Plot-specific 2011 census date.
#|       - name: Date_2014
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: Matched observed plot, if present.
#|         temporal_extent: 2014 census date.
#|         description: Plot-specific 2014 census date.
#|       - name: Date_2015
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: Matched observed plot, if present.
#|         temporal_extent: 2015 census date.
#|         description: Plot-specific 2015 census date.
#|       - name: Date_2017
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: Matched observed plot, if present.
#|         temporal_extent: 2017 census date.
#|         description: Plot-specific 2017 census date.
#|       - name: Date_2019
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: Matched observed plot, if present.
#|         temporal_extent: 2019 census date.
#|         description: Plot-specific 2019 census date.
#|       - name: mortality_count_11_14_ha_yr
#|         type: numeric
#|         units: count ha-1 year-1
#|         spatial_extent: Single Maliau-2 grid cell, standardised to one hectare.
#|         temporal_extent: Annualised, pooled model timesteps, matching the
#|         interval between observed census Date_2011 and Date_2014.
#|         description: Total annualised mortality count across PFTs for pooled
#|         model timesteps matching the interval between observed census Date_2011
#|         and Date_2014, standardised to per hectare.
#|       - name: mortality_fraction_11_14_yr
#|         type: numeric
#|         units: year-1
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Annualised, pooled model timesteps, matching the
#|         interval between observed census Date_2011 and Date_2014.
#|         description: Total annualised mortality fraction across PFTs for pooled
#|         model timesteps matching the interval between observed census Date_2011
#|         and Date_2014.
#|       - name: mortality_count_14_15_ha_yr
#|         type: numeric
#|         units: count ha-1 year-1
#|         spatial_extent: Single Maliau-2 grid cell, standardised to one hectare.
#|         temporal_extent: Annualised, pooled model timesteps, matching the
#|         interval between observed census Date_2014 and Date_2015.
#|         description: Total annualised mortality count across PFTs for pooled
#|         model timesteps matching the interval between observed census Date_2014
#|         and Date_2015, standardised to per hectare.
#|       - name: mortality_fraction_14_15_yr
#|         type: numeric
#|         units: year-1
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Annualised, pooled model timesteps, matching the
#|         interval between observed census Date_2014 and Date_2015.
#|         description: Total annualised mortality fraction across PFTs for pooled
#|         model timesteps matching the interval between observed census Date_2014
#|         and Date_2015.
#|       - name: mortality_count_15_17_ha_yr
#|         type: numeric
#|         units: count ha-1 year-1
#|         spatial_extent: Single Maliau-2 grid cell, standardised to one hectare.
#|         temporal_extent: Annualised, pooled model timesteps, matching the
#|         interval between observed census Date_2015 and Date_2017.
#|         description: Total annualised mortality count across PFTs for pooled
#|         model timesteps matching the interval between observed census Date_2015
#|         and Date_2017, standardised to per hectare.
#|       - name: mortality_fraction_15_17_yr
#|         type: numeric
#|         units: year-1
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Annualised, pooled model timesteps, matching the
#|         interval between observed census Date_2015 and Date_2017.
#|         description: Total annualised mortality fraction across PFTs for pooled
#|         model timesteps matching the interval between observed census Date_2015
#|         and Date_2017.
#|       - name: mortality_count_17_19_ha_yr
#|         type: numeric
#|         units: count ha-1 year-1
#|         spatial_extent: Single Maliau-2 grid cell, standardised to one hectare.
#|         temporal_extent: Annualised, pooled model timesteps, matching the
#|         interval between observed census Date_2017 and Date_2019.
#|         description: Total annualised mortality count across PFTs for pooled
#|         model timesteps matching the interval between observed census Date_2017
#|         and Date_2019, standardised to per hectare.
#|       - name: mortality_fraction_17_19_yr
#|         type: numeric
#|         units: year-1
#|         spatial_extent: Single Maliau-2 grid cell.
#|         temporal_extent: Annualised, pooled model timesteps, matching the
#|         interval between observed census Date_2017 and Date_2019.
#|         description: Total annualised mortality fraction across PFTs for pooled
#|         model timesteps matching the interval between observed census Date_2017
#|         and Date_2019.
#|
#| package_dependencies:
#|   - data.table
#|   - sf
#|   - toml
#|   - reticulate
#|
#| usage_notes: |
#|   Only initial cohorts are retained (timestep 0, dbh > 0.002 m) to match the
#|   validation dataset which comprises only 2011 census trees. Initialisation
#|   rows without whole_crown_gpp are excluded before cohort aggregation to avoid
#|   double-counting timestep zero. Observed data census dates (2015, 2017, 2019)
#|   are parsed and available for plot-level diagnostic comparisons.
#| ---

library(data.table)
library(sf)
library(toml)
library(reticulate)

# Input files and paths -----------------------------------------------------

observed_data_path <-
  "../../../../../data/derived/plant/output_data/validation/observed_data_processing/mortality_maliau.csv"
grid_definition_path <-
  "../../../../../data/derived/site/maliau/maliau_grid_definition.toml"
plants_cohort_data_path <-
  "../../../../../data/scenarios/maliau/maliau_2/out/plants_cohort_data.csv"
compiled_configuration_path <-
  "../../../../../data/scenarios/maliau/maliau_2/out/compiled_configuration.toml"

# Load and validate observed data used by diagnostic figures ----------------

observed_data <- fread(observed_data_path)
observed_data[, Date_2011 := as.Date(Date_2011)]
observed_data[, Date_2014 := as.Date(Date_2014)]
observed_data[, Date_2015 := as.Date(Date_2015)]
observed_data[, Date_2017 := as.Date(Date_2017)]
observed_data[, Date_2019 := as.Date(Date_2019)]

# Load grid definition and model timing ------------------------------------

grid_definition <- read_toml(grid_definition_path)
site_definition <- grid_definition$Scenario$maliau_2
cell_length_m <- site_definition$res
cell_area_ha <- cell_length_m^2 / 10000

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

grid_cells <- data.table::as.data.table(expand.grid(
  cell_x = as.numeric(
    unlist(site_definition$cell_x_centres, use.names = FALSE)
  ),
  cell_y = as.numeric(
    unlist(site_definition$cell_y_centres, use.names = FALSE)
  )
))
# Set the origin manually: use either "top-left" or "bottom-left".
cell_id_origin <- "bottom-left"

# Order coordinates from left to right within each row.
# Reverse the y order when the origin should be at the top of the grid.
grid_order <- order(
  if (cell_id_origin == "top-left") -grid_cells$cell_y else grid_cells$cell_y,
  grid_cells$cell_x
)
grid_cells$cell_id <- NA_integer_
grid_cells$cell_id[grid_order] <- seq_len(nrow(grid_cells)) - 1L

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
      MoreArgs = list(side_length = cell_length_m)
    ),
    crs = site_definition$epsg_code
  )
)

# Match observed plot footprints to overlapping VE cells --------------------

plot_points <- st_as_sf(
  observed_data,
  coords = c("centroid_x", "centroid_y"),
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

column_names <- names(
  data.table::fread(plants_cohort_data_path, nrows = 0)
)
print(column_names)

required_columns <- c(
  "cell_x",
  "cell_y",
  "cohort_id",
  "pft_name",
  "time",
  "time_index",
  "n_individuals",
  "whole_crown_gpp",
  "dbh_value",
  "dbh"
)
plants_cohort_data <- data.table::fread(
  plants_cohort_data_path,
  select = required_columns,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

# Add cell_id here based on the mapping earlier
plants_cohort_data$cell_id <- grid_cells$cell_id[
  match(
    paste(plants_cohort_data$cell_x, plants_cohort_data$cell_y),
    paste(grid_cells$cell_x, grid_cells$cell_y)
  )
]

# Add PlotID
plants_cohort_data$PlotID <- plot_cell_matches$PlotID[
  match(plants_cohort_data$cell_id, plot_cell_matches$cell_id)
]

# To include mortality in the first timestep (0) we need to include the
# initialiation rows. However, because new recruits are only added at the end of
# the first timestep (and are thus not included as cohorts in the initialisation
# rows) - and because we don't want to focus on new recruit mortality anyway in
# this particular validation script, we should exclude the new recruit cohorts
# found under timestep 0.

# We can filter to the correct initial cohorts by taking the unique cohorts at
# timestep 0 and excluding those with dbh below 0.002 (as this is the starting
# dbh for all new recruits). Note that if this initial dbh value for new recruits
# changes in the future VE code, this script will require updating.

initial_cohorts <-
  unique(plants_cohort_data$cohort_id[
    plants_cohort_data$time_index == 0 & plants_cohort_data$dbh_value > 0.002
  ])
length(initial_cohorts)

total_cohorts <- unique(plants_cohort_data$cohort_id)
length(total_cohorts)

# Subset to initial cohorts
plants_cohort_data <-
  plants_cohort_data[plants_cohort_data$cohort_id %in% initial_cohorts, ]

# Next we need to assign a value of -1 to the timestep of initialisation rows.
# This way we can loop over all timesteps when calculating mortality for each
# timestep, and then just remove the NA value for timestep -1. This is easier to
# do than to separate the processin multiple/different steps.
# To define the initialisation rows, use NA for whole_crown_gpp.

plants_cohort_data$time_index[is.na(plants_cohort_data$whole_crown_gpp)] <- -1

# Calculate cohort_mortality_count for each cell and timestep

plants_cohort_data[, cell_id := as.integer(cell_id)]
plants_cohort_data[, time_index := as.numeric(time_index)]
plants_cohort_data[, n_individuals := as.numeric(n_individuals)]
plants_cohort_data[,
  timestep_end_date := simulation_start_date +
    (time_index + 1) * timestep_interval_in_days
]

# cohort_mortality_count is calculated as the different in n-individuals within
# cohorts between consecutive timesteps. Note that new recruits will always
# receive a new cohort name of their own, and so increases in n_individuals
# should never occur. Hence, any reduction in n_individuals between consecutive
# timesteps should always be related to mortality.

data.table::setorder(plants_cohort_data, cell_id, cohort_id, time_index)
plants_cohort_data[, cohort_mortality_count := NA_real_]
plants_cohort_data[
  cohort_id %in% initial_cohorts,
  cohort_mortality_count := data.table::shift(n_individuals) - n_individuals,
  by = .(cell_id, cohort_id)
]

# Each value is the decrease from the previous timestep in the same cell and
# cohort. This assumes one row per consecutive timestep; the first row is NA.

# Next, calculate mortality_count (which is the total cohort_mortality_count
# per timestep for the entire cell across PFTs). The cell total is repeated on
# each matching cohort row.
plants_cohort_data[
  time_index >= 0,
  mortality_count := sum(cohort_mortality_count, na.rm = TRUE),
  by = .(cell_id, time_index)
]

# Next, calculate mortality_count_per_pft (which is the total
# cohort_mortality_count per timestep for the entire cell for each PFT)
# The PFT total is repeated on each matching cohort row.
plants_cohort_data[
  time_index >= 0,
  mortality_count_per_pft := sum(cohort_mortality_count, na.rm = TRUE),
  by = .(cell_id, time_index, pft_name)
]

# Next, calculate mortality_count_ha_yr (which is mortality_count standardised
# per hectare and divided by the timestep duration in years).
# Divide each cell's mortality count by its area and timestep duration in years.
plants_cohort_data[
  time_index >= 0,
  mortality_count_ha_yr := mortality_count /
    cell_area_ha /
    (timestep_interval_in_days / 365.25)
]

# Next, calculate mortality_fraction_yr (which is mortality_count divided by the
# initial trees present during initialisation in the entire cell, and divided by
# the timestep duration in years).
# The denominator is the total initial cohort abundance in each cell.
plants_cohort_data[,
  mortality_fraction_yr := mortality_count /
    sum(n_individuals[time_index == -1], na.rm = TRUE) /
    (timestep_interval_in_days / 365.25),
  by = cell_id
]

##########

# Next, calculate mortality_count_11_14_ha_yr (which is similar to the approach
# to calculate mortality_count_ha_yr but calculates the mortality across the
# simulation period). So, calculate the amount of individuals that died during the
# timesteps that correspond to the census start and end date (these can be found
# in observed_data - for 11_14 use interval_11_14_yr), and then scale this value
# to account for cell area, and divide by the interval duration (i.e., simulation
# timestep end minus start date - in years) to obtain an annualised mortality
# count that is area standardised and is representative for the census period
# duration.

# Add census dates to plants_cohort_data from observed_data

observed_row <- match(plants_cohort_data$PlotID, observed_data$PlotID)

date_columns <- c(
  "Date_2011",
  "Date_2014",
  "Date_2015",
  "Date_2017",
  "Date_2019"
)

for (column in date_columns) {
  plants_cohort_data[[column]] <- observed_data[[column]][observed_row]
}

#####

# For each cell-plot group, find the timesteps containing the census dates.
# Sum cohort deaths across that inclusive range, then annualise by interval and
# cell area. The result is repeated on each cohort row in the group.
plants_cohort_data[
  !is.na(PlotID) & !is.na(Date_2011) & !is.na(Date_2014),
  mortality_count_11_14_ha_yr := {
    start_timestep <- min(time_index[
      time_index >= 0 &
        timestep_end_date - timestep_interval_in_days < Date_2011[1] &
        Date_2011[1] <= timestep_end_date
    ])
    end_timestep <- min(time_index[
      time_index >= 0 &
        timestep_end_date - timestep_interval_in_days < Date_2014[1] &
        Date_2014[1] <= timestep_end_date
    ])
    sum(
      cohort_mortality_count[
        time_index >= start_timestep & time_index <= end_timestep
      ],
      na.rm = TRUE
    ) /
      cell_area_ha /
      (as.numeric(Date_2014[1] - Date_2011[1]) / 365.25)
  },
  by = .(cell_id, PlotID)
]

#####

plants_cohort_data[
  !is.na(PlotID) & !is.na(Date_2014) & !is.na(Date_2015),
  mortality_count_14_15_ha_yr := {
    start_timestep <- min(time_index[
      time_index >= 0 &
        timestep_end_date - timestep_interval_in_days < Date_2014[1] &
        Date_2014[1] <= timestep_end_date
    ])
    end_timestep <- min(time_index[
      time_index >= 0 &
        timestep_end_date - timestep_interval_in_days < Date_2015[1] &
        Date_2015[1] <= timestep_end_date
    ])
    sum(
      cohort_mortality_count[
        time_index >= start_timestep & time_index <= end_timestep
      ],
      na.rm = TRUE
    ) /
      cell_area_ha /
      (as.numeric(Date_2015[1] - Date_2014[1]) / 365.25)
  },
  by = .(cell_id, PlotID)
]

#####

plants_cohort_data[
  !is.na(PlotID) & !is.na(Date_2015) & !is.na(Date_2017),
  mortality_count_15_17_ha_yr := {
    start_timestep <- min(time_index[
      time_index >= 0 &
        timestep_end_date - timestep_interval_in_days < Date_2015[1] &
        Date_2015[1] <= timestep_end_date
    ])
    end_timestep <- min(time_index[
      time_index >= 0 &
        timestep_end_date - timestep_interval_in_days < Date_2017[1] &
        Date_2017[1] <= timestep_end_date
    ])
    sum(
      cohort_mortality_count[
        time_index >= start_timestep & time_index <= end_timestep
      ],
      na.rm = TRUE
    ) /
      cell_area_ha /
      (as.numeric(Date_2017[1] - Date_2015[1]) / 365.25)
  },
  by = .(cell_id, PlotID)
]

#####

plants_cohort_data[
  !is.na(PlotID) & !is.na(Date_2017) & !is.na(Date_2019),
  mortality_count_17_19_ha_yr := {
    start_timestep <- min(time_index[
      time_index >= 0 &
        timestep_end_date - timestep_interval_in_days < Date_2017[1] &
        Date_2017[1] <= timestep_end_date
    ])
    end_timestep <- min(time_index[
      time_index >= 0 &
        timestep_end_date - timestep_interval_in_days < Date_2019[1] &
        Date_2019[1] <= timestep_end_date
    ])
    sum(
      cohort_mortality_count[
        time_index >= start_timestep & time_index <= end_timestep
      ],
      na.rm = TRUE
    ) /
      cell_area_ha /
      (as.numeric(Date_2019[1] - Date_2017[1]) / 365.25)
  },
  by = .(cell_id, PlotID)
]

#####

unique(plants_cohort_data$mortality_count_11_14_ha_yr)
unique(observed_data$mortality_count_11_14_ha_yr)
mean(unique(plants_cohort_data$mortality_count_11_14_ha_yr), na.rm = TRUE)
mean(unique(observed_data$mortality_count_11_14_ha_yr), na.rm = TRUE)

unique(plants_cohort_data$mortality_count_14_15_ha_yr)
unique(observed_data$mortality_count_14_15_ha_yr)
mean(unique(plants_cohort_data$mortality_count_14_15_ha_yr), na.rm = TRUE)
mean(unique(observed_data$mortality_count_14_15_ha_yr), na.rm = TRUE)

unique(plants_cohort_data$mortality_count_15_17_ha_yr)
unique(observed_data$mortality_count_15_17_ha_yr)
mean(unique(plants_cohort_data$mortality_count_15_17_ha_yr), na.rm = TRUE)
mean(unique(observed_data$mortality_count_15_17_ha_yr), na.rm = TRUE)

unique(plants_cohort_data$mortality_count_17_19_ha_yr)
unique(observed_data$mortality_count_17_19_ha_yr)
mean(unique(plants_cohort_data$mortality_count_17_19_ha_yr), na.rm = TRUE)
mean(unique(observed_data$mortality_count_17_19_ha_yr), na.rm = TRUE)

#####

# Next, calculate mortality_fraction_11_14_yr (which is similar to the approach
# to calculate mortality_fraction_yr but calculates the mortality fraction across
# the entire simulation period). So, calculate the amount of individuals that died
# during the timesteps that correspond to the census start and end date (these
# can be found in observed_data - for 11_14 use interval_11_14_yr), and then
# scale this value to account for cell area, and divide by the interval duration
# (i.e., simulation timestep end minus start date - in years) to obtain an
# annualised mortality count that is area standardised and is representative for
# the census period duration.

# For each cell-plot group, sum deaths from the timestep containing Date_2011
# through the timestep containing Date_2014, then annualise by initial abundance.

plants_cohort_data[
  !is.na(PlotID) & !is.na(Date_2011) & !is.na(Date_2014),
  mortality_fraction_11_14_yr := {
    start_timestep <- min(time_index[
      time_index >= 0 &
        timestep_end_date - timestep_interval_in_days < Date_2011[1] &
        Date_2011[1] <= timestep_end_date
    ])
    end_timestep <- min(time_index[
      time_index >= 0 &
        timestep_end_date - timestep_interval_in_days < Date_2014[1] &
        Date_2014[1] <= timestep_end_date
    ])
    sum(
      cohort_mortality_count[
        time_index >= start_timestep & time_index <= end_timestep
      ],
      na.rm = TRUE
    ) /
      sum(n_individuals[time_index == -1], na.rm = TRUE) /
      (as.numeric(Date_2014[1] - Date_2011[1]) / 365.25)
  },
  by = .(cell_id, PlotID)
]

#####

plants_cohort_data[
  !is.na(PlotID) & !is.na(Date_2014) & !is.na(Date_2015),
  mortality_fraction_14_15_yr := {
    start_timestep <- min(time_index[
      time_index >= 0 &
        timestep_end_date - timestep_interval_in_days < Date_2014[1] &
        Date_2014[1] <= timestep_end_date
    ])
    end_timestep <- min(time_index[
      time_index >= 0 &
        timestep_end_date - timestep_interval_in_days < Date_2015[1] &
        Date_2015[1] <= timestep_end_date
    ])
    sum(
      cohort_mortality_count[
        time_index >= start_timestep & time_index <= end_timestep
      ],
      na.rm = TRUE
    ) /
      sum(n_individuals[time_index == -1], na.rm = TRUE) /
      (as.numeric(Date_2015[1] - Date_2014[1]) / 365.25)
  },
  by = .(cell_id, PlotID)
]

#####

plants_cohort_data[
  !is.na(PlotID) & !is.na(Date_2015) & !is.na(Date_2017),
  mortality_fraction_15_17_yr := {
    start_timestep <- min(time_index[
      time_index >= 0 &
        timestep_end_date - timestep_interval_in_days < Date_2015[1] &
        Date_2015[1] <= timestep_end_date
    ])
    end_timestep <- min(time_index[
      time_index >= 0 &
        timestep_end_date - timestep_interval_in_days < Date_2017[1] &
        Date_2017[1] <= timestep_end_date
    ])
    sum(
      cohort_mortality_count[
        time_index >= start_timestep & time_index <= end_timestep
      ],
      na.rm = TRUE
    ) /
      sum(n_individuals[time_index == -1], na.rm = TRUE) /
      (as.numeric(Date_2017[1] - Date_2015[1]) / 365.25)
  },
  by = .(cell_id, PlotID)
]

#####

plants_cohort_data[
  !is.na(PlotID) & !is.na(Date_2017) & !is.na(Date_2019),
  mortality_fraction_17_19_yr := {
    start_timestep <- min(time_index[
      time_index >= 0 &
        timestep_end_date - timestep_interval_in_days < Date_2017[1] &
        Date_2017[1] <= timestep_end_date
    ])
    end_timestep <- min(time_index[
      time_index >= 0 &
        timestep_end_date - timestep_interval_in_days < Date_2019[1] &
        Date_2019[1] <= timestep_end_date
    ])
    sum(
      cohort_mortality_count[
        time_index >= start_timestep & time_index <= end_timestep
      ],
      na.rm = TRUE
    ) /
      sum(n_individuals[time_index == -1], na.rm = TRUE) /
      (as.numeric(Date_2019[1] - Date_2017[1]) / 365.25)
  },
  by = .(cell_id, PlotID)
]

#####

unique(plants_cohort_data$mortality_fraction_11_14_yr)
unique(observed_data$mortality_fraction_11_14_yr)
mean(unique(plants_cohort_data$mortality_fraction_11_14_yr), na.rm = TRUE)
mean(unique(observed_data$mortality_fraction_11_14_yr), na.rm = TRUE)

unique(plants_cohort_data$mortality_fraction_14_15_yr)
unique(observed_data$mortality_fraction_14_15_yr)
mean(unique(plants_cohort_data$mortality_fraction_14_15_yr), na.rm = TRUE)
mean(unique(observed_data$mortality_fraction_14_15_yr), na.rm = TRUE)

unique(plants_cohort_data$mortality_fraction_15_17_yr)
unique(observed_data$mortality_fraction_15_17_yr)
mean(unique(plants_cohort_data$mortality_fraction_15_17_yr), na.rm = TRUE)
mean(unique(observed_data$mortality_fraction_15_17_yr), na.rm = TRUE)

unique(plants_cohort_data$mortality_fraction_17_19_yr)
unique(observed_data$mortality_fraction_17_19_yr)
mean(unique(plants_cohort_data$mortality_fraction_17_19_yr), na.rm = TRUE)
mean(unique(observed_data$mortality_fraction_17_19_yr), na.rm = TRUE)

#####

# Save file

predicted_data <- plants_cohort_data

# Subset based on what's needed for comparison, for now all columns and rows are
# kept.

names(predicted_data)
output_columns <- c(
  "cell_x",
  "cell_y",
  "cohort_id",
  "pft_name",
  "time",
  "time_index",
  "n_individuals",
  "whole_crown_gpp",
  "dbh_value",
  "dbh",
  "cell_id",
  "timestep_end_date",
  "cohort_mortality_count",
  "mortality_count",
  "mortality_count_per_pft",
  "mortality_count_ha_yr",
  "mortality_fraction_yr",
  "PlotID",
  "Date_2011",
  "Date_2014",
  "Date_2015",
  "Date_2017",
  "Date_2019",
  "mortality_count_11_14_ha_yr",
  "mortality_count_14_15_ha_yr",
  "mortality_count_15_17_ha_yr",
  "mortality_count_17_19_ha_yr",
  "mortality_fraction_11_14_yr",
  "mortality_fraction_14_15_yr",
  "mortality_fraction_15_17_yr",
  "mortality_fraction_17_19_yr"
)

predicted_data <- predicted_data[, output_columns, with = FALSE]

output_dir <-
  "../../../../../data/derived/plant/output_data/validation/predicted_outputs_processing"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
data.table::fwrite(
  predicted_data,
  file.path(output_dir, "mortality_maliau_2.csv")
)
