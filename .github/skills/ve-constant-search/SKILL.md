---
name: ve-constant-search
description: Search Virtual Ecosystem (VE) configuration constants, follow up supplied PDFs and reconcile issue status. Use for parameter literature searches, PDF follow-ups or refreshing their issue cards and umbrella index.
---

# VE constant search

Purpose: lead a human to **a small, verified set of sources** for each selected
constant, then stop. Values are a by-product when a full text reports them
directly. Anything needing a scientific judgement, recalculation, digitising,
pooling or other analysis is **handed off**, not done here.

User setup (environment, OpenAlex key, private PDFs) is in
`docs/AI-assisted-parameterisation.md`. Treat every result as a proposal.

## The batch workflow

The user works in batches. Each phase covers every issue in the batch when
access permits and ends with **one short batch summary** in chat. Checkpoint
unfinished work and report blockers rather than claiming completion.

| Phase | User says | Agent does | Ends with |
| --- | --- | --- | --- |
| 1. Search | "Search #309 #308" (or qualified names) | Ground, search, screen, read open-access full text | Cards updated; one batch PDF list |
| 2. Fetch | (human only) | Nothing | PDFs saved in one private folder |
| 3. Follow up | "PDFs are ready in `<folder>`" | Match PDFs to issues, checkpoint receipt, then review | Cards handed off or explicitly pending; batch next steps |

A batch is small: about 2–5 issues. Do not expand scope beyond the named
issues or constants. If the user names a module or class, agree on a few
qualified names first.

### Durable state: one card per issue

Each issue has **one** skill card: a single comment written with
`assets/handoff_template.md` and **edited in place** in later phases
(`gh api -X PATCH repos/{owner}/{repo}/issues/comments/{id} -F body=@card.md`).
Find it by its `<!-- ve-constant-search:card -->` marker. Never post a second
status comment; GitHub keeps the edit history. Do not register runs, write
drift analyses or post progress comments.

Use this skill for current workflow mechanics when an older issue launch prompt
conflicts. Preserve issue-specific evidence criteria and human decisions.

The card's centre is a **status matrix**: one row per group (one row if the
constant is not group-specific), one column per constant. Each cell is one of:

| Cell | Meaning |
| --- | --- |
| `value` | Verified full text reports it directly; at most a unit conversion is needed |
| `analysis` | A relevant source exists, but a human must judge or analyse (state what) |
| `review pending` | A needed PDF was received and identified but not scientifically reviewed |
| `waiting PDF` | A needed source is not accessible; it is on the shared PDF list |
| `gap` | No eligible source within this search's budget |
| `gap (no access)` | The user chose to finish without an inaccessible source; not evidence of absence |
| `n/a` | Structurally zero or not applicable in VE source |

Use card status `searching` during discovery; otherwise use `review pending`
while any needed received source still needs review, `waiting for PDFs` when
only unavailable sources remain, and `handed off` only when neither remains.
Label each needed source in the reading set `review pending` or `waiting PDF`
as appropriate. If a cell has both, show `review pending` and retain the
missing source on the PDF list. Receipt is not verified evidence; recheck
private-file access when resuming a later session.

The shared PDF list is one comment on the umbrella issue the user names (for
soil microbes, #215), marked `<!-- ve-constant-search:pdf-list -->`. Derive it
from the cards' source-level `waiting PDF` labels, deduplicated with the
issues that still need each PDF. Show the current batch's requests in chat.

### Reconcile issue state

After each card change, update the affected issue/source pairs in the shared
PDF list and the corresponding rows of any maintained umbrella readiness
index. Preserve outstanding pairs from other batches, including other issues
needing the same paper. Edit identifiable workflow-owned current status
summaries in place; for an older conflicting workflow status comment, add a
supersession pointer to the current card only when its origin and edit
permission are clear. Preserve historical evidence, other people's comments
and human decisions. Report stale links that cannot safely be edited.

When agents run concurrently, only the coordinator edits shared cards, list
and index, serially. Re-read their live content and human replies before
editing; reconcile concurrent changes instead of overwriting them. Before
reporting a phase complete or blocked, re-read the affected cards, list and
index. Check source labels against actual receipt and review, issue/source
pairs against the list, and index counts against the matrices. Report any
failed update and its link rather than claiming the issues are refreshed.

## Phase 1: Search

For each issue in the batch:

1. **Read the issue** body, its existing card (if any) and human comments after
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
6. **Write or update the card.**

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
   `waiting PDF`, update affected cells and restore its issue/source pair to
   the list.
3. Before asking for manifest approval or reading the papers, checkpoint each
   matched, unreviewed source and its unresolved cells as `review pending` in
   the existing card, replacing its `waiting PDF` label. Preserve assessed
   results and human decisions. Keep missing sources `waiting PDF`, then
   reconcile the shared list and umbrella index. This checkpoint is not a
   scientific assessment or hand-off.
4. Compare matched PDFs by SHA-256 with `sources/manifest.csv`. If any are
   missing, ask once per batch whether to add them to this Git-tracked file.
   Identify the PDFs and explain that it records their original filenames
   (not paths), hashes, citation metadata and page counts. Only after explicit
   approval, append one row per new hash using the existing columns, leaving
   unknown metadata blank and preserving existing rows. If declined, leave the
   file unchanged and continue. Ask regardless of whether any value rows are
   proposed; manifest approval does not authorise saving results or end the
   follow-up. Report whether an update is uncommitted, committed locally or
   pushed, including the branch when pushed; verify before claiming either.
5. Read methods, tables and figures. Remove `review pending` from each
   assessed source, reclassify the affected cells and reconcile each card as
   its review finishes. Do not search again unless a full text names a clearly
   better primary source; then add at most that one source. If a matched PDF
   cannot be read sufficiently, mark its source `waiting PDF`, restore its
   issue/source pair to the list and report the need for a readable copy or
   OCR; do not treat the failure as an evidence gap.
6. If the user explicitly chooses to finish without an inaccessible source,
   remove that issue/source pair from the list. Use `gap (no access)` only for
   cells with no supported result or remaining source to review; preserve
   results supported by other sources. Keep other missing sources `waiting PDF`
   and unfinished reviews `review pending`. **Hand off** an issue only when
   every needed source has been reviewed or explicitly waived; fill its Next
   steps. Reconcile and verify issue state, then give the batch summary.

### Next steps (hand-off)

For each `analysis` cell, write one line: the human task and the source to use,
for example "Decide whether leaf-litter culture bacteria represent soil
bacteria; [Mouginot et al. (2014)](https://doi.org/10.1016/j.soilbio.2014.05.011)
reports 3.94 g C/g N." For a `gap`, give the best lead or say none is known.
Post-search analyses (re-fitting, digitising, pooling, proxy studies,
reanalysing datasets) are out of scope: describe them, do not start them.
Suggest a follow-up issue only if the user asks.

## Saving results (optional, end of Phase 3)

Only `value` cells can become result CSV rows. List the proposed rows in chat
as one numbered batch; the user replies, for example, "save 1, 3" or
"save none". Never write result rows without that reply. If approved:

- Append to `data/derived/llm/<module>_constant_literature_values.csv` and
  `data/derived/llm/<module>_constant_search_log.csv`, using
  `assets/README.md` as the field guide. Never alter existing rows.
- Run `scripts/validate_constant_results.py` with `--values`, `--log` and each
  `--qualified-name` (baseline options are described in that README).
- Open one PR for the batch against `constant-search-microbial-pilot` (or the
  branch the user names), listing the issues it covers.

Without result approval, do not write result rows or commit changes.

## Batch summary (chat)

Keep the hand-off summary to one screen:

```markdown
**Batch #309, #308: search done**

| Issue | value | analysis | review pending | waiting PDF | gap |
| --- | --- | --- | --- | --- | --- |
| #309 Microbial stoichiometry | 0 | 2 | 0 | 4 | 2 |

**PDFs to fetch (3).** Save them in one private folder, then say "PDFs ready".

1. [Camenzind et al. (2021)](https://doi.org/10.1111/ele.13632): #309
2. ...
```

In Phase 3, report **Next steps** per issue, remaining PDF requests, and, if
any, the numbered rows proposed for saving. Link every source title to its DOI
or canonical URL. Leave run details, commits, queries and process narration
in the card's collapsed agent record.

## Rules

- Ask the user only when access is blocked, when VE units or functional form
  are ambiguous, before widening the search budget, or for the approvals
  described above. Scientific judgements (proxies, habitat transfer, a unit
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
- Private PDFs, extracted text, private paths and credentials never enter Git,
  issues or PRs. Quote briefly, and only where retention rights allow.
- Do not edit this skill, its prompt or the VE usage inventory during a batch;
  list proposed improvements in the batch summary instead.

## Tools

### Grounding

Verify a sibling `virtual_ecosystem` checkout (or a clone passed with
`--ve-root`) at the reviewed commit with clean Python source. For the microbial
pilot, run `uv sync --locked --group dev-pinned`, then use `uv run --no-sync`.
If the checkout is missing or does not match, stop and ask.

Search `assets/ve_constant_usage.toml` for each exact `qualified_name`; do not
read the whole file. If its `project_commit` differs from VE HEAD, dry-run
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
runs keyless, from the environment or a `.env` beside this file. Record the
mode it prints, never the credential.

### Open-access PDFs

`webfetch` may open only a specific article or PDF URL returned by the helper.
Download open-access PDFs into a private folder outside Git:

```bash
uv run --no-sync python \
  .github/skills/ve-constant-search/scripts/download_authorized_pdf.py \
  "PDF_URL" "OUTPUT.pdf" --doi "DOI"
```

If a PDF cannot be fetched or read, its source goes on the batch PDF list.
