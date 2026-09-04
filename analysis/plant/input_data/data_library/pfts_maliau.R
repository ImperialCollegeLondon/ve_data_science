#| ---
#| title: pfts_maliau
#|
#| description: |
#|     This script assigns plant functional types (pfts) to taxa in the SAFE
#|     tree census dataset and exports a curated lookup table for downstream
#|     plant-input workflows.
#|
#|     Classification is applied in two stages. First, broad genus-level rules
#|     define initial pft assignments. Second, species-level rules add or
#|     override assignments for taxa that require finer resolution from
#|     literature sources.
#|
#|     The final output is a CSV file containing pft_name plus taxonomic fields
#|     (taxa_name, taxa_level, species, genus and family).
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
#|
#| output_files:
#|   - name: pfts_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       A CSV file containing the plant functional type classification for taxa
#|       in the tree census. The file contains pft_name, taxa_name, taxa_level,
#|       species, genus and family columns linking each taxon to its assigned
#|       plant functional type (PFT).
#|     variables:
#|       - name: pft_name
#|         type: character
#|         units: dimensionless
#|         description: |
#|           The name of the plant functional type (pft) a species is assigned to.
#|         references:
#|           - citation: "Kohler and Huth (1998)"
#|             doi: "https://doi.org/10.1016/S0304-3800(98)00066-0"
#|             url: "https://www.sciencedirect.com/science/article/pii/S0304380098000660?via%3Dihub"
#|             origin: "Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp rainforest"
#|             site_condition: null
#|             date: null
#|           - citation: "Phillips et al. (2002)"
#|             doi: "https://doi.org/10.1016/S0378-1127(00)00666-6"
#|             url: "https://www.sciencedirect.com/science/article/pii/S0378112700006666?via%3Dihub"
#|             origin: "STREK Project, East Kalimantan, Indonesia"
#|             biome: "tropical"
#|             vegetation_type: "mixed tropical forest"
#|             site_condition: "primary and logged-over"
#|             date: null
#|           - citation: "Okuda et al. (2003)"
#|             doi: "https://doi.org/10.1016/S0378-1127(02)00137-8"
#|             url: "https://www.sciencedirect.com/science/article/pii/S0378112702001378?casa_token=Zs7KS5tPN2MAAAAA:JyhnmBtoW3tAeRaimVFxTxPcmyQSlL7Z5iKMRqrm1K2ZD6h1xAw8wYhvgO1841kJ_J7bkeJtwik"
#|             origin: "Pasoh Forest Reserve, Kuala Lumpur, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: null
#|           - citation: "Bischoff et al. (2005)"
#|             doi: "https://doi.org/10.1016/j.foreco.2005.07.009"
#|             url: "https://www.sciencedirect.com/science/article/pii/S0378112705004603?casa_token=SSJY4togabQAAAAA:ZnMQwQkwl-yNGTABN3aVlYNBOGITV71CRJhM9H4r7OPD2RrURUW1vrF7IGGAGZY9j_jxqUk71bc"
#|             origin: "Danum Valley Conservation Area, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp rain forest"
#|             site_condition: "primary and secondary"
#|             date: null
#|           - citation: "Manokaran et al. (1987)"
#|             doi: "https://doi.org/10.1017/S0266467400002303"
#|             url: "https://www.cambridge.org/core/journals/journal-of-tropical-ecology/article/abs/recruitment-growth-and-mortality-of-tree-species-in-a-lowland-dipterocarp-forest-in-peninsular-malaysia/5A808ECED3B05794757E73F09E54232F#article"
#|             origin: "Sungei Menyala Forest Reserve, Peninsular Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "unlogged primary and regenerated"
#|             date: null
#|           - citation: "Lee et al. (2002)"
#|             doi: null
#|             url: "https://www.jstor.org/stable/43594474"
#|             origin: "Lambir Hills National Park, Sarawak, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland mixed dipterocarp forest"
#|             site_condition: "primary"
#|             date: null
#|           - citation: "Burghouts et al. (1994)"
#|             doi: "https://doi.org/10.1017/S0266467400007677"
#|             url: "https://www.cambridge.org/core/journals/journal-of-tropical-ecology/article/abs/effects-of-tree-species-heterogeneity-on-leaf-fall-in-primary-and-logged-dipterocarp-forest-in-the-ulu-segama-forest-reserve-sabah-malaysia/3A615C73D4BBF3A1CA91E33FD5D4AEB0"
#|             origin: "Danum Valley Conservation Area, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "primary and selectively logged"
#|             date: null
#|         assumptions: null
#|       - name: taxa_name
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Taxonomic info to finest resolution available.
#|         references:
#|           - citation: "Svátek et al. (2025)"
#|             doi: "https://doi.org/10.5281/zenodo.14882506"
#|             url: "https://zenodo.org/records/14882506"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: null
#|       - name: taxa_level
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Taxonomic level identified to.
#|         references:
#|           - citation: "Svátek et al. (2025)"
#|             doi: "https://doi.org/10.5281/zenodo.14882506"
#|             url: "https://zenodo.org/records/14882506"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: null
#|       - name: species
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Species level ID.
#|         references:
#|           - citation: "Svátek et al. (2025)"
#|             doi: "https://doi.org/10.5281/zenodo.14882506"
#|             url: "https://zenodo.org/records/14882506"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: null
#|       - name: genus
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Genus level ID.
#|         references:
#|           - citation: "Svátek et al. (2025)"
#|             doi: "https://doi.org/10.5281/zenodo.14882506"
#|             url: "https://zenodo.org/records/14882506"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: null
#|       - name: family
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Family level ID.
#|         references:
#|           - citation: "Svátek et al. (2025)"
#|             doi: "https://doi.org/10.5281/zenodo.14882506"
#|             url: "https://zenodo.org/records/14882506"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: null
#|
#| package_dependencies:
#|     - readxl
#|
#| usage_notes: |
#|   The pft species classification represents both old-growth and (selectively)
#|   logged plots.
#| ---

# Load packages

library(readxl)

# Load SAFE tree census data

tree_census_11_20 <- read_excel(
  "../../../../data/primary/plant/tree_census/tree_census_11_20.xlsx",
  sheet = "Census11_20",
  col_names = FALSE
)

# Clean dataset and create subset based on species classification

colnames(tree_census_11_20) <- tree_census_11_20[10, ]
tree_census_11_20 <- tree_census_11_20[11:max(nrow(tree_census_11_20)), ]
names(tree_census_11_20)

##########

# This classification is predominantly based on the one provided by
# Kohler and Huth (1998; https://doi.org/10.1016/S0304-3800(98)00066-0)
# containing the pfts: emergent, overstory, understory and pioneer.

data_taxa <- tree_census_11_20

data_taxa$pft_name <- NA

data_taxa$pft_name[
  data_taxa$Genus %in%
    c(
      "Parashorea",
      "Shorea",
      "Artocarpus",
      "Parartocarpus",
      "Pentace",
      "Castanopsis",
      "Nothaphoebe"
    )
] <- "emergent"

data_taxa$pft_name[
  data_taxa$Genus %in%
    c(
      "Ganua",
      "Madhuca",
      "Palaquium",
      "Payena",
      "Litsea"
    )
] <- "overstory"

data_taxa$pft_name[
  data_taxa$Genus %in%
    c(
      "Macaranga",
      "Melicope",
      "Neonauclea",
      "Octomeles",
      "Trema",
      "Leea"
    )
] <- "pioneer"

data_taxa$pft_name[
  data_taxa$Genus %in%
    c(
      "Eugenia",
      "Hydnocarpus"
    )
] <- "understory"

# For the understory PFT, the species list is expanded to also include
# the species listed in group 9 (small shade trees) in
# Phillips et al. (2002; DOI https://doi.org/10.1016/S0378-1127(00)00666-6).

data_taxa$pft_name[
  data_taxa$Genus %in%
    c(
      "Gonystylus",
      "Madhuca",
      "Kayea"
    )
] <- "understory"

# Below we add specific species to PFT species classification, based on:
# - Okuda et al. (2003; DOI https://doi.org/10.1016/S0378-1127(02)00137-8)
# - Bischoff et al. (2005; DOI https://doi.org/10.1016/j.foreco.2005.07.009)
# - Manokaran et al. (1987; DOI https://doi.org/10.1017/S0266467400002303)
# - Lee et al. (2002; DOI https://www.jstor.org/stable/43594474)
# - Burghouts et al. (1994; DOI https://doi.org/10.1017/S0266467400007677)

data_taxa$pft_name[
  data_taxa$TaxaName %in%
    c(
      "Dipterocarpus caudiferus",
      "Dryobalanops lanceolata",
      "Heritiera simplicifolia",
      "Shorea maxwelliana",
      "Shorea acuminata",
      "Shorea macroptera",
      "Neobalanocarpus heimii",
      "Shorea pauciflora",
      "Shorea leprosula",
      "Dipterocarpus cornutus",
      "Dipterocarpus sublamellatus",
      "Dipterocarpus crinitus",
      "Sindora coriacea",
      "Shorea lepidota",
      "Koompassia malaccensis",
      "Shorea parvifolia",
      "Dyera costulata",
      "Heritiera simplicifolia",
      "Quercus argentata",
      "Dipterocarpus costulatus",
      "Intsia palembanica",
      "Shorea ovalis",
      "Pentaspadon motleyi",
      "Triomma malaccensis",
      "Shorea bracteolata",
      "Dialium platysepalum",
      "Atuna excelsa",
      "Anisoptera laevis",
      "Parashorea densiflora",
      "Myristica maingayi",
      "Dipterocarpus verrucosus",
      "Koompassia excelsa",
      "Parashorea malaanonan",
      "Shorea argentifolia",
      "Shorea fallax",
      "Shorea johorensis"
    )
] <- "emergent"

data_taxa$pft_name[
  data_taxa$TaxaName %in%
    c(
      "Shorea xanthophylla",
      "Hopea nervosa",
      "Pentace laxiflora",
      "Xerospermum noronhianum",
      "Ixonanthes icosandra",
      "Pimelodendron griffithianum",
      "Dacryodes rostrata",
      "Xanthophyllum eurhynchum",
      "Mesua ferrea",
      "Millettia atropurpurea",
      "Lithocarpus curtisii",
      "Canarium littorale",
      "Vatica bella",
      "Dacryodes costata",
      "Gymnacranthera forbesii",
      "Teijsmanniodendron coriaceum",
      "Hopea mengerawan",
      "Scaphium macropodum",
      "Anisophyllea corneri",
      "Artocarpus maingayi",
      "Santiria laevigata",
      "Castanopsis schefferiana",
      "Monocarpia marginalis",
      "Parkia speciosa",
      "Artocarpus scortechinii",
      "Dacryodes rugosa",
      "Sarcotheca griffithii",
      "Ochanostachys amentacea",
      "Neoscortechinia kingii",
      "Pometia pinnata",
      "Nephelium costatum",
      "Lithocarpus wallichianus",
      "Xylopia ferruginea",
      "Lithocarpus rassa",
      "Santiria tomentosa",
      "Shorea multiflora",
      "Artocarpus rigidus",
      "Sandoricum koetjape",
      "Knema scortechinii",
      "Dillenia reticulata",
      "Santiria apiculata",
      "Trigoniastrum hypoleucum",
      "Aglaia elliptica",
      "Canarium odontophyllum",
      "Drypetes macrophylla",
      "Durio zibethinus",
      "Eugenia lineata",
      "Ficus calophylla",
      "Litsea ochracea",
      "Madhuca korthalsii",
      "Microcos crassifolia",
      "Palaquium eriocalyx",
      "Polyalthia sumatrana",
      "Syzygium malaccensis",
      "Teijsmanniodendron bogoriense"
    )
] <- "overstory"

data_taxa$pft_name[
  data_taxa$TaxaName %in%
    c(
      "Alstonia angustiloba",
      "Dillenia borneensis",
      "Dillenia excelsa",
      "Endospermum peltatum",
      "Glochidion elmeri",
      "Glochidion lancisepalum",
      "Glochidion rubrum",
      "Homalanthus populneus",
      "Macaranga conifera",
      "Macaranga gigantea",
      "Macaranga hypoleuca",
      "Macaranga triloba",
      "Macaranga winkleri",
      "Melicope confusa",
      "Melicope glabra",
      "Melicope incana",
      "Melicope luna-akenda",
      "Neolamarckia cadamba",
      "Neonauclea gigantea",
      "Vitex pubescens",
      "Duabanga moluccana"
    )
] <- "pioneer"

data_taxa$pft_name[
  data_taxa$TaxaName %in%
    c(
      "Gironniera parvifolia",
      "Scaphocalyx spathacea",
      "Alangium ebenaceum",
      "Aporusa bracteosa",
      "Knema furfuracea",
      "Aporusa aurea",
      "Knema patentinervia",
      "Archidendron bubalinum",
      "Lepisanthes senegalensis",
      "Aporusa prainiana",
      "Barringtonia macrostachya",
      "Aidia wallichiana",
      "Macaranga lowii",
      "Memecylon minutiflorum",
      "Oncodostigma monosperma",
      "Payena lucida",
      "Diospyros apiculata",
      "Croton argyratus",
      "Porterandia anisophylla",
      "Diospyros venosa",
      "Canarium patentinervium",
      "Xylopia malayana",
      "Drypetes pendula",
      "Antidesma cuspidatum",
      "Xylopia caudata",
      "Grewia miqueliana",
      "Buchanania sessifolia",
      "Gironniera nervosa",
      "Mallotus wrayi",
      "Urophyllum corymbosum",
      "Rinorea bengalensis",
      "Fordia splendidissima",
      "Aporosa sarawakensis",
      "Cleistanthus pubens",
      "Drypetes myrmecophila",
      "Polyalthia glabrescens",
      "Ficus stolonifera",
      "Aporosa benthamiana",
      "Hopea mesuoides",
      "Cleistanthus beccarianus",
      "Anisophyllea disticha",
      "Agrostistachys longifolia",
      "Casearia grewiaefolia",
      "Antidesma linearifolium",
      "Fagraea spicata",
      "Dimorphocalyx denticulatus",
      "Koilodepas longifolium",
      "Drypetes xanthophylloides",
      "Hydnocarpus borneensis",
      "Semecarpus rufovelutinus",
      "Croton oblongus",
      "Trigonostemon capillipes",
      "Vatica micrantha",
      "Diospyros mindanensis",
      "Baccaurea sarawakensis",
      "Xanthophyllum velutinum",
      "Dillenia sumatrana"
    )
] <- "understory"

unique(data_taxa$pft_name)

# Exclude where pft is NA

data_taxa <- data_taxa[!is.na(data_taxa$pft_name), ]

##########

# Prepare final format of data_taxa

data_taxa <- data_taxa[, c(
  "pft_name",
  "TaxaName",
  "TaxaLevel",
  "Species",
  "Genus",
  "Family"
)]

data_taxa <- unique(data_taxa)

data_taxa <- data_taxa[
  order(
    data_taxa$pft_name,
    data_taxa$Family,
    data_taxa$Genus
  ),
]

# Clean up names

colnames(data_taxa) <- c(
  "pft_name",
  "taxa_name",
  "taxa_level",
  "species",
  "genus",
  "family"
)

# Write CSV file

dir.create(
  "../../../../data/derived/plant/input_data/data_library",
  recursive = TRUE,
  showWarnings = FALSE
)

write.csv(
  data_taxa,
  "../../../../data/derived/plant/input_data/data_library/pfts_maliau.csv",
  row.names = FALSE
)
