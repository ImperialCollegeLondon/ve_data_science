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
