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
title: Troubleshooting continuous outputs related to animals
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

<!-- markdownlint-disable MD013 MD031 MD055-->

```{r}
#| label: load-packages
library(tidync)
library(tidyverse)
library(here)
library(knitr)
library(reticulate)
use_virtualenv(here(".venv"), required = TRUE)
source(here("tools/R/R/tidy_continuous_data.R"))
source(here("tools/R/R/get_ve_variables.R"))
```

## Preamble

::: {.callout-caution collapse="false"}

## Outdated

I am conducting a sensitivity analysis for the soil and litter modules. A sensitivity analysis examines how much of the variation in an output is attributed to variation in an input. **However, if an output never varies, it is meaningless to conduct a sensitivity analysis.** This happens to a few animal-related outputs in the `all_continuous_data.nc` file. My gut feeling is that the lack of temporal variation is due to the animal FGs dying off, hence the exploration here.

At the end of this report, I explain why we might want to design a scenario where there is at least some persistent animal populations, at least for the purpose of sensitivity analyses.

:::

Most if not all of the issues raised previously have been resolved. This report shows the some of the latest figures of VE outputs related to animal diet.

## Model and data summary

I ran the full `maliau_2` scenario available from Globus using `uv run`:

```bash
uv run --group dev-pinned \
  ve_run data/scenarios/maliau/maliau_2/config/abiotic_simple_config.toml \
  data/scenarios/maliau/maliau_2/config/animal_config.toml \
  data/scenarios/maliau/maliau_2/config/data_config.toml \
  data/scenarios/maliau/maliau_2/config/hydrology_config.toml \
  data/scenarios/maliau/maliau_2/config/litter_config.toml \
  data/scenarios/maliau/maliau_2/config/plant_config.toml \
  data/scenarios/maliau/maliau_2/config/soil_config.toml \
  --out data/scenarios/maliau/maliau_2/out \
  --log data/scenarios/maliau/maliau_2/out/logfile.log
```

- Config in `data/scenarios/maliau/maliau_2/config`
- Data in `data/scenarios/maliau/maliau_2/data`
- The animal functional group was from the file `data/scenarios/maliau/maliau_2/data/animal_functional_groups_Maliau_level3.csv` as below. The FG of interest in `Detritivorous_soil_earthworms` that consumes `detritus_fungi_pom_bacteria`.

```{r}
#| label: animal-fg-table
#| echo: false
#| results: asis
read_csv(
  here(
    "data/scenarios/maliau/maliau_2/data/animal_functional_groups_Maliau_level3.csv"
  ),
  show_col_types = FALSE
) |>
  knitr::kable(format = "pipe")
```

```{r}
#| label: ve-version
#| echo: false
#| output: asis
lock_path <- here("uv.lock")

if (!file.exists(lock_path)) {
  cat("- VE version: unknown (`uv.lock` not found)\n")
} else {
  lock_lines <- readLines(lock_path, warn = FALSE)

  get_group_block <- function(group) {
    start <- grep(paste0("^", group, " = \\["), lock_lines)[1]
    if (is.na(start)) {
      return(character())
    }
    end_rel <- which(lock_lines[(start + 1):length(lock_lines)] == "]")[1]
    if (is.na(end_rel)) {
      return(character())
    }
    lock_lines[(start + 1):(start + end_rel - 1)]
  }

  ve_entry <- get_group_block("dev-pinned")
  ve_entry <- ve_entry[grepl('name = "virtual-ecosystem"', ve_entry)][1]

  if (is.na(ve_entry)) {
    ve_entry <- lock_lines[grepl(
      'name = "virtual-ecosystem"',
      lock_lines,
      fixed = TRUE
    )][1]
  }

  if (is.na(ve_entry)) {
    cat("- VE version: unknown (no `virtual-ecosystem` entry in `uv.lock`)\n")
  } else {
    version <- sub('.*version = "([^"]+)".*', '\\1', ve_entry)
    git_src <- sub('.*source = \\{ git = "([^"]+)" \\}.*', '\\1', ve_entry)

    if (identical(git_src, ve_entry)) {
      cat(sprintf("- VE version: v%s (PyPI release)\n", version))
    } else {
      commit <- sub(".*#", "", git_src)
      short <- substr(commit, 1, 7)
      repo <- sub("\\?.*", "", sub("#.*", "", git_src))
      url <- paste0(sub("\\.git$", "", repo), "/commit/", commit)

      cat(sprintf(
        "- VE version: v%s (dev-pinned; commit [%s](%s))\n",
        version,
        short,
        url
      ))
    }
  }
}
```
- OS: Windows 11

## Animal continuous state variables

I examined:

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

ve_output_path <- here("data/scenarios/maliau/maliau_2/out/model_data.zarr")

animal_cont <- tidy_continuous_data(ve_output_path, variables = animal_vars)
```

::: {.callout-caution collapse="false"}

## Outdated

First I saw that the range of these state variables are very small. Are they truly very small, or are they numerical imprecisions that need to be clamped to zero?

:::

The state variables are no longer always minute, they also showed peaks that correspond to the density of microbial consumers (see *Trophic interactions*). However, their lower bounds were not perfectly zero.

```{r}
#| label: summary-table
animal_cont |>
  group_by(variable) |>
  summarise(min = min(value), max = max(value))
```

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


## Trophic interactions

```{r}
#| label: fig-resource-interactions
#| fig-width: 6
#| fig-height: 4
#| fig-dpi: 300
# source function to post-process trophic interactions from #243
# this is a placeholder under Nick's PR is merged
source_python(
  "https://github.com/ImperialCollegeLondon/ve_data_science/raw/3706cdcb0281a021cafa91a081c74f9f1b678cfb/tools/python/animal/trophic_mass_flow.py"
)

# read the trophic interactions output and process them for plotting
trophic_interactions <- read_csv(
  here("data/scenarios/maliau/maliau_2/out/animal_trophic_interactions.csv")
)
trophic_analysis <- TrophicFlowAnalysis(trophic_interactions)
trophic_analysis$group_and_aggregate()

# plot
py_to_r(trophic_analysis$group_df) |>
  ggplot() +
  geom_line(aes(time_index, C)) +
  facet_wrap(~resource_kind, scales = "free_y", ncol = 1) +
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

Before proceeding, I checked the animal cohort data and saw that at least some cohorts persisted until the final time step `r max_cohort_time`.

## Resource continuous state variables

Following Nick’s suggestion, I also checked the temporal trends in resource availability:

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

resource_cont <- tidy_continuous_data(ve_output_path, variables = resource_vars)

resource_cont |>
  unite("variable2", variable, element, na.rm = TRUE) |>
  ggplot() +
  facet_wrap(~variable2, ncol = 1, scales = "free_y") +
  geom_line(aes(time_index, value, group = cell_id), alpha = 0.5) +
  theme_bw()
```

## Questions

::: {.callout-caution collapse="false"}

## Outdated

A few follow-up questions upon seeing the temporal graphs:

- Why do we still see non-zero values in some variables long after all animals have gone extinct since time step `r max_cohort_time`?
- Presumably these variables are positive only; what do the negative values mean? The way they fluctuate almost symmetrically around zero makes me suspect that the non-zero values are not true non-zeros but numerical imprecision.
- There seems to be some relationship with resource availability. But there is no animal to consume then at later time steps?

*If these trends are numerical artefacts rather than true consumption and respiration rates, then there is not much point to read on.*

:::

The only persisting question seems to be the non-zero lower bounds of some animal continuous variables.

## Why do we need persistent animal populations

::: {.callout-caution collapse="false"}

## Outdated

Mainly so that we can include animal-related state variables into the sensitivity analyses. More importantly, the animal variables feed back into the non-animal variables. Unless we are truly aiming for an empty-forest scenario, we will be left with a half-complete sensitivity analysis.

Should we consider an alternative set of animal FG definitions? Currently `maliau_2` uses the level 1 definition, which contain only a single herbivorous endotherm that always go extinct very early on. Has anyone run VE with the level 2 definitions? If the level 2 groups also go extinct, should we consider an alternative set (perhaps more basal in tropic levels) that can persist over time, and hence continue to keep the animal and non-animal components coupled until the end of simulation?

::: 

We do have persistent animal populations now until the end of the simulation, but note that we are using level 3 FG input data.
<!-- #endregion -->
