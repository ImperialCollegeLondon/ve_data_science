#' ---
#' title: Descriptive name of the script
#'
#' description: |
#'     Brief description of what the script does, its main purpose, and any important
#'     scientific context. Keep it concise but informative.
#'
#'     This can include multiple paragraphs.
#'
#' VE_module: Animal, Plant, Abiotic, Soil
#'
#' author:
#'   - name: David Orme
#'
#' # I don't think we should include this. We need to define our shared R environment
#' # but capturing it here doesn't give us useful information and is not portable across
#' # Python and notebook formats.
#' # R_version: !r R.version.string  # Auto-populated when executed in R
#'
#' status: final or wip
#'
#'
#' input_files:
#'   - name: Input file name
#'     path: Full file path on shared drive
#'     description: |
#'       Source (short citation) and a brief explanation of what this input file
#'       contains and its use case in this script
#'
#' output_files:
#'   - name: Output file name
#'     path: Full file path on shared drive
#'     description: |
#'       What the output file contains and its significance, are they used in any other
#'       scripts?
#'
#' package_dependencies:
#'     - vegan
#'     - MASS
#'
#' usage_notes: |
#'   Any known issues or bugs? Future plans for script/extensions or improvements
#'   planned that should be noted?
#' ---
