<!-- markdownlint-disable MD013 MD033 MD041 -->
# Issue card and batch PDF list

The issue card is one GitHub comment, **edited in place** in later phases.
The optional umbrella list is a separate comment. Keep both easy to skim.

## Issue card

One per issue. Status is `searching`, `review pending`, `waiting for PDFs` or
`handed off`. Keep the visible part to the matrix, the reading set, PDF requests
and (when handed off) the next steps. Everything else goes in the collapsed agent record.

```markdown
<!-- ve-constant-search:card -->
## Constant search — status: waiting for PDFs

| Group | `c_n_ratio` | `c_p_ratio` |
| --- | --- | --- |
| bacteria | analysis | analysis |
| saprotrophic_fungi | waiting PDF | waiting PDF |
| arbuscular_mycorrhiza | gap | gap |
| ectomycorrhiza | gap | gap |

### Reading set

1. [Mouginot et al. (2014)](https://doi.org/10.1016/j.soilbio.2014.05.011): bacterial and fungal culture C:N:P (Table 1); leaf-litter isolates.
2. [Camenzind et al. (2021)](https://doi.org/10.1111/ele.13632) ([Open-access PDF](PDF_URL)): saprotrophic mycelia across N/P supply. **Waiting PDF.**

### PDFs to fetch

- [ ] [Camenzind et al. (2021)](https://doi.org/10.1111/ele.13632) · [Open-access PDF](PDF_URL)

Save PDFs locally in `.github/skills/ve-constant-search/sources/`. In a new
chat, say: "Use ve-constant-search to follow up #123; PDFs are ready."

### Next steps

_Filled when handed off: one line per `analysis` cell (human task + source), best lead per `gap`._

<details>
<summary>Agent record</summary>

- Scope: qualified names, groups, VE commit, last updated (UTC date)
- Queries (exact), OpenAlex access mode, candidates screened/excluded
- Per source: what was read, location, original value and units, conversion
- Per `analysis` cell: why it is not a `value`
- Proposed skill improvements, if any

</details>
```

Rules:

- When first created, a `searching` card may show the requested scope without
  a matrix; do not mark unsearched cells as gaps.
- Matrix cells use only `value`, `analysis`, `review pending`, `waiting PDF`,
  `gap`, `gap (no access)` or `n/a`. A `value` cell may add the converted
  value and units, e.g. `value: 3.9 g/g`. Receipt alone is `review pending`,
  not verified evidence; a later session must recheck private-file access.
- At most five reading-set sources. Link each title to its DOI or canonical URL.
- If OpenAlex supplies a distinct `pdf_url`, add a separately labelled
  `Open-access PDF` link. Do not label an article page as a PDF.
- Label needed sources `review pending` or `waiting PDF`. If a cell has both,
  show `review pending`; the PDF list still includes its missing sources.
- No run IDs, commits, query lists or drift notes in the visible part.
- Human replies after the card are inputs for the next phase.

## Batch PDF list

One per umbrella issue, edited in place. List only needed sources whose full
text is unavailable, deduplicated across issues; preserve outstanding
issue/source pairs from other batches.

```markdown
<!-- ve-constant-search:pdf-list -->
## PDFs to fetch (batch updated YYYY-MM-DD)

Save locally in `.github/skills/ve-constant-search/sources/`, keeping original names. Follow up in a new chat with the relevant issue number.

- [ ] [Camenzind et al. (2021)](https://doi.org/10.1111/ele.13632) · [Open-access PDF](PDF_URL): #309
- [ ] [Author (year)](https://doi.org/...): #308, #309
```

Keep private absolute paths, PDFs, extracts and credentials out of both templates.
