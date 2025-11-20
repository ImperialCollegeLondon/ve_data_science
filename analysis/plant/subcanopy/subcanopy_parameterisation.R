#| ---
#| title: Subcanopy parameterisation
#|
#| description: |
#|     This script collects the subcanopy parameters. Maliau is the
#|     preferred target area, if/when available.
#|
#| virtual_ecosystem_module:
#|   - Plants
#|
#| author:
#|   - Arne Scheire
#|
#| status: final
#|
#|
#| input_files:
#|   - name: dobert_2017_species_trait_data.csv
#|     path: data/primary/plant/traits_data
#|     description: |
#|       https://doi.org/10.5061/dryad.f77p7
#|       This CSV file contains a set of traits (e.g., maximum height, fruit,
#|       dispersal, pollination type, etc.) for each species, measured across the
#|       SAFE project and Maliau.
#|   - name: dobert_2017_plot_species_data.csv
#|     path: data/primary/plant/subcanopy
#|     description: |
#|       https://doi.org/10.5061/dryad.f77p7
#|       This csv file contains a matrix of biomass values for 691 plant taxa
#|       sampled across 180 vegetation plots (2 x 2m) located at the Stability
#|       of Altered Forest Ecosystems (SAFE) project in Sabah, Malaysia.
#|   - name: plant_stoichiometry.csv
#|     path: data/derived/plant/traits_data
#|     description: |
#|       This CSV file contains a summary of stoichiometric ratios and lignin
#|       content for different biomass pools for each PFT.
#|
#| output_files:
#|   - name: subcanopy_parameters.csv
#|     path: data/derived/plant/subcanopy
#|     description: |
#|       This CSV file contains the subcanopy parameters, which are part of the
#|       plant model constants.
#|
#| package_dependencies:
#|     -
#|
#| usage_notes: |
#| ---

# Load packages

##################################################

# Subcanopy vegetation carbon mass
# We'll use Dobert et al., 2017 data to obtain subcanopy vegetation carbon mass,
# measured in the OG plots at Maliau. We'll focus on "leafy" plant growth forms,
# and will obtain an average carbon mass in kg C m-2

# Load Dobert et al. (2017) dataset on species trait data and clean up a bit

dobert_2017_species_trait_data <- read.csv(
  "../../../data/primary/plant/traits_data/dobert_2017_species_trait_data.csv",
  header = TRUE
)

# Abbreviations used in Dobert et al., 2017 Supplementary Information

# Column headings:
# species.code: Unique code for each plant taxa
# family: Plant family name
# genus: Plant genus name
# species: Plant species name or unique identifier where species indeterminate
# species.name: The genus and species name
# tree: Distinction between tree (yes), no tree (no) or indeterminate (na)
# woody: Distinction between woody (yes), non-woody (no) or indeterminate (na)
# origin: Distinction between native (n) and exotic (e) plant species
# pgf: Plant growth form: A = fern, B = graminoid, C = forb, D = herbaceous
# climber, E = herbaceous shrub, F = tree sapling, G = woody climber, H = woody
# shrub, na = indeterminate
# height: Maximum plant height (m)
# sla: Specific leaf area (m2.kg-1)
# wood.dens: Wood density (g.cm-3)
# dispersal: Predominant dispersal mode: J = animal, K = ant, L = ballistic,
# M = bat, N = bird, O = primate, P = water, Q = wind, na = indeterminate
# fruit: The type of fruit: R = achene, S = berry, T = berry-like, U = capsule,
# V = caryopsis, W = drupe, X = follicle, Y = legume, Z = nut, a = samara,
# b = schizocarp, na = indeterminate
# seed: The number of seeds per fruit: 1 = 1, 2 = <4, 3 = <10, 4 = >10
# reproduction: The reproduction strategy: s = seed, v = vegetative, sv = seed or
# vegetative, na = indeterminate
# lifehistory: The lifehistory strategy: a = annual, abp = annual or biennial or
# perennial, ap = annual or perennial, p = perennial, na = indeterminate
# pollination: The pollination syndrome: c = bat, d = bee, e = beetle, f = bird,
# g = butterfly, h = entomophilous.broad, i = entomophilous.narrow, j = fly,
# k = moth, l = passive, m = self, n = thrip, o = wasp, p = wind, na = indeterminate

# For the subcanopy vegetation biomass we will use Dobert's dataset for SAFE to
# get an idea of how much carbon is there.
# For now, all plant growth forms are included except tree sapling,
# woody climber (liana) and woody shrub

data <- dobert_2017_species_trait_data

data <- data[data$pgf %in% c("A", "B", "C", "D", "E"), ]

taxa <- unique(data$species.code)

# Taxa with na are excluded when not part of the PGF above, or when not occurring
# in OG plots
# - apounk, comunk, gne076, indunk, malste, memcal, menunk, rhaunk, rubunk, strbra

# Load Dobert plot species data

dobert_2017_plot_species_data <- read.csv(
  "../../../data/primary/plant/subcanopy/dobert_2017_plot_species_data.csv",
  header = TRUE
)

# columns: The unique identifiers of 691 plant taxa
# rows: The 180 vegetation plots across 3 fragments nested within 8 blocks
# Matrix values: The dry weight biomass (g.m-2) of each species in each plot

# Subset to OG plots

dobert_2017_plot_species_data <- dobert_2017_plot_species_data[160:180, ]

# Subset to taxa of interest

dobert_2017_plot_species_data <-
  dobert_2017_plot_species_data[
    , c("X", taxa[taxa %in% colnames(dobert_2017_plot_species_data)])
  ]

# Keep columns only when sum across plots is more than 0

dobert_2017_plot_species_data <- dobert_2017_plot_species_data[
  , c(TRUE, colSums(dobert_2017_plot_species_data[, 2:150]) > 0)
]

taxa_present <- colnames(dobert_2017_plot_species_data[2:15])

# Evaluate species
# alowon1 = alocasia wongii = forb
# begber1 = begonia berhamanii = forb
# bolhet = bolbitis heteroclita = fern
# cosglo = costus globosus = forb
# cosspe = costus speciosus = forb
# cyr075 = cyrtandra sp. = forb
# din141 = dinochloa sp. = herbaceous climber (bamboo)
# hetste1 = heterogonium stenosemioides = fern
# pip139 = piper sp. = herbaceous climber
# potbor1 = pothos borneensis = herbaceous climber
# scipic = scindapsus pictus = herbaceous climber
# sel225 = selliguea sp. = fern
# stasum = stachyphrynium sumatranum = forb
# zinunk = zingiberaceae = forb (ginger) # nolint

# Calculate total subcanopy dry mass per plot (g m-2)

dobert_2017_plot_species_data$total_dry_mass <-
  rowSums(dobert_2017_plot_species_data[, 2:15], na.rm = TRUE)

mean(dobert_2017_plot_species_data$total_dry_mass)

# Correct this mean value for carbon content
# 41.747% carbon content for herb layer reported by
# Wu et al. (2022; https://doi.org/10.3390/su142416517)
dobert_2017_plot_species_data$total_dry_mass <-
  0.41747 * dobert_2017_plot_species_data$total_dry_mass

# Add it to data
data$mean_total_subcanopy_carbon_mass <-
  mean(dobert_2017_plot_species_data$total_dry_mass)

# Note that this is now in g C m-2, so convert to kg C m-2
data$mean_total_subcanopy_carbon_mass <-
  data$mean_total_subcanopy_carbon_mass * 0.001

# Note that we'll still need to scale this to the grid cell size later

# Subset data to only include species in taxa_present
data <- data[data$species.code %in% taxa_present, ]

# Subset data to only include relevant columns
data <- data[, c("mean_total_subcanopy_carbon_mass", "sla")]

# Calculate mean SLA and set to unique values only
data$sla <- mean(data$sla)
data <- unique(data)

# Correct SLA to account for carbon content (use 46.509% from Xie et al., 2019)
# so that its unit is cm2 g-1 C
data$sla <- data$sla / 0.41747

# Convert cm2 g-1 C to m2 kg-1 C
data$sla <- data$sla * 0.1

##################################################

# Initial subcanopy seedbank biomass
# We derive this as the following:
# - seedbank biomass = 23% of seed rain (ak reproductive tissues), based on
# Dalling et al. (1998; https://doi.org/10.2307/176953)
# - reproductive tissues = 0.166-0.222 of aboveground biomass, based on
# Zhang et al. (2020; https://doi.org/10.1007/s11629-020-6253-6)
# Since we do not have subcanopy seed carbon content, we'll apply this ratio
# directly to subcanopy vegetation carbon mass (this assumes similar carbon
# content in leaf and seed)

# Calculate subcanopy reproductive allocation as the mean ratio between
# reproductive tissues and aboveground biomass, based on Zhang et al., 2020
# ratio = reproductive biomass / aboveground biomass
data$subcanopy_reproductive_allocation <-
  (0.437 + 0.389) / (2.002 + 1.693)

data$subcanopy_reproductive_carbon_mass <- # unit = kg C m-2
  data$mean_total_subcanopy_carbon_mass * data$subcanopy_reproductive_allocation

# Then, 23% of this carbon mass ends up in the seed bank
data$subcanopy_seedbank_carbon_mass <-
  data$subcanopy_reproductive_carbon_mass * 0.23

##################################################

# Clean up parameter summary so far
data <- data[, c(
  "mean_total_subcanopy_carbon_mass",
  "subcanopy_seedbank_carbon_mass",
  "sla",
  "subcanopy_reproductive_allocation"
)]
colnames(data) <- c(
  "subcanopy_vegetation_biomass",
  "subcanopy_seedbank_biomass",
  "subcanopy_specific_leaf_area",
  "subcanopy_reproductive_allocation"
)

##################################################

# Add subcanopy respiration fraction, using the value provided in
# Lötscher et al. (2004; https://doi.org/10.1111/j.1469-8137.2004.01170.x)

data$subcanopy_respiration_fraction <- 0.132

##################################################

# Add subcanopy extinction coefficient, using value provided in White et al.
# (2000; DOI https://doi.org/10.1175/1087-3562(2000)004%3C0003:PASAOT%3E2.0.CO;2)

data$subcanopy_extinction_coef <- 0.48

##################################################

# Add subcanopy yield, using the growth respiration presented in
# Lötscher et al. (2004; https://doi.org/10.1111/j.1469-8137.2004.01170.x)

data$subcanopy_yield <- 1 - 0.32

##################################################

# Add subcanopy vegetation turnover, based on
# Singh (1992; https://doi.org/10.1007/BF00045551) and
# Singh and Singh (1991; https://doi.org/10.1093/oxfordjournals.aob.a088252)

# Herbaceous dry weight biomass = 0.35 t ha-1
# Herbaceous annual litterfall = 90 g m-2 (= 0.9 t ha-1)
# So, express subcanopy turnover as yearly litterfall / standing biomass

data$subcanopy_vegetation_turnover <- 0.9 / 0.35 # unit is year-1

##################################################

# Add subcanopy stoichiometry using data for herb layer in primary forest from
# Wu et al. (2022; https://doi.org/10.3390/su142416517)

data$subcanopy_vegetation_c_n_ratio <- 417.47 / 24.27
data$subcanopy_vegetation_c_p_ratio <- 417.47 / 2.02

# Add subcanopy vegetation lignin content
# Calculate the mass of carbon that is specifically contained within lignin,
# using monocot (grass) lignin content (19.5%) from Amatangelo and Vitousek (2009;
# https://doi.org/10.1111/j.1744-7429.2008.00470.x) and
# the carbon content of lignin (62.5%) from Muddasar et al. (2024;
# https://doi.org/10.1016/j.mtsust.2024.100990)

# 0.195*0.625 = 0.121875 (12.1875% of total dry mass is carbon from lignin)
# divide this by total carbon content (41.747%) from Wu et al., 2022

data$subcanopy_vegetation_lignin <- 0.121875 / 0.41747

##################################################

# Add seedbank turnover (i.e., seeds lost from soil seed bank)
# Calculated as 1-fraction seeds expected to still be viable after one year

data$subcanopy_seedbank_turnover <- 1 - 0.68

# Add subcanopy sprout rate (as the fraction of viable seeds within 1 year, while
# assuming all of these will sprout)

data$subcanopy_sprout_rate <- 0.68

# Add subcanopy sprout yield (using subcanopy yield, as this represents a
# correction for carbon lost to growth respiration), using the value reported
# by Lötscher et al. (2004; https://doi.org/10.1111/j.1469-8137.2004.01170.x)

data$subcanopy_sprout_yield <- 1 - 0.32

##################################################

# Add subcanopy seedbank stoichiometry
# Since data is lacking for this we'll use the same values as for trees
# We'll load these from the stoichiometry input data file

plant_stoichiometry <- read.csv(
  "../../../data/derived/plant/traits_data/plant_stoichiometry.csv",
  header = TRUE
)

data$subcanopy_seedbank_c_n_ratio <-
  unique(plant_stoichiometry$plant_reproductive_tissue_turnover_c_n_ratio)
data$subcanopy_seedbank_c_p_ratio <-
  unique(plant_stoichiometry$plant_reproductive_tissue_turnover_c_p_ratio)
data$subcanopy_seedbank_lignin <-
  unique(plant_stoichiometry$plant_reproductive_tissue_lignin)

##################################################

# Write CSV file

write.csv(
  data,
  "../../../data/derived/plant/subcanopy/subcanopy_parameters.csv",
  row.names = FALSE
)

# Summary of units

# "subcanopy_vegetation_biomass" = kg C m-2 # nolint
# "subcanopy_seedbank_biomass" = kg C m-2 # nolint
# "subcanopy_specific_leaf_area" = m2 kg-1 C # nolint
# "subcanopy_reproductive_allocation" = fraction of aboveground (leaf) biomass # nolint
# "subcanopy_respiration_fraction" = fraction of GPP # nolint
# "subcanopy_extinction_coef" = unitless # nolint
# "subcanopy_yield" = fraction of GPP # nolint
# "subcanopy_vegetation_turnover" = year-1 # nolint
# "subcanopy_vegetation_c_n_ratio" = unitless # nolint
# "subcanopy_vegetation_c_p_ratio" = unitless # nolint
# "subcanopy_vegetation_lignin" = unitless # nolint
# "subcanopy_seedbank_turnover" = year-1 # nolint
# "subcanopy_sprout_rate" = fraction of seedbank carbon mass year-1 # nolint
# "subcanopy_sprout_yield" = fraction of seedbank carbon mass # nolint
# "subcanopy_seedbank_c_n_ratio" = unitless # nolint
# "subcanopy_seedbank_c_p_ratio" = unitless # nolint
# "subcanopy_seedbank_lignin" = unitless # nolint
