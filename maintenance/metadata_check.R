#' ---
#' title: Script metadata checker
#'
#' description: |
#'     This file provides the function `check_metadata` that can be used to check that
#'     a given file contains the expected metadata and that it can read correctly.
#'
#'     We aren't sure if we are going to support R markdown rather than Jupyter
#'     notebooks but we'll start with providing some support.
#'
#' VE_module: None
#'
#' author:
#'   - name: David Orme
#'
#' status: wip
#'
#' package_dependencies:
#'     - rmarkdown
#'     - yaml
#'     - tools
#'
#' usage_notes: |
#'     From within R use:
#'
#'     source('templates/metadata_check.R')
#'     yaml <- check_metadata('path/to/file.R')
#' ---

library(rmarkdown)
library(yaml)
library(tools)

check_metadata <- function(file_path) {
    #' Check VE data science script and notebook metadata
    #'
    #' Checks that a script file or notebook contains expected metadata. It raises an
    #' error if the file is missing metadata, if the metadata is badly formatted or if
    #' it contains unexpected values.
    #'
    #' @param file_path The path to the file to be checked
    #'
    #' @return The function returns the YAML metadata if it can be read cleanly.
    #'
    #'

    if (!file.exists(file_path)) {
        simpleError("File path not found.")
    }

    # Extract the file extension
    file_type <- tolower(file_ext(file_path))

    # For R Markdown files, can just use the standard YAML parser
    if (file_type == "rmd") {
        yaml <- yaml_front_matter(file_path)
    } else if (file_type == "r") {
        # Load the script as text
        content <- readLines("templates/R_script_template.r")

        # Locate the YAML document blocks
        document_markers <- grep("#' ---", content)
        n_doc_markers <- length(document_markers)

        # Check there are two...
        if (n_doc_markers != 2) {
            simpleError(sprintf("Found %i not 2 YAML metadata markers.", n_doc_markers))
        }

        # And that the first one is at the start of the file
        if (document_markers[1] != 1) {
            simpleError(
                sprintf("First YAML metadata markers is not at the file start.")
            )
        }

        # Extract the block and strip the comments
        yaml_block <- content[document_markers[1]:document_markers[2]]
        yaml_block <- sub("^#' ?", "", yaml_block)

        yaml <- try(yaml.load(yaml_block), silent = TRUE)
        if (inherits(yaml, "try-error")) {
            simpleError(
                paste0(
                    "Could not load YAML metadata. The YAML loader repoorts:\n",
                    yaml[1]
                )
            )
        }
    }

    # TODO - this could be extended to validate the contents.

    return(yaml)
}
