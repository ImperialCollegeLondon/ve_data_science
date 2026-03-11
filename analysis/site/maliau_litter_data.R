#| ---
#| title:
#|
#| description: |
#|     This R script
#|
#| virtual_ecosystem_module: Litter
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name:
#|     path:
#|     description: |
#|
#| output_files:
#|
#| package_dependencies:
#|     - tidyverse
#|     - mvtnorm
#|     - RcppTOML
#|
#| usage_notes: |
#|     For more details on statistical and data assumptions, see
#|     data/scenarios/maliau/soil_metadata.toml
#| ---

library(tidyverse)
library(mvtnorm)
library(RcppTOML)



# Maliau site metadata ----------------------------------------------------

maliau <- parseTOML("data/derived/site/maliau_grid_definition_100m.toml")

# total number of grids
n_sim <- with(maliau, cell_nx * cell_ny)




# Set up dataframe --------------------------------------------------------
# this dataframe will store generated initial values, and then be converted
# to a netCDF output at the end

dat <-
  expand_grid(
    cell_x = maliau$cell_x_centres,
    cell_y = maliau$cell_y_centres
  ) |>
  # calculate displacements
  mutate(x = cell_x - min(cell_x),
         y = cell_y - min(cell_y))



# Litter stock ------------------------------------------------------------

# Including:
# litter_pool_above_metabolic
# litter_pool_above_structural
# litter_pool_woody
# litter_pool_below_metabolic
# litter_pool_below_structural

# Litter stock means are straightforward, but not their variances. This is
# because we modelled physical litter types (e.g., leaf, root, twig) but then
# converted them to more abstract pools (e.g., metabolic and structural).
# During this conversion, the propagation of mean values is straightforward,
# but not the propagation of variances is less so. For example, we may know
# that the mean of a structural pool is (1 - f_m) * X, but what is its
# variance? There are a few statistical approaches (e.g., delta method and
# numerical simulation) but they are either slightly out of my comfort zone or
# time consuming. So I opted to set standard deviations at 1/10 of their mean.
# This value is selected such that the aboveground pool sum has similar range
# to their observed physical counterparts at SAFE. Then I assume the same also
# applies to the woody and belowground pools.

litter_stocks <- read_csv("data/derived/litter/stock/litter_stock.csv")

litter_stocks_meanlog <- log(litter_stocks$stock)
litter_stocks_sdlog <- abs(litter_stocks_meanlog / 10)
# generate compound symmetry correlation matrix
rho <- 0.5
litter_stocks_cor <-
  (1 - rho) * diag(length(litter_stocks_meanlog)) + rho
# covariance matrix
litter_stocks_Sigma <-
  litter_stocks_cor * outer(litter_stocks_sdlog, litter_stocks_sdlog)

litter_stocks_sim <- rmvnorm(n_sim, litter_stocks_meanlog, litter_stocks_Sigma)
litter_stocks_sim <- exp(litter_stocks_sim)
colnames(litter_stocks_sim) <- litter_stocks$pool

# hist(litter_stocks_sim[,1] + litter_stocks_sim[,2], breaks = 100)



# lignin_above_structural
# lignin_woody
# lignin_below_structural

