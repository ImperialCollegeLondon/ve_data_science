<!-- markdownlint-disable MD013 -->
# Copilot instructions

## Repository purpose

- This repository stores analysis and parameterisation workflows for the
  Virtual Ecosystem project.
- Primary languages are **R** and **Python**.
- Code quality checks are managed through **pre-commit**
  (`.pre-commit-config.yaml`) and include Python, Markdown, and R hooks.

## Overall folder structure

- `/analysis/`: analysis and parameterisation scripts, mostly by domain
  (`soil`, `plant`, `litter`, `abiotic`, `site`, `animal`).
- `/data/`: project data assets (`primary`, `derived`, `scenarios`).
- `/tools/`: shared R and Python helper utilities used across workflows.
- `/docs/`: documentation sources for building website.
- `/templates/`: starter templates for metadata in R, Python, and notebooks.

## High-value directories (token-efficient routing)

Use this section as the default routing policy. Prefer targeted access over full tree scans.

1. **`/analysis/` (first stop for modelling/parameterisation tasks)**
   - Use for: domain workflows and scripts (`soil`, `plant`, `litter`, `abiotic`, `site`, `animal`).
   - Start in: `analysis/<domain>/` if domain is known from prompt.
   - If domain is unclear: ask one clarification question before scanning multiple domains.

2. **`/tools/` (first stop for shared logic)**
   - Use for: utility functions reused across workflows (R/Python helpers).
   - Check here before proposing duplicate helper code elsewhere.

3. **`/docs/` (first stop for process/explanation questions)**
   - Use for: documentation, onboarding, workflow intent, and usage guidance.
   - Prefer docs lookup before code traversal for “how/why” questions.

4. **`/templates/` (first stop for new metadata/script scaffolding)**
   - Use for: creating new metadata files or starter scripts/notebooks.
   - Reuse template structure rather than inventing new formats.

5. **`/data/` (defer unless task is data-specific)**
   - Use for: data assets only (`primary`, `derived`, `scenarios`).
   - Avoid broad scans here by default (can be large / low signal for code tasks).

### Directory scan limits

- Inspect at most **5 files** initially.
- Prefer nearest README/config/index plus directly referenced files.
- If unresolved after initial pass, return assumptions + ask permission to widen scope.

## Efficiency and token budget

To reduce token usage and repeated context-gathering in new chats:

- **Do not perform broad repository scans by default.**
  - Start with files/paths explicitly mentioned by the user.
  - If none are mentioned, inspect only the most likely directory from this map:
    - soil/litter/plant/abiotic/site/animal analysis → `analysis/<domain>/`
    - shared script utilities → `tools/`
    - dataset questions → `data/`
    - documentation/questions about process → `docs/` then root config files

- **Initial exploration budget:** inspect at most **5 files** before responding.
  - Prefer README, nearest config, and directly referenced scripts.
  - Then provide a brief answer with assumptions and ask whether to expand scope.

- **Ask before widening scope.**
  - If the task requires cross-domain tracing or refactor across multiple modules,
    ask for confirmation before scanning the full repository.

- **Prefer targeted search over tree walking.**
  - Use symbol/string search focused to the relevant directory first.
  - Avoid listing large directories unless required for the task.

- **Response compactness by default.**
  - Give a short answer first (summary + concrete next step).
  - Provide detailed breakdown only if requested.

- **Language alignment rule.**
  - Use the language already used in the touched module (`R` or `Python`).
  - If creating new scripts without a specified language, prefer Python.

## IDE interaction guidelines

These rules optimise for in-IDE Copilot workflows (fast, low-token, low-disruption edits).

- **Clarify once:** if request is ambiguous, ask one concise question with options.
  If no reply, proceed with the most likely option and state assumptions briefly.
- **Patch-first:** prefer minimal edits and show changed files + rationale + quick validation.
- **Local edits first:** change the closest relevant file; avoid wide refactors unless requested.
- **No broad restatement:** do not repeat repository overviews unless asked.
- **Narrow validation first:** suggest/run small, relevant checks before full test suites.
- **Large-file discipline:** inspect only relevant functions/sections before scanning entire files.
- **Dependency gate:** avoid adding dependencies unless necessary; ask before introducing new ones.
- **Notebook/data caution:** avoid full-file rewrites of notebooks or large data assets.
- **Concise default output:** short answer first, then optional detailed explanation.

## Working conventions for agents

- Keep changes minimal and scoped to the requested domain/module.
- Use existing folder conventions (domain-specific subdirectories under
  `analysis/` and `data/`).
- Prefer relative paths in scripts; avoid machine-specific absolute paths.

## Known issues and workarounds

These were encountered during onboarding:

1. Error from pre-commit: `Executable 'Rscript' not found`
   - Cause: R hooks (`parsable-R`, `no-browser-statement`,
     `no-debug-statement`, `air-format`) require `Rscript` on `PATH`.
   - Workaround:
     - Preferred: install R (project docs suggest R 4.4+) so `Rscript` is available.
     - Temporary (Python/docs-only changes): skip R hooks, e.g.
       `SKIP=parsable-R,no-browser-statement,no-debug-statement,air-format`
       `python -m poetry run pre-commit run --all-files`
