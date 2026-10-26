# AI-assisted parameterisation

The `ve-constant-search` skill helps find published values for Virtual Ecosystem
(VE) soil, enzyme and microbial constants. It produces **proposals for human
review**, not validated parameters or automatic changes to VE. A model default
or an abstract alone is not evidence for a new value.

## Before you start

1. Open a workspace containing this repository and a sibling
   `virtual_ecosystem` repository. Use the VE version whose constants you want
   to assess; record its commit and any relevant uncommitted changes.
2. Set up the project dependencies described in [Python with uv](uv_setup.md)
   and [R with renv](renv.md). The skill may use the metadata extraction scripts
   and an OpenAlex search helper.
3. If using the skill's OpenAlex Python helper, set `OPENALEX_EMAIL` to your own
   contact address. Export it in the Python process environment, or put
   `OPENALEX_EMAIL=your_address` in
   `.github/skills/ve-constant-search/.env` for persistent local use.
   That file is ignored by Git. An exported value takes precedence; an R
   `.Renviron` entry alone does not reach the Python helper. You may instead
   use an OpenAlex integration that does not require an email address.

In an assistant that supports repository skills, ask it to use
[`ve-constant-search`](https://github.com/ImperialCollegeLondon/ve_data_science/blob/main/.github/skills/ve-constant-search/SKILL.md).
Name the constants or parameter families you want reviewed. For example:

> Use ve-constant-search to review published values for the soil microbial
> turnover constants in this workspace. Show the search and source evidence,
> units, conversions and gaps before proposing any CSV changes.

The default scope is all qualified constants in `SoilConstants`,
`SoilEnzymeClass` and `SoilMicrobialGroup`, including constants declared
outside the soil module. Narrow the scope if you need a focused review.

## Review the evidence

The assistant uses
[`ve_constant_usage.toml`](https://github.com/ImperialCollegeLondon/ve_data_science/blob/main/data/derived/soil/llm/ve_constant_usage.toml)
to match each constant to its declaration, units, consumers and VE commit. It
checks the
[constant review workbook](https://github.com/ImperialCollegeLondon/ve_data_science/blob/main/data/derived/soil/llm/soil_constant_review.xlsx)
when available. Resolve flagged issues and ambiguous units or functional forms
before accepting an interpretation. Generated metadata may need refreshing if it
does not match the VE source in your workspace.

For each candidate, expect a recorded search query and date, screened and
excluded sources, and a traceable full-text quotation with a page or table
location. Compare the original measurement's units, conditions, organism or
enzyme source, and response function with the model. Check every conversion to
model units. Only use full text you are allowed to access and retain; an
inaccessible paper, search failure or abstract-only result cannot verify a
value. Citation counts do not establish measurement quality.

Microbial-group values need evidence for each applicable group: bacteria,
saprotrophic fungi, arbuscular mycorrhiza and ectomycorrhiza. Enzyme values
need separate bacterial and fungal evidence. Missing groups remain gaps; do
not fill them with pooled measurements. A `no_evidence` result describes the
limits of this search, not proof that no literature exists.

## Approve and retain results

Discuss proposed values, exclusions and gaps before authorising changes. The
assistant should ask before using proxies, changing inclusion criteria or
making consequential scientific judgments. Only after your approval should it
append or replace approved qualified names in
[`soil_constant_literature_values.csv`](https://github.com/ImperialCollegeLondon/ve_data_science/blob/main/data/derived/soil/llm/soil_constant_literature_values.csv).
Other constants' rows must remain unchanged. The skill's
[CSV template](https://github.com/ImperialCollegeLondon/ve_data_science/blob/main/.github/skills/ve-constant-search/assets/soil_constant_literature_values.csv)
defines the fields; it contains no literature values.

Each supported value should identify its source, quotation, original units,
conversion, measurement conditions and confidence. If only a range is
supported, retain the range without inventing a point estimate. For gaps,
record why the evidence is insufficient. Keep the search and screening log
beside the resulting CSV so another reviewer can trace what was considered.
Before using any proposal in VE, verify it against the cited source and the
recorded VE commit. This workflow does not update VE configuration or
historical parameterisation reports automatically.
