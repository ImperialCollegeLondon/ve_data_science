# Copilot cloud agent onboarding notes

## Repository purpose and tech stack

- This repository stores analysis and parameterisation workflows for the Virtual Ecosystem project.
- Primary languages are **R** (most analysis scripts) and **Python** (data processing, downloads, docs tooling).
- Python dependencies are managed with **Poetry** (`pyproject.toml`, `poetry.lock`).
- Code quality checks are managed through **pre-commit** (`.pre-commit-config.yaml`) and include Python, Markdown, and R hooks.

## High-value directories

- `/analysis/`: analysis and parameterisation scripts, mostly by domain (`soil`, `plant`, `litter`, `abiotic`, `site`, `animal`).
- `/data/`: project data assets (`primary`, `derived`, `scenarios`).
- `/tools/R/`: shared R helper utilities used across workflows.
- `/docs/` and `mkdocs.yml`: documentation sources and build configuration.
- `/templates/`: starter templates for R, Python, notebooks, and metadata files.

## Fast start commands

Run from repository root:

1. Install tooling and project dependencies:
   - `python -m pip install --user poetry` (if Poetry is missing)
   - `python -m poetry install`
2. Run repository QA checks:
   - `python -m poetry run pre-commit run --all-files`
3. Validate docs build:
   - `python -m poetry run mkdocs build`

## Known issues and workarounds

These were encountered during onboarding:

1. Error: `poetry: command not found`
   - Workaround: install Poetry with `python -m pip install --user poetry` and invoke via `python -m poetry ...`.

2. Error from pre-commit: `Executable 'Rscript' not found`
   - Cause: R hooks (`parsable-R`, `no-browser-statement`, `no-debug-statement`, `air-format`) require `Rscript` on `PATH`.
   - Workaround:
     - Preferred: install R (project docs suggest R 4.4+) so `Rscript` is available.
     - Temporary (Python/docs-only changes): skip R hooks, e.g.
       `SKIP=parsable-R,no-browser-statement,no-debug-statement,air-format python -m poetry run pre-commit run --all-files`

## Working conventions for agents

- Keep changes minimal and scoped to the requested domain/module.
- Use existing folder conventions (domain-specific subdirectories under `analysis/` and `data/`).
- Prefer relative paths in scripts; avoid machine-specific absolute paths.
- Do not introduce new dependency managers; use Poetry for Python and existing R workflow conventions.
- For Markdown/documentation-only changes, validate with markdown hooks and `mkdocs build`.
