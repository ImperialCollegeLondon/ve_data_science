#| ---
#| title: Estimating the effect of lignin on wood litter decay rate
#|
#| description: |
#|     This R script the effect of lignin on wood litter decay rate following
#|     the exponential decay (Olson) model. There is not a lot of good dataset
#|     that measured both decomposition *and* lignin; when they do, they don't
#|     share the data openly (older studies). For our current goals, I found
#|     Geffen et al. (2010) which fitting the right model and provided species
#|     lignin values. They published the k values (rate parameters), so I fitted
#|     a relationship between k and lignin content. Ideally we would estimate k
#|     from raw data but they did not share any raw data. We will have to settle
#|     for this for now.
#|
#| VE_module: Litter
#|
#| author:
#|   - name: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: ecy201091123686-fig-0002-m.csv
#|     path: data/derived/litter/chemistry_and_turnover
#|     description: |
#|       This csv file is digitised from Figure 1 in the original study, Geffen
#|       et al. (2010) https://doi.org/10.1890/09-2224.1 using the metaDigitise
#|       package in R.
#|
#| output_files:
#|
#| package_dependencies:
#|     - tidyverse
#|     - glmmTMB
#|
#| usage_notes: |
#|     Note that there is no output file. The outputs here will be combined
#|     using the script
#|     analysis/litter/chemistry_and_turnover/combined_parameters.R
#| ---

library(tidyverse)
library(glmmTMB)



# Data --------------------------------------------------------------------

# decay rate digitised from Fig. 1 of https://doi.org/10.1890/09-2224.1 using
# metaDigitise; see github.com/daniel1noble/metaDigitise?tab=readme-ov-file
# then lignin data extracted from Table 1 of the same study

geffen_2010_traits <-
  tibble(
    species = c(
      "P. laevis",
      "H. crepitans",
      "Ocotea sp.",
      "P. cecropiilolia",
      "P. nemorosa",
      "S. saponaria",
      "T. oblonga",
      "A. bonariensis",
      "C. estrellensis",
      "F. boliviana",
      "O. guianensis",
      "S. parahyba",
      "C. concolor",
      "H. americanus",
      "T. micrantha"
    ),
    n = c(10, 10, 9, 8, 8, 8, 10, 8, 9, 10, 8, 8, 8, 8, 8),
    CN = c(
      182.9, 238.7, 137.5, 308.4, 336.1, 156.7, 191.5, 222.3, 258.1, 236.1,
      205.9, 274.5, 333.0, 237.9, 339.9
    ),
    N = c(
      2.45, 2.06, 3.37, 1.52, 1.33, 2.80, 2.31, 2.03, 1.80, 1.91, 2.35,
      1.66, 1.36, 1.94, 1.35
    ),
    L = c(
      213.8, 197.3, 194.0, 209.6, 152.1, 161.6, 200.9, 192.9, 203.2, 210.3,
      204.5, 199.9, 178.2, 132.2, 203.3
    )
  ) %>%
  mutate(
    # calculate carbon content (g / g dry mass)
    C = CN * N / 1000,
    # convert lignin to g C in lignin / g C in dry mass
    # assuming 0.625 of lignin is carbon; see Arne's plant stoichiometry script
    lignin = (L / 1000 * 0.625) / C
  )

geffen_2010 <-
  read_csv(
    "data/derived/litter/chemistry_and_turnover/ecy201091123686-fig-0002-m.csv"
  ) %>%
  select(species = group_id, k = mean, se_k = se) %>%
  # convert decay rate from per year to per day
  mutate(k = k / 365.25) %>%
  # join nutrient data
  left_join(geffen_2010_traits)





# Model -------------------------------------------------------------------

mod_k_lignin <- glmmTMB(
  k ~ 1 + lignin,
  data = geffen_2010,
  family = lognormal()
)

summary(mod_k_lignin)
param_k_lignin <- confint(mod_k_lignin)

# interestingly and reassuringly, the decay rate in Geffen et al. (2010)
# was in the same magnitude as the decay rate inferred from our own wood model
