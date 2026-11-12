<!-- markdownlint-disable MD013 -->
# Reusable prompt: VE constant literature search

Copy the prompt below into a new agent session, replace every `{{PLACEHOLDER}}`,
and delete the "Constant-specific hints" lines you do not need. Placeholders and
the instructions in them are the only parts meant to change between issues.

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
- Current VE default and source: {{DEFAULT_AND_SOURCE}}
- Starting-point references from the issue: {{SEED_REFERENCES}}
- Constant-specific hints (optional): {{HINTS}}  (e.g. what the model
  equation does with the constant, likely confusable quantities)
- Results and search log directory: {{OUTPUT_DIR}} (default data/derived/llm/)
- Integration/base branch: {{BASE_BRANCH}} (pilot: constant-search-microbial-pilot)

## Setup
1. Fetch the GitHub remote and create a new testing branch
   `issue-{{ISSUE_NUMBER}}-{{SHORT_NAME}}` from `origin/{{BASE_BRANCH}}`.
   If that testing branch already exists, use a unique round suffix.
   Target any testing pull request at `{{BASE_BRANCH}}`, not main.
2. Run `uv sync`. Report which OpenAlex access mode the helper uses.
3. Verify that the sibling VE Git clone exists and check its commit and source
   status. If it is missing or unverifiable, stop and ask me to restore or
   provide it before grounding or proposing results. Ground the constant in the
   skill's inventory and VE source (units, functional form, reference sites).

## Work
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
  virtual_ecosystem.models.soil.model_config.SoilMicrobialGroup.turnover_rate
- Groups needing separate evidence: bacteria, saprotrophic fungi, arbuscular
  mycorrhiza, ectomycorrhiza
- Current VE default and source: 0.005 day^-1 at 12 degrees Celsius. The issue
  attributes the default to Fatichi et al. (2019), Global Biogeochemical Cycles,
  DOI 10.1029/2018GB006077. Verify the original paper; the default is not evidence.
- Starting-point references from the issue:
  https://onlinelibrary.wiley.com/doi/epdf/10.1111/gcb.15550 (their `tau`
  parameter); https://doi.org/10.1111/ele.70278
- Constant-specific hints: not SoilEnzymeClass.turnover_rate. In VE 0.2.3,
  calculate_maintenance_biomass_synthesis applies the rate to microbial biomass
  with an Arrhenius temperature factor. Confirm this in the checked-out version.
  Growth/community turnover and maintenance respiration do not by themselves
  identify this biomass-loss coefficient. Do not convert them into it.
- Results and search log directory: data/derived/llm/
- Integration/base branch: constant-search-microbial-pilot

## Setup
1. Fetch origin and create a new issue-198-microbial-turnover-rate testing branch
   from origin/constant-search-microbial-pilot. Use a unique round suffix if that
   branch exists. Target any testing PR at constant-search-microbial-pilot,
   not main.
2. Run uv sync. Report the OpenAlex helper's access mode without credentials.
3. Require the sibling virtual_ecosystem Git checkout. If it is missing or
   unverifiable, stop and ask me to restore or provide it. Verify the commit,
   source status and match with the installed package. Ground this constant
   using the selected inventory record and narrow VE source/doc ranges.
   Review the inventory refresh dry run before applying a required refresh.

## Work
- Use only the skill's OpenAlex helper for discovery. Start with the three DOI
  seeds above, then run 3-6 distinct queries. DOI text search is fuzzy: compare
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
