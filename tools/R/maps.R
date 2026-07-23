#| ---
#| title: Utilities to map VE
#|
#| description: |
#|     A collection of mapping functions to visualise VE metadata and data
#|
#| virtual_ecosystem_module: All
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|
#| output_files:
#|
#| package_dependencies:
#|     - leaflet
#|     - toml
#|     - purrr
#|
#| usage_notes: See function documentation below.
#| ---

#' Map VE Scenario Extent
#'
#' Creates an interactive leaflet map showing the geographic extent of a
#' scenario defined in a TOML site-definition file.
#'
#' @param site_definition Path to a TOML file containing scenario definitions
#'   with WGS84 bounds.
#' @param site_name Character string naming the site within the TOML file.
#'
#' @return A leaflet map object with satellite imagery and a yellow rectangle
#'   indicating the scenario bounds.
#'
#' @importFrom leaflet leaflet addProviderTiles fitBounds addRectangles
#' @importFrom toml read_toml
#' @importFrom purrr pluck
#'
#' @examples
#' \dontrun{
#'   map_scenario_extent(
#'     "data/derived/site/safe/safe_grid_definition.toml",
#'     "safe_1"
#'   )
#' }
#'
#' @export

map_scenario_extent <- function(site_definition, site_name) {
  # retrieve site boundary coordinates
  site_extent <-
    toml::read_toml(site_definition) |>
    purrr::pluck("Scenario", site_name, "wgs84_bounds") |>
    unlist()

  # serve the leaflet map
  leaflet::leaflet() %>%
    leaflet::addProviderTiles("Esri.WorldImagery") %>%
    leaflet::fitBounds(
      site_extent[1],
      site_extent[2],
      site_extent[3],
      site_extent[4]
    ) |>
    leaflet::addRectangles(
      lng1 = site_extent[1],
      lat1 = site_extent[2],
      lng2 = site_extent[3],
      lat2 = site_extent[4],
      fillOpacity = 0,
      color = "#FFFF00",
      weight = 2
    )
}
