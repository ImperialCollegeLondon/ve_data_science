---
name: ve-constant-search
description: Find and review published values for one or a few Virtual Ecosystem configuration constants in any module. Use for parameter literature searches, evidence appraisal, or proposing values from full text.
---

# VE constant search

Work in `ve_data_science`; use the Virtual Ecosystem source available in the
workspace for the version under review, rather than a remote branch. For user
setup, review and approval, see `docs/AI-assisted-parameterisation.md`. Treat
every result as an unverified proposal.

## 1. Ground the selected constants

Start with one or a few user-selected configuration constants, identified by
**qualified_name** (`module.Class.attribute`). If the user names a module,
class, or parameter family instead, identify matching names and agree on a
small subset before searching. Do not default to every constant in a class or
module.

Read `assets/ve_constant_usage.toml` (`metadata`, `functions`, `constants`); it
inventories declared configuration attributes across VE modules, including
shared model and disturbance settings. The TOML is generated model context, not
literature evidence. It excludes hardcoded literals and external trait tables;
reference lookup is best-effort. Compare `project_commit` with local VE HEAD and
check uncommitted Python source changes. For a changed VE commit, run
`uv run --no-sync python .github/skills/ve-constant-search/scripts/refresh_constant_metadata.py`
from the repository root after `uv sync` (which installs `jedi`, `tomli-w` and
`virtual-ecosystem`), with a sibling VE clone. Review the staged added, removed
and changed record names; then run with `--apply` to replace the TOML. The
script refuses dirty VE package source and leaves the existing asset intact on a
dry run. If the source is dirty, inspect the selected declarations and
references directly; do not infer that its commit describes local changes. A
committed change outside VE package source may also affect imports; check
provenance and relevant files before relying on an inventory. Do not refresh
literature assets when VE changes.

Inspect each selected constant's source and reference sites directly. If broader
model context would help, optionally query the existing VE documentation store
from the repository root with
`Rscript .github/skills/ve-constant-search/scripts/search_ve_docs.R "QUERY"`
(requires R and `renv::restore()` from the repository root to install `ragnar`
and `DBI` from `renv.lock`). This read-only BM25 lookup needs no embedding
credentials. It checks the store's VE commit and Markdown checksums against the
sibling VE clone before returning snippets. Older stores have no provenance and
will be rejected; rebuild with `analysis/soil/llm/rag_ve.R` when appropriate
(`tidyverse` from `renv.lock` and Azure embedding credentials required). If the
store is missing, stale or unavailable, use local VE docs rather than relying on
retrieved snippets. Treat model docs as context, never empirical evidence.

For each selected constant, use its declaration, docstring, default, type,
reference sites and the `functions` table's consumer docstrings to establish
units and functional form. Check the corresponding Virtual Ecosystem source
when interpretation is uncertain. Defaults and Virtual Ecosystem docs are model
context, never empirical evidence. If units, functional form or a forwarded
reference remain ambiguous, ask the user before proposing values.

## 2. Discover and screen literature

Search per constant or a small group of related constants, not one generic
corpus query. Use `scripts/openalex_search.py` for OpenAlex searches:
`search_openalex()` returns title, authors, year, DOI, abstract, open-access PDF
URL, journal and OpenAlex ID; `fetch_snowball_citations()` can follow promising
papers. Run from the repository root with
`uv run --no-sync python .github/skills/ve-constant-search/scripts/openalex_search.py search "QUERY"`
(or `snowball --id W...`) after `uv sync`, which installs `requests`. The helper
requires `OPENALEX_EMAIL` in the process environment; ask the user to set their
own address as described in `docs/AI-assisted-parameterisation.md`. Do not
create credentials or choose an address for the user. If none is available, use
an OpenAlex integration that does not require one. Record exact query and date.
The helper only discovers candidates; it does not screen, download or verify
full text. A failed API request raises an error rather than returning an empty
list. Retry or switch integrations and log failed searches separately; never
count failure as zero results or use it to justify `no_evidence`.

Keep a per-parameter search/screening log beside the resulting CSV. Start from
`assets/constant_search_log.csv` and its `assets/README.md` field guide; record
query, date, success or failure, counts screened and excluded, reasons, and
DOI/OpenAlex ID for each candidate.
Screen abstracts for the exact measured process, organism/enzyme source, units,
conditions and compatible model form; an abstract only identifies candidates,
not a value. Track no-DOI and inaccessible papers so `no_evidence` describes the
search coverage, not universal absence. Follow references when coverage is thin.
Do not infer study quality from citation count or publisher alone.

Obtain full text for screened candidates through authorized sources; retain
source URL and DOI, inspect the actual tables/methods, and keep a stable
provenance record. Do not assume a local OpenAlex full-text library exists or
covers the selected constants. Check access and sharing rights before copying
restricted full text into the repository. Neither a PDF cache nor abstract
results substitute for verified full text.

## 3. Extract and verify

For each proposed value, cite the exact full-text sentence or table entry and
its page/table location, identify original value and units, show the conversion
factor and calculation to the model's units, and check measurement conditions
(relevant habitat, temperature, taxa and method). Do not map an incompatible
response function or an aggregate measurement to a group-specific parameter. For
soil examples, `SoilMicrobialGroup` needs separate evidence for bacteria,
saprotrophic fungi, arbuscular mycorrhiza and ectomycorrhiza; `SoilEnzymeClass`
needs separate bacterial and fungal evidence. For other VE modules, identify the
applicable groups and conditions from the selected constant's source. Report
unsupported groups as gaps; never fill by pooling. Keep materially different
sources as separate rows; report ranges only where justified. Confidence: high
for direct comparable measurements, medium for supported conversion or
moderately different conditions, low for indirect analogy (not a verified exact
value).

Use `no_evidence` when no eligible full text supports a defensible value or
conversion. State whether the gap is search coverage, inaccessible text, missing
measurement, unresolved units or functional-form mismatch. Never echo a model
default as evidence. Ask the user before changing inclusion criteria, using
proxy measurements, or making a consequential scientific judgment.

## 4. Deliver results

Discuss evidence and unresolved gaps with the user before writing a research
result. With approval, write results under `data/derived/llm/`, grouped by VE
module: `<module>_constant_literature_values.csv`. For soil, create this CSV
from `assets/soil_constant_literature_values.csv` if it does not exist. The
existing `data/derived/soil/llm/soil_constant_literature_values.csv` contains
historical results. Do not copy its rows into a new CSV without approval. Do not
silently rewrite the historical file. Use `assets/README.md`
as the field guide. CSV headers may differ in order: match columns by name. Keep
a per-parameter search/screening log beside the module CSV. Preserve prior rows:
append or replace only user-approved qualified names; do not overwrite other
constants. Each row represents one constant-source pair (or a documented
`no_evidence` outcome). Populate `qualified_name`, `ve_commit`, `retrieved_at`
(UTC), `status`, `rationale`, and evidence fields; `name` and `model_default`
come from the TOML. For source-group-specific values, identify the group in
`rationale` and `measurement_conditions`. Leave unsupported citation and
numerical fields empty. Keep `suggested_value` numeric; if only a range is
supported, fill `value_low` and `value_high` without inventing a point estimate.
For conversions, record original units, multiplier and calculation in
`conversion_notes`. Cite DOI when available, and locate retained source text in
`rationale` or `conversion_notes` if there is no DOI. Check that each
`value_found` row has a traceable full-text quote and source, matches the
recorded model commit and units, and does not merely repeat the default. Flag
remaining gaps for human review. Existing first- and second-pass reports
describe historical results in the older soil CSV; they do not read the new
output. Do not silently rewrite their conclusions.

Stop once the chosen constants are assessed and the user-approved output is
checked; report counts of `value_found` and `no_evidence`, sources screened, and
remaining coverage limits.
