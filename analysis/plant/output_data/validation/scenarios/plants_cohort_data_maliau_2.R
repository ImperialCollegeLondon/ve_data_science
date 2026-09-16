#| ---
#| title: plants_cohort_data_maliau_2
#|
#| description: |
#|   Calculates realised stem, foliage, root, fruit, and seed carbon
#|   productivity from Virtual Ecosystem plant cohort output for the Maliau 2
#|   scenario. Cohort-level biomasses are multiplied by cohort abundance,
#|   summed to cell-level carbon stocks, and differenced between consecutive
#|   timesteps. Rows with missing `whole_crown_gpp` are treated as the initial
#|   state before regular `time_index = 0`, allowing the first productivity
#|   interval to be calculated. The output retains interval values, cell-level
#|   period means, and means across all cells for both the selected period and
#|   full simulation.
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
#|
#| output_files:
#|   - name: plants_cohort_data_standardised_maliau_2.csv
#|     path: data/derived/plant/output_data/validation/scenarios
#|     description: |
#|       Realised stem, foliage, root, fruit, and seed carbon productivity in
#|       Mg C ha^-1 year^-1, including interval values, cell-level means, and
#|       spatial means across all cells for the selected period and the full
#|       Maliau 2 simulation.
#|
#| package_dependencies: null
#|
#| usage_notes: |
#|   If no period dates are supplied, the selected-period mean equals the full
#|   simulation-period mean. Dates are matched by month when supplied.
#|   The validation data provide a regional mean rather than observations for
#|   individual cells, so the spatial mean across all model cells for the
#|   selected validation period is the primary comparison value. Cell-level
#|   interval values and period means are retained for diagnostics and for
#|   future validation cases with an exact spatial match.
#|   This corresponds to a spatially aggregated, temporally resolved model
#|   comparison followed by a mean over the selected validation period.
#| ---

source("../../../../../tools/R/R/get_ve_variables.R")

plants_cohort_data <- "../../../../../data/scenarios/maliau/maliau_2/out/plants_cohort_data.csv"

output_dir <- "../../../../../data/derived/plant/output_data/validation/scenarios"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

standardised_stem_c_productivity <- calculate_ve_realised_tissue_productivity(
  plants_cohort_data = plants_cohort_data,
  input_variable = "stem_c_biomass",
  output_variable = "stem_c_productivity",
  cell_area_ha = 1,
  start_date = "2011-08-25",
  end_date = "2018-07-17"
)

standardised_foliage_c_productivity <-
  calculate_ve_realised_tissue_productivity(
    plants_cohort_data = plants_cohort_data,
    input_variable = "foliage_c_biomass",
    output_variable = "foliage_c_productivity",
    cell_area_ha = 1,
    start_date = "2011-08-25",
    end_date = "2018-07-17"
  )

standardised_root_c_productivity <- calculate_ve_realised_tissue_productivity(
  plants_cohort_data = plants_cohort_data,
  input_variable = "root_c_biomass",
  output_variable = "root_c_productivity",
  cell_area_ha = 1,
  start_date = "2011-08-25",
  end_date = "2018-07-17"
)

standardised_fruit_c_productivity <-
  calculate_ve_realised_tissue_productivity(
    plants_cohort_data = plants_cohort_data,
    input_variable = "fruit_c_biomass",
    output_variable = "fruit_c_productivity",
    cell_area_ha = 1,
    start_date = "2011-08-25",
    end_date = "2018-07-17"
  )

standardised_seed_c_productivity <-
  calculate_ve_realised_tissue_productivity(
    plants_cohort_data = plants_cohort_data,
    input_variable = "seed_c_biomass",
    output_variable = "seed_c_productivity",
    cell_area_ha = 1,
    start_date = "2011-08-25",
    end_date = "2018-07-17"
  )

# Note that the validation data here would compare against the column:
# stem_c_productivity_spatial_simulation_period_mean, assuming we run the entire
# simulation and that the period is included in the simulation (which should be
# the case when not terminated early)

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
    "plants_cohort_data_standardised_maliau_2.csv"
  ),
  row.names = FALSE
)
