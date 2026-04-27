library(tidyverse)
library(RNetCDF)
library(tidync)
library(ncdf4)
library(purrr)
library(toml)
source("analysis/soil/initialisation/convert_array_to_nc.R")
source("analysis/soil/initialisation/subset_nc.R")


# Maliau site metadata ----------------------------------------------------

maliau_subset <- read_toml(
  "data/derived/site/maliau/maliau_grid_definition_100m_10x10.toml"
)
ll_x <- maliau_subset$ll_x
ll_y <- maliau_subset$ll_y
ur_x <- maliau_subset$ur_x
ur_y <- ll_y + seq_len(maliau_subset$cell_ny) * maliau_subset$res
# determine the cell_id that corresponds to ur_y for plants
cell_id_mat <-
  t(matrix(
    seq_len(maliau_subset$cell_nx * maliau_subset$cell_ny) - 1,
    maliau_subset$cell_nx,
    maliau_subset$cell_ny
  ))
cell_ids <- vector("list", nrow(cell_id_mat))
for (i in seq_len(nrow(cell_id_mat))) {
  row_start <- nrow(cell_id_mat)
  row_end <- row_start - (i - 1)
  cell_ids[[i]] <- as.vector(cell_id_mat[row_start:row_end, ])
}


# Subset input data ------------------------------------------------------

# To quantify runtime per cell, we vary the subset data to be 1x10, 2x10, 3x10
# ... cells from the Maliau 2 scenario data

# First we copy over stuff that do not change across scenarios
copy_dir <- "data/scenarios/maliau/maliau_2/data/"
paste_dir <- "data/scenarios/runtime_per_cell/data/"
files_to_copy <- c(
  "animal_functional_groups_Maliau_level1.csv",
  "plant_constants_Maliau_10x10.csv",
  "plant_pft_definitions_maliau_10x10.csv"
)
file.copy(paste0(copy_dir, files_to_copy), paste_dir)

# Then we generate data and configs that do vary across scenarios
for (j in seq_along(ur_y)) {
  # soil data
  subset_nc(
    nc = "data/scenarios/maliau/maliau_1/data/soil_maliau.nc",
    ll_x = ll_x,
    ll_y = ll_y,
    ur_x = ur_x,
    ur_y = ur_y[j],
    filename = paste0(
      "data/scenarios/runtime_per_cell/data/soil_maliau_",
      j,
      "x10.nc"
    )
  )

  # litter data
  subset_nc(
    nc = "data/scenarios/maliau/maliau_1/data/litter_maliau.nc",
    ll_x = ll_x,
    ll_y = ll_y,
    ur_x = ur_x,
    ur_y = ur_y[j],
    filename = paste0(
      "data/scenarios/runtime_per_cell/data/litter_maliau_",
      j,
      "x10.nc"
    )
  )

  # elevation data
  subset_nc(
    nc = "data/scenarios/maliau/maliau_2/data/elevation_maliau_10x10.nc",
    ll_x = ll_x,
    ll_y = ll_y,
    ur_x = ur_x,
    ur_y = ur_y[j],
    filename = paste0(
      "data/scenarios/runtime_per_cell/data/elevation_maliau_",
      j,
      "x10.nc"
    )
  )

  # climate / abiotic data
  subset_nc(
    nc = "data/scenarios/maliau/maliau_2/data/era5_maliau_10x10_2010_2020.nc",
    ll_x = ll_x,
    ll_y = ll_y,
    ur_x = ur_x,
    ur_y = ur_y[j],
    filename = paste0(
      "data/scenarios/runtime_per_cell/data/era5_maliau_",
      j,
      "x10_2010_2020.nc"
    )
  )

  # plant data
  subset_nc(
    nc = "data/scenarios/maliau/maliau_2/data/plant_input_data_maliau_10x10.nc",
    cell_ids = cell_ids[[j]],
    filename = paste0(
      "data/scenarios/runtime_per_cell/data/plant_input_data_maliau_",
      j,
      "x10.nc"
    )
  )
  # reset cell_id to be compatible with the internal operation of VE
  # very clunky but can't be helped
  plant_nc_tmp <- nc_open(
    paste0(
      "data/scenarios/runtime_per_cell/data/plant_input_data_maliau_",
      j,
      "x10.nc"
    ),
    write = TRUE
  )
  cell_id_reset <- seq_along(ncvar_get(plant_nc_tmp, "cell_id")) - 1
  ncvar_put(plant_nc_tmp, "cell_id", cell_id_reset)
  nc_close(plant_nc_tmp)
  # Subset plant cohort
  plant_cohort <-
    read_csv(
      "data/scenarios/maliau/maliau_2/data/plant_cohort_data_maliau_10x10.csv"
    ) |>
    filter(plant_cohorts_cell_id %in% cell_ids[[j]]) |>
    # reset cell_id to start from zero here too
    mutate(
      plant_cohorts_cell_id = plant_cohorts_cell_id - min(plant_cohorts_cell_id)
    )
  write_csv(
    plant_cohort,
    paste0(
      "data/scenarios/runtime_per_cell/data/plant_cohort_data_maliau_",
      j,
      "x10.csv"
    )
  )

  # now reconfigure the config files
  config_dir <- paste0(
    "data/scenarios/runtime_per_cell/config/config_",
    j,
    "x10"
  )
  if (!dir.exists(config_dir)) {
    dir.create(config_dir)
  }

  # Copy over the remaining config files that do not require modification
  copy_dir <- "data/scenarios/maliau/maliau_2/config/"
  files_to_copy <- c(
    "ve_run.toml",
    "soil_microbial_groups.toml"
  )
  file.copy(paste0(copy_dir, files_to_copy), config_dir)

  # core config
  read_toml(paste0(copy_dir, "data_config.toml")) |>
    write_toml() |>
    edit_toml("core.grid.cell_ny", j) |>
    edit_toml("core.data_output_options.save_initial_state", FALSE) |>
    edit_toml("core.data_output_options.save_continuous_data", FALSE) |>
    edit_toml("core.data_output_options.save_final_state", FALSE) |>
    edit_toml(
      "core.data.variable",
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
        file_path = paste0("../../data/era5_maliau_", j, "x10_2010_2020.nc")
      ) |>
        bind_rows(
          data.frame(
            var_name = c("elevation"),
            file_path = paste0("../../data/elevation_maliau_", j, "x10.nc")
          )
        ) |>
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
            file_path = paste0("../../data/soil_maliau_", j, "x10.nc")
          )
        ) |>
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
            file_path = paste0("../../data/litter_maliau_", j, "x10.nc")
          )
        )
    ) |>
    write_lines(paste0(config_dir, "/data_config.toml"))

  # plants config
  read_toml(paste0(copy_dir, "plant_config.toml")) |>
    write_toml() |>
    edit_toml(
      "plants.cohort_data_path",
      paste0("../../data/plant_cohort_data_maliau_", j, "x10.csv")
    ) |>
    edit_toml(
      "plants.pft_definitions_path",
      "../../data/plant_pft_definitions_Maliau_10x10.csv"
    ) |>
    edit_toml(
      "core.data.variable",
      data.frame(
        var_name = c(
          "plant_pft_propagules",
          "subcanopy_vegetation_biomass",
          "subcanopy_seedbank_biomass"
        ),
        file_path = paste0("../../data/plant_input_data_maliau_", j, "x10.nc")
      )
    ) |>
    edit_toml("plants.community_data_export.required_data", list()) |>
    write_lines(paste0(config_dir, "/plant_config.toml"))

  # animal config
  read_toml(paste0(copy_dir, "animal_config.toml")) |>
    write_toml() |>
    # same plants cohort across
    edit_toml(
      "animal.functional_group_definitions_path",
      "../../data/animal_functional_groups_Maliau_level1.csv"
    ) |>
    edit_toml("animal.cohort_data_export.enabled", FALSE) |>
    edit_toml("animal.cohort_data_export.cohort_attributes", list()) |>
    write_lines(paste0(config_dir, "/animal_config.toml"))
}
