#| ---
#| title: Plant functional type species classification base
#|
#| description: |
#|     This script classifies tree species into plant functional types (PFTs).
#|     This classification is predominantly based on the one provided by
#|     Kohler and Huth (1998; DOI https://doi.org/10.1016/S0304-3800(98)00066-0)
#|     and contains the following PFTs:
#|     -emergent trees
#|     -overstory trees
#|     -understory trees
#|     -pioneer trees
#|     For the understory PFT, the species list is expanded to also include
#|     the species listed in group 9 (small shade trees) in
#|     Phillips et al. (2002; DOI https://doi.org/10.1016/S0378-1127(00)00666-6).
#|     This PFT species classification is then applied to the SAFE census dataset.
#|     The output of this script generates a CSV file containing a list of
#|     species and their respective PFT.
#|     In a follow up script, the remaining species that have not been assigned
#|     a PFT yet will be assigned into one based on their species maximum height
#|     relative to the PFT maximum height.
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
#|   - name: tree_census_11_20.xlsx
#|     path: data/primary/plant/tree_census
#|     description: |
#|       https://doi.org/10.5281/zenodo.14882506
#|       Tree census data from the SAFE Project 2011–2020.
#|       Data includes measurements of DBH and estimates of tree height for all
#|       stems, fruiting and flowering estimates,
#|       estimates of epiphyte and liana cover, and taxonomic IDs.
#|
#| output_files:
#|   - name: plant_functional_type_species_classification_base.csv
#|     path: data/derived/plant/plant_functional_type
#|     description: |
#|       This CSV file contains a list of species and their respective PFT.
#|
#| package_dependencies:
#|     - readxl
#|
#| usage_notes: |
#|   If the PFT species classification is updated in the future,
#|   this script should be the starting point.
#| ---

# Load packages

library(readxl)

# Load SAFE tree census data

tree_census_11_20 <- read_excel(
  "../../../data/primary/plant/tree_census/tree_census_11_20.xlsx",
  sheet = "Census11_20",
  col_names = FALSE
)

# Clean dataset and create subset based on species classification

data <- tree_census_11_20

max(nrow(data))
colnames(data) <- data[10, ]
data <- data[11:40511, ]
names(data)

##########

data_taxa <- data

unique(data_taxa$TaxaName)

##########

# Assign plant functional type number to correct taxa

# 1 is emergent
# 2 is overstory
# 3 is pioneer
# 4 is understory

data_taxa$PFT <- NA

data_taxa$PFT[
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
] <- 1
data_taxa$PFT[
  data_taxa$Genus %in%
    c(
      "Ganua",
      "Madhuca",
      "Palaquium",
      "Payena",
      "Litsea"
    )
] <- 2
data_taxa$PFT[
  data_taxa$Genus %in%
    c(
      "Macaranga",
      "Melicope",
      "Neonauclea",
      "Octomeles",
      "Trema",
      "Leea"
    )
] <- 3
data_taxa$PFT[
  data_taxa$Genus %in%
    c(
      "Eugenia",
      "Hydnocarpus"
    )
] <- 4

# For group 4, also added species from group 9 from
# Phillips et al. (2002) (small shade trees)
data_taxa$PFT[
  data_taxa$Genus %in%
    c(
      "Gonystylus",
      "Madhuca",
      "Kayea"
    )
] <- 4

# Below we add specific species to PFT species classification, based on:
# - Okuda et al. 2003
# - Bischoff et al. 2005
# - Manokaran et al. 1987
# - Lee et al. 2002
# - Burghouts et al. 1994

data_taxa$PFT[
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
] <- 1

data_taxa$PFT[
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
] <- 2

data_taxa$PFT[
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
] <- 3

data_taxa$PFT[
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
] <- 4

unique(data_taxa$PFT)

# Exclude where PFT is NA

data_taxa <- data_taxa[!is.na(data_taxa$PFT), ]

##########

# Prepare final format of data_taxa

data_taxa <- data_taxa[, c(
  "Family",
  "Genus",
  "Species",
  "TaxaName",
  "TaxaLevel",
  "PFT"
)]
data_taxa <- unique(data_taxa)

data_taxa$PFT_name <- NA
data_taxa$PFT_name[data_taxa$PFT == "1"] <- "emergent"
data_taxa$PFT_name[data_taxa$PFT == "2"] <- "overstory"
data_taxa$PFT_name[data_taxa$PFT == "3"] <- "pioneer"
data_taxa$PFT_name[data_taxa$PFT == "4"] <- "understory"

data_taxa$PFT_name <- as.character(data_taxa$PFT_name)

data_taxa <- data_taxa[, c(
  "PFT",
  "PFT_name",
  "TaxaName",
  "TaxaLevel",
  "Species",
  "Genus",
  "Family"
)]
data_taxa <- data_taxa[
  order(
    data_taxa$PFT,
    data_taxa$Family,
    data_taxa$Genus
  ),
]

# Write CSV file

write.csv(
  data_taxa,
  "../../../data/derived/plant/plant_functional_type/plant_functional_type_species_classification_base.csv", # nolint
  row.names = FALSE
)
