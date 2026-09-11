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
title: "Soil constant search (first pass review)"
format: gfm
author: Hao Ran Lai
---

This is an intermittent report to review the rationales of a LLM when asked to
search for soil constant values from the literature. The R script that ran the
query is [`analysis/soil/llm/chat.R`].

```text {r, warning=FALSE, message=FALSE}
library(tidyverse)
library(knitr)

results <-
  read_csv(here::here(
    "data/derived/soil/llm/soil_constant_literature_values.csv"
  )) |>
  select(
    name,
    rationale,
    suggested_value,
    unit,
    original_value,
    original_unit,
    conversion_notes,
    doi,
    measurement_conditions,
    confidence
  )

kable(results, format = "pipe")
```
