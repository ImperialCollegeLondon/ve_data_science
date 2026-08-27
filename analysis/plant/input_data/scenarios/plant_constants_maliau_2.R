#| ---
#| title: plant_constants_maliau_2
#|
#| description: |
#|     Builds the plant constants table for the Maliau 2 scenario by combining
#|     subcanopy constants with T-model, stoichiometric and reproductive values.
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
#|   - name: stoichiometry_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       This CSV file contains PFT-level stoichiometric ratios and lignin
#|       fractions for plant biomass pools, including sapwood, foliage,
#|       senesced leaves, reproductive tissue, fruits, flowers, and fine roots.
#|       Where PFT-specific measurements are unavailable, literature-derived
#|       proxy values are used.
#|   - name: t_model_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       A CSV file listing T-model parameters by pft.
#|   - name: reproduction_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       This CSV file contains a summary of the ratios needed to calculate
#|       reproductive tissue allocation, and to separate propagules from
#|       non-propagules.
#|   - name: subcanopy_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       This CSV file contains the subcanopy parameters used as plant model
#|       constants in the plant input data library workflow.
#|
#| output_files:
#|   - name: plant_constants_maliau_2.csv
#|     path: data/derived/plant/input_data/scenarios/maliau_2
#|     description: |
#|       Plant constants table for the Maliau 2 scenario.
#|     variables:
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
#|         assumptions: "Loaded from subcanopy_maliau.csv. Original assumption: Calculated as the mean SLA across selected non-tree subcanopy growth forms and converted to a carbon-mass basis using the same carbon fraction as for biomass."
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
#|         assumptions: "Loaded from subcanopy_maliau.csv. Original assumption: Estimated from literature biomass ratios rather than from direct measurements in the SAFE or Maliau subcanopy."
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
#|         assumptions: "Loaded from subcanopy_maliau.csv. Original assumption: Used directly as a literature constant for subcanopy vegetation."
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
#|         assumptions: "Loaded from subcanopy_maliau.csv. Original assumption: null."
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
#|         assumptions: "Loaded from subcanopy_maliau.csv. Original assumption: Derived as one minus the reported growth respiration fraction."
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
#|         assumptions: "Loaded from subcanopy_maliau.csv. Original assumption: Calculated as annual litterfall divided by standing herbaceous biomass from literature rather than from the SAFE/Maliau subcanopy data."
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
#|         assumptions: "Loaded from subcanopy_maliau.csv. Original assumption: Taken from herb-layer elemental composition in primary forest as a proxy for subcanopy vegetation."
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
#|         assumptions: "Loaded from subcanopy_maliau.csv. Original assumption: Taken from herb-layer elemental composition in primary forest as a proxy for subcanopy vegetation."
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
#|         assumptions: "Loaded from subcanopy_maliau.csv. Original assumption: Derived from monocot lignin content and converted to a carbon basis using literature lignin and vegetation carbon fractions."
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
#|         assumptions: "Loaded from subcanopy_maliau.csv. Original assumption: Derived from the fraction of seeds not expected to remain viable after one year."
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
#|         assumptions: "Loaded from subcanopy_maliau.csv. Original assumption: Assumes the viable seed fraction within one year represents the annual sprouting rate."
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
#|         assumptions: "Loaded from subcanopy_maliau.csv. Original assumption: Set equal to the general subcanopy yield, assuming the same growth respiration correction applies to sprouting."
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
#|         assumptions: "Loaded from subcanopy_maliau.csv. Original assumption: Imported directly from the derived stoichiometry_maliau reproductive tissue turnover field as a proxy because seedbank-specific data are lacking."
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
#|         assumptions: "Loaded from subcanopy_maliau.csv. Original assumption: Imported directly from the derived stoichiometry_maliau reproductive tissue turnover field as a proxy because seedbank-specific data are lacking."
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
#|         assumptions: "Loaded from subcanopy_maliau.csv. Original assumption: Imported directly from the derived stoichiometry_maliau reproductive tissue lignin field as a proxy because seedbank-specific lignin data are lacking."
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
#|         assumptions: "Loaded from t_model_maliau.csv. Original assumption: Applied uniformly across PFTs."
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
#|             origin: "Danum Valley Conservation Area, Sabah, Malaysia"
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
#|         assumptions: "Loaded from t_model_maliau.csv. Original assumption: Derived by combining a literature seed establishment probability with an annualised seedling survival correction."
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
#|         assumptions: "Loaded from t_model_maliau.csv. Original assumption: Allocation assumed to be constant across pfts."
#|       - name: dsr_to_ppfd
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Conversion factor from daily solar radiation to PPFD.
#|         references:
#|           - citation: null
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Assigned in this script as the Maliau 2 scenario value."
#|       - name: stem_lignin
#|         type: numeric
#|         units: g lignin C g^-1 stem C
#|         description: |
#|           Fraction of stem carbon mass present as lignin.
#|         references:
#|           - citation: "White et al. (2000)"
#|             doi: "https://doi.org/10.1175/1087-3562(2000)004%3C0003:PASAOT%3E2.0.CO;2"
#|             url: "https://journals.ametsoc.org/view/journals/eint/4/3/1087-3562_2000_004_0003_pasaot_2.0.co_2.xml"
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
#|         assumptions: "Loaded from stoichiometry_maliau.csv. Original assumption: Derived by combining literature lignin fraction with mean sapwood carbon content from the SAFE wood nutrient dataset."
#|       - name: senesced_leaf_lignin
#|         type: numeric
#|         units: g lignin C g^-1 senesced leaf C
#|         description: |
#|           Fraction of senesced leaf carbon mass present as lignin.
#|         references:
#|           - citation: "Both et al. (2019)"
#|             doi: "https://doi.org/10.5281/zenodo.3247631"
#|             url: "https://zenodo.org/records/3247631"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: "Loaded from stoichiometry_maliau.csv for the emergent PFT. Original assumption: Assumed equal to live foliage lignin because senesced leaf-specific lignin data were not separately derived."
#|       - name: plant_reproductive_tissue_lignin
#|         type: numeric
#|         units: g lignin C g^-1 reproductive tissue C
#|         description: |
#|           Fraction of reproductive tissue carbon mass present as lignin.
#|         references:
#|           - citation: "Nakagawa and Nakashizuka (2004)"
#|             doi: "https://doi.org/10.1111/1365-2745.12379"
#|             url: "https://besjournals.onlinelibrary.wiley.com/doi/10.1111/1365-2745.12379"
#|             origin: "Mount Kinabalu, Borneo"
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
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
#|         assumptions: "Loaded from stoichiometry_maliau.csv. Original assumption: Estimated from seed lignin and carbon content, so it serves as a propagule-based proxy for broader reproductive tissue lignin."
#|       - name: root_lignin
#|         type: numeric
#|         units: g lignin C g^-1 root C
#|         description: |
#|           Fraction of fine root carbon mass present as lignin.
#|         references:
#|           - citation: "White et al. (2000)"
#|             doi: "https://doi.org/10.1175/1087-3562(2000)004%3C0003:PASAOT%3E2.0.CO;2"
#|             url: "https://journals.ametsoc.org/view/journals/eint/4/3/1087-3562_2000_004_0003_pasaot_2.0.co_2.xml"
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
#|         assumptions: "Loaded from stoichiometry_maliau.csv. Original assumption: Derived from a global mean fine-root lignin fraction combined with fine-root carbon content from Imai et al. rather than from site-specific lignin measurements."
#|       - name: propagule_mass_portion
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Fraction of live reproductive-organ carbon mass allocated to propagules.
#|         references:
#|           - citation: "Ichie et al. (2005)"
#|             doi: "https://doi.org/10.1016/S0378-1127(03)00161-0"
#|             url: "https://www.sciencedirect.com/science/article/pii/S0378112703001610?via%3Dihub"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Loaded from reproduction_maliau.csv using the Ichie dipterocarp forest propagule_live_organ_carbon_percentage value."
#|       - name: carbon_mass_per_propagule
#|         type: numeric
#|         units: g C
#|         description: |
#|           Carbon mass per propagule, represented here by seed carbon mass.
#|         references:
#|           - citation: "Ichie et al. (2005)"
#|             doi: "https://doi.org/10.1016/S0378-1127(03)00161-0"
#|             url: "https://www.sciencedirect.com/science/article/pii/S0378112703001610?via%3Dihub"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|           - citation: "Nakagawa and Nakashizuka (2004)"
#|             doi: "https://doi.org/10.1111/1365-2745.12379"
#|             url: "https://besjournals.onlinelibrary.wiley.com/doi/10.1111/1365-2745.12379"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Loaded from stoichiometry_maliau.csv. Original assumption: Derived using seed dry mass from Nakagawa and Nakashizuka with fruit carbon concentration from Ichie as a proxy for seed carbon concentration."
#|
#| package_dependencies:
#|   - tidyverse
#|
#| usage_notes: |
#|   This script creates the Maliau 2 plant constants table from the subcanopy
#|   data-library output and adds selected T-model, stoichiometric, reproductive
#|   and scenario-specific constants.
#| ---

library(tidyverse)

# Load the input data files

stoichiometry_maliau <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/stoichiometry_maliau.csv",
  header = TRUE
)

t_model_maliau <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/t_model_maliau.csv",
  header = TRUE
)

reproduction_maliau <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/reproduction_maliau.csv",
  header = TRUE
)

subcanopy_maliau <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/subcanopy_maliau.csv",
  header = TRUE
)

##########

# Start from subcanopy_parameters
plant_constants_maliau_2 <- subset(
  subcanopy_maliau,
  select = -c(
    subcanopy_vegetation_biomass,
    subcanopy_seedbank_biomass
  )
)

# Variables required:
# subcanopy_extinction_coef OK
# subcanopy_specific_leaf_area OK
# subcanopy_respiration_fraction OK
# subcanopy_yield OK
# subcanopy_reproductive_allocation OK
# subcanopy_sprout_rate OK
# subcanopy_sprout_yield OK
# subcanopy_vegetation_turnover OK
# subcanopy_seedbank_turnover OK
# subcanopy_seedbank_c_n_ratio OK
# subcanopy_seedbank_c_p_ratio OK
# subcanopy_vegetation_c_n_ratio OK
# subcanopy_vegetation_c_p_ratio OK
# subcanopy_vegetation_lignin OK
# subcanopy_seedbank_lignin OK

# per_stem_annual_mortality_probability ADD from t_model_maliau
# per_propagule_annual_recruitment_probability ADD from t_model_maliau
# dsr_to_ppfd ADD default
# stem_lignin ADD from stoichiometry_maliau
# senesced_leaf_lignin ADD from stoichiometry_maliau
# plant_reproductive_tissue_lignin ADD from stoichiometry_maliau
# root_lignin ADD from stoichiometry_maliau
# root_exudates ADD from t_model_maliau
# propagule_mass_portion ADD from reproduction_maliau
# carbon_mass_per_propagule ADD from stoichiometry_maliau

# Add missing ones

# per_stem_annual_mortality_probability
plant_constants_maliau_2$per_stem_annual_mortality_probability <-
  unique(t_model_maliau$per_stem_annual_mortality_probability)
# per_propagule_annual_recruitment_probability
plant_constants_maliau_2$per_propagule_annual_recruitment_probability <-
  unique(t_model_maliau$per_propagule_annual_recruitment_probability)
# root_exudates
plant_constants_maliau_2$root_exudates <-
  unique(t_model_maliau$root_exudates)

# dsr_to_ppfd
plant_constants_maliau_2$dsr_to_ppfd <- 2.04

# stem_lignin
plant_constants_maliau_2$stem_lignin <-
  unique(stoichiometry_maliau$stem_lignin)
# senesced_leaf_lignin
plant_constants_maliau_2$senesced_leaf_lignin <-
  unique(stoichiometry_maliau$senesced_leaf_lignin[
    stoichiometry_maliau$pft_name == "emergent"
  ]) # Note that 1 value can only be assigned
# plant_reproductive_tissue_lignin
plant_constants_maliau_2$plant_reproductive_tissue_lignin <-
  unique(stoichiometry_maliau$plant_reproductive_tissue_lignin)
# root_lignin
plant_constants_maliau_2$root_lignin <-
  unique(stoichiometry_maliau$root_lignin)

# propagule_mass_portion
# Use the propagule live-organ carbon percentage for dipterocarp forest.
plant_constants_maliau_2$propagule_mass_portion <- as.numeric(
  reproduction_maliau$value[
    reproduction_maliau$variable == "propagule_live_organ_carbon_percentage" &
      reproduction_maliau$source == "ichie" &
      reproduction_maliau$notes == "dipterocarp forest"
  ][1]
)

# carbon_mass_per_propagule
plant_constants_maliau_2$carbon_mass_per_propagule <-
  unique(stoichiometry_maliau$carbon_mass_per_propagule)

# Write out summary of variable data types and units

# Write CSV file

write.csv(
  plant_constants_maliau_2,
  "../../../../data/derived/plant/input_data/scenarios/maliau_2/plant_constants_maliau_2.csv",
  row.names = FALSE
)

##########
