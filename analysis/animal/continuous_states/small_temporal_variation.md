---
jupyter:
  jupytext:
    cell_metadata_filter: all,-trusted
    notebook_metadata_filter: settings,mystnb,language_info,ve_data_science,-jupytext.text_representation.jupytext_version
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
  kernelspec:
    display_name: Python 3 (ipykernel)
    language: python
    name: python3
    path: C:\Users\User\AppData\Local\Python\pythoncore-3.14-64\share\jupyter\kernels\python3
title: Empty forest? We need a scenario with persistent animal populations over the simulation period
author:
  name: Lai, Hao Ran
date: last-modified
format: commonmark
fig-width: 8
fig-height: 10
fig-dpi: 300
execute:
  warning: false
---

```{r}
#| label: load-packages
library(tidync)
library(tidyverse)
library(here)
library(knitr)
source(here("tools/R/tidy_continuous_data.R"))
```

# Preamble

I am conducting a sensitivity analysis for the soil and litter modules. A sensitivity analysis examines how much of the variation in an output is attributed to variation in an input. **However, if an output never varies, it is meaningless to conduct a sensitivity analysis.** This happens to a few animal-related outputs in the `all_continuous_data.nc` file. My gut feeling is that the lack of temporal variation is due to the animal FGs dying off, hence the exploration here.

At the end of this report, I explain why we might want to design a scenario where there is at least some persistent animal populations, at least for the purpose of sensitivity analyses.

# Model and data summary

I ran the full `maliau_2` scenario available from Globus:

- config in `data/scenarios/maliau/maliau_2/config`
- data in `data/scenarios/maliau/maliau_2/data`
- The animal functional group is

|name                   |taxa   |diet                                   |metabolic_type |reproductive_environment |reproductive_type |development_type |development_status |offspring_functional_group |excretion_type |migration_type |vertical_occupancy | birth_mass| adult_mass|density_individuals_m2 |
|:----------------------|:------|:--------------------------------------|:--------------|:------------------------|:-----------------|:----------------|:------------------|:--------------------------|:--------------|:--------------|:------------------|----------:|----------:|:----------------------|
|Herbivorous_endotherms |mammal |wood_seeds_fruit_foliage_flowers_fungi |endothermic    |terrestrial              |iteroparous       |direct           |adult              |Herbivorous_endotherms     |ureotelic      |none           |ground             |        100|       2915|None

- VE version: v0.2.0 (dev version; commit [3c6e75](https://github.com/ImperialCollegeLondon/virtual_ecosystem/commit/3c6e752e6ca3a8a22239bf6112e14236528e32e3))
- OS: Windows 11

# Animal continuous state variables

Currently, I'm examining:

- `animal_arbuscular_mycorrhiza_consumption`
- `animal_bacteria_consumption`
- `animal_ectomycorrhiza_consumption`
- `animal_pom_consumption_cnp`
- `animal_saprotrophic_fungi_consumption`
- `total_animal_respiration`

```{r}
#| label: get-data
animal_vars <- c(
  "animal_arbuscular_mycorrhiza_consumption",
  "animal_bacteria_consumption",
  "animal_ectomycorrhiza_consumption",
  "animal_pom_consumption_cnp",
  "animal_saprotrophic_fungi_consumption",
  "total_animal_respiration"
)
animal_cont <- tidy_continuous_data(
  here("data/scenarios/maliau/maliau_2/out/all_continuous_data.nc"),
  variables = animal_vars
)
```

First I saw that the range of these state variables are very small. Are they truly very small, or are they numerical imprecisions that need to be clamped to zero?
```{r}
#| label: summary-table
animal_cont |>
  group_by(variable) |>
  summarise(min = min(value), max = max(value))
```

Here's how the variables looked over simulation time steps:
```{r}
#| label: fig-temporal-trend
#| fig-cap: "Temporal trends in animal state variables. Each semi-transparent line is a grid cell."
animal_cont |>
  unite("variable2", variable, element, na.rm = TRUE) |>
  ggplot() +
  facet_wrap(~variable2, ncol = 1, scales = "free_y") +
  geom_line(aes(time_index, value, group = cell_id), alpha = 0.5) +
  theme_bw()
```

```{r}
#| label: last-cohort
animal_cohort <- read_csv(
  here("data/scenarios/maliau/maliau_2/out/animal_cohort_data.csv")
)
# add one to the time index because python starts from zero
max_cohort_time <- max(animal_cohort$time_index) + 1
```

Before proceeding, I checked the animal cohort data and saw that all cohorts went extinct after time step `r max_cohort_time`.

Following Nick's suggestion, I also checked the temporal trends in resource availability:
```{r}
#| label: fig-resource-trend
#| fig-cap: "Temporal trends in resource state variables. Each semi-transparent line is a grid cell."
resource_vars <- c(
  "soil_c_pool_arbuscular_mycorrhiza",
  "soil_c_pool_bacteria",
  "soil_c_pool_ectomycorrhiza",
  "soil_c_pool_saprotrophic_fungi",
  "soil_cnp_pool_pom"
)

resource_cont <- tidy_continuous_data(
  here("data/scenarios/maliau/maliau_2/out/all_continuous_data.nc"),
  variables = resource_vars
)

resource_cont |>
  unite("variable2", variable, element, na.rm = TRUE) |>
  ggplot() +
  facet_wrap(~variable2, ncol = 1, scales = "free_y") +
  geom_line(aes(time_index, value, group = cell_id), alpha = 0.5) +
  theme_bw()
```

A few follow-up questions upon seeing the temporal graphs:

- Why do we still see non-zero values in some variables long after all animals have gone extinct since time step `r max_cohort_time`?
- Presumably these variables are positive only; what do the negative values mean? The way they fluctuate almost symmetrically around zero makes me suspect that the non-zero values are not true non-zeros but numerical imprecision.
- There seems to be some relationship with resource availability. But there is no animal to consume then at later time steps?

*If these trends are numerical artefacts rather than true consumption and respiration rates, then there is not much point to read on.*

# Why do we need persistent animal populations

Mainly so that we can include animal-related state variables into the sensitivity analyses. More importantly, the animal variables feed back into the non-animal variables. Unless we are truly aiming for an empty-forest scenario, we will be left with a half-complete sensitivity analysis.

Should we consider an alternative set of animal FG definitions? Currently `maliau_2` uses the level 1 definition, which contain only a single herbivorous endotherm that always go extinct very early on. Has anyone run VE with the level 2 definitions? If the level 2 groups also go extinct, should we consider an alternative set (perhaps more basal in tropic levels) that can persist over time, and hence continue to keep the animal and non-animal components coupled until the end of simulation?
