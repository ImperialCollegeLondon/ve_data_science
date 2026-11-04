# Soil constant search (second pass review)

Hao Ran Lai

> [!NOTE]
>
> This report follows
> [`analysis/soil/llm/reports/scoping_report.md`](analysis/soil/llm/reports/scoping_report.md)
> and
> [`analysis/soil/llm/reports/soil_search_first_pass.qmd`](analysis/soil/llm/reports/soil_search_first_pass.qmd).
> It focuses on the second pass described in
> [\#629](https://github.com/ImperialCollegeLondon/ve_data_science/issues/629).
> I recommend a quick read of the GitHub Issue before continuing here.

## What changed

The workflow now replaces online search with a local full-text library:

- `analysis/soil/llm/paper_library.R` searches the OpenAlex library for
  soil, litter or microbial literature and retrieves a list of results
  with DOIs
- `analysis/soil/llm/download_full_text.R` downloads generic full text
  from the DOIs and converts it to Markdown with metadata.
- `analysis/soil/llm/rag_literature.R` builds the RAG literature store
  from those Markdown files.
- `analysis/soil/llm/chat.R` keeps the Virtual Ecosystem docs store for
  model context, and additionally uses the soil literature store for
  empirical evidence.

## How to read the first-pass result now

The first-pass conclusion still stands: many soil constants are hard to
obtain directly from the literature, especially when the VE parameter
does not match the measured quantity in a paper.

What changes is the interpretation of failure. With local full-text
retrieval and explicit provenance, a `no_evidence` result is less likely
to mean “the model never searched enough text” and more likely to mean
one of the following:

1. the OpenAlex library does not contain enough useful papers;
2. the OpenAlex library contains useful papers, but many are hard to
   download programmatically (due to paywall, bot and crawler gating
   etc.)
3. the paper does not report the needed quantity in usable form;
4. the value would require reanalysis rather than direct extraction

Point 2 was the most painful process. Half of the papers are paywalled;
Wiley, Elsevier and Nature publishing have their separate APIs for text
mining, but they require more time to implement (this is worth still
exploring next time). For the “open access” papers, many still suffer
from stale links, slow server responses etc., such that the returned
PDFs are not consistently the kind of full text that I looked for.

## Specific points for issue \#629

Building our own paper library is possible, but time consuming. I
decided to call it a checkpoint to stop this from becoming a serious
time sink. This feels like a separate, huge project on its own now.

## Summary of the written output

The second-pass script writes
[`data/derived/soil/llm/soil_constant_literature_values.csv`](data/derived/soil/llm/soil_constant_literature_values.csv).
As discussed above, even with a downloaded paper library there is still
ZERO constant with found value:

    library(dplyr)

    Warning: package 'dplyr' was built under R version 4.6.1

    Attaching package: 'dplyr'

    The following objects are masked from 'package:stats':

        filter, lag

    The following objects are masked from 'package:base':

        intersect, setdiff, setequal, union

    library(knitr)
    library(readr)

    Warning: package 'readr' was built under R version 4.6.1

    library(here)

    here() starts at C:/Users/User/Documents/ve_data_science

    constant_values_table <- read_csv(
      here::here("data/derived/soil/llm/soil_constant_literature_values.csv"),
      show_col_types = FALSE
    )

    summary_table <- tibble(
      Metric = c(
        "Unique constants",
        "Total rows",
        "Rows with status == \"value_found\"",
        "Rows with status == \"no_evidence\"",
        "Other statuses"
      ),
      Value = c(
        n_distinct(constant_values_table$qualified_name),
        nrow(constant_values_table),
        sum(constant_values_table$status == "value_found", na.rm = TRUE),
        sum(constant_values_table$status == "no_evidence", na.rm = TRUE),
        sum(
          !constant_values_table$status %in% c("value_found", "no_evidence"),
          na.rm = TRUE
        )
      )
    )

    status_table <- constant_values_table |>
      count(status, sort = TRUE) |>
      mutate(status = paste0("`", status, "`")) |>
      rename(Status = status, Rows = n)

    value_found_table <- tibble(
      Measure = c(
        "Unique constants with values",
        "Value-found rows",
        "Rows with DOI",
        "Rows with quote"
      ),
      Value = c(
        constant_values_table |>
          filter(status == "value_found") |>
          pull(qualified_name) |>
          n_distinct(),
        sum(constant_values_table$status == "value_found", na.rm = TRUE),
        sum(
          constant_values_table$status == "value_found" &
            !is.na(constant_values_table$doi) &
            constant_values_table$doi != "",
          na.rm = TRUE
        ),
        sum(
          constant_values_table$status == "value_found" &
            !is.na(constant_values_table$quote) &
            constant_values_table$quote != "",
          na.rm = TRUE
        )
      )
    )

    kable(summary_table, format = "pipe")

| Metric                            | Value |
|:----------------------------------|------:|
| Unique constants                  |    81 |
| Total rows                        |   151 |
| Rows with status == “value_found” |     0 |
| Rows with status == “no_evidence” |   151 |
| Other statuses                    |     0 |

    kable(status_table, format = "pipe")

| Status        | Rows |
|:--------------|-----:|
| `no_evidence` |  151 |

    kable(value_found_table, format = "pipe")

| Measure                      | Value |
|:-----------------------------|------:|
| Unique constants with values |     0 |
| Value-found rows             |     0 |
| Rows with DOI                |     0 |
| Rows with quote              |     0 |

There is definitely constants values out there; it’s just that we need
to do a much better job to address the challenges listed
[above](#how-to-read-the-first-pass-result-now).

## Practical implication

- LLM may be more useful for **identifying** candidate papers. It is
  less useful as a fully automatic path from heterogeneous papers to a
  complete VE-ready table.
- This suggest that a second human-reviewer pass is necessary.
- Even if this is not a fully automated pipeline, having an AI that can
  suggest candidate papers reliably is already a huge gain.
- If we switch direction, then we may not need to build our own AI to
  search the literature. That said, there is still value in a custom AI
  because we can feed in VE context.
- If we still opt to build our own literature library as a curated
  source of truth, then this should be treated as a standalone, big line
  of tasks.

## Suggested next steps

- Discuss if we should switch the goal from full automation to only
  identifying papers.
