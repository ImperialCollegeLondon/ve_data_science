#| ---
#| title: Short, descriptive script title
#|
#| description: |
#|   Briefly explain the purpose of the script, the problem it solves, and any
#|   important assumptions or context needed to understand it.
#|
#|   Use one or more paragraphs if needed. Keep the description specific enough
#|   that a future reader can tell what the script is for without reading the
#|   code.
#|
#| virtual_ecosystem_module: [Animal, Plant, Abiotic, Soil, Litter, or All]
#|
#| author:
#|   - Full name of the script author
#|
#| status: final or wip
#|
#| input_files:
#|   - name: Input file name
#|     path: Relative repository path to the input file
#|     description: |
#|       What the file contains and why the script needs it.
#|
#| output_files:
#|   - name: Output file name
#|     path: Relative repository path to the output file
#|     description: |
#|       What the file contains and how it is intended to be used.
#|
#| source_files:
#|   - name: Source script name
#|     path: Relative repository path to the sourced file
#|     description: |
#|       Why the script is sourced or imported.
#|
#| package_dependencies:
#|   - package_name
#|
#| usage_notes: |
#|   Add important caveats, known limitations, required setup, or follow-up work.
#|   Keep this field focused on information that helps a future maintainer run
#|   or extend the script safely.
#| ---

# Load required packages
# Add only the packages actually used by this script.
library(package_name)

# Optional helper functions
# Define local helpers with source() or box::use() here if needed
# These should be listed under source_files in the metadata header

#' Brief function summary
#'
#' Describe what the function does in one or more sentences.
#'
#' @param value Description of the input.
#' @return Description of the returned value.
#' @examples
#' \dontrun{
#'   example_function()
#' }
example_function <- function(value) {
  value
}

# Main workflow
# Keep the top-level execution in a clear, linear order.

# Read inputs
# Transform data
# Write outputs
