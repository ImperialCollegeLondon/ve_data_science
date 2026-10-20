#| ---
#| title: master_validation_tracker
#|
#| description: |
#|   Generates a Markdown-formatted tracking table of all completed validation
#|   comparisons within the Virtual Ecosystem plant module. This table is
#|   rendered in the documentation.
#|
#| virtual_ecosystem_module:
#|   - Plant
#|
#| author:
#|   - Arne Scheire
#|
#| status: wip
#|
#| output_files:
#|   - name: plant_validation_tracker.md
#|     path: docs/
#|     description: |
#|       Markdown-formatted table of all plant validation comparisons.
#|
#| package_dependencies:
#|   - knitr
#|
#| usage_notes: |
#|   Run this script to regenerate the validation tracking table.
#|   It reads comparison CSVs with explicit aggregation metadata and generates
#|   a Markdown table that is automatically picked up by the MkDocs site.
#| ---

library(knitr)

# List of all plant comparison output files to track
comparison_files <- c(
  "../../../../../data/derived/plant/output_data/validation/comparisons/realised_tissue_productivity_comparison_maliau_2.csv",
  "../../../../../data/derived/plant/output_data/validation/comparisons/tree_standing_carbon_mass_comparison_maliau_2.csv"
)

output_md_path <- "../../../../../docs/plant_validation_tracker.md"

required_columns <- c(
  "observed_variable",
  "predicted_variable",
  "observed_units",
  "predicted_units",
  "observed_spatial_extent",
  "predicted_spatial_extent",
  "observed_temporal_extent",
  "predicted_temporal_extent",
  "observed_spatial_aggregation",
  "predicted_spatial_aggregation",
  "observed_temporal_aggregation",
  "predicted_temporal_aggregation"
)

get_aggregation_status <- function(data, column_name) {
  values <- unique(as.character(data[[column_name]]))
  values <- values[!is.na(values) & nzchar(values)]
  if (length(values) != 1 || !values %in% c("exact", "pooled")) {
    stop(sprintf(
      "Expected one exact or pooled status in %s for each variable pair.",
      column_name
    ))
  }
  values
}

format_extent <- function(values, aggregation_status) {
  values <- as.character(values)
  values <- values[!is.na(values) & nzchar(values)]
  if (aggregation_status == "pooled") {
    values <- trimws(unlist(strsplit(values, ";", fixed = TRUE)))
    values <- values[!is.na(values) & nzchar(values)]
    values <- unique(values)
    cell_ids <- suppressWarnings(as.integer(values))
    if (!anyNA(cell_ids)) {
      cell_ids <- sort(unique(cell_ids))
      if (length(cell_ids) > 1 && all(diff(cell_ids) == 1L)) {
        return(paste(range(cell_ids), collapse = " to "))
      }
      return(paste(cell_ids, collapse = "; "))
    }
  }
  paste(values, collapse = "; ")
}

get_one_value <- function(data, column_name) {
  values <- unique(as.character(data[[column_name]]))
  values <- values[!is.na(values) & nzchar(values)]
  if (length(values) != 1) {
    stop(sprintf(
      "Expected one value in %s for each variable pair.",
      column_name
    ))
  }
  values
}

read_comparison_file <- function(file_path) {
  if (!file.exists(file_path)) {
    stop(sprintf("Comparison CSV not found: %s", file_path))
  }

  data <- read.csv(
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
tracker_rows <- lapply(seq_len(nrow(variable_pairs)), function(pair_index) {
  pair <- variable_pairs[pair_index, , drop = FALSE]
  pair_data <- comparison_data[
    comparison_data$observed_variable == pair$observed_variable &
      comparison_data$predicted_variable == pair$predicted_variable,
    ,
    drop = FALSE
  ]
  observed_spatial_status <- get_aggregation_status(
    pair_data,
    "observed_spatial_aggregation"
  )
  predicted_spatial_status <- get_aggregation_status(
    pair_data,
    "predicted_spatial_aggregation"
  )
  observed_temporal_status <- get_aggregation_status(
    pair_data,
    "observed_temporal_aggregation"
  )
  predicted_temporal_status <- get_aggregation_status(
    pair_data,
    "predicted_temporal_aggregation"
  )

  data.frame(
    observed_variable = pair$observed_variable,
    predicted_variable = pair$predicted_variable,
    observed_units = get_one_value(pair_data, "observed_units"),
    predicted_units = get_one_value(pair_data, "predicted_units"),
    observed_spatial_extent = format_extent(
      pair_data$observed_spatial_extent,
      observed_spatial_status
    ),
    predicted_spatial_extent = format_extent(
      pair_data$predicted_spatial_extent,
      predicted_spatial_status
    ),
    observed_temporal_extent = format_extent(
      pair_data$observed_temporal_extent,
      observed_temporal_status
    ),
    predicted_temporal_extent = format_extent(
      pair_data$predicted_temporal_extent,
      predicted_temporal_status
    ),
    observed_spatial_aggregation = observed_spatial_status,
    predicted_spatial_aggregation = predicted_spatial_status,
    observed_temporal_aggregation = observed_temporal_status,
    predicted_temporal_aggregation = predicted_temporal_status,
    stringsAsFactors = FALSE
  )
})
tracker_data <- do.call(rbind, tracker_rows)
row.names(tracker_data) <- NULL

# Create Markdown table
md_table <- kable(tracker_data, format = "markdown", row.names = FALSE)

# Add a header for the markdown document
file_content <- c(
  "# Plant validation Overview",
  "",
  "Each row summarizes one observed-predicted variable pair.",
  "For exact extents, entries in the spatial and date lists are aligned by",
  "position; repeated plot or cell labels represent separate matches.",
  "",
  "Exact means values remain separate at the comparison's plot/cell and",
  "census/timestep units. Coordinates and dates do not necessarily match",
  "exactly: a validation plot may only partly cover a simulation cell, but",
  "we assume its observation can validate the entire cell.",
  "",
  "Pooled consecutive simulation dates and cell IDs are shown as ranges.",
  "",
  md_table,
  "",
  "![Observed vs predicted values for Maliau-2 validation comparisons](../analysis/plant/output_data/validation/metadata/observed_predicted_summary/observed_predicted_summary_maliau_2.png)"
)

# Save the Markdown file
writeLines(file_content, output_md_path)

message(sprintf("Plant validation tracker rendered to: %s", output_md_path))
