library(tidyverse)
library(readxl)
library(gllvm)
library(corrplot)
library(gclus)



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

y <- t(as.matrix(comm[, -1]))
colnames(y) <- comm$guild

offset <- log(rowSums(y))

y <- y[, -which(colnames(y) == "other")]

y <- y[, order(colMeans(y), decreasing = TRUE)]



# Model -------------------------------------------------------------------

mod <- gllvm(
  y = y,
  family = "negative.binomial",
  num.lv = 2,
  row.eff = "random",
  offset = offset
)

summary(mod)
mod$params

ordiplot(mod, biplot = TRUE)

# Plot residual correlations
cr <- getResidualCor(mod)
corrplot(
  cr[order.single(cr), order.single(cr)],
  diag = FALSE,
  type = "lower",
  tl.cex = 0.8,
  tl.srt = 45,
  tl.col = "red"
)
