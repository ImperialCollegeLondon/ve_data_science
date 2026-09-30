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
#|   It scans the comparison CSV files and generates a Markdown table
#|   that is automatically picked up by the MkDocs site.
#| ---

library(knitr)

# List of all plant comparison output files to track
comparison_files <- c(
  "../../../../../data/derived/plant/output_data/validation/comparisons/realised_tissue_productivity_comparison_maliau_2.csv"
)

output_md_path <- "../../../../../docs/plant_validation_tracker.md"

# Function to extract tracking metadata from a comparison CSV
get_tracking_info <- function(file_path) {
  if (!file.exists(file_path)) {
    return(NULL)
  }

  data <- read.csv(file_path, stringsAsFactors = FALSE, check.names = FALSE)

  # Select metadata columns (ensure they exist)
  metadata_columns <- c(
    "observed_variable",
    "predicted_variable",
    "observed_period",
    "predicted_period",
    "observed_spatial_extent",
    "predicted_spatial_extent",
    "observed_temporal_extent",
    "predicted_temporal_extent",
    "observed_units",
    "predicted_units"
  )

  # Return unique rows
  unique(data[, metadata_columns, drop = FALSE])
}

# Consolidate all tracking info
all_tracking_info <- do.call(rbind, lapply(comparison_files, get_tracking_info))

# Create Markdown table
md_table <- kable(all_tracking_info, format = "markdown")

# Add a header for the markdown document
file_content <- c(
  "# Plant validation Overview",
  "",
  "This table summarizes all completed plant validation comparisons.",
  "",
  md_table
)

# Save the Markdown file
writeLines(file_content, output_md_path)

message(sprintf("Plant validation tracker rendered to: %s", output_md_path))
