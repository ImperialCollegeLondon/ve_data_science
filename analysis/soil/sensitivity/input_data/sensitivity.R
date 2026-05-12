library(sensobol)


sobol_mat <- read_rds(
  "data/scenarios/sensitivity_soil_litter/data/sobol_matrix.rds"
)
pars <- colnames(sobol_mat)

ind <- sobol_indices(Y = 1:nrow(sobol_mat), N = n_sample, params = pars)
