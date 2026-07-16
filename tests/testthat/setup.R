#| ---
#| title: Setup script for R testthat tests
#|
#| description: |
#|     Configures the test environment and creates mock data for testthat tests
#|     of R functions. Generates mock arrays matching Virtual Ecosystem model
#|     output structure, and creates temporary netCDF and TOML config files for
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
#|   - name: mock_data.nc
#|     path: tests/testthat/ (temporary)
#|     description: |
#|       Temporary mock netCDF file with soil pool arrays, deleted after test
#|   - name: mock_config.TOML
#|     path: tests/testthat/ (temporary)
#|     description: |
#|       Temporary mock VE config file, deleted after test
#|
#| source_files:
#|   - name: convert_array_to_nc.R
#|     path: tools/R/
#|     description: |
#|       Helper function to convert R arrays to netCDF format
#|   - name: get_data_variables.R
#|     path: tools/R/
#|     description: |
#|       Helper function to extract VE data variables
#|   - name: get_derived_variables.R
#|     path: tools/R/
#|     description: |
#|       Helper function to compute derived variables
#|   - name: generate_test_config.py
#|     path: tools/python/
#|     description: |
#|       Python wrapper around VE's config generation function
#|
#| package_dependencies:
#|     - testthat
#|     - withr
#|     - reticulate
#|     - toml
#|
#| usage_notes: |
#|     Run via: testthat::test_dir("tests/testthat")
#|     Uses relative paths from tests/testthat/ directory. All temporary files
#|     are automatically cleaned up after tests complete via defer_parent().
#| ---

library(here)
library(testthat)
library(withr)
library(reticulate)
source(here("tools/R/convert_array_to_nc.R"))
source(here("tools/R/get_data_variables.R"))
source(here("tools/R/get_derived_variables.R"))


# Mock data --------------------------------------------------------------

# Dimension definitions
element <- c("C", "N", "P")
cell_id <- 0:2
time_index <- 0:1

# Create mock arrays matching model output structure
# Arrays with element dimension: [element × cell_id × time_index]
mock_arrays <- list(
  soil_cnp_pool_lmwc = array(
    1:18,
    dim = c(3, 3, 2),
    dimnames = list(
      element = element,
      cell_id = cell_id,
      time_index = time_index
    )
  ),
  soil_cnp_pool_maom = array(
    2:19,
    dim = c(3, 3, 2),
    dimnames = list(
      element = element,
      cell_id = cell_id,
      time_index = time_index
    )
  ),
  soil_cnp_pool_necromass = array(
    3:20,
    dim = c(3, 3, 2),
    dimnames = list(
      element = element,
      cell_id = cell_id,
      time_index = time_index
    )
  ),
  soil_cnp_pool_pom = array(
    4:21,
    dim = c(3, 3, 2),
    dimnames = list(
      element = element,
      cell_id = cell_id,
      time_index = time_index
    )
  ),
  # Arrays without element dimension: [cell_id × time_index]
  soil_c_pool_arbuscular_mycorrhiza = array(
    5:8,
    dim = c(3, 2),
    dimnames = list(cell_id = cell_id, time_index = time_index)
  ),
  soil_c_pool_bacteria = array(
    6:9,
    dim = c(3, 2),
    dimnames = list(cell_id = cell_id, time_index = time_index)
  ),
  soil_c_pool_ectomycorrhiza = array(
    7:10,
    dim = c(3, 2),
    dimnames = list(cell_id = cell_id, time_index = time_index)
  ),
  soil_c_pool_saprotrophic_fungi = array(
    8:11,
    dim = c(3, 2),
    dimnames = list(cell_id = cell_id, time_index = time_index)
  ),
  soil_n_pool_ammonium = array(
    9:12,
    dim = c(3, 2),
    dimnames = list(cell_id = cell_id, time_index = time_index)
  ),
  soil_n_pool_nitrate = array(
    10:13,
    dim = c(3, 2),
    dimnames = list(cell_id = cell_id, time_index = time_index)
  ),
  soil_p_pool_labile = array(
    11:14,
    dim = c(3, 2),
    dimnames = list(cell_id = cell_id, time_index = time_index)
  ),
  soil_p_pool_primary = array(
    12:15,
    dim = c(3, 2),
    dimnames = list(cell_id = cell_id, time_index = time_index)
  ),
  soil_p_pool_secondary = array(
    13:16,
    dim = c(3, 2),
    dimnames = list(cell_id = cell_id, time_index = time_index)
  )
)

# Function to convert mock arrays to netCDF file for testing
create_mock_nc <- function() {
  mock_nc_path <- test_path("mock_data.nc")
  # save the mock data to a temporary netCDF file
  convert_array_to_nc(mock_arrays, mock_nc_path)
  # Schedule cleanup (file deleted after test completes)
  defer_parent(unlink(mock_nc_path))
}


# Mock config ------------------------------------------------------------

# Import Python config generator, which is a wrapper around VE's function
source_python(here("tools/python/generate_test_config.py"))

# Function to create mock TOML config file for testing
create_mock_cfg <- function() {
  mock_cfg_path <- test_path("mock_config.TOML")
  # save the generated config file to a temporary TOML file, then read it
  generate_test_config(mock_cfg_path)
  cfg <- toml::read_toml(mock_cfg_path)
  # Schedule cleanup
  defer_parent(unlink(mock_cfg_path))
  cfg
}
