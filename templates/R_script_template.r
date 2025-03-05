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
#'     - tools
#'
#' usage_notes: |
#'   Any known issues or bugs? Future plans for script/extensions or improvements
#'   planned that should be noted?
#' ---


# An R Markdown template
# First we load the packages at the top of the notebook

library(tools)

# We can define local functions and these should be documented using the
# [ROxygen2 format](https://roxygen2.r-lib.org/articles/rd.html).

my_function <- function(value = 10) {
  #' A function to return a value
  #'
  #' This function simply prints out the value passed to it and then returns the value.
  #' It is just a simple example to give a template for the function description syntax.
  #'
  #' @param value A value to be used in the function
  #'
  #' @return Returns the original valu

  # Print the value
  print(value)

  # Return the value
  return(value)
}

# Now we can use the function.
x <- my_function()
