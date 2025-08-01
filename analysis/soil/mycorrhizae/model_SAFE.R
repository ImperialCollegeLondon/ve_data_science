#| ---
#| title: Estimating relative abundance of soil fungi by guilds
#|
#| description: |
#|     To quantify the relative abundance of different guilds of fungal species
#|     (e.g., ectomycorrhizal, arbuscular mycorrhizal, saprotrophs) in the soil
#|     I start with the SAFE dataset collected by Sam Robinson, Elias Dafydd
#|     et al. Their original study assigned species into guilds using the
#|     FunGuilds database, but I will be using the newer FungalTraits database.
#|     I also focus on genus level, rather than species level. This should be
#|     okay because congeners will belong to the same guilds.
#|
#| virtual_ecosystem_module:
#|   - Soil
#|
#| author:
#|   - Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: 13225_2020_466_MOESM4_ESM.xlsx
#|     path: data/primary/soil/mycorrhizae/
#|     description: |
#|       Fungal trait database from FungalTraits (Polme et al. 2020)
#|       Paper DOI: https://doi.org/10.1007/s13225-020-00466-2
#|       Data available from their supplementary; I used Table S1 which
#|       provides the genus-level traits; this dataset is for assigning
#|       fungal genera into guilds
#|   - name: Soil_Mycelial_Fungi_SAFE_Dataset.xlsx
#|     path: data/primary/soil/mycorrhizae/
#|     description: |
#|       Fungal community data from SAFE collected by Robinson et al.
#|       Available on Zenodo https://doi.org/10.5281/zenodo.13122106
#|
#| output_files:
#|   - name: NA
#|     path: NA
#|     description: |
#|       NA
#|
#| package_dependencies:
#|     - tidyverse
#|     - readxl
#|     - gllvm
#|     - corrplot
#|     - gclus
#|
#| usage_notes: |
#|   The control.start argument for the gllvm model is to run multiple fits
#|   to ensure that we reach the global optimum
#| ---


# packages
library(tidyverse)
library(readxl)
library(gllvm)
library(corrplot)
library(gclus)



# Data --------------------------------------------------------------------

# read data from the file path
filepath <- "data/primary/soil/mycorrhizae/"

# trait / guild data from the FungalTraits database
trait <-
  read_excel(paste0(filepath, "13225_2020_466_MOESM4_ESM.xlsx"))

# taxonomic info from the SAFE dataset
taxo <-
  read_xlsx(paste0(filepath, "Soil_Mycelial_Fungi_SAFE_Dataset.xlsx"),
    sheet = 3
  )

# community data from the SAFE dataset
comm <-
  read_xlsx(paste0(filepath, "Soil_Mycelial_Fungi_SAFE_Dataset.xlsx"),
    sheet = 5,
    skip = 9
  ) %>%
  # join taxonomic info
  left_join(
    taxo %>%
      select(
        fungal_taxon = Name,
        Genus
      )
  ) %>%
  # clean up genus epithet for matching with traits
  mutate(Genus = str_remove(Genus, "g__")) %>%
  left_join(
    trait %>%
      select(
        Genus = GENUS,
        primary_lifestyle
      )
  ) %>%
  # rename / merge guilds into coarser groups that we want
  # and then sum their abundances
  mutate(guild = case_when(
    primary_lifestyle == "arbuscular_mycorrhizal" ~ "AM",
    primary_lifestyle == "ectomycorrhizal" ~ "EM",
    str_detect(primary_lifestyle, "saprotroph") ~ "saprotroph",
    str_detect(primary_lifestyle, "pathogen") ~ "pathogen",
    str_detect(primary_lifestyle, "parasite") ~ "parasite",
    str_detect(primary_lifestyle, "endophyte") ~ "endophyte",
    str_detect(primary_lifestyle, "lichenized") ~ "lichenized",
    str_detect(primary_lifestyle, "epiphyte") ~ "epiphyte",
    .default = "other"
  )) %>%
  group_by(guild) %>%
  summarise_at(vars(starts_with("MYC_")), sum)

# turn community dataframe into matrix for modelling
comm_matrix <- t(as.matrix(comm[, -1]))
colnames(comm_matrix) <- comm$guild

# generate offsets from total abundance per sample
# for modelling abundances as relative abundances
offset <- log(rowSums(comm_matrix))

# remove "other" groups because we are not interested in them
comm_matrix <- comm_matrix[, -which(colnames(comm_matrix) == "other")]

# reorder the columns of community matrix to facilitate model identifiability
comm_matrix <- comm_matrix[, order(colMeans(comm_matrix), decreasing = TRUE)]



# Model -------------------------------------------------------------------

# fit a generalised linear latent variable model (a variant of joint
# species distribution model) using the negative binomial distribution with
# log-link and two latent dimensions
mod <- gllvm(
  y = comm_matrix,
  family = "negative.binomial",
  num.lv = 2,
  row.eff = "random",
  offset = offset,
  control.start = list(n.init = 10, jitter.var = 0.1)
)

summary(mod)

# retrieve species intercepts (these should be their relative abundance
# since we included an offset, which turns the modelled outcome into
# count per unit sample)
rel_abun <- plogis(mod$params$beta0)
rel_abun

# model-based ordination plot for curiosity
ordiplot(mod, biplot = TRUE)

# Plot residual correlations for curiosity
cr <- getResidualCor(mod)
corrplot(
  cr[order.single(cr), order.single(cr)],
  diag = FALSE,
  type = "lower",
  tl.cex = 0.8,
  tl.srt = 45,
  tl.col = "red"
)
