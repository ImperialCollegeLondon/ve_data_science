# Reusable prompt: VE constant literature search

Use the `ve-constant-search` skill for the complete workflow and evidence
rules. The following prompts are starting points, not approval of scientific
results or changes to inclusion criteria.

## Search a batch

Replace the example issues with the issues or qualified names you want searched:

```text
Use the ve-constant-search skill to search #309 and #308. Ground and screen
each issue, update its card, and collect any PDFs I need to fetch in one list.
Give me one short batch summary.
```

For the microbial pilot, begin from the latest
`constant-search-microbial-pilot` and use the reviewed `dev-pinned` VE revision.
The skill explains the search budget, grounding, evidence gates and hand-off.
Keep issue-specific seeds, exclusions and human decisions; do not treat an
example value or abstract as empirical evidence.

## Follow up on PDFs

```text
Use the ve-constant-search skill to follow up the waiting issues in the batch.
The PDFs are available in my uploaded files or the private folder I provide.
Update the cards and give me one short summary of the next steps.
```

The folder must be readable by the agent's session. Match files by their front
matter, keep them private and unchanged, and report unmatched or unreadable
files. A scientific judgement or post-search analysis is a hand-off, not
permission to perform that work or save a value.

## Concurrent work and saving approved results

The user may ask independent agents to work concurrently. Assign each an
explicit, non-overlapping issue scope unless the user requests a comparison.
Each agent returns its findings to a coordinator; only the coordinator edits
the shared issue cards and batch PDF list, serially, after rereading the latest
versions and human replies. Do not overwrite another agent's results or a
human decision. Search agents do not edit the skill, prompt or inventory.

Saving results is optional and requires the user's approval of the exact rows.
Use one PR for an approved batch, not one per search. Before preparing or
integrating a microbial pilot PR, fetch the current pilot, review relevant
decisions and reconcile with its latest results and search log. Preserve all
baseline rows and the exact log prefix; never resolve conflicts by choosing one
entire file. Require separate approval for schema changes or replacements.
Validate against private copies of the latest pilot baseline using the
validator and selected qualified names in the skill's asset guide.

A human integration owner admits only one shared-file PR at a time; a merge
queue or passing CI is not scientific approval. Recheck the pilot before
merging and repeat reconciliation and validation if it moved. Pause affected
work if the scientific criteria, VE pin or approved decisions change. Target
`constant-search-microbial-pilot`, never `main`, and verify the PR base.
Do not open an empty PR when no approved output exists.

## Skill and prompt edits

Workflow improvements are separate from research runs. For an edit job, fetch
the latest pilot and `main`, start from the pilot, and merge `origin/main` before
branching. Resolve conflicts with the user. Open the workflow PR against
`constant-search-microbial-pilot` and verify its base.

Earlier launch prompts and concurrency decisions remain historical records in
the issues and Git history. Do not treat this draft workflow as integrated
until its pilot PR is approved and merged.
