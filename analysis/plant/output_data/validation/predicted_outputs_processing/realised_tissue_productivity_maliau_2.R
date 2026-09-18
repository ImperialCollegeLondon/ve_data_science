#| ---
#| title: realised_tissue_productivity_maliau_2
#|
#| description: |
#|   Calculates realised stem, foliage, root, fruit, and seed carbon
#|   productivity from Virtual Ecosystem plant cohort output for the Maliau 2
#|   scenario. Cohort-level biomasses are multiplied by cohort individuals,
#|   summed to cell-level carbon stocks, and differenced between consecutive
#|   timesteps to give an annual area-normalised rate per cell and timestep.
#|   `time_index = 0` has no preceding timestep, so its rate is `NA`. The
#|   rate is also pooled across all cells and timesteps within the selected
#|   period into a single mean and standard deviation, matching the spatial
#|   and temporal extent of the expected validation data.
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
#|       Virtual Ecosystem plant cohort output containing realised tissue carbon
#|       mass per individual, cohort abundance, cell identifiers, and timestamps.
#|   - name: master_observed_data_processing_metadata.yml
#|     path: analysis/plant/output_data/validation/metadata
#|     description: |
#|       Provides the validation period (`period_start`/`period_end`) declared
#|       by carbon_balance_components_maliau.R, so the pooled mean/sd below
#|       always match the observed dataset's temporal extent. Requires
#|       master_observed_data_processing.R to have been run first.
#|
#| output_files:
#|   - name: realised_tissue_productivity_maliau_2.csv
#|     path: data/derived/plant/output_data/validation/predicted_outputs_processing
#|     description: |
#|       Realised stem, foliage, root, fruit, and seed carbon productivity in
#|       Mg C ha-1 year-1, with one row per cell and timestep, plus a pooled
#|       mean and standard deviation across all cells and timesteps within
#|       the selected period. The mean/sd/`selected_period` columns are `NA`
#|       for timesteps outside the selected period. The standard deviation
#|       describes variability across cells and intervals, not prediction
#|       uncertainty.
#|     variables:
#|       - name: cell_id
#|         type: integer
#|         units: dimensionless
#|         description: VE spatial cell identifier.
#|       - name: time
#|         type: date
#|         units: ISO 8601 date
#|         description: Interval-ending simulation date.
#|       - name: time_index
#|         type: integer
#|         units: dimensionless
#|         description: Interval-ending simulation timestep index.
#|       - name: selected_period
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Month-based period used for calculating pooled mean/sd.
#|       - name: units
#|         type: character
#|         units: dimensionless
#|         description: Units of the productivity columns.
#|       - name: stem_c_productivity
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Single cell (cell_id).
#|         temporal_extent: Single interval ending at time/time_index.
#|         description: Interval realised stem carbon productivity for each cell.
#|       - name: stem_c_productivity_mean
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Pooled across all cells.
#|         temporal_extent: |
#|           Pooled across all timesteps from start month 2011-08 to end month 2018-07.
#|         description: |
#|           Mean stem carbon productivity pooled across all cells and
#|           timesteps in the selected period. NA outside that period.
#|       - name: stem_c_productivity_sd
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Pooled across all cells.
#|         temporal_extent: |
#|           Pooled across all timesteps from start month 2011-08 to end month 2018-07.
#|         description: |
#|           Standard deviation of stem carbon productivity pooled across all
#|           cells and timesteps in the selected period. NA outside that period.
#|       - name: foliage_c_productivity
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Single cell (cell_id).
#|         temporal_extent: Single interval ending at time/time_index.
#|         description: Interval realised foliage carbon productivity for each cell.
#|       - name: foliage_c_productivity_mean
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Pooled across all cells.
#|         temporal_extent: |
#|           Pooled across all timesteps from start month 2011-08 to end month 2018-07.
#|         description: |
#|           Mean foliage carbon productivity pooled across all cells and
#|           timesteps in the selected period. NA outside that period.
#|       - name: foliage_c_productivity_sd
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Pooled across all cells.
#|         temporal_extent: |
#|           Pooled across all timesteps from start month 2011-08 to end month 2018-07.
#|         description: |
#|           Standard deviation of foliage carbon productivity pooled across
#|           all cells and timesteps in the selected period. NA outside that
#|           period.
#|       - name: root_c_productivity
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Single cell (cell_id).
#|         temporal_extent: Single interval ending at time/time_index.
#|         description: Interval realised root carbon productivity for each cell.
#|       - name: root_c_productivity_mean
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Pooled across all cells.
#|         temporal_extent: |
#|           Pooled across all timesteps from start month 2011-08 to end month 2018-07.
#|         description: |
#|           Mean root carbon productivity pooled across all cells and
#|           timesteps in the selected period. NA outside that period.
#|       - name: root_c_productivity_sd
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Pooled across all cells.
#|         temporal_extent: |
#|           Pooled across all timesteps from start month 2011-08 to end month 2018-07.
#|         description: |
#|           Standard deviation of root carbon productivity pooled across all
#|           cells and timesteps in the selected period. NA outside that period.
#|       - name: fruit_c_productivity
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Single cell (cell_id).
#|         temporal_extent: Single interval ending at time/time_index.
#|         description: Interval realised fruit carbon productivity for each cell.
#|       - name: fruit_c_productivity_mean
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Pooled across all cells.
#|         temporal_extent: |
#|           Pooled across all timesteps from start month 2011-08 to end month 2018-07.
#|         description: |
#|           Mean fruit carbon productivity pooled across all cells and
#|           timesteps in the selected period. NA outside that period.
#|       - name: fruit_c_productivity_sd
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Pooled across all cells.
#|         temporal_extent: |
#|           Pooled across all timesteps from start month 2011-08 to end month 2018-07.
#|         description: |
#|           Standard deviation of fruit carbon productivity pooled across all
#|           cells and timesteps in the selected period. NA outside that period.
#|       - name: seed_c_productivity
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Single cell (cell_id).
#|         temporal_extent: Single interval ending at time/time_index.
#|         description: Interval realised seed carbon productivity for each cell.
#|       - name: seed_c_productivity_mean
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Pooled across all cells.
#|         temporal_extent: |
#|           Pooled across all timesteps from start month 2011-08 to end month 2018-07.
#|         description: |
#|           Mean seed carbon productivity pooled across all cells and
#|           timesteps in the selected period. NA outside that period.
#|       - name: seed_c_productivity_sd
#|         type: numeric
#|         units: Mg C ha-1 year-1
#|         spatial_extent: Pooled across all cells.
#|         temporal_extent: |
#|           Pooled across all timesteps from start month 2011-08 to end month 2018-07.
#|         description: |
#|           Standard deviation of seed carbon productivity pooled across all
#|           cells and timesteps in the selected period. NA outside that period.
#|
#| package_dependencies:
#|   - data.table
#|   - yaml
#|
#| usage_notes: |
#|   If no period dates are supplied, the mean/sd are pooled across the entire
#|   simulation instead. Dates are matched by month.
#|   The validation data provide a single regional mean rather than
#|   observations for individual cells, so `<variable>_mean` (pooled across
#|   all cells and timesteps in the selected period) is the primary
#|   comparison value.
#|   Each tissue's period is loaded at runtime from its own corresponding
#|   variable in master_observed_data_processing_metadata.yml (stem ->
#|   WoodyNPP_Stem, foliage -> CanopyNPP_Leaf, root -> FineRootNPP, fruit and
#|   seed -> CanopyNPP_Reproductive), so they always match the observed
#|   dataset's declared periods without manual syncing.
#| ---

source("../../../../../tools/R/R/get_ve_variables.R")

plants_cohort_data_path <- "../../../../../data/scenarios/maliau/maliau_2/out/plants_cohort_data.csv"
observed_metadata_file <- "../metadata/master_observed_data_processing_metadata.yml"

# Read only the columns needed for the productivity calculations to reduce
# memory pressure when this large scenario file is loaded into R. Using
# data.table::fread(select = ...) avoids a large header-only pass over the CSV.
required_columns <- c(
  "cell_id",
  "time",
  "time_index",
  "n_individuals",
  "whole_crown_gpp",
  "stem_c_biomass",
  "foliage_c_biomass",
  "root_c_biomass",
  "fruit_c_biomass",
  "seed_c_biomass"
)
plants_cohort_data <- data.table::fread(
  plants_cohort_data_path,
  select = required_columns,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

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
observed_variables <- observed_metadata$scripts[[1]]$output_files[[1]]$variables

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

stem_period <- get_observed_period("WoodyNPP_Stem")
foliage_period <- get_observed_period("CanopyNPP_Leaf")
root_period <- get_observed_period("FineRootNPP")
fruit_period <- get_observed_period("CanopyNPP_Reproductive")
seed_period <- get_observed_period("CanopyNPP_Reproductive")

standardised_stem_c_productivity <- calculate_ve_realised_tissue_productivity(
  plants_cohort_data = plants_cohort_data,
  input_variable = "stem_c_biomass",
  output_variable = "stem_c_productivity",
  cell_area_ha = 1,
  start_date = stem_period$start_date,
  end_date = stem_period$end_date
)

standardised_foliage_c_productivity <-
  calculate_ve_realised_tissue_productivity(
    plants_cohort_data = plants_cohort_data,
    input_variable = "foliage_c_biomass",
    output_variable = "foliage_c_productivity",
    cell_area_ha = 1,
    start_date = foliage_period$start_date,
    end_date = foliage_period$end_date
  )

standardised_root_c_productivity <- calculate_ve_realised_tissue_productivity(
  plants_cohort_data = plants_cohort_data,
  input_variable = "root_c_biomass",
  output_variable = "root_c_productivity",
  cell_area_ha = 1,
  start_date = root_period$start_date,
  end_date = root_period$end_date
)

standardised_fruit_c_productivity <-
  calculate_ve_realised_tissue_productivity(
    plants_cohort_data = plants_cohort_data,
    input_variable = "fruit_c_biomass",
    output_variable = "fruit_c_productivity",
    cell_area_ha = 1,
    start_date = fruit_period$start_date,
    end_date = fruit_period$end_date
  )

standardised_seed_c_productivity <-
  calculate_ve_realised_tissue_productivity(
    plants_cohort_data = plants_cohort_data,
    input_variable = "seed_c_biomass",
    output_variable = "seed_c_productivity",
    cell_area_ha = 1,
    start_date = seed_period$start_date,
    end_date = seed_period$end_date
  )

# Merge the data together

standardised_data <- merge(
  standardised_stem_c_productivity,
  standardised_foliage_c_productivity,
  by = c("cell_id", "time", "time_index", "selected_period", "units"),
  all = TRUE,
  sort = FALSE
)
standardised_data <- merge(
  standardised_data,
  standardised_root_c_productivity,
  by = c("cell_id", "time", "time_index", "selected_period", "units"),
  all = TRUE,
  sort = FALSE
)
standardised_data <- merge(
  standardised_data,
  standardised_fruit_c_productivity,
  by = c("cell_id", "time", "time_index", "selected_period", "units"),
  all = TRUE,
  sort = FALSE
)
standardised_data <- merge(
  standardised_data,
  standardised_seed_c_productivity,
  by = c("cell_id", "time", "time_index", "selected_period", "units"),
  all = TRUE,
  sort = FALSE
)

# Write standardised data

write.csv(
  standardised_data,
  file.path(
    output_dir,
    "realised_tissue_productivity_maliau_2.csv"
  ),
  row.names = FALSE
)
