#| ---
#| title: Estimating deadwood litter stocks from SAFE data
#|
#| description: |
#|     This R script estimates deadwood litter stocks (kg C/m2) from SAFE data.
#|     It does through a few hoops: first estimate deadwood count per area, then
#|     estimate deadwood volume distribution, then deadwood density distribution,
#|     and then combine their expected value with deadwood carbon content from
#|     a global study to get deadwood stock.
#|
#| virtual_ecosystem_module:
#|   - Litter
#|
#| author:
#|   - Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: SAFE_DeadwoodSurvey_SAFEdatabase_2021-06-04.xlsx
#|     path: data/primary/litter/
#|     description: |
#|       Deadwood survey data at SAFE vegetation plots;
#|       downloaded from https://zenodo.org/records/4899608
#|   - name: SAFE_WoodDecomposition_Data_SAFEdatabase_2021-06-04.xlsx
#|     path: data/primary/litter/
#|     description: |
#|       Deadwood decay and traits in the SAFE landscape, used to obtain
#|       deadwood densities; downloaded from https://zenodo.org/records/4899610
#|   - name: Fractal_point_nesting.xlsx
#|     path: data/primary/site/
#|     description: |
#|       SAFE plot type information including site, habitat, logging treatment,
#|       and plot nesting order; used to classify plots by logging group
#|
#| output_files:
#|
#| package_dependencies:
#|     - tidyverse
#|     - readxl
#|     - glmmTMB
#|
#| usage_notes: |
#|   There is also deadwood density from https://zenodo.org/records/1237722 but
#|   their densities seems too low? They were in the range around ~0.2 g/cm3
#| ---

library(tidyverse)
library(readxl)
library(glmmTMB)


# Data --------------------------------------------------------------------

# SAFE plot type information
safe_plot_info <-
  read_xlsx(
    "data/primary/site/Fractal_point_nesting.xlsx",
    sheet = 3,
    skip = 5
  ) |>
  pivot_longer(
    cols = ends_with("Order"),
    names_to = "Order",
    values_to = "Plot"
  ) |>
  filter(!is.na(Plot), Plot != "NA") |>
  distinct(Site, Habitat, Logging, Order, Plot) |>
  # reclassify logging
  mutate(
    Logging_grp = replace_values(
      Logging,
      "LowIntensity" ~ "Logged",
      "Twice" ~ "Logged",
      "Variable" ~ "Logged"
    )
  )

# deadwood volume
deadwood_V <-
  read_xlsx(
    "data/primary/litter/SAFE_DeadwoodSurvey_SAFEdatabase_2021-06-04.xlsx",
    sheet = 3,
    skip = 5
  ) |>
  mutate(across(
    c(Length, Diameter1, Diameter2, HollowDiameter),
    parse_double
  )) |>
  # use the first survey for now
  # also use fallen deadwood
  # remove those with diameter <10 cm because the survey targeted >10 cm (100 mm)
  # some of these smaller deadwood might have made it into the records due to
  # opportunistic sampling; I think it is important to remove them because we
  # are not sure if the sampling effort for <10 cm is the same as >10 cm
  # also remove decay class 5 because we do not have density for them and they
  # do not consist of a lot of samples
  filter(
    CensusNumber == "1st",
    Status == "B",
    DecayClass != "DC_5",
    Diameter1 >= 100,
    Diameter2 >= 100
  ) |>
  # convert mm to m
  mutate_at(vars(Diameter1, Diameter2, HollowDiameter), ~ . / 1000) |>
  # calculate volume (of a hollow conical frustum)
  # ignoring hollow diameter for now because (1) they don't comprise of the
  # majority and because we are doing a quick job for initialisation now
  mutate(
    Volume = pi *
      Length /
      3 *
      (Diameter1^2 + Diameter1 * Diameter2 + Diameter2^2)
  ) |>
  filter(!is.na(Volume)) |>
  # join SAFE plot type
  left_join(safe_plot_info |> select(Plot, Logging_grp)) |>
  mutate(
    Logging_grp = ifelse(
      is.na(Logging_grp) & Block == "OG3",
      "Never",
      Logging_grp
    )
  )

# deadwood count
deadwood_N <-
  deadwood_V |>
  group_by(CensusNumber, Block, Plot, Logging_grp, DecayClass) |>
  count()

# deadwood density
density_file <-
  "data/primary/litter/SAFE_WoodDecomposition_Data_SAFEdatabase_2021-06-04.xlsx"
deadwood_rho <-
  read_xlsx(density_file, sheet = 3, skip = 5) |>
  # use the first census
  filter(SamplingCampaign == "1st") |>
  # calculate mean density per wood sample
  select(SamplingYear:Tag, starts_with("Density")) |>
  pivot_longer(
    cols = starts_with("Density"),
    names_to = "Type",
    values_to = "Density"
  ) |>
  mutate(Density = parse_double(Density)) |>
  group_by(
    SamplingYear,
    SamplingCampaign,
    SamplingDate,
    RA_Lab,
    Block,
    Plot,
    PlotCode,
    Tag
  ) |>
  summarise(Density = mean(Density, na.rm = TRUE)) |>
  ungroup() |>
  # join decay class information
  left_join(
    read_xlsx(density_file, sheet = 2, skip = 5) |>
      filter(SamplingCampaign == "1st") |>
      distinct(Tag, DecayClass)
  ) |>
  # join SAFE plot type
  left_join(safe_plot_info |> select(PlotCode = Plot, Logging_grp)) |>
  mutate(
    Logging_grp = ifelse(
      is.na(Logging_grp) & Block == "OG3",
      "Never",
      Logging_grp
    )
  )


# Model -------------------------------------------------------------------

# volume model
mod_V <-
  glmmTMB(
    Volume ~ 0 + DecayClass * Logging_grp + (1 | Block / Plot),
    dispformula = ~ 0 + DecayClass,
    data = deadwood_V,
    family = lognormal()
  )
summary(mod_V)

# count model
# no dispersion submodel because the variance for decay class 1 was very
# high, I think we don't have enough data to let dispersion vary by class
mod_N <-
  glmmTMB(
    n ~ 0 + DecayClass * Logging_grp + (1 | Block),
    data = deadwood_N,
    family = truncated_nbinom2()
  )
summary(mod_N)

# density model
mod_rho <-
  glmmTMB(
    Density ~ 0 + DecayClass * Logging_grp + (1 | Block / Plot),
    dispformula = ~ 0 + DecayClass,
    data = deadwood_rho,
    family = lognormal()
  )
summary(mod_rho)


# Estimate deadwood stock -------------------------------------------------

# I think we can simply multiply the expected values together
# expected total deadwood C mass =
# expected count * expected volume * expected density * deadwood C content

# SAFE plot area (m2)
plot_area <- 25 * 25

# deadwood C content (decay class 1 to 4) from Table 1 in
# Martin, A.R., Domke, G.M., Doraisami, M. et al. Carbon fractions in the
# world’s dead wood. Nat Commun 12, 889 (2021).
# https://doi.org/10.1038/s41467-021-21149-9
deadwood_C <- c(0.4753, 0.4755, 0.4798, 0.4868)

# predict deadwood stock
newdat_deadwood <-
  expand_grid(
    DecayClass = unique(deadwood_V$DecayClass),
    Logging_grp = unique(deadwood_V$Logging_grp),
    Block = NA,
    Plot = NA
  )
total_deadwood_stock <-
  newdat_deadwood |>
  mutate(
    # expected count in [count / m2]
    mu_N = predict(
      mod_N,
      newdat_deadwood,
      type = "response",
      allow.new.levels = TRUE
    ) /
      plot_area,
    # expected volumn in m3
    mu_V = predict(
      mod_V,
      newdat_deadwood,
      type = "response",
      allow.new.levels = TRUE
    ),
    # expected density in g/cm3
    mu_rho = predict(
      mod_rho,
      newdat_deadwood,
      type = "response",
      allow.new.levels = TRUE
    ),
    # stock in kg C/m2
    deadwood_stock = mu_N * mu_V * (mu_rho * 1000) * deadwood_C
  ) |>
  # total up deadwood stock across decay classes
  group_by(Logging_grp) |>
  summarise(deadwood_stock = sum(deadwood_stock)) |>
  # simplify to named vector
  pull(deadwood_stock, name = Logging_grp)
