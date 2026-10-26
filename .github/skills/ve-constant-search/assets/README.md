# Skill assets

`ve_constant_usage.toml` is the generated, all-module VE configuration
inventory used for model grounding. It is not literature evidence. Refresh it
with `../scripts/refresh_constant_metadata.py` after checking the VE commit.

## Evidence templates

`soil_constant_literature_values.csv` is an empty template, not an evidence set.
Write module results under `data/derived/llm/` as
`<module>_constant_literature_values.csv` (for example,
`soil_constant_literature_values.csv`). Existing CSV headers may differ in
order: match columns by name, not position. Append or update only approved
results; leave other rows unchanged. The log template `constant_search_log.csv`
is also empty. Copy it beside the module results and keep one row per
search/candidate (or one row for an empty or failed search). Never rewrite a
historical search log.

## Search log fields

| Fields | Meaning |
| --- | --- |
| `qualified_name`, `ve_commit` | Selected configuration attribute and local VE commit. |
| `search_date`, `source`, `query` | UTC date, search service, and exact query or citation seed. |
| `search_status`, `result_count`, `screened_count` | `success` or `failed`; counts only for successful requests. Zero is valid only for a successful request. |
| `candidate_id`, `doi`, `title` | OpenAlex ID, DOI when available, and candidate title. Blank for zero-result or failed searches. |
| `screening_decision`, `exclusion_reason` | Retain, exclude, or pending; give a reason for exclusions. |
| `full_text_status`, `source_url`, `notes` | Access and verification state, original URL, and coverage limits. A download is not full-text verification. |

## Values CSV fields

| Fields | Meaning |
| --- | --- |
| `qualified_name`, `name`, `model_default`, `ve_commit` | From the selected TOML record and VE metadata; default is model context, not evidence. |
| `retrieved_at`, `status`, `rationale` | UTC timestamp, `value_found` or `no_evidence`, and decision including remaining gaps. |
| `suggested_value`, `value_low`, `value_high`, `unit` | Numeric point estimate or defensible bounds, and model units. Leave unsupported values blank. |
| `original_value`, `original_unit`, `conversion_factor`, `conversion_notes` | Published measurement and reproducible conversion to model units. |
| `quote`, `citation_authors`, `citation_title`, `citation_journal`, `citation_year`, `doi` | Exact full-text evidence and citation; include page or table location in `rationale` or `conversion_notes`. |
| `source_type`, `measurement_conditions`, `confidence` | Study type, comparable experimental context, and supported confidence level. |

Every `value_found` needs verified source text and model-compatible units and
form. `no_evidence` means no defensible value within the documented search,
not that no study exists. Keep separate rows for materially different sources.
