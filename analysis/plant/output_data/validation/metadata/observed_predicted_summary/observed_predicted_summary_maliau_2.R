#| ---
#| title: observed_predicted_summary_maliau_2
#|
#| description: |
#|   Creates observed-versus-predicted scatterplots for all active plant
#|   validation comparison outputs in one scatterplot using raw values.
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
#|   - name: realised_tissue_productivity_comparison_maliau_2.csv
#|     path: data/derived/plant/output_data/validation/comparisons
#|     description: Observed and pooled predicted productivity values.
#|   - name: tree_standing_carbon_mass_comparison_maliau_2.csv
#|     path: data/derived/plant/output_data/validation/comparisons
#|     description: Matched observed and predicted standing-carbon values.
#|
#| output_files:
#|   - name: observed_predicted_summary_maliau_2.png
#|     path: analysis/plant/output_data/validation/metadata/observed_predicted_summary
#|     description: Raw observed-versus-predicted comparison scatterplot.
#|
#| usage_notes: |
#|   Run this script from its directory after generating the comparison CSVs.
#|   Each point represents one row in a comparison CSV; plot observations
#|   repeated across intersecting cells are not independent observations.
#|   Values use a shared raw-value scale; units vary between variable pairs.
#| ---

comparison_files <- c(
  "../../../../../../data/derived/plant/output_data/validation/comparisons/realised_tissue_productivity_comparison_maliau_2.csv",
  "../../../../../../data/derived/plant/output_data/validation/comparisons/tree_standing_carbon_mass_comparison_maliau_2.csv"
)
output_file <- "observed_predicted_summary_maliau_2.png"

required_columns <- c(
  "observed_variable",
  "predicted_variable",
  "observed_units",
  "predicted_units",
  "observed_value",
  "predicted_value"
)

read_comparison_file <- function(file_path) {
  if (!file.exists(file_path)) {
    stop(sprintf("Comparison CSV not found: %s", file_path))
  }

  data <- utils::read.csv(
    file_path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  missing_columns <- setdiff(required_columns, names(data))
  if (length(missing_columns) > 0) {
    stop(sprintf(
      "%s is missing required columns: %s",
      basename(file_path),
      paste(missing_columns, collapse = ", ")
    ))
  }
  data[, required_columns, drop = FALSE]
}

comparison_data <- do.call(
  rbind,
  lapply(comparison_files, read_comparison_file)
)
variable_pairs <- unique(comparison_data[
  c("observed_variable", "predicted_variable")
])

draw_comparison_figure <- function(data, pairs, file_path) {
  pair_count <- nrow(pairs)
  pair_colours <- grDevices::hcl.colors(pair_count, palette = "Dark 3")
  pair_labels <- character(pair_count)
  raw_values <- vector("list", pair_count)

  for (pair_index in seq_len(pair_count)) {
    pair <- pairs[pair_index, , drop = FALSE]
    pair_data <- data[
      data$observed_variable == pair$observed_variable &
        data$predicted_variable == pair$predicted_variable,
      ,
      drop = FALSE
    ]
    units <- unique(c(pair_data$observed_units, pair_data$predicted_units))
    if (length(units) != 1) {
      stop(sprintf(
        "Observed and predicted units must match for %s.",
        pair$observed_variable
      ))
    }

    observed_values <- as.numeric(pair_data$observed_value)
    predicted_values <- as.numeric(pair_data$predicted_value)
    valid_rows <- is.finite(observed_values) & is.finite(predicted_values)
    observed_values <- observed_values[valid_rows]
    predicted_values <- predicted_values[valid_rows]
    if (length(observed_values) == 0) {
      stop(sprintf(
        "No finite comparison values for %s.",
        pair$observed_variable
      ))
    }

    raw_values[[pair_index]] <- list(
      observed = observed_values,
      predicted = predicted_values
    )
    pair_labels[pair_index] <- paste(
      pair$observed_variable,
      "/",
      pair$predicted_variable,
      sprintf("(%s; n=%d)", units, length(observed_values))
    )
  }

  grDevices::png(file_path, width = 2400, height = 2800, res = 200)
  graphics::layout(matrix(c(1, 2), nrow = 2), heights = c(5, 2.2))
  old_par <- graphics::par(
    mar = c(4.5, 4.5, 3.5, 1),
    pty = "s"
  )
  on.exit({
    graphics::par(old_par)
    grDevices::dev.off()
  })

  all_values <- unlist(lapply(raw_values, function(values) {
    c(values$observed, values$predicted)
  }))
  plot_limits <- range(all_values)
  if (diff(plot_limits) == 0) {
    plot_limits <- plot_limits + c(-1, 1)
  } else {
    padding <- diff(plot_limits) * 0.04
    plot_limits <- plot_limits + c(-padding, padding)
  }
  graphics::plot(
    NA,
    xlim = plot_limits,
    ylim = plot_limits,
    asp = 1,
    xaxs = "i",
    yaxs = "i",
    xlab = "Observed value (units vary by comparison)",
    ylab = "Predicted value (units vary by comparison)",
    main = "Observed vs predicted across Maliau-2 comparisons"
  )
  graphics::mtext(
    paste(
      "Red dashed line indicates 1:1 agreement (predicted equals observed).",
      "Raw values shown; units are listed in the legend."
    ),
    side = 3,
    line = 0.3,
    cex = 0.85
  )
  graphics::segments(
    plot_limits[1],
    plot_limits[1],
    plot_limits[2],
    plot_limits[2],
    col = "#B34A3C",
    lty = 2,
    lwd = 1.5
  )
  for (pair_index in seq_len(pair_count)) {
    graphics::points(
      raw_values[[pair_index]]$observed,
      raw_values[[pair_index]]$predicted,
      pch = 16,
      col = grDevices::adjustcolor(pair_colours[pair_index], alpha.f = 0.7)
    )
  }
  graphics::par(mar = c(1.5, 0, 0, 0), pty = "m")
  graphics::plot.new()
  graphics::legend(
    "top",
    legend = pair_labels,
    col = pair_colours,
    pch = 16,
    bty = "n",
    cex = 0.85,
    ncol = 1
  )
  graphics::mtext(
    "Repeated plot-cell matches are not always independent observations.",
    side = 1,
    line = 0.3,
    cex = 0.8
  )
}

draw_comparison_figure(comparison_data, variable_pairs, output_file)
message(sprintf("Observed-versus-predicted figure written to: %s", output_file))
