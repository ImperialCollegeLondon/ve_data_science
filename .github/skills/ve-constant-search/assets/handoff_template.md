<!-- markdownlint-disable MD013 MD033 MD041 -->
# Issue card and batch PDF list

Two templates. Each is one GitHub comment, **edited in place** in later phases.
A human should take in either one in under a minute.

## Issue card

One per issue. Status is `searching`, `waiting for PDFs` or `handed off`. Keep
the visible part to the matrix, the reading set and (when handed off) the next
steps. Everything else goes in the collapsed agent record.

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
2. [Camenzind et al. (2021)](https://doi.org/10.1111/ele.13632): saprotrophic mycelia across N/P supply. **Waiting PDF.**

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

- Matrix cells use only `value`, `analysis`, `waiting PDF`, `gap`,
  `gap (no access)` or `n/a`. A `value` cell may add the converted value and
  units, e.g. `value: 3.9 g/g`.
- At most five reading-set sources. Link each title to its DOI or canonical URL.
- No run IDs, commits, query lists or drift notes in the visible part.
- Human replies after the card are inputs for the next phase.

## Batch PDF list

One per umbrella issue, replaced each batch. Lists only sources whose full text
the agent could not access, deduplicated across issues.

```markdown
<!-- ve-constant-search:pdf-list -->
## PDFs to fetch (batch updated YYYY-MM-DD)

Save into one private folder (keep the original names), then tell Copilot "PDFs ready in <folder>".

- [ ] [Camenzind et al. (2021)](https://doi.org/10.1111/ele.13632): #309
- [ ] [Author (year)](https://doi.org/...): #308, #309
```

Keep private paths, PDFs, extracts and credentials out of both templates.
