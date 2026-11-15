<!-- markdownlint-disable MD013 -->
# Reusable prompt: VE constant literature search

Copy the prompt below into a new agent session, replace every `{{PLACEHOLDER}}`,
and delete the "Constant-specific hints" lines you do not need. Placeholders and
the instructions in them are the only parts meant to change between issues.

This pilot stays on `constant-search-microbial-pilot`; do not promote any
iteration to `main`. Set `{{BASE_BRANCH}}` to that pilot branch. An issue should
contain its task contract in the body and a fully filled launch comment; do not
leave unresolved placeholders in issue prompts. Read the latest approved
launch comment and retain earlier decisions and exclusions.

## Prompt template

```text
Use the `ve-constant-search` skill (.github/skills/ve-constant-search/SKILL.md)
to address GitHub issue #{{ISSUE_NUMBER}}: "{{ISSUE_TITLE}}". Read the issue
first (`gh issue view {{ISSUE_NUMBER}} --comments`). Follow the skill's workflow
and rules; this prompt only adds task framing.

## Target
- Constant (qualified_name): {{QUALIFIED_NAME}}
- Groups needing separate evidence: {{GROUPS}}  (e.g. bacteria, saprotrophic
  fungi, arbuscular mycorrhiza, ectomycorrhiza; or "none")
- Required/default status and group-specific example context: {{DEFAULT_AND_SOURCE}}
- VE revision: the reviewed `dev-pinned` commit in pyproject.toml, currently
  6c3132f46e06fa83b9133aa2c4d2adbd60cf21ad. Do not use floating VE main.
- Starting-point references from the issue: {{SEED_REFERENCES}}
- Constant-specific hints (optional): {{HINTS}}  (e.g. what the model
  equation does with the constant, likely confusable quantities)
- Results and search log directory: {{OUTPUT_DIR}} (default data/derived/llm/)
- Integration/base branch: {{BASE_BRANCH}} (default: constant-search-microbial-pilot)
- Optional private PDF folder or uploads: {{PDF_DIR}} (or "not supplied")

## Setup
1. For every experiment, explicitly fetch the latest integration branch:
   git fetch origin refs/heads/{{BASE_BRANCH}}:refs/remotes/origin/{{BASE_BRANCH}}
   A plain git fetch may fetch only main in a restricted checkout.
   Use a fresh session based on origin/{{BASE_BRANCH}}. In an app-managed
   worktree, keep its dedicated branch; do not create or rename extra branches.
   If a clean new session starts from another base, align its branch to the
   pilot before editing, without merging main. Stop if existing work would be
   lost or fetching fails. In a standalone checkout, create a fresh testing
   branch with an issue/round-specific name from origin/{{BASE_BRANCH}}.
   Target every testing pull request back at `{{BASE_BRANCH}}`, not main.
   Pass `{{BASE_BRANCH}}` explicitly when creating the PR, even if workspace
   metadata names main. Never substitute the repository default. Verify the
   created PR's base branch matches `{{BASE_BRANCH}}` before reporting success.
2. Run `uv sync --locked --group dev-pinned`; use uv run --no-sync afterward.
   Report OpenAlex access mode only when the helper is actually exercised.
   Automatic cloud setup may still use main's released VE; verify this session.
3. Verify a sibling VE Git clone, or a session-isolated clone passed explicitly
   with --ve-root, and check its commit and source
   status. If it is missing or unverifiable, stop and ask me to restore or
   provide it before grounding or proposing results. Ground the constant in the
   skill's inventory and VE source (units, functional form, reference sites).
   Follow runtime consumers directly when inventory references are empty.
   Required inputs have no model default; examples are not evidence. Old
   qualified-name aliases do not authorise changing historical result rows.

## Work
- If PDFs are supplied, use the skill's private PDF intake. Verify that this
  session can read uploads or the specified folder; local folder access is not
  automatically available to a cloud agent. Keep original filenames and generate
  the inventory privately; do not require manual renaming or a manifest.
  Never commit PDFs, private inventories, full-text extracts or private paths.
- Search with the skill's OpenAlex helper only; start from the issue's seed
  references, then run 3-6 distinct queries. DOI text search is fuzzy: verify
  matches, and use `snowball --doi` for seed citations. It does not return the
  seed's full metadata; exact DOI metadata lookup is not yet available. Log
  every query, including failures, in the search log.
- If a query mostly returns unrelated papers, shorten or refocus the next query
  within that budget. Record what changed and why; do not repeat low-yield
  searches unchanged.
- Screen abstracts for the exact process, organism group, units and model form.
- Before retrieving full text, check each relevant publisher host with a bounded
  HTTPS request to its specific seed or candidate URL. Log the outcome. If a
  host is unreachable or access fails, ask me to supply an authorised PDF;
  continue with other accessible candidates. An HTTP response alone does not
  prove full-text access. Follow the skill's access and retention rules.
- Extract a value only from verified full text, with quote, location, units and
  a reproducible conversion. Never use the default, an abstract or pooled
  groups as evidence. Do not reanalyse or digitise data without my approval.
- Check existing analyses in this repo for leads (for example
  analysis/soil/llm/reports/).

## Outputs (commit separately from any skill/prompt edits)
- Search log and values CSV in `{{OUTPUT_DIR}}` (default `data/derived/llm/`),
  named `<module>_constant_literature_values.csv` and
  `<module>_constant_search_log.csv`. One values row per constant-group source,
  or per group with `no_evidence`.
- If values are found: report them as proposals with confidence and limits.
- If no value is found: per the skill, name the best lead, blocker and next
  human step for each unresolved group, and post that as a comment on the issue.
- Post a comment on issue #{{ISSUE_NUMBER}} with: task summary, findings,
  decision points, and prompt/skill improvement suggestions.
- Discuss evidence before saving it. Require human approval for output rows.
  For new traits, retain explicit group and full-text source_location columns;
  add them to an older active CSV only with approval, leaving historical fields
  and VE commits unchanged. Run validate_constant_results.py with selected
  names and baseline result/log files from the fetched pilot. Logs are
  append-only; replacement requires explicit approval. Do not rewrite history
  to make obsolete rows pass current-version validation.
- A verified record can be PR-ready without being an approved parameter.
  Infrastructure failures are blocked work, not evidence gaps. Record the
  decision owner, next action and limits; do not force a numerical outcome.
- Commit changes separately by task and intent, then push the branch to the
  GitHub remote. Verify the remote branch points to the committed HEAD.
  If the push fails, report the failure rather than claiming completion.

## Ask me (use the ask_user tool) when
- the group split, units or functional form is ambiguous;
- a proxy, reanalysis or change to inclusion criteria could help;
- you see a way to improve this prompt or the skill. Propose the concrete edit
  and wait for my decision before applying it. Keep prompt and skill edits in
  separate commits.

## Prompt-improvement reflection (end of task)
State which steps were easy and which were hard (for example: seed lookup,
group mapping, access to full text, unit conversion), what you had to guess,
and what extra instruction would have removed the guess.
```

## Filled example: issue #198

```text
Use the `ve-constant-search` skill (.github/skills/ve-constant-search/SKILL.md)
to address GitHub issue #198: "Microbial `turnover_rate`".

Read the issue and its comments first. Follow the skill's workflow and rules.
Growth/community turnover is not maintenance turnover; do not use that proxy.

## Target
- Constant (qualified_name):
  virtual_ecosystem.models.soil.microbial_groups.SoilMicrobe.turnover_rate
- Groups needing separate evidence: bacteria, saprotrophic fungi, arbuscular
  mycorrhiza, ectomycorrhiza
- Required input: no model default. At the reviewed dev-pinned VE commit
  6c3132f46e06fa83b9133aa2c4d2adbd60cf21ad, example_microbial_groups.csv uses
  bacteria 0.005, saprotrophic fungi 0.002, AM and ECM 0.0012 day^-1, all at
  12 degrees Celsius. Examples are model context, not empirical estimates.
  The old issue attributes the earlier default to Fatichi et al. (2019),
  DOI 10.1029/2018GB006077; verify the original paper before using it as evidence.
- Starting-point references from the issue:
  https://onlinelibrary.wiley.com/doi/epdf/10.1111/gcb.15550 (their `tau`
  parameter); https://doi.org/10.1111/ele.70278
- Constant-specific hints: not SoilEnzyme.turnover_rate. In the reviewed VE,
  calculate_maintenance_biomass_synthesis applies the rate to microbial biomass
  with an Arrhenius temperature factor. Confirm this in the checked-out version.
  Growth/community turnover and maintenance respiration do not by themselves
  identify this biomass-loss coefficient. Do not convert them into it.
- Results and search log directory: data/derived/llm/
- Integration/base branch: constant-search-microbial-pilot
- Optional private PDF folder or uploads: not supplied; accept a folder or
  uploads when provided and verify access in this session.

## Setup
1. For every experiment, fetch the latest pilot explicitly:
   git fetch origin refs/heads/constant-search-microbial-pilot:refs/remotes/origin/constant-search-microbial-pilot
   Stop if fetching fails. Use a fresh session based on the fetched pilot.
   Keep the app-managed session branch; do not create/rename extra branches.
   Align a clean new session to the pilot before editing; do not merge main.
   If existing work is at risk, stop. For standalone checkouts, use a fresh
   issue/round-specific testing branch. Target every PR at the pilot,
   not main.
   Pass constant-search-microbial-pilot explicitly when creating the PR, even
   if workspace metadata names main. Never substitute the repository default.
   Verify the created PR's base branch is constant-search-microbial-pilot.
2. Run uv sync --locked --group dev-pinned; use uv run --no-sync afterward.
   Report the helper's access mode only if OpenAlex is exercised.
3. Require a matching clean virtual_ecosystem Git checkout. An explicit
   session-isolated clone is allowed with --ve-root. If missing or
   unverifiable, stop and ask me to restore or provide it. Verify the commit,
   source status and match with the installed package. Ground this constant
   using the selected inventory record and narrow VE source/doc ranges.
   Review the inventory refresh dry run before applying a required refresh.
   Follow pools.py's runtime consumer if reference discovery is empty.

## Work
- Use the skill's private PDF intake if I provide uploads or a folder. Confirm
  session access, keep filenames unchanged and generate the citation inventory
  outside Git. Do not require a manual manifest or commit PDFs, private
  inventories, full-text extracts or private paths. Supplied PDFs still need
  scientific verification, but not publisher connectivity to read them.
- Resume the blockers documented in #198 and merged pilot PR #784: Behera's
  bacterial coefficient needs experimental-temperature and transferability
  review; fungal groups need additional primary texts. Do not repeat the broad
  searches or treat the earlier six-PDF review as a new discovery run.
- If new discovery is justified, use only the skill's OpenAlex helper. Start
  with the DOI seeds, then run 3-6 distinct queries. DOI text search is fuzzy: compare
  returned DOIs. Use snowball --doi for citation lookup; it does not return seed
  metadata. Log every request, failure, candidate and screening decision.
- Screen the exact process, groups, units, temperature and model form. If long
  queries return unrelated papers, shorten/refocus the next query within the
  same budget and record why.
- Before full-text retrieval, check each relevant publisher host with a bounded
  HTTPS request to the specific seed/candidate URL. Log the outcome. If blocked,
  ask me for authorised PDFs and continue with other accessible candidates.
  An HTTP response alone does not establish full-text access.
- Follow the skill's access and retention rules. Extract only from verified
  full text, with quotation, location, original units and reproducible
  conversion. Do not reanalyse, digitise or pool groups without approval.
- Check existing soil analyses for leads, not evidence; preserve historical
  files and do not repeat earlier proxy suggestions rejected in the issue.

## Outputs and review
- Discuss findings and gaps before writing research results. With my approval,
  save soil_constant_literature_values.csv and soil_constant_search_log.csv
  under data/derived/llm/. Preserve unrelated constants and prior runs.
  Keep the reusable prompt under analysis/soil/llm/.
  New rows use explicit group and source_location; required model_default is
  blank. Preserve legacy rows and their old qualified names/commits. Run
  validate_constant_results.py with the selected new name and baseline files;
  its structural checks do not replace scientific review.
- If values are found, present proposals with units, sources, confidence and
  limits. If none are found, say so and identify each group's best lead,
  blocker, next human step and coverage limits. Never fill numerical evidence
  fields from defaults or abstracts.
- Record task summary, findings, decisions and prompt/skill performance on
  issue #198. Explain which steps were easy/hard and what needs improvement.
- Ask with ask_user before changing scientific criteria, using any other proxy,
  reanalysing data or applying a proposed prompt/skill improvement.
- Commit research, inventory, prompt and skill changes separately by intent.
  Push the testing branch, verify the remote HEAD and report any push failure.
  Do not merge into main. Use constant-search-microbial-pilot as the integration
  target for iterative results.
```

## Change log

- v1 (issue #198): initial template.
- v2: require pushing and verifying the branch on GitHub.
- v3: require a VE checkout, publisher pre-flight and configurable output.
- v4: base testing branches on the pilot integration branch, not main.
- v5: complete the pilot example and adapt low-yield queries within the budget.
- v6: fetch the latest pilot explicitly and use a fresh branch for every experiment.
- v7: accept optional private PDFs through verified local or cloud session access.
- v8: preserve and verify the pilot PR target despite workspace default metadata.
- v9: pin post-1958 VE, ground required trait inputs and group-specific examples,
  preserve historical evidence, validate new rows and respect app worktree branches.
