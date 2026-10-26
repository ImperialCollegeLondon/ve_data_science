---
name: ve-constant-search
description: Find and review published values for Virtual Ecosystem soil, enzyme, and microbial constants. Use for soil parameter literature searches, evidence appraisal, or updating soil_constant_literature_values.csv from full text.
---

# VE constant search

Use the IDE workspace containing `ve_data_science` and `virtual_ecosystem`. Work
in `ve_data_science`; locate the sibling repository from the workspace, not a
remote branch. This skill replaces `analysis/soil/llm/chat.R` as the
value-search interface. For user setup, review and approval, see
`docs/AI-assisted-parameterisation.md`. Treat every result as an unverified
proposal.

## 1. Ground the constants

Read `data/derived/soil/llm/ve_constant_usage.toml` (`metadata`, `functions`,
`constants`). If absent or stale against the workspace's `virtual_ecosystem`
tree, run `analysis/soil/llm/extract_constant_metadata.R` with its declared
dependencies, then inspect the commit and dirty-tree metadata. A dirty tree
requires identifying which changes affect a constant before relying on its
recorded commit. Do not regenerate derived files just to inspect them. Review
`data/derived/soil/llm/soil_constant_review.xlsx` when available; resolve any
relevant `human_decision_required` or `issue` rows before interpreting usage.
Generate this workbook with
`analysis/soil/llm/generate_constant_review_workbook.R` if needed; do not
overwrite completed human review without permission.

Default scope matches the former chat: constants whose `class_name` is
`SoilConstants`, `SoilEnzymeClass`, or `SoilMicrobialGroup`, selected by
**qualified_name**, including those outside the soil module. Accept a narrower
user-selected subset. For each constant, use its declaration, docstring,
default, type, reference sites and the `functions` table's consumer docstrings
to establish units and functional form. Check the corresponding source in the
workspace `virtual_ecosystem` repository when interpretation is uncertain.
Defaults and Virtual Ecosystem docs are model context, never empirical evidence.
If units, functional form or a forwarded reference remain ambiguous, ask the
user before proposing values.

## 2. Discover and screen literature

Search per constant or a small group of related constants, not one generic
corpus query. Use `scripts/deep_scholar_tool.py` for OpenAlex searches:
`search_openalex()` returns title, authors, year, DOI, abstract, open-access PDF
URL, journal and OpenAlex ID; `fetch_snowball_citations()` can follow promising
papers. Run it with the Python environment specified by that script (requires
`requests` and the other declared dependencies). The helper requires
`OPENALEX_EMAIL`; ask the user to set their own address as described in
`docs/AI-assisted-parameterisation.md`. Do not create the `.env` file or choose
an address for the user. If none is available, use an OpenAlex integration that
does not require one. Record the exact query and date. Avoid the helper's
`run-pipeline` scoring, Scholar/SerpAPI dependency, and PDF downloads: its
review ranking and filenames do not preserve soil parameter specificity or the
local downloader's DOI-based provenance.

The helper logs request errors and returns an empty list, which is
indistinguishable from a successful zero-result search. Check for request errors
before interpreting empty results; retry or switch integrations if a search
fails. Record failed searches separately and never count them as zero results
or use them to justify `no_evidence`.

Keep a search/screening log beside the resulting CSV, recording the query, date,
counts screened and excluded, reasons, and DOI/OpenAlex ID for each candidate.
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
(soil type, temperature, biome, method). Do not map an incompatible response
function or an aggregate measurement to a group-specific parameter. Require
separate estimates for bacteria, saprotrophic fungi, arbuscular mycorrhiza and
ectomycorrhiza for `SoilMicrobialGroup`, and for bacteria and fungi for
`SoilEnzymeClass`. If evidence supports only some groups, report the remaining
groups as gaps; never fill by pooling. Keep materially different sources as
separate rows; report ranges only where justified. Confidence: high for direct
comparable measurements, medium for supported conversion or moderately different
conditions, low for indirect analogy (not a verified exact value).

Use `no_evidence` when no eligible full text supports a defensible value or
conversion. State whether the gap is search coverage, inaccessible text, missing
measurement, unresolved units or functional-form mismatch. Never echo a model
default as evidence. Ask the user before changing inclusion criteria, using
proxy measurements, or making a consequential scientific judgment.

## 4. Deliver results

Discuss evidence and unresolved gaps with the user before writing a research
result. With approval, write
`data/derived/soil/llm/soil_constant_literature_values.csv` using
`assets/soil_constant_literature_values.csv` as the column header and field
guide (the file is a blank template, not a value dataset). Preserve prior rows:
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
