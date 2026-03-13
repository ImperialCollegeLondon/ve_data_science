#| ---
#| title: Guesstimate soil enzyme concentrations
#|
#| description: |
#|     This R script is a placeholder to estimate soil enzyme concentrations.
#|     I have not been able to find enzyme concentration or biomass stock in
#|     the soil. Most, if not all, studies reported enzyme *activity* levels
#|     instead of biomass. While it is possible to use enzyme activity level
#|     to estimate enzyme stock using Michaelis-Menten kinetics, there are
#|     other unknowns in this approach, e.g., rate constants and substrate
#|     concentrations. For now, our best bet is to initialise VE the same
#|     way as the MEND model (Wang et al. 2013). These initial variables are
#|     certainty worth revisiting.
#|
#| virtual_ecosystem_module: Soil
#|
#| author: Hao Ran Lai
#|
#| status: wip
#|
#| input_files:
#|   - name:
#|     path:
#|     description: |
#|
#| output_files:
#|
#| package_dependencies:
#|
#| usage_notes: |
#|     Currently this script simply records the distributional parameters that
#|     generate lognormal random values that match the MEND model values.
#| ---

# In the MEND model (Wang et al. 2013) https://doi.org/10.1890/12-0681.1
# they used an enzyme concentration of 1e-3 mg C / g soil, which is loosely
# an order of magnitude higher than the value reported by Tabatabai (2003),
# which is a book that I could not find / download;
# Tabatabai (2003) reported glucosidase concentration ranges from 1e-5 to 5e-3
# mg C / g soil, with a mean value of 2e-4 mg C / g soil, assuming a lognormal
# distribution;
# I have iteratively tweaked the following lognormal distribution to get
# random variates that resemble the Tabatabai range and centrality:
# test <- exp(rnorm(10000, log(2e-4), 1.8))   # nolint
# quantile(test, c(0.05, 0.5, 0.95))          # nolint

# There are four groups of soil extracellular enzymes in VE currently and
# I will simply split them equally

enzyme_conc_mean <- log(2e-4)
enzyme_conc_sd <- 1.8

# scaling factor in MEND to raise the Tabatabai values by
# one order of magnitude; I will use a factor of 10 for simplicity here
MEND_factor <- 10
