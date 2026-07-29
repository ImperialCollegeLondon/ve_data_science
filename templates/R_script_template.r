#| ---
#| title: Descriptive name of the script
#|
#| description: |
#|     Brief description of what the script does, its main purpose, and any
#|     important scientific context. Keep it concise but informative.
#|
#|     This can include multiple paragraphs.
#|
#| virtual_ecosystem_module: [Animal, Plant, Abiotic, Soil, Litter, or All]
#|
#| author:
#|   - David Orme
#|
#| status: final or wip
#|
#| input_files:
#|   - name: Input file name with extension
#|     path: Full relative path in the repository
#|     description: |
#|       Brief explanation of what this file contains and use case here
#|
#| output_files:
#|   - name: Output file name with extension
#|     path: Full relative path in the repository
#|     description: |
#|       Brief explanation of what this file contains and use case here
#|
#| source_files:
#|   - name: Source scripts used in source() or box::use()
#|     path: Full relative path in the repository
#|     description: |
#|       Brief explanation of what this script contains and use case here
#|
#| package_dependencies:
#|     - tools
#|
#| usage_notes: |
#|   Any known issues or bugs? Future plans for extensions or improvements
#|   that should be noted?
#| ---

# An R Script template
# First we load the packages at the top of the notebook

library(tools)

# We can define local functions and these should be documented using the
# [ROxygen2 format](https://roxygen2.r-lib.org/articles/rd.html).

my_function <- function(value = 10) {
  #| A function to return a value
  #|
  #| This function simply prints out the value passed to it and then returns the value.
  #| It is just a simple example to give a template for the function description syntax.
  #|
  #| @param value A value to be used in the function
  #|
  #| @return Returns the original valu

  # Print the value
  print(value)

  # Return the value
  return(value)
}

# Now we can use the function.
my_value <- my_function()
