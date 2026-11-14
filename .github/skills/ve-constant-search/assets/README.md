# Skill assets

`ve_constant_usage.toml` is the generated, all-module VE configuration and
validated soil trait-input inventory used for model grounding. It is not
literature evidence. Refresh it
with `../scripts/refresh_constant_metadata.py` after checking the VE commit.

For the microbial pilot use `uv sync --locked --group dev-pinned`; the
installed source must match the reviewed clone. Schema version 2 includes
`SoilMicrobe` CSV inputs (22 fields) and `SoilEnzyme` inputs. Internal,
`InitVar` and computed dataclass fields are excluded. Each record distinguishes
`required` inputs from defaults. `example_values` are keyed by microbial group
or enzyme source/substrate, with `example_file` and `example_sha256` provenance.
They are neither class defaults nor empirical evidence. `model_unit` is the
unit spelling from the declaration docstring. `aliases` map old qualified
names for lookup, including the one-to-two enzyme-allocation split; they do
not authorise historical-row migration.

## Evidence templates

`soil_constant_literature_values.csv` is an empty template, not an evidence set.
Write new module results in the user-selected output directory (default
`data/derived/llm/`) as
`<module>_constant_literature_values.csv` (for example,
`soil_constant_literature_values.csv`). The existing
`data/derived/soil/llm/soil_constant_literature_values.csv` contains historical
results. Do not copy its rows into a new CSV without approval. Do not silently
rewrite the historical file. CSV headers may differ in order:
match columns by name, not position. Append or update only approved
results; leave other rows unchanged. The log template `constant_search_log.csv`
is also empty. Copy it beside the module results and keep one row per
search/candidate (or one row for an empty or failed search). Never rewrite a
historical search log.

For user-supplied PDFs, the agent creates a separate private `pdf_inventory.csv`;
it is not a required user input and must not be committed. Keep original
filenames, checksums and verified citation identities there. In the research
log, use `source=user_supplied_pdf`, record the intake date and screening
decision, and identify the supplied file using a non-sensitive filename or
checksum in `notes`. Leave unknown DOI and source URL fields empty; do not put
private absolute paths or extracted full text in committed CSVs. A successful
read is not itself verified evidence for a constant.

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
| `group`, `source_location` | Explicit trait group identifier and full-text page/table/equation location for new rows. Leave these blank on unchanged historical rows when extending an older CSV. |
| `retrieved_at`, `status`, `rationale` | UTC timestamp, `value_found` or `no_evidence`, and decision including remaining gaps. |
| `suggested_value`, `value_low`, `value_high`, `unit` | Numeric point estimate or defensible bounds, and model units. Leave unsupported values blank. |
| `original_value`, `original_unit`, `conversion_factor`, `conversion_notes` | Published measurement and reproducible conversion to model units. |
| `quote`, `citation_authors`, `citation_title`, `citation_journal`, `citation_year`, `doi` | Exact full-text evidence and citation; include page or table location in `rationale` or `conversion_notes`. |
| `source_type`, `measurement_conditions`, `confidence` | Study type, comparable experimental context, and supported confidence level. |

Every `value_found` needs verified source text and model-compatible units and
form. `no_evidence` means no defensible value within the documented search,
not that no study exists. Keep separate rows for materially different sources.

Required inputs have an empty `model_default`; never copy an example value into
that column. New evidence rows use `model_unit` spelling, and their matching
full-text log entry uses `full_text_status=verified` and
`search_status=success`. Preserve a matching DOI, or a source URL or
`sha256=<64 lowercase hex characters>` in the rationale and log for no-DOI
sources. Failed searches do not establish `no_evidence`.

Run `../scripts/validate_constant_results.py` with result/log paths and selected
qualified names after approval. Optional baseline files check preservation;
`--replace-approved` is only for explicit user-approved replacements. The
validator checks new or approved replacement rows, leaving baseline historical
rows unchanged even when their names or VE commits are obsolete. It checks
record integrity, not scientific correctness.
