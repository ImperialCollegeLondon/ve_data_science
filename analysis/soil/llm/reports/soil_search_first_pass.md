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
---

---

title: "Soil constant search (first pass review)"
format: gfm

## author: Hao Ran Lai

This is an intermittent report to review the rationales of a LLM when asked to
search for soil constant values from the literature. The R script that ran the
query is [`analysis/soil/llm/chat.R`].

The result table can be found at the end of this report; note that only selected
columns are shown (otherwise the table is too wide). The `rationale` column
records the LLM's justification of (not) finding a value. Because it contains a
large amount of text, I also asked an AI to summary them into a paragraph below.

## Summary

Empirical parameterization of the Virtual Ecosystem soil model faces substantial
barriers, with only 11 of 158 soil constants (7%) receiving literature-supported
values. Successful parameter discovery occurs under narrow, specific conditions:
when published studies provide direct experimental measurements of a single
process under controlled conditions (e.g., Myers' measured nitrification optimum
of 35°C in tropical soil; Orchard and Cook's determination of soil respiration
cessation at −15 MPa), or when systematic reviews synthesize measurements across
comparable systems into a summary estimate with clear measurement conditions
(e.g., Strickland and Rousk's synthesis yielding bacterial biomass C:N ratios of
3–6). Categorical parameters (taxonomic assignments, enzyme source
classifications) are more discoverable because they map straightforwardly to
established taxonomic or ecological literature, but numeric parameters require
source-specific, temperature-calibrated, and functionally compatible
measurements. The predominant barriers are structural rather than simply due to
missing data. First, unit and functional-form mismatches prevent conversion of
published measurements: empirical denitrification studies report Q₁₀ values or
Arrhenius activation energies, but the model requires three jointly-fitted
parameters of a modified Lloyd–Taylor function, making literature Q₁₀ values
alone insufficient without access to raw temperature-response data. Second,
source-resolution problems arise because bulk-soil measurements (e.g.,
extracellular enzyme temperature responses, NH₃ volatilization flux) aggregate
across bacterial, fungal, stabilized, and plant-derived components, yet the
model requires organism-group-specific or enzyme-source-specific rate constants.
Third, parameterization anchors like reference temperature must be traceable to
the specific empirical conditions of the rates they normalize, but this
joint-parameter dependency is rarely published together. Fourth, many soil model
parameters require measurements at defined ecological or pedological scales (per
unit fungal biomass, per unit labile P pool, per compartment) that
field-integrated studies do not isolate. To advance parameterization, priorities
should include: (1) targeted empirical studies measuring temperature-response
kinetics for organism-resolved processes (e.g., temperature-series microbial
uptake assays with identified biomass pools), with full reporting of functional
forms and measurement conditions; (2) systematic reanalysis of legacy
soil-incubation datasets to extract first-order rate constants with stated
temperature and pool definitions; (3) development of scaling relationships to
convert ecosystem-level field observations (e.g., ectomycorrhizal production per
root length) to model-compatible, pool-specific parameters; and (4) formal
meta-analytic synthesis of existing temperature-response studies, with joint
fitting of multi-parameter functions rather than aggregation of individual Q₁₀
values.

## Rationale table

```text {r, warning=FALSE, message=FALSE}
library(tidyverse)
library(knitr)

results <-
  read_csv(here::here(
    "data/derived/soil/llm/soil_constant_literature_values.csv"
  )) |>
  arrange(suggested_value) |>
  select(
    name,
    rationale,
    suggested_value,
    unit,
    doi,
    confidence
  )

kable(results, format = "pipe")
```
