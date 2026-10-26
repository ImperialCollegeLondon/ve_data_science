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

Read `data/derived/soil/llm/ve_constant_usage.toml` (`metadata`, `functions`,
`constants`); despite its path, it inventories configuration constants across VE
modules. The TOML is the single generated grounding asset, not literature
evidence. It covers declared configuration attributes, not hardcoded literals or
external trait tables; its reference lookup is best-effort. Compare
`project_commit` with local VE HEAD and check uncommitted Python source changes.
For a changed VE commit, run
`uv run --no-sync python .github/skills/ve-constant-search/scripts/refresh_constant_metadata.py`
from the repository root (requires the project Python dependencies and a sibling
VE clone). Review the staged added, removed and changed record names; then run
with `--apply` to replace the TOML. The script refuses dirty VE package source
and leaves the existing asset intact on a dry run. If the source is dirty,
inspect the selected declarations and references directly; do not infer that its
commit describes local changes. A committed change outside VE package source may
also affect imports; check provenance and relevant files before relying on an
inventory. Keep the human-edited soil workbook separate and refresh it only with
explicit permission. Do not refresh literature assets when VE changes.

For a soil constant, review its row in
`data/derived/soil/llm/soil_constant_review.xlsx` when available; resolve any
relevant `human_decision_required` or `issue` flags before interpreting usage.
The workbook generator at
`analysis/soil/llm/generate_constant_review_workbook.R` filters to the soil
module. Generate it only for soil constants if needed, and never overwrite
completed human review without permission. For other modules, inspect the
selected constant's source and reference sites directly; the soil workbook is
not a substitute for their review.

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
papers. Run from the repository root with `uv run --no-sync python
.github/skills/ve-constant-search/scripts/openalex_search.py search "QUERY"`
(or `snowball --id W...`); this path needs `requests`. The helper requires
`OPENALEX_EMAIL` in the process environment; ask the user to set their own
address as described in `docs/AI-assisted-parameterisation.md`. Do not create
credentials or choose an address for the user. If none is available, use an
OpenAlex integration that does not require one. Record exact query and date.
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

Read existing local full text under `data/derived/soil/llm/full_text/markdown/`
when relevant. Newly found full text that you can legally access is also
allowed: obtain it through authorized sources, retain source URL and DOI,
inspect the actual tables/methods, and keep a stable provenance record. Check
access and sharing rights before copying restricted full text into the
repository. The existing `analysis/soil/llm/paper_library.R` accepts a manual
OpenAlex CSV, not the colleague's JSON; use it only when that input exists. The
`download_full_text.R` downloader needs `record_id`, `doi`, `source_type`,
`preferred_full_text_url`, `retrieval_method`, and `title_export`; its current
filter only downloads `generic_direct`. Use it only with compatible input.
Neither the colleague's PDF cache nor its abstract results are a substitute for
verified full text. Existing `rag_literature.R` is optional for retrieval from
its prepared Markdown library, not for validating source text. `rag_ve.R` uses
remote develop docs, which may differ from the workspace commit.

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
result. For soil constants, with approval, write
`data/derived/soil/llm/soil_constant_literature_values.csv` using
`assets/soil_constant_literature_values.csv` as the blank column template and
`assets/README.md` as the field guide. Its header order differs from the
existing soil CSV: match columns by name. For non-soil constants, agree on a
result path and log path with the user before writing either; do not place them
in the soil results CSV by default. Preserve prior rows:
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
remaining gaps for human review. Existing first- and second-pass reports read
this CSV but describe historical results; do not silently rewrite their
conclusions.

Stop once the chosen constants are assessed and the user-approved output is
checked; report counts of `value_found` and `no_evidence`, sources screened, and
remaining coverage limits.
