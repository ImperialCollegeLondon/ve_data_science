#| ---
#| title: gpp_and_npp_maliau_2
#|
#| description: |
#|   Calculates gpp and npp from Virtual Ecosystem plant cohort output for the
#|   Maliau 2 scenario. Cohort-level gpp and npp are multiplied by cohort
#|   individuals, corrected for cell area and timestep duration to give an
#|   annualised area-normalised rate per cell and timestep.
#|   These standardised gpp and npp values are also pooled across
#|   all cells and timesteps within the selected period into a single mean and
#|   standard deviation, matching the spatial and temporal extent of the
#|   validation data.
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
#|       Virtual Ecosystem plant cohort output containing gpp and npp carbon
#|       mass per individual, cohort abundance, cell coordinates, and timestep
#|       indices.
#|   - name: maliau_grid_definition.toml
#|     path: data/derived/site/maliau
#|     description: Maliau-2 grid coordinate vectors used to map cell IDs.
#|   - name: master_observed_data_processing_metadata.yml
#|     path: analysis/plant/output_data/validation/metadata
#|     description: |
#|       Provides the validation period (`period_start`/`period_end`) declared
#|       by carbon_balance_components_maliau.R, so the pooled mean/sd below
#|       always match the observed dataset's temporal extent. Requires
#|       master_observed_data_processing.R to have been run first.
#|
#| output_files:
#|   - name: gpp_and_npp_maliau_2.csv
#|     path: data/derived/plant/output_data/validation/predicted_outputs_processing
#|     description: |
#|       Gpp and npp in Mg C ha-1 year-1, with one row per cell and timestep,
#|       plus a pooled mean and standard deviation across all cells and
#|       timesteps within each variable's selected period. The mean/sd/period
#|       columns are `NA` for timesteps outside the selected period.
#|       The standard deviation describes variability across cells and intervals,
#|       not prediction uncertainty.
#|     variables:
#|       - name: cell_id
#|         type: integer
#|         units: dimensionless
#|         description: VE spatial cell identifier.
#|       - name: cell_x
#|         type: numeric
#|         units: m
#|         spatial_extent: Cell centre.
#|         description: Cell centre easting in the grid CRS.
#|       - name: cell_y
#|         type: numeric
#|         units: m
#|         spatial_extent: Cell centre.
#|         description: Cell centre northing in the grid CRS.
#|       - name: time
#|         type: date
#|         units: ISO 8601 date
#|         description: Interval-ending simulation date.
#|       - name: time_index
#|         type: integer
#|         units: dimensionless
#|         description: Interval-ending simulation timestep index.
#|       - name: gpp_selected_period
#|         type: character
#|         units: dimensionless
#|         description: Month-based period for pooled gpp mean/sd.
#|       - name: npp_selected_period
#|         type: character
#|         units: dimensionless
#|         description: Month-based period for pooled npp mean/sd.
#|       - name: units
#|         type: character
#|         units: dimensionless
#|         description: Units of the gpp and npp columns.
#|       - name: gpp
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Single cell (cell_id).
#|         temporal_extent: Single interval ending at time/time_index.
#|         description: Interval gpp for each cell.
#|       - name: gpp_mean
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Pooled across all cells.
#|         temporal_extent: |
#|           Pooled across all timesteps from start month 2011-08 to end month 2018-07.
#|         description: |
#|           Mean gpp pooled across all cells and
#|           timesteps in the selected period. NA outside that period.
#|       - name: gpp_sd
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Pooled across all cells.
#|         temporal_extent: |
#|           Pooled across all timesteps from start month 2011-08 to end month 2018-07.
#|         description: |
#|           Standard deviation of gpp pooled across all
#|           cells and timesteps in the selected period. NA outside that period.
#|       - name: npp
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Single cell (cell_id).
#|         temporal_extent: Single interval ending at time/time_index.
#|         description: Interval npp for each cell.
#|       - name: npp_mean
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Pooled across all cells.
#|         temporal_extent: |
#|           Pooled across all timesteps from start month 2011-08 to end month 2018-07.
#|         description: |
#|           Mean npp pooled across all cells and
#|           timesteps in the selected period. NA outside that period.
#|       - name: npp_sd
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Pooled across all cells.
#|         temporal_extent: |
#|           Pooled across all timesteps from start month 2011-08 to end month 2018-07.
#|         description: |
#|           Standard deviation of npp pooled across
#|           all cells and timesteps in the selected period. NA outside that
#|           period.
#|
#| package_dependencies:
#|   - data.table
#|   - yaml
#|   - toml
#|   - reticulate
#|
#| usage_notes: |
#|   If no period dates are supplied, the mean/sd are pooled across the entire
#|   simulation instead. Dates are matched by month.
#|   The validation data provide a single regional mean rather than
#|   observations for individual cells, so `<variable>_mean` (pooled across
#|   all cells and timesteps in the selected period) is the primary
#|   comparison value.
#|   Each variable's period is loaded at runtime from its own corresponding
#|   variable in master_observed_data_processing_metadata.yml:
#|   gpp -> GPP_WithoutMycorrhiza, npp -> TotalNPP_WithoutMycorrhiza.
#|   Input carbon masses are in kg C per individual per timestep for gpp and npp.
#|   Each variable has its own selected-period column.
#| ---

library(data.table)
library(yaml)
library(toml)
library(reticulate)

source("../../../../../tools/R/R/get_ve_variables.R")

plants_cohort_data_path <- "../../../../../data/scenarios/maliau/maliau_2/out/plants_cohort_data.csv"
grid_definition_path <- "../../../../../data/derived/site/maliau/maliau_grid_definition.toml"
observed_metadata_file <- "../metadata/master_observed_data_processing_metadata.yml"

compiled_configuration_path <- "../../../../../data/scenarios/maliau/maliau_2/out/compiled_configuration.toml"
compiled_configuration <- toml::read_toml(compiled_configuration_path)
grid_definition <- toml::read_toml(grid_definition_path)
site_definition <- grid_definition$Scenario$maliau_2
simulation_start_date <- as.Date(
  compiled_configuration$core$timing$start_date
)

# Define simulation timestep duration (days) and cell area (ha) for use in
# standardise_ve_cohort_carbon_output function
# Both are derived from compiled_configuration.toml
cell_area_m2 <- compiled_configuration$core$grid$cell_area
cell_area_ha <- cell_area_m2 / 10000

# Load the update interval from the config
update_interval <- compiled_configuration$core$timing$update_interval

# Use the repository Python environment for pint. This environment is managed by
# uv and includes the repository's dev group, so this pulls the installed
# virtual_ecosystem version rather than another Python environment.
# required = TRUE : R must find and use that environment.
# If it cannot, the script stops with an error instead of silently choosing
# another Python installation.
use_virtualenv("../../../../../.venv", required = TRUE)

# Import pint and create a unit registry
pint <- import("pint")
ureg <- pint$UnitRegistry()

# Use pint to convert to days and extract the magnitude
# ureg(update_interval_str) creates a Quantity object
# .to("days") converts it
# .magnitude extracts the numeric value
update_interval_in_days <- ureg(update_interval)$to("days")$magnitude

# Read only the columns needed for respiration and turnover to reduce
# memory pressure when this large scenario file is loaded into R. Using
# data.table::fread(select = ...) avoids a large header-only pass over the CSV.

column_names <- names(
  data.table::fread(plants_cohort_data_path, nrows = 0)
)
print(column_names)

required_columns <- c(
  "cell_x",
  "cell_y",
  "time_index",
  "n_individuals",
  "whole_crown_gpp",
  "npp"
)
plants_cohort_data <- data.table::fread(
  plants_cohort_data_path,
  select = required_columns,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
plants_cohort_data[, time_index := as.numeric(time_index)]
plants_cohort_data[,
  time := simulation_start_date +
    (time_index + 1) * update_interval_in_days
]

grid_cells <- data.table::as.data.table(expand.grid(
  cell_x = as.numeric(
    unlist(site_definition$cell_x_centres, use.names = FALSE)
  ),
  cell_y = as.numeric(
    unlist(site_definition$cell_y_centres, use.names = FALSE)
  )
))
cell_id_origin <- "bottom-left"
grid_order <- order(
  if (cell_id_origin == "top-left") -grid_cells$cell_y else grid_cells$cell_y,
  grid_cells$cell_x
)
grid_cells$cell_id <- NA_integer_
grid_cells$cell_id[grid_order] <- seq_len(nrow(grid_cells)) - 1L

plants_cohort_data$cell_id <- grid_cells$cell_id[
  match(
    paste(plants_cohort_data$cell_x, plants_cohort_data$cell_y),
    paste(grid_cells$cell_x, grid_cells$cell_y)
  )
]
if (anyNA(plants_cohort_data$cell_id)) {
  stop("Some cohort coordinates do not match the Maliau-2 grid definition.")
}

output_dir <- "../../../../../data/derived/plant/output_data/validation/predicted_outputs_processing"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Look up the observed period declared for a specific validation variable,
# so each tissue's calculation uses its own corresponding observed variable
# rather than a single shared reference.
if (!file.exists(observed_metadata_file)) {
  stop(
    "Observed metadata not found. Run master_observed_data_processing.R first."
  )
}
observed_metadata <- yaml::yaml.load_file(observed_metadata_file)
names(observed_metadata$scripts) <- sapply(
  observed_metadata$scripts,
  `[[`,
  "script_path"
)
observed_variables <- observed_metadata$scripts[[
  "carbon_balance_components_maliau.R"
]]$output_files[[1]]$variables

get_observed_period <- function(variable_name) {
  matches <- Filter(
    function(variable) identical(variable$name, variable_name),
    observed_variables
  )
  if (length(matches) != 1) {
    stop(sprintf(
      "Expected exactly one observed variable named '%s'.",
      variable_name
    ))
  }
  list(
    start_date = matches[[1]]$period_start,
    end_date = matches[[1]]$period_end
  )
}

gpp_period <- get_observed_period("GPP_WithoutMycorrhiza")
npp_period <- get_observed_period("TotalNPP_WithoutMycorrhiza")

standardised_gpp <- standardise_ve_cohort_carbon_output(
  plants_cohort_data = plants_cohort_data,
  input_variable = "whole_crown_gpp",
  output_variable = "gpp",
  input_mass_unit = "kg",
  cell_area_ha = cell_area_ha,
  update_interval_in_days = update_interval_in_days,
  start_date = gpp_period$start_date,
  end_date = gpp_period$end_date
)

standardised_npp <-
  standardise_ve_cohort_carbon_output(
    plants_cohort_data = plants_cohort_data,
    input_variable = "npp",
    output_variable = "npp",
    input_mass_unit = "kg",
    cell_area_ha = cell_area_ha,
    update_interval_in_days = update_interval_in_days,
    start_date = npp_period$start_date,
    end_date = npp_period$end_date
  )

standardised_outputs <- list(
  gpp = standardised_gpp,
  npp = standardised_npp
)
for (variable_name in names(standardised_outputs)) {
  names(standardised_outputs[[variable_name]])[
    names(standardised_outputs[[variable_name]]) == "selected_period"
  ] <- paste0(variable_name, "_selected_period")
}

standardised_data <- Reduce(
  function(x, y) {
    merge(
      x,
      y,
      by = c("cell_id", "time", "time_index", "units"),
      all = TRUE,
      sort = FALSE
    )
  },
  standardised_outputs
)
standardised_data <- merge(
  standardised_data,
  grid_cells[, .(cell_id, cell_x, cell_y)],
  by = "cell_id",
  all.x = TRUE,
  sort = FALSE
)

# Write standardised data

write.csv(
  standardised_data,
  file.path(
    output_dir,
    "gpp_and_npp_maliau_2.csv"
  ),
  row.names = FALSE
)
