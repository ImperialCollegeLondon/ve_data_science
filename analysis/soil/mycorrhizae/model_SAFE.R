library(tidyverse)
library(readxl)
library(gllvm)




# Data --------------------------------------------------------------------

filepath <- "data/primary/soil/mycorrhizae/"

trait <-
  read_excel(paste0(filepath, "13225_2020_466_MOESM4_ESM.xlsx"))

taxo <-
  read_xlsx(paste0(filepath, "Soil_Mycelial_Fungi_SAFE_Dataset.xlsx"),
    sheet = 3
  )

comm <-
  read_xlsx(paste0(filepath, "Soil_Mycelial_Fungi_SAFE_Dataset.xlsx"),
    sheet = 5,
    skip = 9
  ) %>%
  left_join(
    taxo %>%
      select(
        fungal_taxon = Name,
        Genus
      )
  ) %>%
  mutate(Genus = str_remove(Genus, "g__")) %>%
  left_join(
    trait %>%
      select(
        Genus = GENUS,
        primary_lifestyle
      )
  ) %>%
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

comm_total <-
  comm %>%
  pivot_longer(
    cols = starts_with("MYC_"),
    names_to = "Sample_ID",
    values_to = "Abundance"
  ) %>%
  group_by(Sample_ID) %>%
  summarise(Total = sum(Abundance))

comm_long <-
  comm %>%
  pivot_longer(
    cols = starts_with("MYC_"),
    names_to = "Sample_ID",
    values_to = "Abundance"
  ) %>%
  left_join(comm_total)




# Model -------------------------------------------------------------------

mod <- gllvm(
  Abundance ~
    0 + guild + rr(guild + 0 | Sample_ID, d = 2),
  offset = log(Total),
  family = nbinom2,
  data = comm_long
)

summary(mod)
