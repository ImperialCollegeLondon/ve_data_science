# This file is used to record packages used by the project system that would not
# otherwise be used within R code. The `renv` package automatically scans R code files
# for packages used within the project, so there is no need to add packages used in
# analysis.

# This is required for R support in VSCode
library(languageserver)
library(styler) # Provides code formatting suggestions and auto-formatting
# The VSCode lintr extension uses this package for linting, but it isn't included as a
# dependency of lintr so it needs to be explicitly included here.
library(cyclocomp)
