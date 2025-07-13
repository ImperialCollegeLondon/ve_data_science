# Testing script to convert dataframe to netCDF
# The goal is to mimic an ecologist's workflow of converting their field
# data to VE input

# nolint Based on https://pjbartlein.github.io/REarthSysSci/netCDF.html#data-frame-to-array-conversionrectangular-to-raster


library(tidyverse)
library(ncdf4)


# coordinates from ve_example
nx <- 9
ny <- 9
displacement <- seq(0, 721, 90)

# a dataframe that mimics the example soil data
# the functions to generate soil variables are directly copied from the
# generation script of soil example data
mimic <-
  expand.grid(
    x = displacement,
    y = displacement
  ) %>%
  mutate(gradient = x / 90 * y / 90) %>%
  mutate(
    pH_values = 3.5 + 1.00 * gradient / 64.0,
    bulk_density_values = 1200.0 + 600.0 * gradient / 64.0,
    clay_fraction_values = 0.27 + 0.13 * gradient / 64.0,
    lmwc_values = 0.005 + 0.005 * gradient / 64.0,
    maom_values = 1.0 + 2.0 * gradient / 64.0,
    bacterial_C_values = 0.0015 + 0.0035 * gradient / 64.0,
    fungal_C_values = 0.0015 + 0.0035 * gradient / 64.0,
    pom_values = 0.1 + 0.9 * gradient / 64.0,
    necromass_values = 0.00015 + 0.00035 * gradient / 64.0,
    soil_enzyme_pom_bacteria = 0.01 + 0.49 * gradient / 64.0,
    soil_enzyme_maom_bacteria = 0.01 + 0.49 * gradient / 64.0,
    soil_enzyme_pom_fungi = 0.01 + 0.49 * gradient / 64.0,
    soil_enzyme_maom_fungi = 0.01 + 0.49 * gradient / 64.0,
    don_values = 2.5e-4 + 2.5e-4 * gradient / 64.0,
    particulate_n_values = 7.5e-4 + 7.5e-4 * gradient / 64.0,
    maom_n_values = 0.2 + 0.4 * gradient / 64.0,
    ammonium_values = 1e-3 + 4e-3 * gradient / 64.0,
    nitrate_values = 1e-3 + 4e-3 * gradient / 64.0,
    necromass_n_values = 3e-5 + 7e-5 * gradient / 64.0,
    dop_values = 1e-5 + 1e-5 * gradient / 64.0,
    particulate_p_values = 3e-5 + 3e-5 * gradient / 64.0,
    maom_p_values = 0.008 + 0.016 * gradient / 64.0,
    necromass_p_values = 1.2e-6 + 2.8e-6 * gradient / 64.0,
    primary_p_values = 0.001 + 0.004 * gradient / 64.0,
    secondary_p_values = 0.005 + 0.045 * gradient / 64.0,
    labile_p_values = 2.5e-5 + 2.5e-5 * gradient / 64.0
  )

# convert dataframe to arrays
soil_vars <- names(mimic)[-(1:3)]
array_list <- vector("list", length(soil_vars))
names(array_list) <- soil_vars
for (i in soil_vars) {
  array_list[[i]] <- array(mimic[[i]], dim = c(nx, ny))
}

# path and file name of netCDF
ncpath <- "generation/soil/"
ncname <- "example_soil_data_mimic"
ncfname <- paste(ncpath, ncname, ".nc", sep = "")

# create and write the netCDF file -- ncdf4 version
# define dimensions
xdim <- ncdim_def("x", "m", as.double(displacement))
ydim <- ncdim_def("y", "m", as.double(displacement))

# define variables
# can this be simplified with lapply or a loop?
vardef <- list(
  ncvar_def("pH", "unitless", list(xdim, ydim)),
  ncvar_def("bulk_density", "kg m^-3", list(xdim, ydim)),
  ncvar_def("clay_fraction", "fraction", list(xdim, ydim)),
  ncvar_def("soil_c_pool_lmwc", "kg C m^-3", list(xdim, ydim)),
  ncvar_def("soil_c_pool_maom", "kg C m^-3", list(xdim, ydim)),
  ncvar_def("soil_c_pool_bacteria", "kg C m^-3", list(xdim, ydim)),
  ncvar_def("soil_c_pool_fungi", "kg C m^-3", list(xdim, ydim)),
  ncvar_def("soil_c_pool_pom", "kg C m^-3", list(xdim, ydim)),
  ncvar_def("soil_c_pool_necromass", "kg C m^-3", list(xdim, ydim)),
  ncvar_def("soil_enzyme_pom_bacteria", "kg C m^-3", list(xdim, ydim)),
  ncvar_def("soil_enzyme_maom_bacteria", "kg C m^-3", list(xdim, ydim)),
  ncvar_def("soil_enzyme_pom_fungi", "kg C m^-3", list(xdim, ydim)),
  ncvar_def("soil_enzyme_maom_fungi", "kg C m^-3", list(xdim, ydim)),
  ncvar_def("soil_n_pool_don", "kg N m^-3", list(xdim, ydim)),
  ncvar_def("soil_n_pool_particulate", "kg N m^-3", list(xdim, ydim)),
  ncvar_def("soil_n_pool_maom", "kg N m^-3", list(xdim, ydim)),
  ncvar_def("soil_n_pool_ammonium", "kg N m^-3", list(xdim, ydim)),
  ncvar_def("soil_n_pool_nitrate", "kg N m^-3", list(xdim, ydim)),
  ncvar_def("soil_n_pool_necromass", "kg N m^-3", list(xdim, ydim)),
  ncvar_def("soil_p_pool_dop", "kg P m^-3", list(xdim, ydim)),
  ncvar_def("soil_p_pool_particulate", "kg P m^-3", list(xdim, ydim)),
  ncvar_def("soil_p_pool_maom", "kg P m^-3", list(xdim, ydim)),
  ncvar_def("soil_p_pool_necromass", "kg P m^-3", list(xdim, ydim)),
  ncvar_def("soil_p_pool_primary", "kg P m^-3", list(xdim, ydim)),
  ncvar_def("soil_p_pool_secondary", "kg P m^-3", list(xdim, ydim)),
  ncvar_def("soil_p_pool_labile", "kg P m^-3", list(xdim, ydim))
)

# create netCDF file and put arrays
ncout <- nc_create(ncfname, vardef, force_v4 = TRUE)

# put variables
for (i in seq_along(soil_vars)) {
  ncvar_put(ncout, vardef[[i]], array_list[[i]])
}

# add global attributes
ncatt_put(
  ncout, 0, "description",
  "Soil data for dummy Virtual Ecosystem model (mimicked in R)"
)

# Get a summary of the created file:
ncout

# close the file, writing data to disk
nc_close(ncout)
