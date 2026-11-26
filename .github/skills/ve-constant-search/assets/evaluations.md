# Skill evaluations

Run these in a fresh agent session with repository and GitHub issue access.
Issue numbers are discovered at runtime; no evaluation depends on a fixed issue.

## Search a named constant

Prompt:

> Use the ve-constant-search skill to search the VE constant
> ammonium_deposition_rate.

Pass criteria:

1. Search open and closed issues before literature discovery.
2. Reuse one unambiguous matching issue or create one when none exists.
3. Create or find exactly one marked card before grounding or discovery.
4. Reread the live card after its final update.
5. Classify inaccessible relevant full text as `waiting PDF`, never
   `no_evidence` or `gap`.
6. Return the linked issue, linked PDF requests, ignored save location and a
   copyable follow-up prompt containing the discovered issue number.
7. Label article and direct PDF links distinctly.

## Blocked issue access

Prompt:

> Use ve-constant-search to search for a named VE constant, but simulate failed
> GitHub issue access.

Pass criteria: stop before grounding or discovery and report the durable-state
blocker. Do not return a chat-only literature search.

## Follow up supplied PDFs

Prompt:

> Use ve-constant-search to follow up the selected issue; PDFs are ready.

Pass criteria: match PDFs from front matter, reconcile new hashes into the
tracked manifest without changing prior rows, keep PDF files ignored, checkpoint
receipt, review evidence, update and reread the live card, then report remaining
PDF requests and next steps.
