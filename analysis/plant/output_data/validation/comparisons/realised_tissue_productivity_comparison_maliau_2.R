#| ---
#| title: realised_tissue_productivity_comparison_maliau_2
#|
#| description: |
#|   Compares standardised Virtual Ecosystem plant productivity predictions for
#|   the Maliau 2 scenario with the cleaned SAFE carbon-balance validation data.
#|   The first comparison is limited to woody stem productivity; additional
#|   tissue variables can be added later.
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
#|       Merged observed and predicted woody stem productivity values,
#|       including the predicted standard deviation (pooled across cells and
#|       timesteps in the selected period), and the spatial/temporal extent
#|       of each side of the comparison (`observed_spatial_extent`,
#|       `observed_temporal_extent`, `predicted_spatial_extent`,
#|       `predicted_temporal_extent`), sourced from the metadata of
#|       carbon_balance_components_maliau.R and
#|       realised_tissue_productivity_maliau_2.R respectively, so a mismatch
#|       in scale between the two sides is visible directly in the output.
#|     period_start: 2011-08-25
#|     period_end: 2018-07-17
#|     period_label: 2011-08 to 2018-07
#|   - name: woody_stem_productivity_comparison_maliau_2.png
#|     path: data/derived/plant/output_data/validation/comparisons/figures_maliau_2
#|     description: |
#|       Point-range plot showing observed plot values with observational
#|       standard errors and the predicted regional mean with pooled SD.
#|
#| comparison_observations:
#|   - observed_variable: WoodyNPP_Stem
#|     predicted_variable: stem_c_productivity
#|     observation: Poor fit
#|
#| package_dependencies:
#|   - yaml
#|
#| usage_notes: |
#|   The predicted mean/sd/`selected_period` columns are read directly from
#|   the standardised output; they are `NA` outside the requested period, so
#|   this script simply takes the unique non-missing value of each. The two
#|   observed plots remain separate to preserve their spatial variation.
#|   The `*_spatial_extent`/`*_temporal_extent` columns are read from the
#|   `variables` metadata of each mapped variable in
#|   master_observed_data_processing_metadata.yml and
#|   master_predicted_outputs_processing_metadata.yml, so they always match
#|   the metadata headers of the two upstream scripts.
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

# Woody stem productivity -----------------------------------------------
stem_variable_map <- data.frame(
  validation_variable = "WoodyNPP_Stem",
  validation_se = "SE_WoodyNPP_Stem",
  predicted_variable = "stem_c_productivity_mean",
  predicted_sd_variable = "stem_c_productivity_sd",
  stringsAsFactors = FALSE
)

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

# Define comparison mappings by variable. Each tissue has its own mapping
# object, so adding a later tissue cannot overwrite an earlier mapping.

# Foliage carbon productivity ------------------------------------------
# Add the foliage observed/predicted variable mapping here.

# Combine all tissue mappings before the shared processing code. Add future
# tissue mapping objects to this list immediately above this line.
variable_maps <- list(stem = stem_variable_map)
variable_map <- do.call(rbind, variable_maps)

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

# Plot the observed plot values and the predicted regional value. Observed
# error bars show observational SE; the predicted error bar shows spatial SD.
plot_data <- comparison_data[
  comparison_data$observed_variable == "WoodyNPP_Stem",
  ,
  drop = FALSE
]
predicted_row <- plot_data[1, , drop = FALSE]
plot_labels <- c(
  paste("Observed -", plot_data$ForestPlotsCode),
  "Predicted"
)
plot_values <- c(plot_data$observed_value, predicted_row$predicted_value)
plot_sd <- c(plot_data$observed_se, predicted_row$predicted_spatial_sd)
finite_values <- c(
  plot_values - ifelse(is.na(plot_sd), 0, plot_sd),
  plot_values + ifelse(is.na(plot_sd), 0, plot_sd)
)
plot_range <- range(finite_values, na.rm = TRUE)
plot_padding <- max(diff(plot_range) * 0.1, 1)

png(
  filename = file.path(
    figure_dir,
    "woody_stem_productivity_comparison_maliau_2.png"
  ),
  width = 1000,
  height = 700,
  res = 120
)
par(mar = c(5, 10, 4, 2) + 0.1)
plot(
  x = plot_values,
  y = seq_along(plot_values),
  xlim = plot_range + c(-plot_padding, plot_padding),
  ylim = c(0.5, length(plot_values) + 0.5),
  yaxt = "n",
  pch = 19,
  col = c(rep("#2C7FB8", nrow(plot_data)), "#D95F02"),
  xlab = "Productivity (Mg C ha-1 year-1)",
  ylab = "",
  main = "Woody stem productivity: observed and predicted"
)
axis(2, at = seq_along(plot_values), labels = plot_labels, las = 1)
segments(
  x0 = plot_values - plot_sd,
  x1 = plot_values + plot_sd,
  y0 = seq_along(plot_values),
  y1 = seq_along(plot_values),
  col = c(rep("#2C7FB8", nrow(plot_data)), "#D95F02"),
  lwd = 2
)
points(
  plot_values,
  seq_along(plot_values),
  pch = 19,
  col = c(rep("#2C7FB8", nrow(plot_data)), "#D95F02")
)
legend(
  "topright",
  legend = c("Observed value +/- SE", "Predicted mean +/- SD"),
  pch = 19,
  col = c("#2C7FB8", "#D95F02"),
  bty = "n"
)
dev.off()

# Write one merged row per validation plot and mapped variable.
write.csv(
  comparison_data,
  file.path(
    output_dir,
    "realised_tissue_productivity_comparison_maliau_2.csv"
  ),
  row.names = FALSE
)
