# AI-assisted parameterisation

The `ve-constant-search` skill helps find published values for Virtual Ecosystem
(VE) configuration constants in any module, one or a few at a time. It produces
**proposals for human review**, not validated parameters or automatic changes to
VE. A model default or an abstract alone is not evidence for a new value.

## Before you start

1. Open a workspace containing this repository and a sibling
   `virtual_ecosystem` repository. Use the VE version whose constants you want
   to assess; record its commit and any relevant uncommitted changes.
2. Set up the project dependencies described in [Python with uv](uv_setup.md)
   and [R with renv](renv.md). The skill may use the metadata extraction scripts
   and an OpenAlex search helper.
3. If using the skill's OpenAlex Python helper, export `OPENALEX_EMAIL` with
   your own contact address in the Python process environment. It does not
   read `.env` or R `.Renviron` files. You may instead use an OpenAlex
   integration that does not require an email address.

In an assistant that supports repository skills, ask it to use
[`ve-constant-search`](https://github.com/ImperialCollegeLondon/ve_data_science/blob/main/.github/skills/ve-constant-search/SKILL.md).
Name the constants or parameter families you want reviewed. For example:

> Use ve-constant-search to review published values for the soil microbial
> turnover constants in this workspace. Show the search and source evidence,
> units, conversions and gaps before proposing any CSV changes.

Select one or a few qualified names (`module.Class.attribute`). If you name a
module, class or family, agree on a small subset before searching. The example
above is a soil-specific request, not the default scope.

## Review the evidence

The assistant uses
[`ve_constant_usage.toml`](../.github/skills/ve-constant-search/assets/ve_constant_usage.toml)
to match selected constants to declarations, reference sites, functions and
VE commit. This generated inventory covers declared configuration attributes
across VE modules, including shared model and disturbance settings. It excludes
hardcoded numeric literals and external trait tables. Reference resolution is
best-effort. Review the VE declaration and reference sites directly for each
selected constant. Resolve ambiguous units or functional forms before accepting
an interpretation.

When the local VE commit changes, run the inventory dry run from this repository
root with a clean VE package source tree:

```bash
uv run --no-sync python .github/skills/ve-constant-search/scripts/refresh_constant_metadata.py
```

Review listed added, removed and changed qualified names. Only then rerun with
`--apply` to replace the TOML. The script skips a matching commit and rejects
uncommitted VE package source changes. It uses the sibling VE clone by default;
use `--ve-root` to point to another clone. Match the tool's Python environment
to the selected local VE clone before regenerating: the generator imports VE
configuration classes. Do not apply an inventory built from a different VE
installation. Check changes outside the package
that might affect imports separately. The TOML is generated model grounding,
not empirical evidence. Updating it does not rerun literature searches or
update historical reports. Do not assume a local full-text library exists.

For each candidate, expect a recorded search query and date, screened and
excluded sources, and a traceable full-text quotation with a page or table
location. Compare the original measurement's units, conditions, organism or
enzyme source, and response function with the model. Check every conversion to
model units. Only use full text you are allowed to access and retain; an
inaccessible paper, search failure or abstract-only result cannot verify a
value. Citation counts do not establish measurement quality.

For soil microbial groups, seek separate evidence for bacteria, saprotrophic
fungi, arbuscular mycorrhiza and ectomycorrhiza; soil enzymes need separate
bacterial and fungal evidence. For other modules, check their applicable
categories and measurement conditions. Missing groups remain gaps; do not
fill them with pooled measurements. A `no_evidence` result describes the
limits of this search, not proof that no literature exists.

## Approve and retain results

Discuss proposed values, exclusions and gaps before authorising changes. The
assistant should ask before using proxies, changing inclusion criteria or
making consequential scientific judgments. For soil constants only, after your
approval, append or replace approved qualified names in
[`soil_constant_literature_values.csv`](https://github.com/ImperialCollegeLondon/ve_data_science/blob/main/data/derived/soil/llm/soil_constant_literature_values.csv).
Other constants' rows must remain unchanged. The skill's
[CSV template](https://github.com/ImperialCollegeLondon/ve_data_science/blob/main/.github/skills/ve-constant-search/assets/soil_constant_literature_values.csv)
is blank; the
[field guide](../.github/skills/ve-constant-search/assets/README.md) defines its
fields. The existing soil CSV uses a different column order, so match columns by
name. For non-soil constants, agree on an output and log path before writing
either; do not add non-soil results to the soil CSV by default.

Each supported value should identify its source, quotation, original units,
conversion, measurement conditions and confidence. If only a range is
supported, retain the range without inventing a point estimate. For gaps,
record why the evidence is insufficient. Keep the search and screening log
beside the resulting CSV so another reviewer can trace what was considered.
Start a new per-parameter log from the
[blank log template](../.github/skills/ve-constant-search/assets/constant_search_log.csv).
Record failed requests separately from successful zero-result searches. The
OpenAlex helper supports `search "QUERY"` and `snowball --id W...` via
`uv run --no-sync python
.github/skills/ve-constant-search/scripts/deep_scholar_tool.py` from the
repository root. It only returns candidates; it does not verify full text.
Before using any proposal in VE, verify it against the cited source and the
recorded VE commit. This workflow does not update VE configuration or
historical parameterisation reports automatically.
