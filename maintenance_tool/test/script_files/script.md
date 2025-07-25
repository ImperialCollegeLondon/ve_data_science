---
jupytext:
  formats: md:myst
  text_representation:
    extension: .md
    format_name: myst
    format_version: 0.13
    jupytext_version: 1.17.2
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
  title: "Updating carbon use efficiency parameters"

  description: |
    This analysis involves a GLM to estimate parameters for
    temperature-dependent microbial carbon use efficiency (CUE)
    that does not predict CUE out of bound (stays between 0 and 1).
    It also updates the soil constant --- currently the one we use
    originates from a rice paddy study in the US, which is too
    narrow. The data used here is a global dataset. I re-analysed the
    dataset using a GLM, because the original study used a Gaussian
    regression. See the output html file for more details.

  author:
    - Hao Ran Lai

  virtual_ecosystem_module:
    - soil

  status: final

  input_files:
    - name: referenced_file.csv
      path: .
      description: A referenced file

  output_files:
    - name: referenced_file.csv
      path: .
      description: A referenced file

  package_dependencies:
        - tidyverse
        - readxl
        - sf
        - tmap
        - brms

  usage_notes: |
    The Bayesian model takes a few minutes to run, grab a cuppa! If the setup
    works as intended, then the model will only run once unless you make changes.
    Run jupytext --to ipynb code/soil/cue/update_cue_parameters.Rmd
    --output code/soil/cue/update_cue_parameters.ipynb
    to convert this Rmd file to ipynb
---

<!-- Markdownlint _insists_ that there are multiple top level headings -->
<!-- markdownlint-disable-next-line MD025 -->
# Heading

```{code-cell} ipython3
a = 1
```
