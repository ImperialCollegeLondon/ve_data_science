#' Title
#'
#' @returns
#'
#' @export
#' @examples

build_data_variables_table <- function() {
  toml::read_toml(
    "https://github.com/ImperialCollegeLondon/virtual_ecosystem/raw/refs/heads/develop/virtual_ecosystem/data_variables.toml"
  ) |>
    purrr::pluck("variable") |>
    {
      \(x) purrr::set_names(x, purrr::map_chr(x, "name"))
    }() |>
    purrr::map(~ purrr::discard(.x, names(.x) == "name")) |>
    yaml::write_yaml(
      "data/derived/soil/validation/config/units_canonical.yaml"
    )
}
