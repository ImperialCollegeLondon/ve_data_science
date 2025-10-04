library(tidyverse)
library(readxl)
library(lubridate)
library(gllvm)


# Data --------------------------------------------------------------------

census <-
  read_excel(
    "data/primary/plant/tree_census/TreeCensus11_20.xlsx",
    sheet = 4,
    skip = 9,
    col_types = "text"
  )

fruiting <-
  census %>%
  select(
    Block,
    Plot,
    PlotID,
    TagStem_latest,
    Stem_suffix,
    Family,
    Genus,
    TaxaName,
    Date_2011:Date_2020,
    Fruit_2011:Fruit_2020
  ) %>%
  filter(Family != "NA") %>%
  mutate_at(
    vars(starts_with("Fruit_20")),
    ~ as.numeric(factor(
      .,
      levels = c("none", "quarter", "half", "threequarters", "full")
    ))
  ) %>%
  mutate_at(vars(starts_with("Date_20")), as.numeric) %>%
  pivot_longer(cols = c(starts_with("Fruit_20"), starts_with("Date_20"))) %>%
  mutate(
    var = str_extract(name, "^[A-Za-z]+"),
    census = str_extract(name, "\\d+[A-Za-z]*")
  ) %>%
  select(-name) %>%
  # remove possibly erroneous records that had the same tree ID but multiple
  # rows (usually multiple species names)
  mutate(Tree = str_extract(TagStem_latest, "^\\d+(?=-)")) %>%
  group_by(Block, Plot, PlotID, Tree, census, var) %>%
  filter(n() == 1) %>%
  ungroup() %>%
  pivot_wider(names_from = var, values_from = value) %>%
  filter(!is.na(Fruit), !is.na(Date)) %>%
  mutate(
    Date = as.Date(Date, origin = "1899-12-30"),
    Year = year(Date),
    Month = month(Date)
  ) %>%
  # remove taxa with singular fruit category
  group_by(Family) %>%
  filter(length(unique(Fruit)) > 1) %>%
  ungroup() %>%
  # remove "site" with singular fruit category
  group_by(PlotID, Year, Month) %>%
  filter(length(unique(Fruit)) > 1) %>%
  ungroup() %>%
  # remove taxa with singular fruit category
  group_by(Family) %>%
  filter(length(unique(Fruit)) > 1) %>%
  ungroup()

# aggregate to population level
# THIS COULD BE MESSING UP THE ORDINAL DATA but I'll explore on
fruiting_agg <-
  fruiting %>%
  group_by(Block, Plot, PlotID, Family, Year, Month) %>%
  summarise(Fruit = mean(Fruit - 1))

# taxa per family for reference later
taxa_list <-
  fruiting %>%
  filter(Genus != "NA") %>%
  group_by(Family) %>%
  summarise(
    Genera = paste(unique(Genus), collapse = ", "),
    Taxa = paste(unique(TaxaName), collapse = ", ")
  )

# response matrix
y_mat <- with(
  fruiting_agg,
  tapply(Fruit, list(paste0(Block, Plot, "-", Year, "-", Month), Family), sum)
)

# study design dataframe
sDesign <-
  data.frame(rownames = rownames(y_mat)) %>%
  separate(rownames, c("PlotID", "Year", "Month"), sep = "-") %>%
  mutate(Month = factor(Month, levels = 1:12))


# Model -------------------------------------------------------------------

fit <- gllvm(
  y_mat,
  family = "tweedie",
  studyDesign = sDesign,
  row.eff = ~ (1 | PlotID) + (1 | Year),
  lvCor = ~ corAR1(1 | Month),
  num.lv = 2,
  method = "EVA",
  seed = 777
)

summary(fit)
fit$params

ordiplot(fit, biplot = TRUE)

LVs <- getLV(fit)
matplot(str_extract(rownames(LVs), "\\d+"), LVs)

pred <- predict(
  fit,
  newX = data.frame(rep(0, 12)),
  newLV = LVs
)

matplot(1:12, pred, type = "l")

# for October and November
taxa_list_trip <-
  taxa_list %>%
  left_join(
    data.frame(fruiting = colMeans(pred[10:11, ])) %>%
      rownames_to_column("Family")
  ) %>%
  arrange(desc(fruiting))
