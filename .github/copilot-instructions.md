<!-- markdownlint-disable MD013 -->
# Copilot instructions

## Repository purpose

- This repository stores analysis and parameterisation workflows for the
  Virtual Ecosystem project.
- Primary languages are **R** and **Python**.
- Code quality checks are managed through **pre-commit**
  (`.pre-commit-config.yaml`) and include Python, Markdown, and R hooks.

## High-value directories

- `/analysis/`: analysis and parameterisation scripts, mostly by domain
  (`soil`, `plant`, `litter`, `abiotic`, `site`, `animal`).
- `/data/`: project data assets (`primary`, `derived`, `scenarios`).
- `/tools/`: shared R and Python helper utilities used across workflows.
- `/docs/`: documentation sources.
- `/templates/`: starter templates for metadata in R, Python, and notebooks.

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

## Working conventions for agents

- Keep changes minimal and scoped to the requested domain/module.
- Use existing folder conventions (domain-specific subdirectories under
  `analysis/` and `data/`).
- Prefer relative paths in scripts; avoid machine-specific absolute paths.
