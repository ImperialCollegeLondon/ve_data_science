#| ---
#| title: Estimate dissolved organic carbon (DOC) and nitrogen (DON)
#|
#| description: |
#|     This R script estimates dissolved organic carbon (DOC) and nitrogen (DON)
#|     from a Mexican tropical deciduous forest for the initialisation of Maliau
#|     scenario.
#|
#| virtual_ecosystem_module: Soil
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
#|
#| usage_notes: |
#|     DOC is used as an imperfect proxy for LMWC for now. We think this is a
#|     reasonable placeholder value because the goal now is only to get as
#|     close to the initial value as possible.
#| ---


# Dissolved organic carbon (DOC) and nitrogen (DON) from Montano et al. (2007)
# https://doi.org/10.1007/s11104-007-9281-x
# The system was a Mexican tropical deciduous forest; I took the rainy season
# values to approximate moist tropical forests (e.g., Maliau Basin)
# The authors provided means and standard deviations for two consecutive years
# I calculated the global mean and SD based on same sample sizes
# values are in units [microgram / gram]

doc_mean <- (117.6 + 102.2) / 2
doc_sd   <- sqrt(11.2^2 + 7.8^2) / 2
don_mean <- (50.7 + 63.5) / 2
don_sd   <- sqrt(14^2 + 8.8^2) / 2

# Placeholder code to simulate DOC and DON across grids
# then convert units to kg/m^3 assuming a bulk density of 1400.0 kg/m^3
# (this bulk density comes from the soil microbe config; or should we use
# the current abiotic module constant 1175.0 kg/m^3 ?)

n_sim <- 100

doc_sim <- rnorm(n_sim, doc_mean, doc_sd)
doc_sim <- doc_sim / 1e6 * 1400

don_sim <- rnorm(n_sim, don_mean, don_sd)
don_sim <- don_sim / 1e6 * 1400
