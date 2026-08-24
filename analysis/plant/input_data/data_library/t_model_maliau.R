#| ---
#| title: t_model_maliau
#|
#| description: |
#|     This script calculates values for the T model parameters for Maliau.
#|     Taxa are linked to their PFT by using the pfts_maliau output.
#|     Some additional traits that are part of the plant constants are also
#|     included in the final output.
#|
#| virtual_ecosystem_module:
#|   - Plants
#|
#| author:
#|   - Arne Scheire
#|
#| status: final
#|
#| input_files:
#|   - name: tree_census_11_20.xlsx
#|     path: data/primary/plant/tree_census
#|     description: |
#|       https://doi.org/10.5281/zenodo.14882506
#|       Tree census data from the SAFE Project 2011–2020.
#|       Data includes measurements of DBH and estimates of tree height for
#|       all stems, fruiting and flowering estimates, estimates of epiphyte
#|       and liana cover, and taxonomic IDs.
#|   - name: pfts_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       A CSV file listing species by PFT.
#|   - name: inagawa_nutrients_wood_density.xlsx
#|     path: data/primary/plant/traits_data
#|     description: |
#|       https://doi.org/10.5281/zenodo.8158811
#|       Nutrients and wood density in coarse root, trunk and branches in
#|       Bornean tree species.
#|   - name: both_tree_functional_traits.xlsx
#|     path: data/primary/plant/traits_data
#|     description: |
#|       https://doi.org/10.5281/zenodo.3247631
#|       Functional traits of tree species in old-growth and selectively
#|       logged forest.
#|
#| output_files:
#|   - name: t_model_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       A CSV file listing T model parameters by pft.
#|     variables:
#|       - name: pft_name
#|         type: character
#|         units: dimensionless
#|         description: |
#|           See pfts_maliau.
#|         references:
#|           - citation: null
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: null
#|       - name: h_max
#|         type: numeric
#|         units: m
#|         description: |
#|           Asymptotic maximum tree height.
#|         references:
#|           - citation: "Svátek et al. (2025)"
#|             doi: "https://doi.org/10.5281/zenodo.14882506"
#|             url: "https://zenodo.org/records/14882506"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: "Estimated by fitting an asymptotic height-diameter model to SAFE census trees within each PFT, using 2011 data across all plots."
#|       - name: a_hd
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Initial slope parameter of the height–diameter relationship.
#|         references:
#|           - citation: "Svátek et al. (2025)"
#|             doi: "https://doi.org/10.5281/zenodo.14882506"
#|             url: "https://zenodo.org/records/14882506"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: "Estimated by fitting an asymptotic height-diameter model to SAFE census trees within each PFT, using 2011 data across all plots."
#|       - name: ca_ratio
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Initial ratio of crown area to stem cross-sectional area.
#|         references:
#|           - citation: "Svátek et al. (2025)"
#|             doi: "https://doi.org/10.5281/zenodo.14882506"
#|             url: "https://zenodo.org/records/14882506"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: "Estimated by fitting crown projected area relationships for each PFT, using 2011 data across all plots."
#|       - name: rho_s
#|         type: numeric
#|         units: kg C m-3
#|         description: |
#|           Sapwood density expressed as carbon mass per unit volume.
#|         references:
#|           - citation: "Both et al. (2019)"
#|             doi: "https://doi.org/10.5281/zenodo.3247631"
#|             url: "https://zenodo.org/records/3247631"
#|             origin: "SAFE Project and Danum Valley Conservation Area, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2014-2018"
#|           - citation: "Inagawa et al. (2023)"
#|             doi: "https://doi.org/10.5281/zenodo.8158811"
#|             url: "https://zenodo.org/records/8158811"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "mixed dipterocarp lowland rainforest"
#|             site_condition: "logged"
#|             date: "2014-2015"
#|         assumptions: "Mean sapwood density without bark converted to carbon density using mean sapwood carbon content."
#|       - name: sla
#|         type: numeric
#|         units: mm2 mg-1 C
#|         description: |
#|           Specific leaf area expressed per unit carbon mass.
#|         references:
#|           - citation: "Both et al. (2019)"
#|             doi: "https://doi.org/10.5281/zenodo.3247631"
#|             url: "https://zenodo.org/records/3247631"
#|             origin: "SAFE Project and Danum Valley Conservation Area, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2014-2018"
#|         assumptions: "Species specific leaf area per carbon mass, averaged by PFT."
#|       - name: lai
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Leaf area index.
#|         references:
#|           - citation: "Pfeifer et al. (2016)"
#|             doi: "https://doi.org/10.1016/j.rse.2016.01.014"
#|             url: "https://www.sciencedirect.com/science/article/pii/S003442571630013X?via%3Dihub"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "primary and secondary"
#|             date: "2012-2013"
#|         assumptions: "Applied as a single constant across pfts, using the value from primary forest only."
#|       - name: par_ext
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Light extinction coefficient for photosynthetically active radiation.
#|         references:
#|           - citation: "White et al. 2000"
#|             doi: "https://doi.org/10.1175/1087-3562(2000)004%3C0003:PASAOT%3E2.0.CO;2"
#|             url: "https://journals.ametsoc.org/view/journals/eint/4/3/1087-3562_2000_004_0003_pasaot_2.0.co_2.xml"
#|             origin: null
#|             biome: null
#|             vegetation_type: "rain forest"
#|             site_condition: null
#|             date: ""
#|         assumptions: "Value used is the one reported for rain forest by Waring and Schlesinger (1985)."
#|       - name: tau_f
#|         type: numeric
#|         units: years
#|         description: |
#|           Leaf turnover time.
#|         references:
#|           - citation: "Anderson et al. 1983"
#|             doi: "https://doi.org/10.2307/2259731"
#|             url: "https://www.jstor.org/stable/2259731?origin=crossref"
#|             origin: "Gunung Mulu National Park, Sarawak, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: "primary"
#|             date: "1978"
#|         assumptions: "Derived as the inverse of reported annual leaf turnover and applied uniformly across pfts."
#|       - name: tau_rt
#|         type: numeric
#|         units: years
#|         description: |
#|           Reproductive tissue turnover time.
#|         references:
#|           - citation: "Anderson et al. 1983"
#|             doi: "https://doi.org/10.2307/2259731"
#|             url: "https://www.jstor.org/stable/2259731?origin=crossref"
#|             origin: "Gunung Mulu National Park, Sarawak, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: "primary"
#|             date: "1978"
#|         assumptions: "Derived as the inverse of reported annual reproductive-organ turnover and applied uniformly across pfts."
#|       - name: tau_r
#|         type: numeric
#|         units: years
#|         description: |
#|           Fine root turnover time.
#|         references:
#|           - citation: "Huaraca Huasco et al. (2021)"
#|             doi: "https://doi.org/10.1111/gcb.15677"
#|             url: "https://onlinelibrary.wiley.com/doi/10.1111/gcb.15677"
#|             origin: "Maliau and Danum Valley Conservation Area, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "primary"
#|             date: "2021"
#|         assumptions: "Calculated as the mean root residence time across two Maliau plots and applied uniformly across pfts."
#|       - name: resp_r
#|         type: numeric
#|         units: year-1
#|         description: |
#|           Fine root specific maintenance respiration rate.
#|         references:
#|           - citation: "Yan and Zhao (2007)"
#|             doi: "http://dx.doi.org/10.1016/S1872-2032(07)60056-0"
#|             url: "https://www.sciencedirect.com/science/article/pii/S1872203207600560?via%3Dihub"
#|             origin: null
#|             biome: null
#|             vegetation_type: "rain forest tree"
#|             site_condition: null
#|             date: null
#|         assumptions: "Converted from a daily literature respiration value to an annual rate and applied uniformly across pfts."
#|       - name: resp_f
#|         type: numeric
#|         units: year-1
#|         description: |
#|           Leaf specific maintenance respiration rate.
#|         references:
#|           - citation: "Yan and Zhao (2007)"
#|             doi: "http://dx.doi.org/10.1016/S1872-2032(07)60056-0"
#|             url: "https://www.sciencedirect.com/science/article/pii/S1872203207600560?via%3Dihub"
#|             origin: null
#|             biome: null
#|             vegetation_type: "rain forest tree"
#|             site_condition: null
#|             date: null
#|         assumptions: "Converted from a daily literature respiration value to an annual rate and applied uniformly across pfts."
#|       - name: resp_s
#|         type: numeric
#|         units: year-1
#|         description: |
#|           Wood specific maintenance respiration rate.
#|         references:
#|           - citation: "Yan and Zhao (2007)"
#|             doi: "http://dx.doi.org/10.1016/S1872-2032(07)60056-0"
#|             url: "https://www.sciencedirect.com/science/article/pii/S1872203207600560?via%3Dihub"
#|             origin: null
#|             biome: null
#|             vegetation_type: "rain forest tree"
#|             site_condition: null
#|             date: null
#|         assumptions: "Converted from a daily literature respiration value to an annual rate and applied uniformly across pfts."
#|       - name: resp_rt
#|         type: numeric
#|         units: year-1
#|         description: |
#|           Reproductive tissue respiration parameter.
#|         references:
#|           - citation: "Kinugasa et al. (2005)"
#|             doi: "https://doi.org/10.1093/aob/mci152"
#|             url: "https://academic.oup.com/aob/article-abstract/96/1/81/174607?redirectedFrom=fulltext"
#|             origin: "laboratory settings"
#|             biome: "temperate"
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Production of reproductive organs is assumed to be consistent throughout the year. Value is treated as constant across pfts."
#|       - name: yld
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Yield factor used in the T model.
#|         references:
#|           - citation: "Yan and Zhao (2007)"
#|             doi: "http://dx.doi.org/10.1016/S1872-2032(07)60056-0"
#|             url: "https://www.sciencedirect.com/science/article/pii/S1872203207600560?via%3Dihub"
#|             origin: null
#|             biome: null
#|             vegetation_type: "rain forest tree"
#|             site_condition: null
#|             date: null
#|         assumptions: "Derived from growth respiration coefficient."
#|       - name: zeta
#|         type: numeric
#|         units: kg C m-2
#|         description: |
#|           Fine root carbon mass to foliage area ratio.
#|         references:
#|           - citation: "Niiyama et al. (2010)"
#|             doi: "http://dx.doi.org/10.1017/S0266467410000040"
#|             url: "https://www.cambridge.org/core/journals/journal-of-tropical-ecology/article/abs/estimation-of-root-biomass-based-on-excavation-of-individual-root-systems-in-a-primary-dipterocarp-forest-in-pasoh-forest-reserve-peninsular-malaysia/523F092746792B1ABF3B18DEE483895F"
#|             origin: "Pasoh Forest Reserve, Peninsular Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: "primary"
#|             date: "2004-2005"
#|           - citation: "Both et al. (2019)"
#|             doi: "https://doi.org/10.5281/zenodo.3247631"
#|             url: "https://zenodo.org/records/3247631"
#|             origin: "SAFE Project and Danum Valley Conservation Area, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2014-2018"
#|           - citation: "Imai et al. (2010)"
#|             doi: "https://doi.org/10.1017/S0266467410000350"
#|             url: "https://www.cambridge.org/core/journals/journal-of-tropical-ecology/article/abs/distribution-of-phosphorus-in-an-abovetobelowground-profile-in-a-bornean-tropical-rain-forest/FCCE8AA3D75C97EA444F509BF8F3FF51"
#|             origin: "Deramakot Forest Reserve, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "rain forest"
#|             site_condition: "pristine"
#|             date: "2010"
#|         assumptions: "Derived using plot level fine-root to foliage mass relationships combined with PFT-specific SLA and mean fine-root carbon content."
#|       - name: root_exudates
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Fraction of NPP carbon allocated to root exudates.
#|         references:
#|           - citation: "Aoki et al. (2013)"
#|             doi: "https://doi.org/10.1007/s10021-012-9575-6"
#|             url: "https://link.springer.com/article/10.1007/s10021-012-9575-6"
#|             origin: "Mount Kinabalu, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland rainforest"
#|             site_condition: "primary"
#|             date: "2012"
#|         assumptions: "Allocation assumed to be constant across pfts."
#|       - name: per_stem_annual_mortality_probability
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Annual probability of mortality per stem.
#|         references:
#|           - citation: "Bisschoff et al. (2005)"
#|             doi: "https://doi.org/10.1016/j.foreco.2005.07.009"
#|             url: "https://www.sciencedirect.com/science/article/pii/S0378112705004603?via%3Dihub"
#|             origin: "Danum Valley Conservation Area, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp rain forest"
#|             site_condition: "primary and secondary"
#|             date: "1995-2001"
#|         assumptions: "Applied uniformly across PFTs."
#|       - name: per_propagule_annual_recruitment_probability
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Annual probability of recruitment per propagule.
#|         references:
#|           - citation: "Howlett and Davidson (2003)"
#|             doi: "https://doi.org/10.1016/S0378-1127(03)00161-0"
#|             url: "https://www.sciencedirect.com/science/article/pii/S0378112703001610?via%3Dihub"
#|             origin: "Danum Valley Conservation Area, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "logged"
#|             date: "1993"
#|           - citation: "Kennedy and Swaine (1992)"
#|             doi: "https://doi.org/10.1098/rstb.1992.0027"
#|             url: "https://royalsocietypublishing.org/rstb/article-abstract/335/1275/357/18258/Germination-and-growth-of-colonizing-species-in?redirectedFrom=fulltext"
#|             origin: "Danum Valley COnservation Area, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland rain forest"
#|             site_condition: "primary"
#|             date: "1989"
#|           - citation: "Kuusipalo et al. (1996)"
#|             doi: "https://doi.org/10.1016/0378-1127(95)03654-7"
#|             url: "https://www.sciencedirect.com/science/article/pii/0378112795036547?via%3Dihub"
#|             origin: "Kintap, South Kalimantan, Indonesia"
#|             biome: "tropical"
#|             vegetation_type: "mixed dipterocarp rainforest"
#|             site_condition: "unlogged and logged"
#|             date: "1996"
#|         assumptions: "Derived by combining a literature seed establishment probability with an annualised seedling survival correction."
#|
#| package_dependencies:
#|   - readxl
#|   - dplyr
#|   - ggplot2
#|   - stringr
#|
#| usage_notes: |
#|   No notes.
#| ---

# Load packages

library(readxl)
library(dplyr)
library(ggplot2)
library(stringr)

# Load SAFE tree census data and clean up a bit

tree_census_11_20 <- read_excel(
  "../../../../data/primary/plant/tree_census/tree_census_11_20.xlsx",
  sheet = "Census11_20",
  col_names = FALSE
)

colnames(tree_census_11_20) <- tree_census_11_20[10, ]
tree_census_11_20 <- tree_census_11_20[11:max(nrow(tree_census_11_20)), ]
names(tree_census_11_20)

# Load PFT classification and clean up a bit

pfts_maliau <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/pfts_maliau.csv",
  header = TRUE
)

pfts_maliau <- pfts_maliau[, c("pft_name", "taxa_name")]

# Note that taxa_name in the original tree_census_11_20 is still called TaxaName

names(tree_census_11_20)[names(tree_census_11_20) == "TaxaName"] <- "taxa_name"

# Add pft_name to tree_census_11_20 based on taxa_name and call it data_taxa

data_taxa <- left_join(tree_census_11_20, pfts_maliau, by = "taxa_name")

# Give plots a logging indicator

data_taxa$logging <- NA

data_taxa$logging[
  data_taxa$Block %in%
    c(
      "LFE",
      "LF1",
      "LF2",
      "LF3"
    )
] <- "logged"

data_taxa$logging[
  data_taxa$Block %in%
    c(
      "A",
      "B",
      "C",
      "D",
      "E",
      "F",
      "VJR",
      "OG1",
      "OG2",
      "OG3"
    )
] <- "unlogged"

data_taxa$logging[
  data_taxa$Block %in%
    c(
      "OP1",
      "OP2",
      "OP3"
    )
] <- "oil_palm"

unique(data_taxa$logging)

data_taxa <- data_taxa[
  data_taxa$Block %in%
    c(
      "LFE",
      "LF1",
      "LF2",
      "LF3",
      "A",
      "B",
      "C",
      "D",
      "E",
      "F",
      "VJR",
      "OG1",
      "OG2",
      "OG3"
    ),
]

##########

# From here, we start gathering T model parameters to replace/update the ones
# from Li et al. (2014): DOI https://doi.org/10.5194/bg-11-6711-2014

# Initial slope of height–diameter relationship

plot_data <- data_taxa[, c(
  "Block",
  "Plot",
  "PlotID",
  "logging",
  "TagStem_latest",
  "pft_name",
  "Genus",
  "Species",
  "taxa_name",
  "HeightTotal_m_2011",
  "DBH2011_mm_clean",
  "CanopyRadiusNorth_cm_2011",
  "CanopyRadiusEast_cm_2011",
  "CanopyRadiusSouth_cm_2011",
  "CanopyRadiusWest_cm_2011",
  "HeightBranch_m_2011"
)]

plot_data$HeightTotal_m_2011 <-
  as.numeric(plot_data$HeightTotal_m_2011)
plot_data$DBH2011_mm_clean <-
  as.numeric(plot_data$DBH2011_mm_clean)
plot_data$CanopyRadiusNorth_cm_2011 <-
  as.numeric(plot_data$CanopyRadiusNorth_cm_2011)
plot_data$CanopyRadiusEast_cm_2011 <-
  as.numeric(plot_data$CanopyRadiusEast_cm_2011)
plot_data$CanopyRadiusSouth_cm_2011 <-
  as.numeric(plot_data$CanopyRadiusSouth_cm_2011)
plot_data$CanopyRadiusWest_cm_2011 <-
  as.numeric(plot_data$CanopyRadiusWest_cm_2011)
plot_data$HeightBranch_m_2011 <-
  as.numeric(plot_data$HeightBranch_m_2011)
plot_data$logging <-
  as.factor(plot_data$logging)

# Note that measurements of height, dbh and crown radius are linked per row
# So, even though crown radius is not required for height-diameter relationship,
# using na.omit on the next line is OK.
# Also note that a lot of rows have missing values, figure out why they were not
# measured (maybe trees were dead?). If trees were actually there, they also
# need to be included for stem distribution later on.

plot_data <- na.omit(plot_data)
unique(plot_data$pft_name)

plot_data$crown_radius <- rowMeans(cbind(
  plot_data$CanopyRadiusNorth_cm_2011,
  plot_data$CanopyRadiusEast_cm_2011,
  plot_data$CanopyRadiusSouth_cm_2011,
  plot_data$CanopyRadiusWest_cm_2011
))

plot_data$crown_circular_area <- pi * ((plot_data$crown_radius / 100)^2)
# Converted to meters
plot_data$crown_ellipsoidal_area <- 0.25 *
  (pi *
    2 *
    plot_data$crown_radius /
    100 *
    (plot_data$HeightTotal_m_2011 - plot_data$HeightBranch_m_2011))
plot_data$crown_projected_area <- plot_data$crown_ellipsoidal_area

plot_data$DBH2011_m <- plot_data$DBH2011_mm_clean / 1000 # Scale DBH to meters

###

# Checking crown projected area

ggplot(
  plot_data,
  aes(
    x = DBH2011_m,
    y = crown_projected_area,
    color = factor(pft_name)
  )
) +
  geom_point() +
  geom_smooth(method = "lm", formula = y ~ exp(x), se = FALSE) + # Exponential fit
  ylim(0, 300) + # Limit y-axis to 300
  labs(x = "DBH 2011 (m)", y = "Crown projected area (m²)", color = "PFT") +
  theme_minimal()

###

# Fitting the asymptotic height-diameter model
# Nonlinear model: H = Hm * (1 - exp(-a * D / Hm))

# pft = emergent

plot(
  HeightTotal_m_2011 ~ DBH2011_m,
  data = plot_data[plot_data$pft_name == "emergent", ]
)

nls_model_1 <- nls(
  HeightTotal_m_2011 ~ Hm * (1 - exp(-a * DBH2011_m / Hm)),
  data = plot_data[plot_data$pft_name == "emergent", ],
  start = list(Hm = 40, a = 116), # Starting guesses for Hm and a
  control = nls.control(maxiter = 100)
) # Increase iterations if needed
summary(nls_model_1)
coef_1 <- coef(nls_model_1)
coef_1
Hm_1 <- coef_1["Hm"]
a_1 <- coef_1["a"]

ggplot(
  plot_data[plot_data$pft_name == "emergent", ],
  aes(
    x = DBH2011_m,
    y = HeightTotal_m_2011,
    color = logging
  )
) +
  geom_point() +
  stat_function(
    fun = function(D) {
      coef(nls_model_1)["Hm"] *
        (1 - exp(-coef(nls_model_1)["a"] * D / coef(nls_model_1)["Hm"]))
    },
    color = "blue"
  ) +
  labs(
    x = "Diameter (m)",
    y = "Height (m)",
    title = "Height-Diameter Relationship emergent pft"
  )

data_taxa$Hm <- NA
data_taxa$Hm_SE <- NA
data_taxa$a <- NA
data_taxa$a_SE <- NA

data_taxa$Hm[data_taxa$pft_name == "emergent"] <- Hm_1
data_taxa$a[data_taxa$pft_name == "emergent"] <- a_1
data_taxa$Hm_SE[data_taxa$pft_name == "emergent"] <-
  round(summary(nls_model_1)$coefficients["Hm", "Std. Error"], 2)
data_taxa$a_SE[data_taxa$pft_name == "emergent"] <-
  round(summary(nls_model_1)$coefficients["a", "Std. Error"], 2)

# pft = overstory

plot(
  HeightTotal_m_2011 ~ DBH2011_m,
  data = plot_data[plot_data$pft_name == "overstory", ]
)

nls_model_2 <- nls(
  HeightTotal_m_2011 ~ Hm * (1 - exp(-a * DBH2011_m / Hm)),
  data = plot_data[plot_data$pft_name == "overstory", ],
  start = list(Hm = 40, a = 116), # Starting guesses for Hm and a
  control = nls.control(maxiter = 100)
) # Increase iterations if needed
summary(nls_model_2)
coef_2 <- coef(nls_model_2)
coef_2
Hm_2 <- coef_2["Hm"]
a_2 <- coef_2["a"]

ggplot(
  plot_data[plot_data$pft_name == "overstory", ],
  aes(x = DBH2011_m, y = HeightTotal_m_2011, color = logging)
) +
  geom_point() +
  stat_function(
    fun = function(D) {
      coef(nls_model_2)["Hm"] *
        (1 - exp(-coef(nls_model_2)["a"] * D / coef(nls_model_2)["Hm"]))
    },
    color = "blue"
  ) +
  labs(
    x = "Diameter (m)",
    y = "Height (m)",
    title = "Height-Diameter Relationship overstory pft"
  )

data_taxa$Hm[data_taxa$pft_name == "overstory"] <- Hm_2
data_taxa$a[data_taxa$pft_name == "overstory"] <- a_2
data_taxa$Hm_SE[data_taxa$pft_name == "overstory"] <-
  round(summary(nls_model_2)$coefficients["Hm", "Std. Error"], 2)
data_taxa$a_SE[data_taxa$pft_name == "overstory"] <-
  round(summary(nls_model_2)$coefficients["a", "Std. Error"], 2)

# pft = pioneer

plot(
  HeightTotal_m_2011 ~ DBH2011_m,
  data = plot_data[plot_data$pft_name == "pioneer", ]
)

nls_model_3 <- nls(
  HeightTotal_m_2011 ~ Hm * (1 - exp(-a * DBH2011_m / Hm)),
  data = plot_data[plot_data$pft_name == "pioneer", ],
  start = list(Hm = 40, a = 116), # Starting guesses for Hm and a
  control = nls.control(maxiter = 100)
) # Increase iterations if needed
summary(nls_model_3)
coef_3 <- coef(nls_model_3)
coef_3
Hm_3 <- coef_3["Hm"]
a_3 <- coef_3["a"]

ggplot(
  plot_data[plot_data$pft_name == "pioneer", ],
  aes(x = DBH2011_m, y = HeightTotal_m_2011, color = logging)
) +
  geom_point() +
  stat_function(
    fun = function(D) {
      coef(nls_model_3)["Hm"] *
        (1 - exp(-coef(nls_model_3)["a"] * D / coef(nls_model_3)["Hm"]))
    },
    color = "blue"
  ) +
  labs(
    x = "Diameter (m)",
    y = "Height (m)",
    title = "Height-Diameter Relationship pioneer pft"
  )

data_taxa$Hm[data_taxa$pft_name == "pioneer"] <- Hm_3
data_taxa$a[data_taxa$pft_name == "pioneer"] <- a_3
data_taxa$Hm_SE[data_taxa$pft_name == "pioneer"] <-
  round(summary(nls_model_3)$coefficients["Hm", "Std. Error"], 2)
data_taxa$a_SE[data_taxa$pft_name == "pioneer"] <-
  round(summary(nls_model_3)$coefficients["a", "Std. Error"], 2)

# pft = understory (low data availability for height measurements)

plot(
  HeightTotal_m_2011 ~ DBH2011_m,
  data = plot_data[
    plot_data$pft_name == "understory",
  ]
)

nls_model_4 <- nls(
  HeightTotal_m_2011 ~ Hm * (1 - exp(-a * DBH2011_m / Hm)),
  data = plot_data[plot_data$pft_name == "understory", ],
  start = list(Hm = 40, a = 116), # Starting guesses for Hm and a
  control = nls.control(maxiter = 100)
) # Increase iterations if needed
summary(nls_model_4)
coef_4 <- coef(nls_model_4)
coef_4
Hm_4 <- coef_4["Hm"]
a_4 <- coef_4["a"]

ggplot(
  plot_data[plot_data$pft_name == "understory", ],
  aes(x = DBH2011_m, y = HeightTotal_m_2011, color = logging)
) +
  geom_point() +
  stat_function(
    fun = function(D) {
      coef(nls_model_4)["Hm"] *
        (1 - exp(-coef(nls_model_4)["a"] * D / coef(nls_model_4)["Hm"]))
    },
    color = "blue"
  ) +
  labs(
    x = "Diameter (m)",
    y = "Height (m)",
    title = "Height-Diameter Relationship understory pft"
  )

data_taxa$Hm[data_taxa$pft_name == "understory"] <- Hm_4
data_taxa$a[data_taxa$pft_name == "understory"] <- a_4
data_taxa$Hm_SE[data_taxa$pft_name == "understory"] <-
  round(summary(nls_model_4)$coefficients["Hm", "Std. Error"], 2)
data_taxa$a_SE[data_taxa$pft_name == "understory"] <-
  round(summary(nls_model_4)$coefficients["a", "Std. Error"], 2)

##########

# Initial ratio of crown area to stem cross-sectional area

# pft = emergent

backup <- plot_data
plot_data <- backup[backup$pft_name == "emergent", ]

plot_data$piDH4a <- pi *
  plot_data$DBH2011_m *
  plot_data$HeightTotal_m_2011 /
  (4 * a_1)
plot(crown_projected_area ~ piDH4a, data = plot_data)
plot_data$a_1 <- a_1

nls_model_1 <- nls(
  crown_projected_area ~ pi *
    c *
    DBH2011_m *
    HeightTotal_m_2011 /
    (4 * a_1),
  data = plot_data,
  start = list(c = 400), # Starting guesses c
  control = nls.control(maxiter = 100)
) # Increase iterations if needed
summary(nls_model_1)
coef_1 <- coef(nls_model_1)
coef_1
c_1 <- coef_1["c"]

plot_data$predicted_crown_area <- predict(nls_model_1, newdata = plot_data)

ggplot(plot_data, aes(x = piDH4a, y = crown_projected_area, color = logging)) +
  geom_point() + # scatterplot of data points
  geom_line(aes(y = predicted_crown_area), color = "blue") + # fitted line
  labs(
    x = "piDH/4a (m2)",
    y = "Crown projected area (m2)",
    title = "Crown-Diameter Relationship emergent pft"
  )

data_taxa$c <- NA
data_taxa$c_SE <- NA
data_taxa$c[data_taxa$pft_name == "emergent"] <- c_1
data_taxa$c_SE[data_taxa$pft_name == "emergent"] <-
  round(summary(nls_model_1)$coefficients["c", "Std. Error"], 2)

###

# Comparing both values for projected crown area (i.e., ellipsoidal and Li method)

plot_data$Ac <- NA
plot_data$Ac <- ((pi * c_1) / (4 * a_1)) *
  plot_data$DBH2011_m *
  plot_data$HeightTotal_m_2011

summary(lm(plot_data$crown_projected_area ~ plot_data$Ac))

ggplot(plot_data, aes(x = Ac, y = crown_projected_area, color = logging)) +
  geom_point() +
  geom_smooth(method = "lm", se = FALSE, color = "blue") +
  labs(
    x = "Ac (m2)",
    y = "Crown projected area (m2)",
    title = "Crown area emergent pft"
  )

##########

# pft = overstory

plot_data <- backup[backup$pft_name == "overstory", ]

# Removed outliers
plot_data <- plot_data[plot_data$crown_projected_area < 90, ]

plot_data$piDH4a <- pi *
  plot_data$DBH2011_m *
  plot_data$HeightTotal_m_2011 /
  (4 * a_2)
plot(crown_projected_area ~ piDH4a, data = plot_data)
plot_data$a_2 <- a_2

nls_model_2 <- nls(
  crown_projected_area ~ pi * c * DBH2011_m * HeightTotal_m_2011 / (4 * a_2),
  data = plot_data,
  start = list(c = 400), # Starting guesses c
  control = nls.control(maxiter = 100)
) # Increase iterations if needed
summary(nls_model_2)
coef_2 <- coef(nls_model_2)
coef_2
c_2 <- coef_2["c"]

plot_data$predicted_crown_area <- predict(nls_model_2, newdata = plot_data)

ggplot(plot_data, aes(x = piDH4a, y = crown_projected_area, color = logging)) +
  geom_point() + # scatterplot of data points
  geom_line(aes(y = predicted_crown_area), color = "blue") + # fitted line
  labs(
    x = "piDH/4a (m2)",
    y = "Crown projected area (m2)",
    title = "Crown-Diameter Relationship overstory pft"
  )

data_taxa$c[data_taxa$pft_name == "overstory"] <- c_2
data_taxa$c_SE[data_taxa$pft_name == "overstory"] <-
  round(summary(nls_model_2)$coefficients["c", "Std. Error"], 2)

###

# Comparing both values for projected crown area (i.e., ellipsoidal and Li values)

plot_data$Ac <- NA
plot_data$Ac <- ((pi * c_2) / (4 * a_2)) *
  plot_data$DBH2011_m *
  plot_data$HeightTotal_m_2011

summary(lm(plot_data$crown_projected_area ~ plot_data$Ac))

ggplot(plot_data, aes(x = Ac, y = crown_projected_area, color = logging)) +
  geom_point() +
  geom_smooth(method = "lm", se = FALSE, color = "blue") +
  labs(
    x = "Ac (m2)",
    y = "Crown projected area (m2)",
    title = "Crown area overstory pft"
  )

##########

# pft = pioneer

plot_data <- backup[backup$pft_name == "pioneer", ]

plot_data$piDH4a <- pi *
  plot_data$DBH2011_m *
  plot_data$HeightTotal_m_2011 /
  (4 * a_3)
plot(crown_projected_area ~ piDH4a, data = plot_data)
plot_data$a_3 <- a_3

nls_model_3 <- nls(
  crown_projected_area ~ pi *
    c *
    DBH2011_m *
    HeightTotal_m_2011 /
    (4 * a_3),
  data = plot_data,
  start = list(c = 400), # Starting guesses c
  control = nls.control(maxiter = 100)
) # Increase iterations if needed
summary(nls_model_3)
coef_3 <- coef(nls_model_3)
coef_3
c_3 <- coef_3["c"]

plot_data$predicted_crown_area <- predict(nls_model_3, newdata = plot_data)

ggplot(plot_data, aes(x = piDH4a, y = crown_projected_area, color = logging)) +
  geom_point() + # scatterplot of data points
  geom_line(aes(y = predicted_crown_area), color = "blue") + # fitted line
  labs(
    x = "piDH/4a (m2)",
    y = "Crown projected area (m2)",
    title = "Crown-Diameter Relationship pioneer pft"
  )

data_taxa$c[data_taxa$pft_name == "pioneer"] <- c_3
data_taxa$c_SE[data_taxa$pft_name == "pioneer"] <-
  round(summary(nls_model_3)$coefficients["c", "Std. Error"], 2)

###

# Comparing both values for projected crown area (i.e., ellipsoidal and Li values)

plot_data$Ac <- NA
plot_data$Ac <- ((pi * c_3) / (4 * a_3)) *
  plot_data$DBH2011_m *
  plot_data$HeightTotal_m_2011

summary(lm(plot_data$crown_projected_area ~ plot_data$Ac))

ggplot(plot_data, aes(x = Ac, y = crown_projected_area, color = logging)) +
  geom_point() +
  geom_smooth(method = "lm", se = FALSE, color = "blue") +
  labs(
    x = "Ac (m2)",
    y = "Crown projected area (m2)",
    title = "Crown area pioneer pft"
  )

##########

# pft = understory

plot_data <- backup[backup$pft_name == "understory", ]

plot_data$piDH4a <- pi *
  plot_data$DBH2011_m *
  plot_data$HeightTotal_m_2011 /
  (4 * a_4)
plot(crown_projected_area ~ piDH4a, data = plot_data)
plot_data$a_4 <- a_4

nls_model_4 <- nls(
  crown_projected_area ~ pi *
    c *
    DBH2011_m *
    HeightTotal_m_2011 /
    (4 * a_4),
  data = plot_data,
  start = list(c = 400), # Starting guesses c
  control = nls.control(maxiter = 100)
) # Increase iterations if needed
summary(nls_model_4)
coef_4 <- coef(nls_model_4)
coef_4
c_4 <- coef_4["c"]

plot_data$predicted_crown_area <- predict(nls_model_4, newdata = plot_data)

ggplot(plot_data, aes(x = piDH4a, y = crown_projected_area, color = logging)) +
  geom_point() + # scatterplot of data points
  geom_line(aes(y = predicted_crown_area), color = "blue") + # fitted line
  labs(
    x = "piDH/4a (m2)",
    y = "Crown projected area (m2)",
    title = "Crown-Diameter Relationship understory pft"
  )

data_taxa$c[data_taxa$pft_name == "understory"] <- c_4
data_taxa$c_SE[data_taxa$pft_name == "understory"] <-
  round(summary(nls_model_4)$coefficients["c", "Std. Error"], 2)

###

# Comparing both values for projected crown area (i.e., ellipsoidal and Li values)

plot_data$Ac <- NA
plot_data$Ac <- ((pi * c_4) / (4 * a_4)) *
  plot_data$DBH2011_m *
  plot_data$HeightTotal_m_2011

summary(lm(plot_data$crown_projected_area ~ plot_data$Ac))

ggplot(plot_data, aes(x = Ac, y = crown_projected_area, color = logging)) +
  geom_point() +
  geom_smooth(method = "lm", se = FALSE, color = "blue") +
  labs(
    x = "Ac (m2)",
    y = "Crown projected area (m2)",
    title = "Crown area understory pft"
  )

##########

# Create summary (in the next part we will add more traits to this)

summary <- data_taxa

backup <- summary

##########

# Create some overview plots

# Figures for total tree height (HeightTotal_m_2011)

data <- data_taxa

names(data)

plot_data <- data[, c(
  "Block",
  "Plot",
  "PlotID",
  "logging",
  "TagStem_latest",
  "pft_name",
  "taxa_name",
  "HeightTotal_m_2011"
)]
plot_data <- na.omit(plot_data)
unique(plot_data$pft_name)

plot_data$HeightTotal_m_2011 <- as.numeric(plot_data$HeightTotal_m_2011)

ggplot(
  plot_data,
  aes(
    x = TagStem_latest,
    y = HeightTotal_m_2011,
    color = as.factor(pft_name)
  )
) +
  geom_point() +
  labs(x = "Individual", y = "Height total 2011 (m)") +
  theme_minimal()

ggplot(
  plot_data,
  aes(
    x = as.factor(pft_name),
    y = HeightTotal_m_2011,
    color = as.factor(logging)
  )
) +
  geom_point(position = position_jitter(width = 0.2), alpha = 0.6) +
  stat_summary(fun = "mean", geom = "point", size = 4, color = "black") +
  labs(x = "PFT", y = "Mean Height total 2011 (m)") +
  theme_minimal()

##########

# Figures for DBH (DBH2011_mm_clean)

data <- data_taxa

names(data)

plot_data <- data[, c(
  "Block",
  "Plot",
  "PlotID",
  "logging",
  "TagStem_latest",
  "pft_name",
  "taxa_name",
  "DBH2011_mm_clean"
)]
plot_data <- na.omit(plot_data)
unique(plot_data$pft_name)

plot_data$DBH2011_mm_clean <- as.numeric(plot_data$DBH2011_mm_clean)

ggplot(
  plot_data,
  aes(
    x = TagStem_latest,
    y = DBH2011_mm_clean,
    color = as.factor(pft_name)
  )
) +
  geom_point() +
  labs(x = "Individual", y = "DBH 2011 (mm)") +
  theme_minimal()

ggplot(
  plot_data,
  aes(
    x = as.factor(pft_name),
    y = DBH2011_mm_clean,
    color = as.factor(logging)
  )
) +
  geom_point(position = position_jitter(width = 0.2), alpha = 0.6) +
  stat_summary(fun = "mean", geom = "point", size = 4, color = "black") +
  labs(x = "PFT", y = "Mean DBH 2011 (mm)") +
  theme_minimal()

################################################################################

# Calculate sapwood carbon content (needed to convert wood density later on)

# Load wood nutrients data and clean up a bit

inagawa_nutrients_wood_density <- read_excel(
  "../../../../data/primary/plant/traits_data/inagawa_nutrients_wood_density.xlsx",
  sheet = "Nutrients",
  col_names = FALSE
)

data <- inagawa_nutrients_wood_density

max(nrow(data))
colnames(data) <- data[7, ]
data <- data[8:427, ]
names(data)

data <- data[, c("Species", "TissueType", "C_total")]
colnames(data) <- c("species", "TissueType", "C_total")

data$C_total <- as.numeric(data$C_total)

# Because we only have 10 unique species, we'll use the mean across species

temp <- data[, c("species", "TissueType", "C_total")]
unique(temp$TissueType)
temp <- temp[temp$TissueType == "Sapwood", ]

temp <- temp %>%
  group_by(species) %>%
  mutate(C_total_mean = mean(as.numeric(C_total), na.rm = TRUE)) %>%
  ungroup()

temp <- temp[, c("species", "TissueType", "C_total_mean")]
temp <- unique(temp)

mean(temp$C_total_mean) # Use 45.9% carbon content for sapwood later in calculations

################################################################################

# More traits (wood density and SLA)

both_tree_functional_traits <- read_excel(
  "../../../../data/primary/plant/traits_data/both_tree_functional_traits.xlsx",
  sheet = "Tree_functional_traits",
  col_names = FALSE
)

data <- both_tree_functional_traits

max(nrow(data))
colnames(data) <- data[7, ]
data <- data[8:724, ]
names(data)

##########

# Replace "." by a space in the species name

data <- data %>%
  mutate(species = str_replace_all(species, fixed("."), " "))

# Seperate genus from species into its own column

data <- data %>%
  mutate(genus = word(species, 1))

data <- data[, c(1:9, 86, 10:85)]

##########

# Link dataset to PFT species classification dataset

# Match by species first
data1 <- left_join(
  data,
  pfts_maliau,
  by = c("species" = "taxa_name")
)

# Match by genus only for rows where PFT is still NA
data2 <- left_join(
  data,
  pfts_maliau,
  by = c("genus" = "taxa_name")
)

# Combine: take PFT and pft_name from species match if available,
# otherwise from genus match
data$pft_name <- ifelse(!is.na(data1$pft_name), data1$pft_name, data2$pft_name)

##########

# Wood density (WD_NB)

plot_data <- data[, c(
  "location",
  "forest_type",
  "sample_code",
  "pft_name",
  "species",
  "WD_NB"
)]
plot_data <- na.omit(plot_data)
unique(plot_data$pft_name)

plot_data$WD_NB <- as.numeric(plot_data$WD_NB)
plot_data$forest_type <- as.factor(plot_data$forest_type)

# Convert WD to carbon content

plot_data$WD_NB <- plot_data$WD_NB * 1000
# Convert WD from g cm-3 to kg m-3
plot_data$WD_NB <- plot_data$WD_NB * 0.459
# Account for 45.9% carbon content (see earlier calculation)

ggplot(
  plot_data,
  aes(x = sample_code, y = WD_NB, color = as.factor(pft_name))
) +
  geom_point() +
  labs(x = "Individual", y = "Wood density (kg C m-3)") +
  theme_minimal()

ggplot(
  plot_data,
  aes(
    x = as.factor(pft_name),
    y = WD_NB,
    color = as.factor(forest_type)
  )
) +
  geom_point(position = position_jitter(width = 0.2), alpha = 0.6) +
  stat_summary(fun = "mean", geom = "point", size = 4, color = "black") +
  labs(x = "PFT", y = "Mean Wood density (kg C m-3)") +
  theme_minimal()

summary_stats <- plot_data %>%
  group_by(pft_name) %>%
  summarise(
    Mean_WD_NB = mean(WD_NB, na.rm = TRUE),
    SD_WD_NB = sd(WD_NB, na.rm = TRUE)
  )

print(summary_stats)

# Write to summary

summary$WD_NB <- NA
summary$WD_NB_SD <- NA

summary$WD_NB[summary$pft_name == "emergent"] <- round(
  summary_stats[1, "Mean_WD_NB"],
  2
)
summary$WD_NB_SD[summary$pft_name == "emergent"] <- round(
  summary_stats[1, "SD_WD_NB"],
  2
)
summary$WD_NB[summary$pft_name == "overstory"] <- round(
  summary_stats[2, "Mean_WD_NB"],
  2
)
summary$WD_NB_SD[summary$pft_name == "overstory"] <- round(
  summary_stats[2, "SD_WD_NB"],
  2
)
summary$WD_NB[summary$pft_name == "pioneer"] <- round(
  summary_stats[3, "Mean_WD_NB"],
  2
)
summary$WD_NB_SD[summary$pft_name == "pioneer"] <- round(
  summary_stats[3, "SD_WD_NB"],
  2
)
summary$WD_NB[summary$pft_name == "understory"] <- round(
  summary_stats[4, "Mean_WD_NB"],
  2
)
summary$WD_NB_SD[summary$pft_name == "understory"] <- round(
  summary_stats[4, "SD_WD_NB"],
  2
)

##########

# SLA (SLA_mm2.mg_mean)

plot_data <- data[, c(
  "location",
  "forest_type",
  "sample_code",
  "pft_name",
  "species",
  "SLA_mm2.mg_mean",
  "C_perc"
)]
plot_data <- na.omit(plot_data)
unique(plot_data$pft_name)

plot_data$forest_type <- as.factor(plot_data$forest_type)
plot_data$SLA_mm2.mg_mean <- as.numeric(plot_data$SLA_mm2.mg_mean)
plot_data$C_perc <- as.numeric(plot_data$C_perc)
plot_data$C_perc <- plot_data$C_perc / 100 # Convert to decimal

plot_data$SLA_mm2.mg_mean <- plot_data$SLA_mm2.mg_mean /
  plot_data$C_perc # Convert using carbon content

ggplot(
  plot_data,
  aes(
    x = sample_code,
    y = SLA_mm2.mg_mean,
    color = as.factor(pft_name)
  )
) +
  geom_point() +
  labs(x = "Individual", y = "SLA (mm2 mg-1 C)") +
  theme_minimal()

ggplot(
  plot_data,
  aes(
    x = as.factor(pft_name),
    y = SLA_mm2.mg_mean,
    color = as.factor(forest_type)
  )
) +
  geom_point(position = position_jitter(width = 0.2), alpha = 0.6) +
  stat_summary(fun = "mean", geom = "point", size = 4, color = "black") +
  labs(x = "PFT", y = "Mean SLA (mm2 mg-1 C)") +
  theme_minimal()

summary_stats <- plot_data %>%
  group_by(pft_name) %>%
  summarise(
    Mean_SLA_mm2.mg_mean = mean(SLA_mm2.mg_mean, na.rm = TRUE),
    SD_SLA_mm2.mg_mean = sd(SLA_mm2.mg_mean, na.rm = TRUE)
  )

print(summary_stats)

# Write to summary

summary$SLA <- NA
summary$SLA_SD <- NA

summary$SLA[summary$pft_name == "emergent"] <-
  round(summary_stats[1, "Mean_SLA_mm2.mg_mean"], 2)
summary$SLA_SD[summary$pft_name == "emergent"] <-
  round(summary_stats[1, "SD_SLA_mm2.mg_mean"], 2)
summary$SLA[summary$pft_name == "overstory"] <-
  round(summary_stats[2, "Mean_SLA_mm2.mg_mean"], 2)
summary$SLA_SD[summary$pft_name == "overstory"] <-
  round(summary_stats[2, "SD_SLA_mm2.mg_mean"], 2)
summary$SLA[summary$pft_name == "pioneer"] <-
  round(summary_stats[3, "Mean_SLA_mm2.mg_mean"], 2)
summary$SLA_SD[summary$pft_name == "pioneer"] <-
  round(summary_stats[3, "SD_SLA_mm2.mg_mean"], 2)
summary$SLA[summary$pft_name == "understory"] <-
  round(summary_stats[4, "Mean_SLA_mm2.mg_mean"], 2)
summary$SLA_SD[summary$pft_name == "understory"] <-
  round(summary_stats[4, "SD_SLA_mm2.mg_mean"], 2)

backup <- summary

################################################################################

# Calculate the number of trees and species within PFT
# This step is primarily used as a quality/robustness check of the data

summary <- backup

names(summary)
summary <- summary[, c(
  "pft_name",
  "Family",
  "Genus",
  "Species",
  "taxa_name",
  "HeightTotal_m_2011",
  "Hm",
  "Hm_SE",
  "a",
  "a_SE",
  "c",
  "c_SE",
  "WD_NB",
  "WD_NB_SD",
  "SLA",
  "SLA_SD",
  "TagStem_latest"
)]

summary <- summary[
  order(
    summary$pft_name,
    summary$Family,
    summary$Genus,
    summary$Species,
    summary$HeightTotal_m_2011
  ),
]

summary$TaxaNames <- NA
summary$Trees <- NA

summary$TaxaNames[summary$pft_name == "emergent"] <-
  length(unique(summary$taxa_name[summary$pft_name == "emergent"]))
summary$TaxaNames[summary$pft_name == "overstory"] <-
  length(unique(summary$taxa_name[summary$pft_name == "overstory"]))
summary$TaxaNames[summary$pft_name == "pioneer"] <-
  length(unique(summary$taxa_name[summary$pft_name == "pioneer"]))
summary$TaxaNames[summary$pft_name == "understory"] <-
  length(unique(summary$taxa_name[summary$pft_name == "understory"]))

summary$Trees[summary$pft_name == "emergent"] <-
  length(unique(summary$TagStem_latest[summary$pft_name == "emergent"]))
summary$Trees[summary$pft_name == "overstory"] <-
  length(unique(summary$TagStem_latest[summary$pft_name == "overstory"]))
summary$Trees[summary$pft_name == "pioneer"] <-
  length(unique(summary$TagStem_latest[summary$pft_name == "pioneer"]))
summary$Trees[summary$pft_name == "understory"] <-
  length(unique(summary$TagStem_latest[summary$pft_name == "understory"]))

# Clean up summary

summary <- summary[, c(
  "pft_name",
  "Family",
  "Genus",
  "Species",
  "taxa_name",
  "TaxaNames",
  "Trees",
  "HeightTotal_m_2011",
  "Hm",
  "Hm_SE",
  "a",
  "a_SE",
  "c",
  "c_SE",
  "WD_NB",
  "WD_NB_SD",
  "SLA",
  "SLA_SD"
)]

summary <- summary[
  order(
    summary$pft_name,
    summary$Family,
    summary$Genus,
    summary$Species,
    summary$HeightTotal_m_2011
  ),
]

names(summary)
summary <- summary[, c(
  "pft_name",
  "Hm",
  "Hm_SE",
  "a",
  "a_SE",
  "c",
  "c_SE",
  "WD_NB",
  "WD_NB_SD",
  "SLA",
  "SLA_SD",
  "TaxaNames",
  "Trees"
)]

summary <- unique(summary)
summary <- na.omit(summary)
summary <- summary[order(summary$pft_name), ]
rownames(summary) <- 1:nrow(summary)

summary$WD_NB <- as.numeric(summary$WD_NB)
summary$WD_NB_SD <- as.numeric(summary$WD_NB_SD)
summary$SLA <- as.numeric(summary$SLA)
summary$SLA_SD <- as.numeric(summary$SLA_SD)

################################################################################

# Below we add the remaining T model parameters. Most of these are not PFT
# specific (for now).

#####

# Leaf area index
# LAI is currently constant across PFTs and within the crown/canopy
# The value for LAI is based on Pfeifer et al. (2016)
# (DOI https://doi.org/10.1016/j.rse.2016.01.014)
# This paper has mean values for primary forest, lightly logged, twice logged,
# salvage logged and oil palm plantation
# It also provides SD as measure of uncertainty (not included here atm)

summary$leaf_area_index <- 4.43

#####

# Light extinction coefficient
# Value is taken from White et al. (2000)
# (DOI https://doi.org/10.1175/1087-3562(2000)004%3C0003:PASAOT%3E2.0.CO;2),
# The value used is the one reported for rain forest by Waring and Schlesinger (1985)

summary$light_extinction_coefficient <- 0.6

#####

# Leaf turnover
# Value based on Anderson et al. (1983)
# (DOI; https://doi.org/10.2307/2259731)
# The value used here is for dipterocarp forest, but paper also has values for
# alluvial forest, heath forest and forest over limestone
# Turnover time (unit = years) is calculated as the inverse of turnover per year

summary$turnover_leaf <- 1 / 1.7

# Reproductive organ turnover
# The same approach and data is used as for leaf turnover

summary$turnover_reproductive_organ <- 1 / 10

# Fine root turnover
# Value based on Huaraca Huasco et al. (2021)
# (DOI https://doi.org/10.1111/gcb.15677)
# Value calculated as the mean root residence time based on 2 plots (Table 4)
# (MLA-01 and MLA-02 from Maliau)

summary$turnover_fine_root <- mean(c(1.50, 1.79))

#####

# Fine root specific respiration
# Value based on Yan and Zhao (2007)
# (DOI http://dx.doi.org/10.1016/S1872-2032(07)60056-0)
# Value for tropical rain forest tree is used (Table 2)

summary$respiration_fine_root <- (1.5 * 10^-3) * 365

# Leaf specific respiration
# Same approach and data used as for fine root specific respiration

summary$respiration_leaf <- (2.0 * 10^-3) * 365

# Wood specific respiration
# Same approach and data used as for fine root and leaf specific respiration

summary$respiration_wood <- (1.0 * 10^-3) * 365

# Reproductive organ respiration
# Using value given in Kinugasa et al. (2005; https://doi.org/10.1093/aob/mci152)
# Respiratory costs are 39% of carbon allocated to reproductive tissues.
# We need maintenance respiration only, which is 5% of carbon allocated to RT
# (vs 34% for growth respiration).
# We assume production of reproductive organs is consistent throughout the year.

summary$respiration_reproductive_organ <- 0.05

#####

# Yield factor
# Value based on Yan and Zhao (2007)
# (DOI http://dx.doi.org/10.1016/S1872-2032(07)60056-0)
# Yield factor calculated from growth respiration coefficient (rg) using the
# formula: 1/(1+rg) where rg = 0.25

summary$yield_factor <- (1 / (1 + 0.25))

#####

# Fine root mass to foliage area ratio
# There are 2 main datasets used here:
# -the data from Kenzo et al. (2015)
# (DOI http://dx.doi.org/10.1007/s10310-014-0465-y)
# -the data from Niiyama et al. (2010)
# (DOI http://dx.doi.org/10.1017/S0266467410000040)

# Both of these papers have data on foliage mass and fine root mass
# However, fine root mass needs to be expressed on carbon mass basis
# So, the dry weight mass of fine roots needs to be corrected for carbon content
# To do this, we'll use the mean carbon content for based on Imai et al. (2010)
# (DOI https://doi.org/10.1017/S0266467410000350) for fine roots: 45.2%.

# As a first approach we can focus on the data from Kenzo et al. (2015)
# Here, we can use leaf and fine root mass and LMA (combined with Imai's fine root
# carbon content) to define a ratio that is (mostly) tracked within 1 study system.

# As a second approach we could focus on getting an average ratio between fine
# root mass and foliage mass, which is then linked to the SLA of each PFT
# Note that PFT SLA values will first need to be converted back to dry weight mass
# using the foliar carbon percentage (found in both_tree_functional_traits)
# or instead use the uncorrected PFT SLA values still stored in plot_data.
# This approach is similar to the one that Li et al. (2014) used
# I think it makes sense to assume that there is more variability in the conversion
# from foliage mass to area than in the ratio between fine root and foliage mass.
# If we then average the ratio between fine root and foliage mass across studies
# we can capture most of this variability across studies/systems.

#####

# First approach: Kenzo et al (2015)
# Data extracted from paper directly
# For fine root mass, values below and above 10 cm depth are combined

kenzo_data <- data.frame(
  site = c("Sabal", "Balai Ringin"),
  leaf_dry_mass_big_trees = c(5.1, 5.5),
  leaf_dry_mass_small_trees = c(2.5, 1.6),
  fine_root_total_dry_mass = c(26.8, 5.8),
  leaf_mass_per_area_big_trees = c(155.6, 155.6),
  leaf_mass_per_area_small_trees = c(73.3, 73.3)
)

# Note that Sabal is logged and Balai Ringin is protected
# So, preferable we'd use the Balai Ringin values, however, the root mass seems
# very low compared to Sabal, and other studies (like Niiyama)

# Convert the leaf dry mass from megagrams per hectare to grams per hectare
kenzo_data$leaf_dry_mass_big_trees <- kenzo_data$leaf_dry_mass_big_trees *
  1000000
kenzo_data$leaf_dry_mass_small_trees <- kenzo_data$leaf_dry_mass_small_trees *
  1000000

# Use LMA to find the total leaf area (m2 per hectare)
kenzo_data$leaf_area_big_trees <-
  kenzo_data$leaf_dry_mass_big_trees / kenzo_data$leaf_mass_per_area_big_trees
kenzo_data$leaf_area_small_trees <-
  kenzo_data$leaf_dry_mass_small_trees /
  kenzo_data$leaf_mass_per_area_small_trees

# Combine leaf area of big and small trees to get total leaf area
kenzo_data$total_leaf_area <-
  kenzo_data$leaf_area_big_trees + kenzo_data$leaf_area_small_trees

# Correct fine root dry mass for carbon content (45.2%)
kenzo_data$fine_root_total_carbon_mass <-
  kenzo_data$fine_root_total_dry_mass * 45.2 / 100

# Convert fine root carbon mass from Mg per hectare to kg per hectare
kenzo_data$fine_root_total_carbon_mass <-
  kenzo_data$fine_root_total_carbon_mass * 1000

# Calculate the ratio of fine root carbon mass divided by leaf area
kenzo_data$fine_root_carbon_foliage_area <-
  kenzo_data$fine_root_total_carbon_mass / kenzo_data$total_leaf_area

print(kenzo_data$fine_root_carbon_foliage_area) # unit is kg C per m2

#####

# Second approach: obtaining a mean ratio between foliage and fine root dry mass
# and then linking this to PFT specific SLA values

# Extract mean dry mass ratio directly from Niiyama et al. (2010) paper
# Add rows for each PFT in the model

niiyama_data <- data.frame(
  pft_name = c("emergent", "overstory", "understory", "pioneer"),
  leaf_dry_mass = c(5.7, 5.7, 5.7, 5.7),
  fine_root_dry_mass = c(13.3, 13.3, 13.3, 13.3)
)

# Get PFT specific SLA values (not corrected for carbon content)
# These data are stored per PFT in "data" (see earlier in this script)
# The unit of SLA is mm2 mg-1

names(data)
pft_sla_data <- data[, c("pft_name", "SLA_mm2.mg_mean")]
pft_sla_data <- na.omit(pft_sla_data)
pft_sla_data$SLA_mm2.mg_mean <- as.numeric(pft_sla_data$SLA_mm2.mg_mean)
pft_sla_data$specific_leaf_area_pft <- NA

pft_sla_data$specific_leaf_area_pft[pft_sla_data$pft_name == "emergent"] <-
  mean(pft_sla_data$SLA_mm2.mg_mean[pft_sla_data$pft_name == "emergent"])
pft_sla_data$specific_leaf_area_pft[pft_sla_data$pft_name == "overstory"] <-
  mean(pft_sla_data$SLA_mm2.mg_mean[pft_sla_data$pft_name == "overstory"])
pft_sla_data$specific_leaf_area_pft[pft_sla_data$pft_name == "understory"] <-
  mean(pft_sla_data$SLA_mm2.mg_mean[pft_sla_data$pft_name == "understory"])
pft_sla_data$specific_leaf_area_pft[pft_sla_data$pft_name == "pioneer"] <-
  mean(pft_sla_data$SLA_mm2.mg_mean[pft_sla_data$pft_name == "pioneer"])

pft_sla_data <- pft_sla_data[, c("pft_name", "specific_leaf_area_pft")]
pft_sla_data <- unique(pft_sla_data)

# Calculate the corresponding leaf area for the leaf dry mass in niiyama_data
# using the PFT specific SLA values. We'll use the PFT specific SLA values
# stored in "data" as these are also based on dry mass (not carbon corrected).
# This is fine as we are only interested in the leaf area here.

# Add PFT SLA values to niiyama data
niiyama_data <- left_join(niiyama_data, pft_sla_data, by = "pft_name")

# Convert foliage dry mass unit Mg/ha to mg/ha to match SLA weight units
niiyama_data$leaf_dry_mass <- niiyama_data$leaf_dry_mass * 10^9

# Calculate foliage area (with unit mm2 ha-1)
niiyama_data$leaf_area <-
  niiyama_data$leaf_dry_mass * niiyama_data$specific_leaf_area_pft

# Convert mm2 to m2
niiyama_data$leaf_area <- niiyama_data$leaf_area / 10^6

# Convert fine root dry mass to carbon mass using 45.2% carbon content (Imai et al.)
# The unit then becomes Mg C per hectare
niiyama_data$fine_root_carbon_mass <- niiyama_data$fine_root_dry_mass *
  45.2 /
  100

# Convert Mg C ha-1 to Kg C ha-1
niiyama_data$fine_root_carbon_mass <- niiyama_data$fine_root_carbon_mass * 1000

# Calculate ratio of fine root carbon mass to foliage area (kg C m-2)
niiyama_data$fine_root_carbon_foliage_area <-
  niiyama_data$fine_root_carbon_mass / niiyama_data$leaf_area

print(niiyama_data$fine_root_carbon_foliage_area)
mean(niiyama_data$fine_root_carbon_foliage_area)

# Note that these ratios are very close to the mean cross both Kenzo and Niiyama
# So I think we can use this second approach, using pft specific values, as it
# works with well studied dipterocarp plots and seems to capture the variability
# across different plots well.

# Subset niiyama_data with ratio and add to summary

niiyama_data <- niiyama_data[, c("pft_name", "fine_root_carbon_foliage_area")]

summary <- left_join(summary, niiyama_data, by = "pft_name")

# Add root exudates
# Root exudates carbon as a fraction (4.7%) of annual NPP reported for tropical
# rainforest in Aoki et al. (2013; https://doi.org/10.1007/s10021-012-9575-6)

summary$root_exudates <- 0.047

# Add mortality probability
# Use mean annual mortality between 1995-2001 across all species at Danum Valley
# reported by Bisschoff et al. (2005; https://doi.org/10.1016/j.foreco.2005.07.009)

summary$per_stem_annual_mortality_probability <- 0.02

# Add recruitment probability
# Use value for establishment from seedbank per seed (2.5%) used in
# Howlett and Davidson (2003; https://doi.org/10.1016/S0378-1127(03)00161-0),
# who refer to the value (2.3% presumably) presented in
# Kennedy and Swaine (1992; https://doi.org/10.1098/rstb.1992.0027)
# Then correct for seedling mortality by multiplying by seedling survival rate
# 0.9006739 (0.84^(12/20) from Kuusipalo et al., 1996;
# DOI: https://doi.org/10.1016/0378-1127(95)03654-7).

seedling_survival_rate <- 0.84^(12 / 20) # converted to per year

summary$per_propagule_annual_recruitment_probability <- 0.023 *
  seedling_survival_rate

# Below we add the base calculation for plant_pft_propagules, which originally
# was included in the scenario preparation script.
# Here we calculate the expected propagules in the seedbank per hectare, which
# can then be scaled for a particular scenario later on dependong on the grid

# First estimate the germinated seedlings prior to seedling mortality, derived
# as recruits per hectare per year
# (from Kuusipalo et al., 1996; DOI: https://doi.org/10.1016/0378-1127(95)03654-7)
# divided by seedling survival 0.9007 (0.84^(12/20) from Kuusipalo et al., 1996;
# DOI: https://doi.org/10.1016/0378-1127(95)03654-7).

# Next, divide this number by the germination rate 0.0115
# (0.023 / 2) to get yearly rate (from Kennedy, D. N., & Swaine, M. D., 1992;
# DOI: https://doi.org/10.1098/rstb.1992.0027).

# The result represents the minimum number of propagules across PFTs required in
# the seedbank to be able to generate the observed seedlings. This means that the
# actual seedbank may be larger.

# Note: for pioneers in logged forest, we can use fill value = 1000 m-2 using
# value from Metcalfe and Turner (1998; https://www.jstor.org/stable/2559870)
# Then scale this according to the cell area used (here 10000 m2)

# Note that we could have used the study by Pillay et al. (2018) which focuses
# on Maliau and SAFE (https://doi.org/10.1002/ece3.4352).
# However, this study measured during a masting event, and only focuses on 1
# species, so this is not ideal for the current state of the model.

# Calculate recruits per hectare, using "Recruitment of new seedlings" for
# Plot 3, which is the unlogged forest
# Note that we need to standardize the values to per year (instead of per
# 20 months; July 1990 - February 1992)
# Also note that the values are reported per 100 m2, so convert this to hectare
# by multiplying by 100

recruits_per_hectare <- (121 * 100) / 20 * 12 # converted to per hectare per year

seedling_survival_rate <- 0.84^(12 / 20) # converted to per year

recruits_per_hectare_without_mortality <-
  recruits_per_hectare / seedling_survival_rate # these represent germinated seeds

germination_rate <- 0.023 / 2 # converted to per year

# Save the total propagules per hectare in summary
summary$propagules <-
  recruits_per_hectare_without_mortality / germination_rate # all seeds across PFTs

################################################################################

# Prep summary output again, check variable names, etc.

names(summary)

summary <- summary[, c(
  "pft_name",
  "Hm",
  "a",
  "c",
  "WD_NB",
  "SLA",
  "leaf_area_index",
  "light_extinction_coefficient",
  "turnover_leaf",
  "turnover_reproductive_organ",
  "turnover_fine_root",
  "respiration_fine_root",
  "respiration_leaf",
  "respiration_wood",
  "respiration_reproductive_organ",
  "yield_factor",
  "fine_root_carbon_foliage_area",
  "root_exudates",
  "per_stem_annual_mortality_probability",
  "per_propagule_annual_recruitment_probability",
  "propagules"
)]

colnames(summary) <- c(
  "pft_name",
  "Hm",
  "a",
  "c",
  "WD",
  "SLA",
  "LAI",
  "LEC",
  "turnover_leaf",
  "turnover_RT",
  "turnover_root",
  "respiration_root",
  "respiration_leaf",
  "respiration_wood",
  "respiration_reproductive_organ",
  "yield_factor",
  "zeta",
  "root_exudates",
  "per_stem_annual_mortality_probability",
  "per_propagule_annual_recruitment_probability",
  "propagules_per_ha"
)

# Below I change the variable names to match those used by the model
# and also provide an overview of the units between parentheses

# pft_name is pft_name
# Hm is h_max (m)
# a is a_hd (-)
# c is ca_ratio (-)
# WD is rho_s (kg C m-3)
# SLA is sla (mm2 mg-1 C)
# LAI is lai (-)
# LEC is par_ext (-)
# turnover_leaf is tau_f (years)
# turnover_RT is tau_rt (years)
# turnover_root is tau_r (years)
# respiration_root is resp_r (year-1)
# respiration_leaf is resp_f (year-1)
# respiration_wood is resp_s (year-1)
# yield_factor is yld (-)
# zeta is zeta (kg C m-2)
# root_exudates (-)
# per_stem_annual_mortality_probability (-)
# per_propagule_annual_recruitment_probability (-)

colnames(summary) <- c(
  "pft_name",
  "h_max",
  "a_hd",
  "ca_ratio",
  "rho_s",
  "sla",
  "lai",
  "par_ext",
  "tau_f",
  "tau_rt",
  "tau_r",
  "resp_r",
  "resp_f",
  "resp_s",
  "resp_rt",
  "yld",
  "zeta",
  "root_exudates",
  "per_stem_annual_mortality_probability",
  "per_propagule_annual_recruitment_probability",
  "propagules_per_ha"
)

################################################################################

# Write CSV file

dir.create(
  "../../../../data/derived/plant/input_data/data_library",
  recursive = TRUE,
  showWarnings = FALSE
)

write.csv(
  summary,
  "../../../../data/derived/plant/input_data/data_library/t_model_maliau.csv",
  row.names = FALSE
)
