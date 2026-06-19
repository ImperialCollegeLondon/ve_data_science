# comment on relative path and this file is meant to run with testthat::test_dir("tests/testthat")

library(testthat)
library(withr)
source("../../tools/R/convert_array_to_nc.R")
source("../../tools/R/get_data_variables.R")
source("../../tools/R/get_derived_variables.R")

element <- c("C", "N", "P")
cell_id <- 0:2
time_index <- 0:1

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
  )
)

create_mock_nc <- function() {
  mock_nc_path <- test_path("mock_data.nc")
  convert_array_to_nc(mock_arrays, mock_nc_path)
  defer_parent(unlink(mock_nc_path))
}
