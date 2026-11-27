#| ---
#| title: symbiote_allocation_maliau_2
#|
#| description: |
#|   Calculates symbiote allocation
#|   from Virtual Ecosystem array variable outputs for the Maliau 2
#|   scenario. Symbiote allocation is corrected for cell area
#|   and timestep duration to give an annualised area-normalised rate per cell
#|   and timestep.
#|   These standardised symbiote allocation values are also pooled across
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
#| status: final
#|
#| input_files:
#|   - name: model_data.nc
#|     path: data/scenarios/maliau/maliau_2/out
#|     description: |
#|       Virtual Ecosystem array variable outputs containing symbiote allocation
#|       per cell, cell coordinates and timestep index.
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
#|   - name: symbiote_allocation_maliau_2.csv
#|     path: data/derived/plant/output_data/validation/predicted_outputs_processing
#|     description: |
#|       Annualised symbiote allocation and cell-total rates in
#|       Mg C ha-1 year-1. There is one row per cell and timestep.
#|       Mean/sd/period columns are `NA` outside the selected period. The
#|       standard deviation describes variability across unique cells and
#|       intervals, not prediction uncertainty.
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
#|       - name: symbiote_allocation_selected_period
#|         type: character
#|         units: dimensionless
#|         description: Month-based period for pooled cell-total symbiote allocation mean/sd.
#|       - name: units
#|         type: character
#|         units: dimensionless
#|         description: Units for standardised symbiote allocation and pooled summaries.
#|       - name: symbiote_allocation
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Single cell (cell_id).
#|         temporal_extent: Single interval ending at time/time_index.
#|         description: |
#|           Annualised symbiote allocation in this cell and timestep.
#|       - name: symbiote_allocation_mean
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Pooled across all cells.
#|         temporal_extent: |
#|           Pooled across all timesteps from start month 2011-08 to end month 2018-07.
#|         description: |
#|           Mean cell-total symbiote allocation pooled across all cells and
#|           timesteps in the selected period, counting each cell/timestep
#|           once. NA outside that period.
#|       - name: symbiote_allocation_sd
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Pooled across all cells.
#|         temporal_extent: |
#|           Pooled across all timesteps from start month 2011-08 to end month 2018-07.
#|         description: |
#|           Standard deviation of cell-total symbiote allocation pooled across
#|           unique cells and timesteps in the selected period. NA outside
#|           that period.
#|
#| package_dependencies:
#|   - data.table
#|   - ncdf4
#|   - yaml
#|   - toml
#|   - reticulate
#|
#| usage_notes: |
#|   If no period dates are supplied, the mean/sd are pooled across the entire
#|   simulation instead. Dates are matched by month.
#|   The validation data provide a single regional mean rather than
#|   observations for individual cells, so `symbiote_allocation_mean`
#|   is the primary comparison value. It is pooled across unique cells and
#|   timesteps in the selected period.
#|   The selected period is loaded from `TotalNPP_WithMycorrhiza` in
#|   master_observed_data_processing_metadata.yml.
#|   Input symbiote allocation rates are in kg C m-2 day-1 and are
#|   converted to Mg C ha-1 year-1.
#| ---

library(data.table)
library(yaml)
library(toml)
library(reticulate)
library(ncdf4)

source("../../../../../tools/R/R/get_ve_variables.R")

model_data_path <- "../../../../../data/scenarios/maliau/maliau_2/out/model_data.nc"
grid_definition_path <- "../../../../../data/derived/site/maliau/maliau_grid_definition.toml"
observed_metadata_file <- "../metadata/master_observed_data_processing_metadata.yml"

output_dir <- "../../../../../data/derived/plant/output_data/validation/predicted_outputs_processing"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

compiled_configuration_path <- "../../../../../data/scenarios/maliau/maliau_2/out/compiled_configuration.toml"
compiled_configuration <- toml::read_toml(compiled_configuration_path)
grid_definition <- toml::read_toml(grid_definition_path)
site_definition <- grid_definition$Scenario$maliau_2
simulation_start_date <- as.Date(
  compiled_configuration$core$timing$start_date
)

# Define simulation timestep duration (days) and cell area (ha) for standardisation.
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

# Load the NetCDF data and extract relevant variables and dimensions
model_data_nc <- nc_open(model_data_path)

output_variables <- model_data_nc$var[
  startsWith(names(model_data_nc$var), "outputs/")
]
output_dimensions <- model_data_nc$dim[
  startsWith(names(model_data_nc$dim), "outputs/")
]

print(names(output_variables))
print(names(output_dimensions))

# Read the coordinate axes used by the output arrays.
time_index <- ncvar_get(model_data_nc, "outputs/time_index")
x <- ncvar_get(model_data_nc, "outputs/x")
y <- ncvar_get(model_data_nc, "outputs/y")
pft <- ncvar_get(model_data_nc, "outputs/pft")
element <- ncvar_get(model_data_nc, "outputs/element")
layers <- ncvar_get(model_data_nc, "outputs/layers")
groundwater_layers <- ncvar_get(model_data_nc, "outputs/groundwater_layers")

# Create a lookup from each y/x position to its bottom-left-origin cell ID.
grid_coordinates <- expand.grid(x = x, y = y)
grid_order <- order(grid_coordinates$y, grid_coordinates$x)
grid_coordinates$cell_id <- NA_integer_
grid_coordinates$cell_id[grid_order] <- seq_len(nrow(grid_coordinates)) - 1L

# Plot the grid to verify
plot(
  grid_coordinates$x,
  grid_coordinates$y,
  pch = 16,
  xlab = "x coordinate (m)",
  ylab = "y coordinate (m)",
  asp = 1
)
text(
  grid_coordinates$x,
  grid_coordinates$y,
  labels = grid_coordinates$cell_id,
  pos = 3,
  cex = 0.7
)

# Read the symbiote allocation arrays before closing the NetCDF file.
symbiote_allocation <- ncvar_get(
  model_data_nc,
  "outputs/plant_symbiote_carbon_supply"
)
nc_close(model_data_nc)

# expand.grid varies x fastest, matching the array order used by as.vector().
array_indices <- expand.grid(
  x_index = seq_along(x),
  y_index = seq_along(y),
  time_index = time_index
)

symbiote_allocation_long <- data.table::data.table(
  x = x[array_indices$x_index],
  y = y[array_indices$y_index],
  time_index = array_indices$time_index,
  symbiote_allocation = as.vector(symbiote_allocation)
)
symbiote_allocation_long$cell_id <- grid_coordinates$cell_id[
  match(
    paste(symbiote_allocation_long$x, symbiote_allocation_long$y),
    paste(grid_coordinates$x, grid_coordinates$y)
  )
]
if (anyNA(symbiote_allocation_long$cell_id)) {
  stop(
    "Some symbiote allocation coordinates do not match the Maliau-2 grid definition."
  )
}

# Note that the NetCDF y axis is stored north-to-south, while cell IDs start at
# the bottom-left. Here, cell 0's y coordinate is at array index 10, not index 1.
# See the example below:
symbiote_allocation_long$symbiote_allocation[
  symbiote_allocation_long$cell_id == 0 &
    symbiote_allocation_long$time_index == 0
]

symbiote_allocation[1, 10, 1]

# Add time based on time_index and timestep duration
symbiote_allocation_long[,
  time := simulation_start_date +
    (time_index + 1) * update_interval_in_days
]

# Now standardize the total symbiote allocation for each cell_id and timestep
# by converting the units from kg C m-2 day-1 to Mg C ha-1 year-1
symbiote_allocation_long$symbiote_allocation <-
  symbiote_allocation_long$symbiote_allocation * 365.25 * 10000 / 1000

# Rename columns
names(symbiote_allocation_long)[
  names(symbiote_allocation_long) == "x"
] <- "cell_x"
names(symbiote_allocation_long)[
  names(symbiote_allocation_long) == "y"
] <- "cell_y"
symbiote_allocation_long$units <- "Mg C ha-1 year-1"

# Then, look up the observed period declared for a specific validation variable,
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

symbiote_allocation_period <- get_observed_period("TotalNPP_WithMycorrhiza")

output_months <- format(symbiote_allocation_long$time, "%Y-%m")
start_month <- format(
  as.Date(symbiote_allocation_period$start_date),
  "%Y-%m"
)
end_month <- format(
  as.Date(symbiote_allocation_period$end_date),
  "%Y-%m"
)
if (!start_month %in% output_months || !end_month %in% output_months) {
  stop("The selected symbiote allocation period is outside the output dates.")
}
period_rows <- output_months >= start_month & output_months <= end_month
period_values <- symbiote_allocation_long$symbiote_allocation[
  period_rows &
    !duplicated(paste(
      symbiote_allocation_long$cell_id,
      symbiote_allocation_long$time_index,
      sep = "_"
    ))
]
symbiote_allocation_long$symbiote_allocation_selected_period <- NA_character_
symbiote_allocation_long$symbiote_allocation_selected_period[period_rows] <-
  paste(start_month, end_month, sep = " to ")
symbiote_allocation_long$symbiote_allocation_mean <- NA_real_
symbiote_allocation_long$symbiote_allocation_mean[period_rows] <-
  mean(period_values)
symbiote_allocation_long$symbiote_allocation_sd <- NA_real_
symbiote_allocation_long$symbiote_allocation_sd[period_rows] <-
  stats::sd(period_values)

symbiote_allocation_long <- symbiote_allocation_long[,
  c(
    "cell_id",
    "cell_x",
    "cell_y",
    "time",
    "time_index",
    "symbiote_allocation_selected_period",
    "units",
    "symbiote_allocation",
    "symbiote_allocation_mean",
    "symbiote_allocation_sd"
  ),
  with = FALSE
]

write.csv(
  symbiote_allocation_long,
  file.path(
    output_dir,
    "symbiote_allocation_maliau_2.csv"
  ),
  row.names = FALSE
)
