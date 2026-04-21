library(toml)


create_data_config <- function() {
  grid <- list(
    grid_type = "square",
    cell_area = 10000,
    cell_nx = 50,
    cell_ny = 50,
    xoff = 494300,
    yoff = 521300
  )

  layers <- list(
    soil_layers = list(-0.25, -1.0),
    canopy_layers = 10,
    above_canopy_height_offset = 2.0,
    subcanopy_layer_height = 1.5,
    surface_layer_height = 0.1
  )

  timing <- list(
    start_date = "2010-01-01",
    update_interval = "1 month",
    run_length = "11 years"
  )

  data_output_options <- list(
    save_initial_state = TRUE
  )

  data_path <- list(
    abiotic = "../data/era5_maliau_2010_2020_100m.nc",
    elevation = "../data/elevation_maliau_2010_2020_100m.nc",
    soil = "../data/soil_maliau.nc",
    litter = "../data/litter_maliau.nc"
  )

  data <- list(
    variable = list(
      list(file_path = data_path$abiotic, var_name = "air_temperature_ref"),
      list(file_path = data_path$abiotic, var_name = "relative_humidity_ref")
    )
  )

  # final output
  list(
    core = list(
      grid = grid,
      layers = layers,
      timing = timing,
      data_output_options = data_output_options,
      data = data
    )
  )
}


create_data_config() |> write_toml()
