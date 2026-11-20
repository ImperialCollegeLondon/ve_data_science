---
name: ve-constant-search
description: Search a Virtual Ecosystem (VE) constant, track its literature in an issue, and follow up supplied PDFs with actionable next steps.
---

# VE constant search

Purpose: lead a human to **a small, verified set of sources** for each selected
constant, then stop. Values are a by-product when a full text reports them
directly. Anything needing a scientific judgement, recalculation, digitising,
pooling or other analysis is **handed off**, not done here.

User setup (environment, OpenAlex key, private PDFs) is in
`docs/AI-assisted-parameterisation.md`. Treat every result as a proposal.

## Start or resume

The entry point can be "Use ve-constant-search to search for `<constant>`".
For each requested constant, search repository issues, including closed issues,
for its name, qualified name and known aliases. Inspect plausible matches and
their comments. Reuse an existing issue when its scope clearly matches; ask the
user when a match is ambiguous or closed. Otherwise create an issue titled
`Search VE constant: <constant>`. If issue search or creation fails, report the
blocker rather than silently proceeding without durable state.

Create or identify the issue **before** full grounding and literature search.
Record the requested constant and scope in its `searching` card; preserve an
existing issue body and card. Include the issue link in chat. If needed, look
up the name in the inventory to disambiguate it before issue creation. If it
maps to multiple VE constants, ask which one the user means.
Do not create a separate issue for an explicitly selected existing issue.

Use `gh` from the repository root. Search broadly enough to catch qualified
names and aliases, then inspect each plausible result:

```bash
gh issue list --state all --search 'CONSTANT in:title,body' \
  --limit 30 --json number,title,state,url,body
gh issue view ISSUE --comments
```

When no issue matches, create one. Put the requested constant and qualified
name in `issue.md`; do not overwrite an existing issue body:

```bash
gh issue create --title 'Search VE constant: CONSTANT' --body-file issue.md
```

If the selected issue has no marked card, create one from
`assets/handoff_template.md` immediately. Put only the card in `card.md`, with
status `searching` and no invented matrix outcomes:

```bash
gh api repos/{owner}/{repo}/issues/ISSUE/comments -F body=@card.md
gh api --paginate repos/{owner}/{repo}/issues/ISSUE/comments \
  --jq '.[] | select(.body | contains("<!-- ve-constant-search:card -->")) |
    [.id, .html_url] | @tsv'
```

**Hard gate:** do not start grounding or literature discovery until both the
issue URL and exactly one card comment ID are known. If issue access, creation
or card creation fails, stop and report that blocker. Never replace durable
issue state with a chat-only report.

A later chat can say "Use ve-constant-search to follow up #123; PDFs are ready".
Read the live issue, card and human replies; use
`.github/skills/ve-constant-search/sources/` as the default local PDF folder.
The issue must be sufficient to resume without the original chat. Do not
assume local PDFs are available in a new environment.

The user may request a small batch. Each phase covers every selected issue
when access permits and ends with **one short batch summary** in chat.
Checkpoint unfinished work and report blockers rather than claiming completion.

| Phase | User says | Agent does | Ends with |
| --- | --- | --- | --- |
| 1. Search | "Search `<constant>`" or "Search #309 #308" | Find or create issues, ground, search, screen, read accessible full text | Cards contain linked PDF requests and resume instructions |
| 2. Fetch | (human only) | Nothing | PDFs saved in the ignored local `sources/` folder |
| 3. Follow up | "Follow up #123; PDFs are ready" | Match PDFs to issues, checkpoint receipt, then review | Cards handed off or explicitly pending; issue next steps |

Do not expand scope beyond the named issues or constants. If the user names a
module or class, agree on a few qualified names first.

### Durable state: one card per issue

Each issue has **one** skill card: a single comment written with
`assets/handoff_template.md` and **edited in place** in later phases
(`gh api -X PATCH repos/{owner}/{repo}/issues/comments/{id} -F body=@card.md`).
Find it by its `<!-- ve-constant-search:card -->` marker. Never post a second
status comment; GitHub keeps the edit history. Do not register runs, write
drift analyses or post progress comments.

After creating or editing a card, fetch that comment again and verify its
marker, status, matrix and PDF requests before continuing:

```bash
gh api repos/{owner}/{repo}/issues/comments/CARD_COMMENT_ID
```

Use this skill for current workflow mechanics when an older issue launch prompt
conflicts. Preserve issue-specific evidence criteria and human decisions.

The card's centre is a **status matrix**: one row per group (one row if the
constant is not group-specific), one column per constant. Each cell is one of:

| Cell | Meaning |
| --- | --- |
| `value` | Verified full text reports it directly; at most a unit conversion is needed |
| `analysis` | A relevant source exists, but a human must judge or analyse (state what) |
| `review pending` | A needed PDF was received and identified but not scientifically reviewed |
| `waiting PDF` | A needed source is not accessible; it is on the card's PDF list |
| `gap` | No eligible source within this search's budget |
| `gap (no access)` | The user chose to finish without an inaccessible source; not evidence of absence |
| `n/a` | Structurally zero or not applicable in VE source |

Use card status `searching` during discovery; otherwise use `review pending`
while any needed received source still needs review, `waiting for PDFs` when
only unavailable sources remain, and `handed off` only when neither remains.
Label each needed source in the reading set `review pending` or `waiting PDF`
as appropriate. If a cell has both, show `review pending` and retain the
missing source on the card's PDF list. Receipt is not verified evidence; recheck
private-file access when resuming a later session.

Each card lists its own requested PDFs with citation links, the default local
folder and a copyable new-chat prompt containing the issue number. If the user
names an umbrella issue, also maintain its shared PDF list, marked
`<!-- ve-constant-search:pdf-list -->`. Derive it from the cards' source-level
`waiting PDF` labels, deduplicated with the issues that still need each PDF.
Show the current batch's requests in chat.

### Reconcile issue state

After each card change, update the affected issue/source pairs in any maintained
shared PDF list and the corresponding rows of any maintained umbrella readiness
index. Preserve outstanding pairs from other batches, including other issues
needing the same paper. Edit identifiable workflow-owned current status
summaries in place; for an older conflicting workflow status comment, add a
supersession pointer to the current card only when its origin and edit
permission are clear. Preserve historical evidence, other people's comments
and human decisions. Report stale links that cannot safely be edited.

When agents run concurrently, only the coordinator edits shared cards and any
maintained list and index, serially. Re-read their live content and human
replies before editing; reconcile concurrent changes instead of overwriting
them. Before reporting a phase complete or blocked, re-read the affected cards
and any maintained list and index. Check source labels against actual receipt
and review, issue/source pairs against any list, and index counts against
matrices. Report any failed update and its link rather than claiming the issues
are refreshed.

## Phase 1: Search

For each issue in the batch:

1. **Read the issue** body, its existing card and human comments after
   the card. Take seeds, exclusions and group definitions from there; human
   replies after the card override it.
2. **Ground** each qualified name (`module.Class.attribute`) in VE source; see
   [Grounding](#grounding). Exclude identifiers such as `name` or `source`.
3. **Search** with the [OpenAlex helper](#openalex-helper). Screen abstracts
   for the exact measured quantity, organism or group, units, conditions and
   model form. Abstracts only nominate candidates.
4. **Read open-access full text** ([download](#open-access-pdfs)) and
   classify each matrix cell.
5. **Choose the reading set**: at most **five** sources per issue, ranked by
   relevance and feasibility, not citation count. Label a needed source
   without accessible full text `waiting PDF` and classify its cells as above.
6. **Write or update the card.** If no sources are pending, hand off now and
   fill its Next steps; otherwise list each requested PDF and the resume prompt.

Budget per issue: 3–6 distinct queries and at most one snowball round
(`--limit 6`) on the best seed. Stop early when the reading set is clear. Ask
before widening the budget.

Then reconcile issue state and give the batch summary.

## Phase 3: Follow up

1. Find the named issues from their cards or the umbrella's PDF list and
   readiness index. If an umbrella is named, inspect its linked family cards
   for `waiting PDF` and `review pending` even if the index or list is stale.
   Follow up the user-selected scope or supplied sources, without starting
   unrelated searches. Re-read each card and any human replies after it.
2. Check that the folder or uploads are readable in this session. Identify each
   PDF from its title page or front matter, never from a DOI in its reference
   list, and match it to the relevant cards. Leave files unrenamed, unchanged
   and outside Git. Report unmatched or unreadable files; do not guess. If a
   previously received, unreviewed PDF is no longer readable, mark its source
   `waiting PDF`, update affected cells and restore the request on the card
   and any maintained shared list.
3. Reconcile matched PDFs with `sources/manifest.csv`. Keep one row per SHA-256
   using the existing columns. Append missing hashes with the original filename,
   title-page citation metadata and page count; preserve every existing row.
   This manifest is tracked, but the PDFs and downloader sidecars remain
   ignored. Do not record private paths or extracted text. Report duplicate
   hashes or metadata conflicts instead of guessing.
4. Before reading the papers, checkpoint each matched, unreviewed source and
   its unresolved cells as `review pending` in
   the existing card, replacing its `waiting PDF` label. Preserve assessed
   results and human decisions. Keep missing sources `waiting PDF`, then
   reconcile any maintained shared list and umbrella index. This checkpoint is
   not a scientific assessment or hand-off.
5. Read methods, tables and figures. Remove `review pending` from each
   assessed source, reclassify the affected cells and reconcile each card as
   its review finishes. Do not search again unless a full text names a clearly
   better primary source; then add at most that one source. If a matched PDF
   cannot be read sufficiently, mark its source `waiting PDF`, restore its
   request on the card and any shared list, and report the need for a readable
   copy or OCR; do not treat the failure as an evidence gap.
6. If the user explicitly chooses to finish without an inaccessible source,
   remove its request from the card and any shared list. Use `gap (no access)`
   only for cells with no supported result or remaining source to review;
   preserve results supported by other sources. Keep other missing sources
   `waiting PDF` and unfinished reviews `review pending`. **Hand off** an issue
   only when every needed source has been reviewed or explicitly waived; fill
   its Next steps. Reconcile and verify issue state, then give the batch
   summary.

### Next steps (hand-off)

For each `analysis` cell, write one line: the human task and the source to use,
for example "Decide whether leaf-litter culture bacteria represent soil
bacteria;
[Mouginot et al. (2014)](https://doi.org/10.1016/j.soilbio.2014.05.011) reports
3.94 g C/g N." For a `gap`, give the best lead or say none is known. Post-search
analyses (re-fitting, digitising, pooling, proxy studies, reanalysing datasets)
are out of scope: describe them, do not start them. Suggest a follow-up issue
only if the user asks.

The skill ends with the issue hand-off. Do not write result CSVs, create a PR
or perform downstream analysis as part of this workflow. These are separate
tasks if explicitly requested. Maintaining `sources/manifest.csv` for matched
PDFs is part of Phase 3, not a result-saving task.

## Batch summary (chat)

Keep the hand-off summary to one screen:

```markdown
**Batch #309, #308: search done**

| Issue | value | analysis | review pending | waiting PDF | gap |
| --- | --- | --- | --- | --- | --- |
| #309 Microbial stoichiometry | 0 | 2 | 0 | 4 | 2 |

**PDFs to fetch (3).** Save them in the ignored local `sources/` folder.

1. [Camenzind et al. (2021)](https://doi.org/10.1111/ele.13632) ·
   [Open-access PDF](PDF_URL): #309
2. ...
```

Link each issue and give a copyable follow-up prompt with its issue number.
In Phase 3, report **Next steps** per issue and remaining PDF requests. Link
every source title to its DOI or canonical article URL. When OpenAlex supplies
a distinct `pdf_url`, also label and link it as `Open-access PDF`; never present
an article page as a direct download. Leave run details, commits, queries and
process narration in the card's collapsed agent record.

Before sending the summary, verify all of these. A missing item means the phase
is blocked, not done:

- each issue number links to its live issue;
- each live card was reread after its final update;
- status is `waiting for PDFs`, `review pending` or `handed off`;
- every unavailable needed source is `waiting PDF` and appears under **PDFs to
  fetch** with an article link and, when known, a direct PDF link;
- the ignored `sources/` save location and a copyable follow-up prompt
  containing the issue number appear in both the card and chat; and
- no failed search or retrieval is reported as `gap`, `no_evidence` or
  completion.

## Rules

- Ask the user when duplicate issue selection, constant identity, access, VE
  units or functional form is ambiguous, or before widening the search budget.
  Scientific judgements (proxies, habitat transfer, a unit
  basis inferred from data, pooling, temperature normalisation, inclusion
  criteria) become `analysis` cells; do not ask about them mid-batch.
- Evidence is verified full text only: cite the exact sentence or table and
  its page, original value and units, and the conversion to model units.
  Abstracts, model defaults, example inputs and VE docs are never evidence.
- Keep groups separate; never fill one group from another or from pooled
  measurements. `SoilMicrobe`: bacteria, saprotrophic fungi, arbuscular
  mycorrhiza, ectomycorrhiza. `SoilEnzyme`: each bacterial/fungal and POM/MAOM
  combination. Fruiting bodies are not vegetative biomass. Maintenance biomass
  loss is not growth turnover or maintenance respiration.
- A search or access failure is blocked work, not evidence of absence. Use
  `gap (no access)` only when the user explicitly closes the affected scope.
- Private PDFs, extracted text, private absolute paths and credentials never
  enter Git, issues or PRs. Quote briefly, and only where retention rights
  allow.
- Do not edit this skill or its prompt during a search; list proposed
  improvements in the batch summary instead. Refresh the generated inventory
  when needed as described below.

## Tools

### Grounding

Use a sibling `virtual_ecosystem` checkout (or a clone passed with `--ve-root`)
at the reviewed commit with clean Python source. If missing, clone the official
`ImperialCollegeLondon/virtual_ecosystem` repository into the sibling location
and check out the applicable reviewed commit. For the microbial pilot, derive
that commit from the `dev-pinned` source in `pyproject.toml`; do not assume a
floating branch is equivalent. If an existing checkout is dirty or mismatched,
stop and ask; never overwrite or switch it automatically. Check that the
installed VE source matches the checkout. For the microbial pilot, prepare
missing or mismatched dependencies with `uv sync --locked --group dev-pinned`,
then use `uv run --no-sync`. Report setup failures.

Read `assets/README.md` and `assets/handoff_template.md` for grounding and
handoff conventions. Search `assets/ve_constant_usage.toml` for each exact
`qualified_name`; do not read the whole file. If its `project_commit` differs
from VE HEAD, dry-run
`scripts/refresh_constant_metadata.py`, review the changes, then rerun with
`--apply`. Read narrow line ranges around the declaration and reference sites;
when references are empty, follow the field into its runtime consumer. A
`required = true` record has no default, and its `example_values` are context
only. Establish units and functional form from source. Optional VE-docs
context: `Rscript .github/skills/ve-constant-search/scripts/search_ve_docs.R
"QUERY"`.

### OpenAlex helper

```bash
uv run --no-sync python \
  .github/skills/ve-constant-search/scripts/openalex_search.py search "QUERY"
uv run --no-sync python \
  .github/skills/ve-constant-search/scripts/openalex_search.py \
  snowball --doi "DOI" --limit 6
```

Use only this helper for discovery and citation lookup: no OpenAlex MCP tools,
web search or `webfetch` discovery. `search "DOI"` is fuzzy, so compare the
returned DOIs. The helper reads `OPENALEX_API_KEY`, else `OPENALEX_EMAIL`, else
runs keyless, from the environment or a `.env` beside this file. This workflow
requires `api_key` mode: verify the printed mode on every helper invocation,
and stop and ask the user to configure `OPENALEX_API_KEY` if it is missing or
authentication fails. Do not use email or keyless results as a fallback. Record
the mode, never the credential.

### Open-access PDFs

`webfetch` may open only a specific article or PDF URL returned by the helper.
Download permitted open-access PDFs into the Git-ignored
`.github/skills/ve-constant-search/sources/` folder by default, or another
private folder supplied by the user. The helper writes a provenance sidecar
beside the PDF; both are ignored in the default folder:

```bash
uv run --no-sync python \
  .github/skills/ve-constant-search/scripts/download_authorized_pdf.py \
  "PDF_URL" "OUTPUT.pdf" --doi "DOI"
```

If a PDF cannot be fetched or read, its source goes on the issue card's PDF
list.
