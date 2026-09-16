#| ---
#| title: plants_cohort_data_maliau_2
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
#|     path: data/derived/plant/output_data/validation/data_library
#|     description: Cleaned SAFE carbon-balance observations for Maliau plots.
#|   - name: plants_cohort_data_standardised_maliau_2.csv
#|     path: data/derived/plant/output_data/validation/scenarios
#|     description: Standardised Maliau 2 plant productivity outputs.
#|
#| output_files:
#|   - name: plant_validation_comparison_maliau_2.csv
#|     path: data/derived/plant/output_data/validation/comparisons
#|     description: |
#|       Merged observed and predicted woody stem productivity values retained
#|       as separate plot-level entries for structural inspection, including
#|       predicted spatial standard deviation.
#|       Predicted variability fields are calculated upstream from temporal
#|       variation within cells and spatial variation among cell means.
#|     period_start: 2011-08-25
#|     period_end: 2018-07-17
#|     period_label: 2011-08 to 2018-07
#|   - name: woody_stem_productivity_comparison_maliau_2.png
#|     path: data/derived/plant/output_data/validation/comparisons/figures_maliau_2
#|     description: |
#|       Point-range plot showing observed plot values with observational
#|       standard errors and the predicted regional mean with spatial SD.
#|
#| package_dependencies: null
#|
#| usage_notes: |
#|   The requested validation period is August 2011 to July 2018. The current
#|   predicted output does not yet cover that period, so this script uses the
#|   full available simulation-period mean and records that choice in
#|   `predicted_period` and `predicted_temporal_aggregation`. Once the longer
#|   simulation is available, rerunning the validation scenario master creates
#|   non-missing selected-period columns and this comparison script switches to
#|   them automatically; no script edit is required. The two observed plots
#|   remain separate to preserve their spatial variation.
#| ---

validation_file <- "../../../../../data/derived/plant/output_data/validation/data_library/carbon_balance_components_maliau.csv"

model_file <- "../../../../../data/derived/plant/output_data/validation/scenarios/plants_cohort_data_standardised_maliau_2.csv"
output_dir <- "../../../../../data/derived/plant/output_data/validation/comparisons"
figure_dir <- file.path(output_dir, "figures_maliau_2")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

validation_data <- utils::read.csv(
  validation_file,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
model_data <- utils::read.csv(
  model_file,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

# The period and units should be loaded from the metadata summary instead.
comparison_period <- "2011-08 to 2018-07"
expected_units <- "Mg C ha-1 year-1"
if (!all(model_data$units == expected_units)) {
  stop("Predicted output units do not match the expected validation units.")
}

# Define comparison mappings by variable. Each tissue has its own mapping
# object, so adding a later tissue cannot overwrite an earlier mapping.

# Woody stem productivity -----------------------------------------------
stem_variable_map <- data.frame(
  validation_variable = "WoodyNPP_Stem",
  validation_se = "SE_WoodyNPP_Stem",
  selected_predicted_variable = "stem_c_productivity_spatial_selected_period_mean",
  simulation_predicted_variable = "stem_c_productivity_spatial_simulation_period_mean",
  selected_predicted_sd = "stem_c_productivity_spatial_selected_period_sd",
  simulation_predicted_sd = "stem_c_productivity_spatial_simulation_period_sd",
  stringsAsFactors = FALSE
)

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
  variable_map$selected_predicted_variable,
  variable_map$simulation_predicted_variable,
  variable_map$selected_predicted_sd,
  variable_map$simulation_predicted_sd,
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

# Resolve one predicted value for each mapped variable. Prefer the requested
# period and use the full-simulation mean only when that period value is unavailable.
predicted_selection <- lapply(
  seq_len(nrow(variable_map)),
  function(variable_index) {
    selected_variable <- variable_map$selected_predicted_variable[
      variable_index
    ]
    simulation_variable <- variable_map$simulation_predicted_variable[
      variable_index
    ]
    selected_values <- unique(model_data[[selected_variable]][
      !is.na(model_data[[selected_variable]])
    ])
    if (length(selected_values) > 0) {
      if (length(selected_values) != 1) {
        stop(sprintf("Expected one predicted value for %s.", selected_variable))
      }
      return(list(
        value = selected_values,
        variable = selected_variable,
        period = comparison_period,
        temporal_aggregation = "mean_across_selected_period",
        sd = unique(model_data[[variable_map$selected_predicted_sd[
          variable_index
        ]]]),
      ))
    }

    simulation_values <- unique(model_data[[simulation_variable]][
      !is.na(model_data[[simulation_variable]])
    ])
    if (length(simulation_values) != 1) {
      stop(sprintf("Expected one predicted value for %s.", simulation_variable))
    }
    list(
      value = simulation_values,
      variable = simulation_variable,
      period = "full_simulation",
      temporal_aggregation = "mean_across_simulation",
      sd = unique(model_data[[variable_map$simulation_predicted_sd[
        variable_index
      ]]])
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
predicted_periods <- vapply(
  predicted_selection,
  function(selection) selection$period,
  character(1)
)
predicted_temporal_aggregation <- vapply(
  predicted_selection,
  function(selection) selection$temporal_aggregation,
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
    predicted_value <- predicted_values[variable_index]

    lapply(seq_len(nrow(validation_data)), function(plot_index) {
      observed_value <- validation_data[[validation_variable]][plot_index]
      observed_se_value <- validation_data[[validation_se_variable]][plot_index]
      data.frame(
        ForestPlotsCode = validation_data$ForestPlotsCode[plot_index],
        SAFEPlotName = validation_data$SAFEPlotName[plot_index],
        PlotName = validation_data$PlotName[plot_index],
        observed_variable = validation_variable,
        predicted_variable = predicted_variable,
        validation_period = comparison_period,
        predicted_period = predicted_periods[variable_index],
        predicted_spatial_aggregation = "mean_across_cells",
        predicted_temporal_aggregation = predicted_temporal_aggregation[
          variable_index
        ],
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
  legend = c("Observed value +/- SE", "Predicted mean +/- spatial SD"),
  pch = 19,
  col = c("#2C7FB8", "#D95F02"),
  bty = "n"
)
dev.off()

# Write one merged row per validation plot and mapped variable.
write.csv(
  comparison_data,
  file.path(output_dir, "plant_validation_comparison_maliau_2.csv"),
  row.names = FALSE
)
