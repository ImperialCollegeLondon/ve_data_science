#| ---
#| title: subcanopy_maliau
#|
#| description: |
#|     This script derives subcanopy vegetation and seedbank parameters for
#|     Maliau. It combines plot-level and species-level measurements from the
#|     SAFE Project with literature-based stoichiometric and turnover proxies.
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
#|   - name: dobert_2019_plot_species_trait_data.xlsx
#|     path: data/primary/plant/traits_data
#|     description: |
#|       https://doi.org/10.5281/zenodo.2536270
#|       Plot, species and trait data for subcanopy vegetation measured across
#|       Maliau and the SAFE project.
#|   - name: stoichiometry_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       This CSV file contains PFT-level stoichiometric ratios and lignin
#|       fractions for plant biomass pools, including sapwood, foliage,
#|       senesced leaves, reproductive tissue, fruits, flowers, and fine roots.
#|       Where PFT-specific measurements are unavailable, literature-derived
#|       proxy values are used.
#|
#| output_files:
#|   - name: subcanopy_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       This CSV file contains the subcanopy parameters used as plant model
#|       constants in the plant input data library workflow.
#|     variables:
#|       - name: subcanopy_vegetation_biomass
#|         type: numeric
#|         units: kg C m^-2
#|         description: |
#|           Mean standing subcanopy vegetation carbon mass per unit ground area.
#|         references:
#|           - citation: "Dobert et al. (2019)"
#|             doi: "https://doi.org/10.5281/zenodo.2536270"
#|             url: "https://zenodo.org/records/2536270"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2014"
#|           - citation: "Wu et al. (2022)"
#|             doi: "https://doi.org/10.3390/su142416517"
#|             url: "https://www.mdpi.com/2071-1050/14/24/16517"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Derived from old-growth SAFE subcanopy dry biomass and converted to carbon mass using a herb-layer carbon fraction from Wu et al."
#|       - name: subcanopy_seedbank_biomass
#|         type: numeric
#|         units: kg C m^-2
#|         description: |
#|           Estimated seedbank carbon mass per unit ground area.
#|         references:
#|           - citation: "Dalling et al. (1998)"
#|             doi: "https://doi.org/10.2307/176953"
#|             url: "https://esajournals.onlinelibrary.wiley.com/doi/10.1890/0012-9658(1998)079%5B0564:DPASBD%5D2.0.CO;2"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|           - citation: "Zhang et al. (2020)"
#|             doi: "https://doi.org/10.1007/s11629-020-6253-6"
#|             url: "https://link.springer.com/article/10.1007/s11629-020-6253-6"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Derived indirectly as 23% of estimated reproductive allocation from subcanopy vegetation biomass rather than measured seedbank carbon mass."
#|       - name: subcanopy_specific_leaf_area
#|         type: numeric
#|         units: m^2 kg^-1 C
#|         description: |
#|           Specific leaf area of subcanopy vegetation expressed per unit carbon mass.
#|         references:
#|           - citation: "Dobert et al. (2019)"
#|             doi: "https://doi.org/10.5281/zenodo.2536270"
#|             url: "https://zenodo.org/records/2536270"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2014"
#|           - citation: "Wu et al. (2022)"
#|             doi: "https://doi.org/10.3390/su142416517"
#|             url: "https://www.mdpi.com/2071-1050/14/24/16517"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Calculated as the mean SLA across selected non-tree subcanopy growth forms and converted to a carbon-mass basis using the same carbon fraction as for biomass."
#|       - name: subcanopy_reproductive_allocation
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Fraction of aboveground subcanopy biomass allocated to reproductive tissue.
#|         references:
#|           - citation: "Zhang et al. (2020)"
#|             doi: "https://doi.org/10.1007/s11629-020-6253-6"
#|             url: "https://link.springer.com/article/10.1007/s11629-020-6253-6"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Estimated from literature biomass ratios rather than from direct measurements in the SAFE or Maliau subcanopy."
#|       - name: subcanopy_respiration_fraction
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Fraction of gross primary productivity lost to respiration in subcanopy vegetation.
#|         references:
#|           - citation: "Lötscher et al. (2004)"
#|             doi: "https://doi.org/10.1111/j.1469-8137.2004.01170.x"
#|             url: "https://nph.onlinelibrary.wiley.com/doi/10.1111/j.1469-8137.2004.01170.x"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Used directly as a literature constant for subcanopy vegetation."
#|       - name: subcanopy_extinction_coef
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Light extinction coefficient used for subcanopy vegetation.
#|         references:
#|           - citation: "White et al. (2000)"
#|             doi: "https://doi.org/10.1175/1087-3562(2000)004%3C0003:PASAOT%3E2.0.CO;2"
#|             url: "https://journals.ametsoc.org/view/journals/eint/4/3/1087-3562_2000_004_0003_pasaot_2.0.co_2.xml"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: null
#|       - name: subcanopy_yield
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Carbon yield of subcanopy vegetation after growth respiration losses.
#|         references:
#|           - citation: "Lötscher et al. (2004)"
#|             doi: "https://doi.org/10.1111/j.1469-8137.2004.01170.x"
#|             url: "https://nph.onlinelibrary.wiley.com/doi/10.1111/j.1469-8137.2004.01170.x"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Derived as one minus the reported growth respiration fraction."
#|       - name: subcanopy_vegetation_turnover
#|         type: numeric
#|         units: year^-1
#|         description: |
#|           Annual turnover rate of subcanopy vegetation biomass.
#|         references:
#|           - citation: "Singh (1992)"
#|             doi: "https://doi.org/10.1007/BF00045551"
#|             url: "https://link.springer.com/article/10.1007/BF00045551"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|           - citation: "Singh and Singh (1991)"
#|             doi: "https://doi.org/10.1093/oxfordjournals.aob.a088252"
#|             url: "https://academic.oup.com/aob/article-abstract/68/3/263/214008?redirectedFrom=fulltext"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Calculated as annual litterfall divided by standing herbaceous biomass from literature rather than from the SAFE/Maliau subcanopy data."
#|       - name: subcanopy_vegetation_c_n_ratio
#|         type: numeric
#|         units: g C g^-1 N
#|         description: |
#|           Carbon-to-nitrogen ratio of subcanopy vegetation biomass.
#|         references:
#|           - citation: "Wu et al. (2022)"
#|             doi: "https://doi.org/10.3390/su142416517"
#|             url: "https://www.mdpi.com/2071-1050/14/24/16517"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Taken from herb-layer elemental composition in primary forest as a proxy for subcanopy vegetation."
#|       - name: subcanopy_vegetation_c_p_ratio
#|         type: numeric
#|         units: g C g^-1 P
#|         description: |
#|           Carbon-to-phosphorus ratio of subcanopy vegetation biomass.
#|         references:
#|           - citation: "Wu et al. (2022)"
#|             doi: "https://doi.org/10.3390/su142416517"
#|             url: "https://www.mdpi.com/2071-1050/14/24/16517"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Taken from herb-layer elemental composition in primary forest as a proxy for subcanopy vegetation."
#|       - name: subcanopy_vegetation_lignin
#|         type: numeric
#|         units: g lignin C g^-1 vegetation C
#|         description: |
#|           Fraction of subcanopy vegetation carbon mass present as lignin.
#|         references:
#|           - citation: "Amatangelo and Vitousek (2009)"
#|             doi: "https://doi.org/10.1111/j.1744-7429.2008.00470.x"
#|             url: "https://onlinelibrary.wiley.com/doi/10.1111/j.1744-7429.2008.00470.x"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|           - citation: "Muddasar et al. (2024)"
#|             doi: "https://doi.org/10.1016/j.mtsust.2024.100990"
#|             url: "https://www.sciencedirect.com/science/article/pii/S2589234724003269?via%3Dihub"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|           - citation: "Wu et al. (2022)"
#|             doi: "https://doi.org/10.3390/su142416517"
#|             url: "https://www.mdpi.com/2071-1050/14/24/16517"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Derived from monocot lignin content and converted to a carbon basis using literature lignin and vegetation carbon fractions."
#|       - name: subcanopy_seedbank_turnover
#|         type: numeric
#|         units: year^-1
#|         description: |
#|           Annual turnover rate of the subcanopy seedbank.
#|         references:
#|           - citation: "Dalling et al. (1998)"
#|             doi: "https://doi.org/10.2307/176953"
#|             url: "https://esajournals.onlinelibrary.wiley.com/doi/10.1890/0012-9658(1998)079%5B0564:DPASBD%5D2.0.CO;2"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Derived from the fraction of seeds not expected to remain viable after one year."
#|       - name: subcanopy_sprout_rate
#|         type: numeric
#|         units: year^-1
#|         description: |
#|           Annual sprouting rate from the viable subcanopy seedbank.
#|         references:
#|           - citation: "Dalling et al. (1998)"
#|             doi: "https://doi.org/10.2307/176953"
#|             url: "https://esajournals.onlinelibrary.wiley.com/doi/10.1890/0012-9658(1998)079%5B0564:DPASBD%5D2.0.CO;2"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Assumes the viable seed fraction within one year represents the annual sprouting rate."
#|       - name: subcanopy_sprout_yield
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Carbon yield associated with sprouting from the subcanopy seedbank.
#|         references:
#|           - citation: "Lötscher et al. (2004)"
#|             doi: "https://doi.org/10.1111/j.1469-8137.2004.01170.x"
#|             url: "https://nph.onlinelibrary.wiley.com/doi/10.1111/j.1469-8137.2004.01170.x"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Set equal to the general subcanopy yield, assuming the same growth respiration correction applies to sprouting."
#|       - name: subcanopy_seedbank_c_n_ratio
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Carbon-to-nitrogen ratio of seedbank material used for subcanopy inputs.
#|         references:
#|           - citation: null
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Imported directly from the derived stoichiometry_maliau reproductive tissue turnover field as a proxy because seedbank-specific data are lacking."
#|       - name: subcanopy_seedbank_c_p_ratio
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Carbon-to-phosphorus ratio of seedbank material used for subcanopy inputs.
#|         references:
#|           - citation: null
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Imported directly from the derived stoichiometry_maliau reproductive tissue turnover field as a proxy because seedbank-specific data are lacking."
#|       - name: subcanopy_seedbank_lignin
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Fraction of seedbank carbon mass present as lignin.
#|         references:
#|           - citation: null
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Imported directly from the derived stoichiometry_maliau reproductive tissue lignin field as a proxy because seedbank-specific lignin data are lacking."

#|   - name: dobert_subcanopy_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       This CSV file contains the subcanopy vegetation and seedbank carbon mass
#|       at plot level. The file is used for spatial predictions in the scenario
#|       scripts.
#|     variables:
#|       - name: plot_code
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Identifier for the SAFE Project sampling plot.
#|         references:
#|           - citation: "Dobert et al. (2019)"
#|             doi: "https://doi.org/10.5281/zenodo.2536270"
#|             url: "https://zenodo.org/records/2536270"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2014"
#|         assumptions: null
#|       - name: subcanopy_vegetation_carbon_mass_mean
#|         type: numeric
#|         units: kg C m^-2
#|         description: |
#|           Standing subcanopy vegetation carbon mass per unit ground area.
#|         references:
#|           - citation: "Dobert et al. (2019)"
#|             doi: "https://doi.org/10.5281/zenodo.2536270"
#|             url: "https://zenodo.org/records/2536270"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2014"
#|         assumptions: null
#|       - name: subcanopy_seedbank_carbon_mass_mean
#|         type: numeric
#|         units: kg C m^-2
#|         description: |
#|           Standing subcanopy seedbank carbon mass per unit ground area.
#|         references:
#|           - citation: "Dobert et al. (2019)"
#|             doi: "https://doi.org/10.5281/zenodo.2536270"
#|             url: "https://zenodo.org/records/2536270"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2014"
#|         assumptions: null
#|       - name: subcanopy_vegetation_carbon_mass_plot
#|         type: numeric
#|         units: kg C m^-2
#|         description: |
#|           Standing subcanopy vegetation carbon mass per unit ground area at
#|           plot level.
#|         references:
#|           - citation: "Dobert et al. (2019)"
#|             doi: "https://doi.org/10.5281/zenodo.2536270"
#|             url: "https://zenodo.org/records/2536270"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2014"
#|         assumptions: null
#|       - name: subcanopy_seedbank_carbon_mass_plot
#|         type: numeric
#|         units: kg C m^-2
#|         description: |
#|           Standing subcanopy seedbank carbon mass per unit ground area at
#|           plot level.
#|         references:
#|           - citation: "Dobert et al. (2019)"
#|             doi: "https://doi.org/10.5281/zenodo.2536270"
#|             url: "https://zenodo.org/records/2536270"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2014"
#|         assumptions: null
#|
#| package_dependencies:
#|   - readxl
#|
#| usage_notes: |
#|   Run from this script's directory because input and output paths are
#|   relative. The script uses selected non-tree growth forms from the SAFE
#|   Project to estimate subcanopy biomass and applies literature-derived
#|   proxies where direct subcanopy measurements are unavailable.
#| ---

# Load packages

library(readxl)

##################################################

# Subcanopy vegetation carbon mass
# We'll use Dobert et al., 2019 data to obtain subcanopy vegetation carbon mass,
# measured in the OG plots at Maliau. We'll focus on "leafy" plant growth forms,
# and will obtain an average carbon mass in kg C m-2

# Load Dobert et al. (2019) dataset on species trait data and clean up a bit

dobert_2019_species_trait_data <-
  read_excel(
    "../../../../data/primary/plant/traits_data/dobert_2019_plot_species_trait_data.xlsx",
    sheet = "SpeciesTraitDataEcol",
    col_names = FALSE
  )

# Clean dataset and create subset based on species classification
colnames(dobert_2019_species_trait_data) <- dobert_2019_species_trait_data[10, ]
dobert_2019_species_trait_data <- dobert_2019_species_trait_data[
  11:max(nrow(dobert_2019_species_trait_data)),
]
names(dobert_2019_species_trait_data)

# For the subcanopy vegetation biomass we will use Dobert's dataset for SAFE to
# get an idea of how much carbon is there.
# For now, all plant growth forms are included except tree sapling, woody climber
# (liana) and woody shrub

data <- dobert_2019_species_trait_data
data <- data[data$pgf %in% c("A", "B", "C", "D", "E"), ]
taxa <- unique(data$species.code)

# Taxa with na are excluded when not part of the PGF above, or when not occurring
# in OG plots
# - apounk, comunk, gne076, indunk, malste, memcal, menunk, rhaunk, rubunk, strbra

# Load Dobert plot species data

dobert_2019_plot_species_data <-
  read_excel(
    "../../../../data/primary/plant/traits_data/dobert_2019_plot_species_trait_data.xlsx",
    sheet = "DoebertTF_SAFE_PlotSpeciesMeasu",
    col_names = FALSE
  )

# Clean dataset and create subset based on species classification
colnames(dobert_2019_plot_species_data) <- dobert_2019_plot_species_data[10, ]
dobert_2019_plot_species_data <- dobert_2019_plot_species_data[
  11:max(nrow(dobert_2019_plot_species_data)),
]
names(dobert_2019_plot_species_data)

# The dry weight biomass (g.m-2) of each species in each plot

# Subset to OG plots
dobert_2019_plot_species_data <-
  dobert_2019_plot_species_data[
    dobert_2019_plot_species_data$fragment %in% c("og1", "og10", "og100"),
  ]

# Subset to taxa of interest
dobert_2019_plot_species_data <-
  dobert_2019_plot_species_data[
    dobert_2019_plot_species_data$species.code %in% taxa,
  ]

# Keep columns only when sum across plots is more than 0
dobert_2019_plot_species_data$drywgt <-
  as.numeric(dobert_2019_plot_species_data$drywgt)

dobert_2019_plot_species_data <-
  dobert_2019_plot_species_data[!is.na(dobert_2019_plot_species_data$drywgt), ]

taxa_present <- unique(dobert_2019_plot_species_data$species.code)
taxa_present_info <-
  dobert_2019_species_trait_data[
    dobert_2019_species_trait_data$species.code %in% taxa_present,
  ]

# Evaluate species
# alowon1 = alocasia wongii = forb
# begber1 = begonia berhamanii = forb
# bolhet = bolbitis heteroclita = fern
# cosglo = costus globosus = forb
# cosspe = costus speciosus = forb
# cyr075 = cyrtandra sp. = forb
# din141 = dinochloa sp. = herbaceous climber (bamboo) # not present in 2019
# hetste1 = heterogonium stenosemioides = fern
# pip139 = piper sp. = herbaceous climber
# potbor1 = pothos borneensis = herbaceous climber
# scipic = scindapsus pictus = herbaceous climber
# sel225 = selliguea sp. = fern
# stasum = stachyphrynium sumatranum = forb
# zinunk = zingiberaceae = forb (ginger)

# species below are new in 2019 dataset compared to 2017, check
# rha254
# proasp
# cyrped1
# acaunk
# orcunk

# Calculate total subcanopy dry mass across all plots
dobert_2019_plot_species_data$drywgt_total <-
  sum(dobert_2019_plot_species_data$drywgt)

# Calculate total plot area (2x2 = 4 m2)
dobert_2019_plot_species_data$total_plot_area <-
  length(unique(dobert_2019_plot_species_data$plot.code)) * 2 * 2

# Calculate total subcanopy dry mass per area (g m-2)
dobert_2019_plot_species_data$drywgt_total_m2 <-
  dobert_2019_plot_species_data$drywgt_total /
  dobert_2019_plot_species_data$total_plot_area

# For comparison also calculate at plot level
dobert_2019_plot_species_data$drywgt_total_m2_plot <- ave(
  dobert_2019_plot_species_data$drywgt,
  dobert_2019_plot_species_data$plot.code,
  FUN = sum
) /
  4

# Correct these values for carbon content
# 41.747% carbon content for herb layer reported by
# Wu et al. (2022; https://doi.org/10.3390/su142416517)
# Note that these values are in g C m-2, so multiply by 0.001 to convert units
# to kg C m-2
dobert_2019_plot_species_data$drywgt_total_m2_carbon <-
  0.41747 * dobert_2019_plot_species_data$drywgt_total_m2 * 0.001

dobert_2019_plot_species_data$drywgt_total_m2_plot_carbon <-
  0.41747 * dobert_2019_plot_species_data$drywgt_total_m2_plot * 0.001

# Add the mean value to data
data$mean_total_subcanopy_carbon_mass <-
  unique(dobert_2019_plot_species_data$drywgt_total_m2_carbon)

# Subset data to only include species in taxa_present
data <- data[data$species.code %in% taxa_present, ]

# Subset data to only include relevant columns
data <- data[, c("mean_total_subcanopy_carbon_mass", "sla")]

# Calculate mean SLA and set to unique values only
data$sla <- as.numeric(data$sla)
data$sla <- mean(data$sla)
data <- unique(data)

# Correct SLA to account for carbon content (use 41.747% carbon content for herb
# layer reported by Wu et al. (2022; https://doi.org/10.3390/su142416517)
# Unit is m2 kg-1 C
data$sla <- data$sla / 0.41747

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

# Add the mean value across plots to dobert_2019_plot_species_data and
# apply the same reasoning to plot level reproductive carbon mass in
# dobert_2019_plot_species_data so that it can be exported for the scenario
# script. The resulting unit is kg C m-2.

dobert_2019_plot_species_data$seedbank_mass_total_m2_carbon <-
  unique(data$subcanopy_seedbank_carbon_mass)

dobert_2019_plot_species_data$seedbank_mass_total_m2_plot_carbon <-
  dobert_2019_plot_species_data$drywgt_total_m2_plot_carbon *
  unique(data$subcanopy_reproductive_allocation) *
  0.23

# Now save this version of dobert_2019_plot_species_data for use in the
# scenario script

names(dobert_2019_plot_species_data)

dobert_2019_plot_species_data <-
  dobert_2019_plot_species_data[, c(
    "plot.code",
    "drywgt_total_m2_carbon",
    "seedbank_mass_total_m2_carbon",
    "drywgt_total_m2_plot_carbon",
    "seedbank_mass_total_m2_plot_carbon"
  )]

dobert_2019_plot_species_data <- unique(dobert_2019_plot_species_data)

colnames(dobert_2019_plot_species_data) <-
  c(
    "plot_code",
    "subcanopy_vegetation_carbon_mass_mean",
    "subcanopy_seedbank_carbon_mass_mean",
    "subcanopy_vegetation_carbon_mass_plot",
    "subcanopy_seedbank_carbon_mass_plot"
  )

# Write csv file

dir.create(
  "../../../../data/derived/plant/input_data/data_library",
  recursive = TRUE,
  showWarnings = FALSE
)

write.csv(
  dobert_2019_plot_species_data,
  "../../../../data/derived/plant/input_data/data_library/dobert_subcanopy_maliau.csv",
  row.names = FALSE
)

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

# Add seedbank turnover (i.e. seeds lost from soil seed bank)
# based on (Dalling et al. (1998; https://doi.org/10.2307/176953))
# Calculated as 1-fraction seeds expected to still be viable after one year

data$subcanopy_seedbank_turnover <- 1 - 0.68

# Add subcanopy sprout rate (as the fraction of viable seeds within 1 year, while
# assuming all of these will sprout)
# based on (Dalling et al. (1998; https://doi.org/10.2307/176953))

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
  "../../../../data/derived/plant/input_data/data_library/stoichiometry_maliau.csv",
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

dir.create(
  "../../../../data/derived/plant/input_data/data_library",
  recursive = TRUE,
  showWarnings = FALSE
)

write.csv(
  data,
  "../../../../data/derived/plant/input_data/data_library/subcanopy_maliau.csv",
  row.names = FALSE
)

# Summary of units

# "subcanopy_vegetation_biomass" = kg C m-2
# "subcanopy_seedbank_biomass" = kg C m-2
# "subcanopy_specific_leaf_area" = m2 kg-1 C
# "subcanopy_reproductive_allocation" = fraction of aboveground (leaf) biomass
# "subcanopy_respiration_fraction" = fraction of GPP
# "subcanopy_extinction_coef" = unitless
# "subcanopy_yield" = fraction of GPP
# "subcanopy_vegetation_turnover" = year-1
# "subcanopy_vegetation_c_n_ratio" = unitless
# "subcanopy_vegetation_c_p_ratio" = unitless
# "subcanopy_vegetation_lignin" = unitless
# "subcanopy_seedbank_turnover" = year-1
# "subcanopy_sprout_rate" = fraction of seedbank carbon mass year-1
# "subcanopy_sprout_yield" = fraction of seedbank carbon mass
# "subcanopy_seedbank_c_n_ratio" = unitless
# "subcanopy_seedbank_c_p_ratio" = unitless
# "subcanopy_seedbank_lignin" = unitless
