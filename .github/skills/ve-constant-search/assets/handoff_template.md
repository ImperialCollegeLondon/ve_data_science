<!-- markdownlint-disable MD013 MD033 MD041 -->
# Issue comment and PR description layout

Use this layout for every run registration, status update, issue handoff and PR
description. It has two layers in one post:

- **Human brief** (visible): only what a reviewer must read or decide. A human
  should finish it in under a minute.
- **Agent record** (collapsed): the complete run state a later agent needs to
  resume without rereading the session. Nothing is dropped; it is folded.

Write the agent record first, then distil the brief from it. Brief items point
to record entries by decision ID (`D1`, `D2`, ...) instead of restating them.
When reading an issue to resume work, read the latest agent record first, then
the human replies after it; a reply such as "approve D1" refers to that record.

## Human brief rules

- Open with `## Needed from the user`. One numbered item per decision or file,
  each tagged with its decision ID, owner and a concrete choice (for example
  "Reply `approve D1`, `reject D1` or give an alternative"). Name the exact
  files or decision, affected scope and a session-accessible delivery method.
  Write `None` when no user action is pending.
- Follow with `## Outcome`: at most five bullets in plain language. Lead with
  `value_found` / `no_evidence` counts and the headline finding with units and
  a linked source. Mention blockers only if they change what the reader does.
- Then a one-line `**Status:**` (`running`, `awaiting decision`, `blocked`,
  `follow-up` or `complete`) and next owner.
- Link every literature lead's descriptive title or author/year text to its
  DOI resolver or canonical source URL, in both layers.
- Keep run IDs, commit hashes, query lists, drift analysis, screening counts
  and process narration in the agent record.

## Agent record rules

Place it in a `<details>` block after the brief, with a blank line after
`<summary>` so GitHub renders the Markdown inside. Use the fixed headings below
so agents can parse it. Write `None` or `n/a` rather than omitting a heading.

## Template

```markdown
## Needed from the user

1. **D1** (owner: @user): <decision in one sentence>. Reply `approve D1`,
   `reject D1`, or give an alternative.
2. **D2** (owner: @user): upload <exact file> as a session-readable upload, or
   give a folder path this session can read.

## Outcome

- <n> `value_found`, <n> `no_evidence` for <constant/group scope>.
- <Headline finding with value, units and [Author (year)](https://doi.org/...)>.

**Status:** awaiting decision. Next owner: @user.

<details>
<summary>Agent record (run state for follow-up)</summary>

### Run
- Run ID, owner/session, family issue, PR link or `not yet opened`
- Scope: qualified names and groups
- Pilot commit, VE pin, prompt/skill version, decision baseline
- Drift since last record: old/new state, source, affected runs, approval status

### Decisions
| ID | Question | Options and agent recommendation | Owner | Status |
| --- | --- | --- | --- | --- |
| D1 | ... | ... | @user | pending |

### Evidence
- Verified full texts, with location, quoted value, units and conversion
- Candidate values not yet approved, with confidence and limits

### Gaps and leads
- Per unresolved constant/group: best linked lead, blocker, next step, owner
- Dead ends with reasons; untried approaches are not dead ends

### Search coverage
- OpenAlex access mode, queries, candidates screened, publisher checks

### Next actions
- Agent actions after approval or access; human actions are in `D` entries

### Prompt/skill reflection
- What was hard, what was guessed, and the instruction that would remove it

</details>
```

Keep private paths, PDFs, extracts, inventories and credentials out of both
layers.
