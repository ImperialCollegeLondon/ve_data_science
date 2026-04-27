#| ---
#| title: Collect filenames and paths to input data into a dataframe
#|
#| description: |
#|     This is a helper function for build_config() in build_config.R to collect
#|     filenames and paths to input data into a dataframe.
#|
#| VE_module: All
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
#|     - toml
#|
#| usage_notes: See details below
#| ---

#' Collect filenames and paths to input data into a dataframe
#'
#' @param plants Full relative path and filename of the plants module input data.
#' @param climate Full relative path and filename of the climate variables in
#'   the abiotic(_simple) module input data.
#' @param elevation Full relative path and filename of the elevation variable
#'   in the abiotic(_simple) module input data.
#' @param soil Full relative path and filename of the soil module input data.
#' @param litter Full relative path and filename of the litter module input data.
#'
#' @returns A data.frame containing var_name for the variable names and
#'   file_path for the corresponding location of the input data.

collect_data_paths <- function(plants, climate, elevation, soil, litter) {
  # plant data
  data.frame(
    var_name = c(
      "plant_pft_propagules",
      "subcanopy_vegetation_biomass",
      "subcanopy_seedbank_biomass"
    ),
    file_path = plants
  ) |>
    # climate data
    bind_rows(
      data.frame(
        var_name = c(
          "air_temperature_ref",
          "relative_humidity_ref",
          "atmospheric_pressure_ref",
          "precipitation",
          "atmospheric_co2_ref",
          "mean_annual_temperature",
          "wind_speed_ref",
          "downward_longwave_radiation",
          "downward_shortwave_radiation"
        ),
        file_path = climate
      )
    ) |>
    # elevation data
    bind_rows(
      data.frame(
        var_name = "elevation",
        file_path = elevation
      )
    ) |>
    # soil data
    bind_rows(
      data.frame(
        var_name = c(
          "soil_cnp_pool_lmwc",
          "soil_cnp_pool_maom",
          "soil_cnp_pool_necromass",
          "soil_cnp_pool_pom",
          "clay_fraction",
          "fungal_fruiting_bodies",
          "pH",
          "soil_c_pool_arbuscular_mycorrhiza",
          "soil_c_pool_bacteria",
          "soil_c_pool_ectomycorrhiza",
          "soil_c_pool_saprotrophic_fungi",
          "soil_enzyme_maom_bacteria",
          "soil_enzyme_maom_fungi",
          "soil_enzyme_pom_bacteria",
          "soil_enzyme_pom_fungi",
          "soil_n_pool_ammonium",
          "soil_n_pool_nitrate",
          "soil_p_pool_labile",
          "soil_p_pool_primary",
          "soil_p_pool_secondary"
        ),
        file_path = soil
      )
    ) |>
    # litter data
    bind_rows(
      data.frame(
        var_name = c(
          "litter_pool_above_metabolic_cnp",
          "litter_pool_above_structural_cnp",
          "litter_pool_below_metabolic_cnp",
          "litter_pool_below_structural_cnp",
          "litter_pool_woody_cnp",
          "lignin_above_structural",
          "lignin_below_structural",
          "lignin_woody"
        ),
        file_path = litter
      )
    )
}
