#' Title
#'
#' @param yaml_path
#'
#' @returns
#'
#' @export
#' @examples

add_schema <- function(yaml_path) {
  # Read existing YAML
  existing <- yaml::read_yaml(yaml_path)

  # Default template schema
  template <- list(
    source_id = "author_year",
    data_file = "data/primary/soil/source_id/*.csv",
    skip_rows = 0L,
    variables = list(
      var_original_1 = list(
        var_canonical = "var_ve_1",
        transform = NA,
        unit = "unit",
        unit_transform = NA,
        description = NA
      )
    ),
    dedup_key = c("sample_id", "date", "site_id")
  )

  # Merge: existing values can override template
  merged <- purrr::list_modify(existing, !!!template)

  # Write back
  yaml::write_yaml(merged, yaml_path)
}
