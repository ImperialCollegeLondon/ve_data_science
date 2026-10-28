---
name: ve-constant-search
description: Find and review published values for one or a few Virtual Ecosystem (VE) configuration constants in any module. Use for parameter literature searches, evidence appraisal, or proposing values from full text.
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
module. Check that selected attributes represent parameters needing empirical
estimates; exclude identifiers or labels such as `name`, `taxonomic_group` and
`source` from literature searches.

Search `assets/ve_constant_usage.toml` for each exact `qualified_name`. Read
only its constant record, the inventory metadata and any `functions` entries
named by that record. Do not read the full inventory into the conversation. The
inventory includes shared model and disturbance settings, but excludes hardcoded
literals and external trait tables; reference lookup is best-effort. Compare
`project_commit` with local VE HEAD and check uncommitted Python source changes.
If the VE commit changed, run
`uv run --no-sync python .github/skills/ve-constant-search/scripts/refresh_constant_metadata.py`
from the repository root after `uv sync` (installs `jedi`, `tomli-w` and
`virtual-ecosystem`), with a sibling VE clone. Review added, removed and changed
record names; then run with `--apply`. The dry run leaves the asset intact, and
the script refuses dirty VE package source. If source is dirty, inspect selected
declarations and references directly; the commit does not describe local
changes. Check provenance and relevant files if commits outside VE package
source could affect imports. Leave literature assets unchanged when VE changes.

Inspect each selected constant's declaration, docstring, default, type and
recorded reference sites. Read narrow line ranges around those locations, not
whole source files. Read a `functions` consumer docstring only when its recorded
reference forwards or applies the constant. Establish units and functional form
from VE source. For broader context, optionally query the
VE documentation store from the repository root with
`Rscript .github/skills/ve-constant-search/scripts/search_ve_docs.R "QUERY"`
(requires R and `renv::restore()` from the repository root for `ragnar` and
`DBI`). This read-only BM25 lookup needs no embedding credentials. It checks
the store's VE commit and Markdown checksums against the sibling VE clone.
Older stores lack provenance and are rejected; rebuild with
`analysis/soil/llm/rag_ve.R` when appropriate (`tidyverse` from `renv.lock` and
Azure embedding credentials required). If the store is missing, stale or
unavailable, use local VE docs. The inventory, defaults and VE docs provide
model context, never empirical evidence. If units, functional form or a
forwarded reference remain ambiguous, ask the user before proposing values.

## 2. Discover and screen literature

From the repository root, after `uv sync` (installs `requests`), search each
constant or small related group with:

```bash
uv run --no-sync python \
  .github/skills/ve-constant-search/scripts/openalex_search.py search "QUERY"
```

Use only this helper for OpenAlex searches and citation lookup
(`snowball --id W...`). Do not
use OpenAlex MCP tools, `webfetch` or general web search to discover or screen
papers. The helper returns at most eight candidates by default, with title,
authors, year, DOI, abstract, open-access PDF URL, journal and OpenAlex ID.
Start with the default limit; increase it only when screening shows inadequate
coverage. Output omits each work's full reference list; use bounded snowball
citation searches for promising leads.

The helper reads `OPENALEX_EMAIL` from the process environment, then from an
ignored `.env` beside this `SKILL.md`. If absent, ask the user to follow
"Configure OpenAlex" in `docs/AI-assisted-parameterisation.md`; include the
relevant setup command. Do not choose an address or create credentials. Wait
for confirmed setup before searching. Record the exact query and date. Helper
results are candidates, not screened or verified evidence. On API failure, log
the error; retry with the same helper or stop and report it. Never treat failure
as zero results or `no_evidence`.

Keep a per-parameter search/screening log beside the resulting CSV. Start from
`assets/constant_search_log.csv` and its `assets/README.md` field guide; record
query, date, success or failure, counts screened and excluded, reasons, and
DOI/OpenAlex ID for each candidate.
Screen abstracts for the exact measured process, organism/enzyme source, units,
conditions and compatible model form; an abstract only identifies candidates,
not a value. Track no-DOI and inaccessible papers so `no_evidence` describes the
search coverage, not universal absence. Follow references when coverage is thin.
Do not infer study quality from citation count or publisher alone.

Get authorized full text for screened candidates. The sole `webfetch` exception
is a specific article or PDF URL from the helper or user; do not use it to
discover papers or follow links to new candidates. After checking access and
retention rights, optionally download a specific HTTPS PDF URL from either
source. From the repository root, run:

```bash
uv run --no-sync python \
  .github/skills/ve-constant-search/scripts/download_authorized_pdf.py \
  "PDF_URL" "OUTPUT.pdf" --doi "DOI"
```

Create the output directory first; keep PDFs outside
the repository unless copying is permitted. The helper rejects redirects, HTML
and non-PDF responses, preserves existing files, and writes `.pdf.json` with
source URL, DOI, UTC time, HTTP status, SHA-256 and download outcome. It neither
finds alternate URLs nor verifies scientific content. If full text is
inaccessible, log the gap; do not search elsewhere. Retain source URL and DOI,
inspect tables and methods, and keep stable provenance. Do not assume a local
OpenAlex full-text library exists or covers the constants. Check sharing rights
before copying restricted text into the repository. Neither cached PDFs nor
abstracts count as verified evidence.

## 3. Extract and verify

Distinguish unit conversion from reanalysis. Check whether the reported
measurement identifies the model parameter at the required scale, aggregation
and functional form. If extracting a parameter requires re-fitting, digitising,
pooling or other reanalysis of study data, record the paper as relevant but not
extractable under this workflow. Explain what reanalysis would be needed; do not
report a `value_found` or perform that reanalysis without the user's explicit
approval.

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
conversion. Name the gap: search coverage, inaccessible text, missing
measurement, unresolved units, functional-form mismatch or required reanalysis.
Relevant but non-extractable studies are gaps, not proof that research is
absent. Check existing empirical citations and analyses in this repo as leads.
Verify original full text before calling an existing estimate or new finding
`value_found`; never use a model default as evidence. Ask the user before
changing inclusion criteria, using proxies or making a consequential scientific
judgment.

For each unresolved constant, name the best paper or existing analysis, its DOI
or local path, what it measures, the blocker and the next human step (such as
obtaining full text, checking a cited dataset or fitting the model form). Rank
leads by relevance and feasibility, not citation count. Suggest guesses or
modelling analogies only as questions for human review; keep them out of
`value_found` and numeric CSV fields without user approval.

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
remaining gaps for human review. For `no_evidence`, put the strongest lead,
its blocker and the recommended next human step in `rationale`; keep candidate
IDs and screening detail in the search log. Existing first- and second-pass
reports describe historical results in the older soil CSV; they do not read the
new output. Do not silently rewrite their conclusions.

Stop once the chosen constants are assessed and any user-approved output is
checked. In the first user-facing response, lead with **Files touched**: list
each created or modified file and its purpose, or state "No files changed."
Then state **Actions taken**: constants checked, searches attempted, sources
screened and full texts verified. Distinguish completed actions from actions
blocked or awaiting approval.

If defensible values were found, summarise each constant's proposed value or
range, units, source, confidence and important limits. State that values remain
proposals pending user review.

If no defensible value was found, say so explicitly. For each unresolved
constant, identify the best lead and what worked, the blocker and what did not
work, and the next actionable step and who must take it. Flag approaches
unlikely to help or likely to be dead ends, with reasons; do not present an
untried approach as a demonstrated dead end. State when no useful next step is
known.

Report `value_found` and `no_evidence` counts, sources screened and remaining
coverage limits. Say whether the next action is with the user, the agent after
approval or access, or neither.
