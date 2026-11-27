#| title: respiration_and_turnover_comparison_maliau_2
#|
#| description: |
#|   Compares standardised Virtual Ecosystem plant respiration and turnover
#|   predictions with field observations for Maliau scenario 2. Variables
#|   are loaded from respiration_and_turnover_mapping_maliau_2.yml.
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
#|   - name: carbon_balance_components_maliau.csv
#|     path: data/derived/plant/output_data/validation/observed_data_processing
#|     description: Cleaned SAFE carbon-balance observations for Maliau plots.
#|   - name: master_observed_data_processing_metadata.yml
#|     path: analysis/plant/output_data/validation/metadata
#|     description: Variable-specific observed measurement periods.
#|   - name: respiration_and_turnover_maliau_2.csv
#|     path: data/derived/plant/output_data/validation/predicted_outputs_processing
#|     description: Standardised Maliau 2 plant respiration and turnover outputs.
#|   - name: respiration_and_turnover_mapping_maliau_2.yml
#|     path: analysis/plant/output_data/validation/variable_mapping
#|     description: Observed and predicted variable mappings.
#|
#| output_files:
#|   - name: respiration_and_turnover_comparison_maliau_2.csv
#|     path: data/derived/plant/output_data/validation/comparisons
#|     description: |
#|       One row per observed plot and mapped variable, including observed SE,
#|       pooled model SD, spatial/temporal extents, and aggregation statuses.
#|
#| package_dependencies:
#|   - yaml
#|
#| usage_notes: |
#|   Run from this script's directory. Variables are defined in the mapping
#|   YAML. Observed values are per plot and period-averaged; predictions are
#|   pooled across cells and timesteps in each variable's selected period.
#|   Both datasets use Mg C ha-1 year-1. Predicted SD describes pooled
#|   cell-timestep variability, not prediction uncertainty. The output column
#|   predicted_spatial_sd retains the existing comparison-table convention.
#| ---

observed_data_file <- "../../../../../data/derived/plant/output_data/validation/observed_data_processing/carbon_balance_components_maliau.csv"
predicted_outputs_file <- "../../../../../data/derived/plant/output_data/validation/predicted_outputs_processing/respiration_and_turnover_maliau_2.csv"
observed_metadata_file <- "../metadata/master_observed_data_processing_metadata.yml"
mapping_file <- "../variable_mapping/respiration_and_turnover_mapping_maliau_2.yml"
output_dir <- "../../../../../data/derived/plant/output_data/validation/comparisons"

validation_data <- utils::read.csv(
  observed_data_file,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
model_data <- utils::read.csv(
  predicted_outputs_file,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
observed_metadata <- yaml::yaml.load_file(observed_metadata_file)
contract <- yaml::yaml.load_file(mapping_file)

get_variable_extent <- function(metadata, output_file_name, variable_name) {
  for (script in metadata$scripts) {
    for (output_file in script$output_files) {
      if (!identical(output_file$name, output_file_name)) {
        next
      }
      for (variable in output_file$variables) {
        if (identical(variable$name, variable_name)) {
          return(variable)
        }
      }
    }
  }
  stop(sprintf(
    "Variable %s not found in output file %s metadata.",
    variable_name,
    output_file_name
  ))
}

variable_map <- do.call(
  rbind,
  lapply(contract$variable_mappings, function(m) {
    data.frame(
      validation_variable = m$observed$variable,
      validation_se = m$observed$se_variable,
      predicted_variable = m$predicted$variable,
      predicted_sd_variable = m$predicted$sd_variable,
      predicted_period_variable = sub(
        "_mean$",
        "_selected_period",
        m$predicted$variable
      ),
      stringsAsFactors = FALSE
    )
  })
)
if (is.null(variable_map) || nrow(variable_map) == 0) {
  stop("The variable mapping must contain at least one variable.")
}

required_validation_columns <- c(
  variable_map$validation_variable,
  variable_map$validation_se,
  "ForestPlotsCode",
  "SAFEPlotName",
  "PlotName"
)
required_model_columns <- c(
  variable_map$predicted_variable,
  variable_map$predicted_sd_variable,
  variable_map$predicted_period_variable,
  "cell_id",
  "units"
)
missing_columns <- c(
  setdiff(required_validation_columns, names(validation_data)),
  setdiff(required_model_columns, names(model_data))
)
if (length(missing_columns) > 0) {
  stop(sprintf(
    "Comparison columns are missing: %s",
    paste(missing_columns, collapse = ", ")
  ))
}
if (nrow(validation_data) == 0) {
  stop("The observed dataset must contain at least one plot.")
}
expected_units <- "Mg C ha-1 year-1"
if (
  nrow(model_data) == 0 ||
    anyNA(model_data$units) ||
    any(model_data$units != expected_units)
) {
  stop("Predicted output must use Mg C ha-1 year-1 for every row.")
}

comparison_rows <- lapply(seq_len(nrow(variable_map)), function(index) {
  mapping <- variable_map[index, ]
  predicted_variable <- mapping$predicted_variable
  pooled_rows <- !is.na(model_data[[predicted_variable]])
  predicted_values <- unique(model_data[[predicted_variable]][pooled_rows])
  if (length(predicted_values) != 1 || !is.finite(predicted_values)) {
    stop(sprintf(
      "Expected one finite predicted value for %s.",
      predicted_variable
    ))
  }
  selected_periods <- unique(as.character(
    model_data[[mapping$predicted_period_variable]][pooled_rows]
  ))
  if (length(selected_periods) != 1 || anyNA(selected_periods)) {
    stop(sprintf("Expected one selected period for %s.", predicted_variable))
  }
  predicted_cell_ids <- sort(unique(model_data$cell_id[pooled_rows]))
  if (
    length(predicted_cell_ids) == 0 || anyNA(model_data$cell_id[pooled_rows])
  ) {
    stop(sprintf("Missing pooled cell identifiers for %s.", predicted_variable))
  }
  predicted_sd <- unique(model_data[[mapping$predicted_sd_variable]][
    pooled_rows
  ])
  if (
    length(predicted_sd) != 1 ||
      (!is.na(predicted_sd) &&
        (!is.finite(predicted_sd) || predicted_sd < 0)) ||
      (is.na(predicted_sd) && sum(pooled_rows) > 1)
  ) {
    stop(sprintf("Expected one pooled SD for %s.", predicted_variable))
  }

  observed_extent <- get_variable_extent(
    observed_metadata,
    basename(observed_data_file),
    mapping$validation_variable
  )
  observed_dates <- as.Date(c(
    observed_extent$period_start,
    observed_extent$period_end
  ))
  if (
    length(observed_dates) != 2 ||
      anyNA(observed_dates) ||
      observed_dates[1] > observed_dates[2]
  ) {
    stop(sprintf(
      "Observed period metadata is invalid for %s.",
      mapping$validation_variable
    ))
  }
  expected_period <- paste(format(observed_dates, "%Y-%m"), collapse = " to ")
  if (!identical(selected_periods, expected_period)) {
    stop(sprintf(
      "Predicted and observed periods do not match for %s.",
      predicted_variable
    ))
  }

  data.frame(
    ForestPlotsCode = validation_data$ForestPlotsCode,
    SAFEPlotName = validation_data$SAFEPlotName,
    PlotName = validation_data$PlotName,
    observed_variable = mapping$validation_variable,
    predicted_variable = predicted_variable,
    observed_spatial_extent = validation_data$SAFEPlotName,
    predicted_spatial_extent = paste(predicted_cell_ids, collapse = "; "),
    observed_temporal_extent = paste(observed_dates, collapse = " to "),
    predicted_temporal_extent = selected_periods,
    observed_spatial_aggregation = "exact",
    predicted_spatial_aggregation = "pooled",
    observed_temporal_aggregation = "pooled",
    predicted_temporal_aggregation = "pooled",
    observed_units = expected_units,
    predicted_units = expected_units,
    observed_value = validation_data[[mapping$validation_variable]],
    observed_se = validation_data[[mapping$validation_se]],
    predicted_value = predicted_values,
    predicted_spatial_sd = predicted_sd,
    stringsAsFactors = FALSE
  )
})
comparison_data <- do.call(rbind, comparison_rows)
rownames(comparison_data) <- NULL

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(
  comparison_data,
  file.path(output_dir, "respiration_and_turnover_comparison_maliau_2.csv"),
  row.names = FALSE
)
