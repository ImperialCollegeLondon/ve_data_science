#| ---
#| title: Setup script for R testthat tests
#|
#| description: |
#|     Configures the test environment and creates mock data for testthat tests
#|     of R functions. Generates mock arrays matching Virtual Ecosystem model
#|     output structure, and creates temporary Zarr and TOML config files for
#|     testing functions.
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
#|   - name: mock_data.zarr
#|     path: tests/testthat/ (temporary)
#|     description: |
#|       Temporary mock Zarr dataset with soil pool arrays, deleted after test
#|   - name: mock_config.TOML
#|     path: tests/testthat/ (temporary)
#|     description: |
#|       Temporary mock VE config file, deleted after test
#|
#| source_files:
#|   - name: get_ve_variables.R
#|     path: tools/R/R/
#|     description: |
#|       Functions to retrieve and compute derived Virtual Ecosystem variables
#|   - name: generate_test_config.py
#|     path: tools/python/src/ve_data_tools/
#|     description: |
#|       Python wrapper around VE's config generation function
#|
#| package_dependencies:
#|     - testthat
#|     - withr
#|     - reticulate
#|     - toml
#|     - pizzarr
#|
#| usage_notes: |
#|     Run via: testthat::test_dir("tools/R/tests/testthat")
#|     Uses relative paths from tools/R/tests/testthat directory.
#|     All temporary files are automatically cleaned up after tests complete
#|     via defer_parent().
#| ---

library(here)
library(testthat)
library(withr)
library(reticulate)
library(pizzarr)
source(here("tools/R/R/convert_df_to_nc.R"))
source(here("tools/R/R/get_ve_variables.R"))
source(here("tools/R/R/convert_array.R"))
source(here("tools/R/R/valdb.R"))


# Mock data --------------------------------------------------------------

# Dimension definitions
element <- c("C", "N", "P")
cell_id <- 0:2
time_index <- 0:1

# Create mock arrays matching model output structure
# Arrays with element dimension: [time_index × element × cell_id]
# Now that we switched from netCDF to Zarr, we do not need to reverse the
# order of the dimensions anymore
mock_arrays <- list(
  soil_cnp_pool_lmwc = array(
    1:18,
    dim = c(2, 3, 3),
    dimnames = list(
      time_index = time_index,
      cell_id = cell_id,
      element = element
    )
  ),
  soil_cnp_pool_maom = array(
    2:19,
    dim = c(2, 3, 3),
    dimnames = list(
      time_index = time_index,
      cell_id = cell_id,
      element = element
    )
  ),
  soil_cnp_pool_necromass = array(
    3:20,
    dim = c(2, 3, 3),
    dimnames = list(
      time_index = time_index,
      cell_id = cell_id,
      element = element
    )
  ),
  soil_cnp_pool_pom = array(
    4:21,
    dim = c(2, 3, 3),
    dimnames = list(
      time_index = time_index,
      cell_id = cell_id,
      element = element
    )
  ),
  # Arrays without element dimension: [cell_id × time_index]
  soil_c_pool_arbuscular_mycorrhiza = array(
    5:8,
    dim = c(2, 3),
    dimnames = list(time_index = time_index, cell_id = cell_id)
  ),
  soil_c_pool_bacteria = array(
    6:9,
    dim = c(2, 3),
    dimnames = list(time_index = time_index, cell_id = cell_id)
  ),
  soil_c_pool_ectomycorrhiza = array(
    7:10,
    dim = c(2, 3),
    dimnames = list(time_index = time_index, cell_id = cell_id)
  ),
  soil_c_pool_saprotrophic_fungi = array(
    8:11,
    dim = c(2, 3),
    dimnames = list(time_index = time_index, cell_id = cell_id)
  ),
  soil_n_pool_ammonium = array(
    9:12,
    dim = c(2, 3),
    dimnames = list(time_index = time_index, cell_id = cell_id)
  ),
  soil_n_pool_nitrate = array(
    10:13,
    dim = c(2, 3),
    dimnames = list(time_index = time_index, cell_id = cell_id)
  ),
  soil_p_pool_labile = array(
    11:14,
    dim = c(2, 3),
    dimnames = list(time_index = time_index, cell_id = cell_id)
  ),
  soil_p_pool_primary = array(
    12:15,
    dim = c(2, 3),
    dimnames = list(time_index = time_index, cell_id = cell_id)
  ),
  soil_p_pool_secondary = array(
    13:16,
    dim = c(2, 3),
    dimnames = list(time_index = time_index, cell_id = cell_id)
  )
)

# Function to convert mock arrays to a temporary Zarr file for testing
create_mock_zarr <- function(dir) {
  mock_nc_path <- file.path(dir, "mock_data.nc")
  convert_array_to_zarr(mock_arrays, mock_nc_path)
  return(mock_nc_path)
}


# Mock config ------------------------------------------------------------

# Import Python config generator, which is a wrapper around VE's function
source_python(here("tools/python/src/ve_data_tools/generate_test_config.py"))

# Function to create a temporary mock TOML config file for testing
create_mock_cfg <- function(dir) {
  mock_cfg_path <- file.path(dir, "mock_config.TOML")
  generate_test_config(mock_cfg_path)
  return(mock_cfg_path)
}
