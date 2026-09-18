#| title: realised_tissue_productivity_comparison_maliau_2
#|
#| description: |
#|   Compares standardised Virtual Ecosystem plant productivity predictions
#|   with field observations for Maliau scenario 2. The tissues compared are
#|   dynamically loaded from:
#|   ../variable_mapping/realised_tissue_productivity_mapping_maliau_2.yml.
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
#|   - name: carbon_balance_components_maliau.csv
#|     path: data/derived/plant/output_data/validation/observed_data_processing
#|     description: Cleaned SAFE carbon-balance observations for Maliau plots.
#|   - name: realised_tissue_productivity_maliau_2.csv
#|     path: data/derived/plant/output_data/validation/predicted_outputs_processing
#|     description: Standardised Maliau 2 plant productivity outputs.
#|
#| output_files:
#|   - name: realised_tissue_productivity_comparison_maliau_2.csv
#|     path: data/derived/plant/output_data/validation/comparisons
#|     description: |
#|       Merged observed and predicted values for all tissues mapped in the
#|       validation contract, including pooled model SD and spatial/temporal
#|       extent information.
#|
#| package_dependencies:
#|   - yaml
#|
#| usage_notes: |
#|   The comparison is driven by the realised_tissue_productivity_mapping_maliau_2.yml file.
#|   To add or remove variables from this comparison, update the contract
#|   YAML; no changes are required to this script.
#| ---

observed_data_file <- "../../../../../data/derived/plant/output_data/validation/observed_data_processing/carbon_balance_components_maliau.csv"
predicted_outputs_file <- "../../../../../data/derived/plant/output_data/validation/predicted_outputs_processing/realised_tissue_productivity_maliau_2.csv"
observed_metadata_file <- "../metadata/master_observed_data_processing_metadata.yml"
predicted_metadata_file <- "../metadata/master_predicted_outputs_processing_metadata.yml"

output_dir <- "../../../../../data/derived/plant/output_data/validation/comparisons"
figure_dir <- file.path(output_dir, "figures_maliau_2")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

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
predicted_metadata <- yaml::yaml.load_file(predicted_metadata_file)

# Look up one variable's spatial_extent/temporal_extent from a master
# metadata object, by output file name and variable name, so the comparison
# always reflects the upstream scripts' current metadata.
get_variable_extent <- function(metadata, output_file_name, variable_name) {
  for (script in metadata$scripts) {
    for (output_file in script$output_files) {
      if (!identical(output_file$name, output_file_name)) {
        next
      }
      for (variable in output_file$variables) {
        if (identical(variable$name, variable_name)) {
          return(list(
            spatial_extent = variable$spatial_extent,
            temporal_extent = variable$temporal_extent
          ))
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

# Load validation contract and generate variable_map dynamically
contract <- yaml::yaml.load_file(
  "../variable_mapping/realised_tissue_productivity_mapping_maliau_2.yml"
)
variable_map_list <- lapply(contract$variable_mappings, function(m) {
  data.frame(
    validation_variable = m$observed$variable,
    validation_se = m$observed$se_variable,
    predicted_variable = m$predicted$variable,
    predicted_sd_variable = m$predicted$sd_variable,
    stringsAsFactors = FALSE
  )
})
variable_map <- do.call(rbind, variable_map_list)
variable_map_dynamic <- do.call(rbind, variable_map_list)

# Woody stem productivity -----------------------------------------------
variable_map <- variable_map_dynamic

# The predicted mean/sd/selected_period columns are NA outside the pooled
# period, so the single non-missing value is the comparison value.
model_units <- unique(model_data$units)
if (length(model_units) != 1) {
  stop("Predicted output must have exactly one units value.")
}
expected_units <- model_units

comparison_period <- unique(
  model_data$selected_period[!is.na(model_data$selected_period)]
)
if (length(comparison_period) != 1) {
  stop(
    "Predicted output must have exactly one non-missing selected_period value."
  )
}

# Shared validation, prediction selection, and merge logic

# Confirm that every variable named in the mapping is present in the relevant
# input table before accessing any columns dynamically.
required_columns <- c(
  variable_map$validation_variable,
  variable_map$validation_se,
  variable_map$predicted_variable,
  variable_map$predicted_sd_variable,
  "ForestPlotsCode",
  "SAFEPlotName",
  "PlotName"
)
missing_columns <- setdiff(
  required_columns,
  c(names(validation_data), names(model_data))
)
if (length(missing_columns) > 0) {
  stop(
    sprintf(
      "Comparison columns are missing: %s",
      paste(missing_columns, collapse = ", ")
    )
  )
}

# Resolve one predicted value for each mapped variable from the pooled,
# non-missing mean/sd.
predicted_selection <- lapply(
  seq_len(nrow(variable_map)),
  function(variable_index) {
    predicted_variable <- variable_map$predicted_variable[variable_index]
    predicted_sd_variable <- variable_map$predicted_sd_variable[
      variable_index
    ]
    predicted_values <- unique(model_data[[predicted_variable]][
      !is.na(model_data[[predicted_variable]])
    ])
    if (length(predicted_values) != 1) {
      stop(sprintf("Expected one predicted value for %s.", predicted_variable))
    }
    list(
      value = predicted_values,
      variable = predicted_variable,
      sd = unique(model_data[[predicted_sd_variable]][
        !is.na(model_data[[predicted_sd_variable]])
      ])
    )
  }
)
predicted_values <- vapply(
  predicted_selection,
  function(selection) selection$value,
  numeric(1)
)
predicted_sd <- vapply(
  predicted_selection,
  function(selection) selection$sd,
  numeric(1)
)
predicted_variables <- vapply(
  predicted_selection,
  function(selection) selection$variable,
  character(1)
)

# Repeat the regional predicted value for each validation plot. This creates a
# merged structural table without adding comparison metrics yet.
comparison_rows <- lapply(
  seq_len(nrow(variable_map)),
  function(variable_index) {
    validation_variable <- variable_map$validation_variable[variable_index]
    validation_se_variable <- variable_map$validation_se[variable_index]
    predicted_variable <- predicted_variables[variable_index]
    # The output column is named without the "_mean" suffix used internally.
    predicted_display_variable <- sub("_mean$", "", predicted_variable)
    predicted_value <- predicted_values[variable_index]

    observed_extent <- get_variable_extent(
      observed_metadata,
      basename(observed_data_file),
      validation_variable
    )
    predicted_extent <- get_variable_extent(
      predicted_metadata,
      basename(predicted_outputs_file),
      predicted_variable
    )

    lapply(seq_len(nrow(validation_data)), function(plot_index) {
      observed_value <- validation_data[[validation_variable]][plot_index]
      observed_se_value <- validation_data[[validation_se_variable]][plot_index]
      data.frame(
        ForestPlotsCode = validation_data$ForestPlotsCode[plot_index],
        SAFEPlotName = validation_data$SAFEPlotName[plot_index],
        PlotName = validation_data$PlotName[plot_index],
        observed_variable = validation_variable,
        predicted_variable = predicted_display_variable,
        validation_period = comparison_period,
        predicted_period = comparison_period,
        observed_spatial_extent = observed_extent$spatial_extent,
        observed_temporal_extent = observed_extent$temporal_extent,
        predicted_spatial_extent = predicted_extent$spatial_extent,
        predicted_temporal_extent = predicted_extent$temporal_extent,
        observed_units = expected_units,
        predicted_units = expected_units,
        observed_value = observed_value,
        observed_se = observed_se_value,
        predicted_value = predicted_value,
        predicted_spatial_sd = predicted_sd[variable_index],
        stringsAsFactors = FALSE
      )
    })
  }
)

comparison_data <- do.call(rbind, unlist(comparison_rows, recursive = FALSE))
row.names(comparison_data) <- NULL

# Write one merged row per validation plot and mapped variable.
write.csv(
  comparison_data,
  file.path(
    output_dir,
    "realised_tissue_productivity_comparison_maliau_2.csv"
  ),
  row.names = FALSE
)
