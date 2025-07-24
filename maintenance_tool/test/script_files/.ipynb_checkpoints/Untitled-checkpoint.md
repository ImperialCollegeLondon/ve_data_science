---
jupytext:
  formats: md:myst
  text_representation:
    extension: .md
    format_name: myst
    format_version: 0.13
kernelspec:
  name: python3
  display_name: Python 3 (ipykernel)
  language: python
language_info:
  name: python
  version: 3.12.3
  mimetype: text/x-python
  codemirror_mode:
    name: ipython
    version: 3
  pygments_lexer: ipython3
  nbconvert_exporter: python
  file_extension: .py
ve_data_science:
  title: Updating carbon use efficiency parameters
  description: 'This analysis involves a GLM to estimate parameters for

    temperature-dependent microbial carbon use efficiency (CUE)

    that does not predict CUE out of bound (stays between 0 and 1).

    It also updates the soil constant --- currently the one we use

    originates from a rice paddy study in the US, which is too

    narrow. The data used here is a global dataset. I re-analysed the

    dataset using a GLM, because the original study used a Gaussian

    regression. See the output html file for more details.

    '
  author: [Hao Ran Lai]
  virtual_ecosystem_module: [soil]
  status: final
  input_files:
  - name: 41598_2019_42145_MOESM2_ESM.csv
    path: data/primary/soil/carbon_use_efficiency/Qiao2019
    description: 'The global carbon-use-efficiency (CUE) dataset was compiled by

      Qiao et al. (2019) https://doi.org/10.1038/s41598-019-42145-6

      They shared the data in the Supplementary ("Dataset 1")

      The dataset also contains treatment temperature that is used as a

      predictor of CUE in our analysis here.

      The original data was published as a .xlsx file, which is currently

      gitignored. I have saved it as a csv file so it can be pushed for

      code checking, for now.

      '
  output_files:
  - name: update_cue_parameters.md
    path: analysis/soil/carbon_use_efficiency
    description: 'This is a RMarkdown report of my analysis, including the results.

      Need to knitr from the RMarkdown file.

      If you run the script, it will also save the GLM model object as follows.

      '
  - name: model_cue.rds
    path: analysis/soil/carbon_use_efficiency
    description: 'A Bayesian GLM model object in the class brms, which contains the

      summary statistics, as well as the full posterior samples

      '
  package_dependencies: [tidyverse, readxl, sf, tmap, brms]
  usage_notes: 'The Bayesian model takes a few minutes to run, grab a cuppa! If the
    setup

    works as intended, then the model will only run once unless you make changes.

    Run jupytext --to ipynb code/soil/cue/update_cue_parameters.Rmd

    --output code/soil/cue/update_cue_parameters.ipynb

    to convert this Rmd file to ipynb'
---

# Heading

```{code-cell} ipython3
a = 1
```
