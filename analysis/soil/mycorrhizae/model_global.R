#' ---
#' title: Estimate relative abundance of fungal guilds from global datasets
#'
#' description: |
#'     To quantify the relative abundance of different guilds of fungal species
#'     (e.g., ectomycorrhizal, arbuscular mycorrhizal, saprotrophs) in the soil
#'     using global datasets, and to benchmark it against the SAFE data
#'     analysis. Guild data come from the FungalTraits database.
#'     I will also focus on genus level, rather than species level.
#'     This should be okay because congeners will belong to the same guilds.
#'
#' VE_module: Soil
#'
#' author:
#'   - name: Hao Ran Lai
#'
#' status: wip
#'
#' input_files:
#'   - name: GlobalFungi_5_genus_abundance_ITS1_ITS2.txt
#'     path: data/primary/soil/mycorrhizae/
#'     description: |
#'       Global fungal community dataset from https://globalfungi.com/
#'       Download from the "Data download" tab, I kept the original filename
#'       It contains sequences assigned to fungal genera and samples
#'       based on the ITS1 + ITS2 sequences.
#'   - name: GlobalFungi_5_sample_metadata.txt
#'     path: data/primary/soil/mycorrhizae/
#'     description: |
#'       Metadata from the https://globalfungi.com/ database mainly to
#'       retrieve the ITS total abundance to use as offset terms
#'   - name: 13225_2020_466_MOESM4_ESM.xlsx
#'     path: data/primary/soil/mycorrhizae/
#'     description: |
#'       Fungal trait database from FungalTraits (Polme et al. 2020)
#'       Paper DOI: https://doi.org/10.1007/s13225-020-00466-2
#'       Data available from their supplementary; I used Table S1 which
#'       provides the genus-level traits; this dataset is for assigning
#'       fungal genera into guilds
#'
#' output_files:
#'   - name: NA
#'     path: NA
#'     description: |
#'       NA
#'
#' package_dependencies:
#'     - tidyverse
#'     - readxl
#'     - glmmTMB
#'
#' usage_notes: |
#'   Still a work in progress; also need to comment lines later
#' ---


library(tidyverse)
library(readxl)
library(glmmTMB)




# Data --------------------------------------------------------------------

filepath <- "data/primary/soil/mycorrhizae/"

comm <-
  read_delim(paste0(filepath, "GlobalFungi_5_genus_abundance_ITS1_ITS2.txt"))

sample <-
  read_delim(paste0(filepath, "GlobalFungi_5_sample_metadata.txt"))

trait <-
  read_excel(paste0(filepath, "13225_2020_466_MOESM4_ESM.xlsx"))

genus_mycorrhizal <-
  trait %>%
  filter(
    str_detect(primary_lifestyle, "mycorrhizal"),
    GENUS %in% colnames(comm)[-1]
  )

myco <-
  comm %>%
  select(sample_ID, genus_mycorrhizal$GENUS) %>%
  pivot_longer(
    cols = -sample_ID,
    names_to = "Genus",
    values_to = "Abundance"
  ) %>%
  left_join(
    genus_mycorrhizal %>%
      select(Genus = GENUS, primary_lifestyle)
  ) %>%
  group_by(sample_ID, primary_lifestyle) %>%
  summarise(Abundance = sum(Abundance)) %>%
  left_join(
    sample %>%
      select(sample_ID, latitude, longitude, ITS_total)
  ) %>%
  mutate(lat_dev = abs(latitude))





# Model -------------------------------------------------------------------

mod <- glmmTMB(
  cbind(Abundance, ITS_total - Abundance) ~
    0 + primary_lifestyle * lat_dev,
  family = binomial,
  data = myco
)

summary(mod)
