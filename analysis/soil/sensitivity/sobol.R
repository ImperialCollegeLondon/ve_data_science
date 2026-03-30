library(sensobol)
library(ncdf4)
# library(futurize)
library(reticulate)
use_virtualenv("../ve.sandbox/ve_release")




# List initial state variables from Virtual Ecosystem ---------------------

# Import the model class
abiotic_simple <-
  import("virtual_ecosystem.models.abiotic_simple.abiotic_simple_model")
hydrology <-
  import("virtual_ecosystem.models.hydrology.hydrology_model")
plants <-
  import("virtual_ecosystem.models.plants.plants_model")
animal <-
  import("virtual_ecosystem.models.animal.animal_model")
soil <-
  import("virtual_ecosystem.models.soil.soil_model")
litter <-
  import("virtual_ecosystem.models.litter.litter_model")

# Collect the required variables
ve_vars_init <- c(
  unlist(abiotic_simple$AbioticSimpleModel$vars_required_for_init),
  unlist(hydrology$HydrologyModel$vars_required_for_init),
  unlist(plants$PlantsModel$vars_required_for_init),
  unlist(animal$AnimalModel$vars_required_for_init),
  unlist(soil$SoilModel$vars_required_for_init),
  unlist(litter$LitterModel$vars_required_for_init)
) |>
  unique()



# Maliau input data -------------------------------------------------------

get_maliau_range <- function(nc_path) {
  data_maliau <- nc_open(nc_path)
  vars_tmp <- intersect(ve_vars_init, names(data_maliau$var))
  t(sapply(vars_tmp, function(var) {
    ncvar_get(data_maliau, var) |> range()
  }))
}

soil_range <-
  get_maliau_range("data/scenarios/maliau/maliau_1/data/soil_maliau.nc")
litter_range <-
  get_maliau_range("data/scenarios/maliau/maliau_1/data/litter_maliau.nc")

maliau_range <- rbind(soil_range, litter_range)
maliau_vars_init <- rownames(maliau_range)



# Set up Sobol matrix -----------------------------------------------------

n_sample <- 1000

mat <- sobol_matrices(
  N = n_sample,
  params = maliau_vars_init,
  order = "first",
  type = "QRN"
)

# rescale to Maliau ranges
for (i in maliau_vars_init) {
  mat[, i] <-
    mat[, i] * (maliau_range[i, 2] - maliau_range[i, 1]) + maliau_range[i, 1]
}
