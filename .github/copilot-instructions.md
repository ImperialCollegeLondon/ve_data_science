<!-- markdownlint-disable MD013 -->
# Copilot instructions

## Repository purpose

This repository contains analysis and parameterisation workflows for the Virtual Ecosystem project. Primary languages are **R** and **Python**. Code quality checks run via **pre-commit** (`.pre-commit-config.yaml`) with Python, Markdown, and R hooks.

## Repository map

- `analysis/`: domain workflows (`soil`, `plant`, `litter`, `abiotic`, `site`, `animal`)
- `tools/`: shared R/Python utilities
- `docs/`: process, onboarding, and usage documentation
- `templates/`: starter metadata/scripts/notebooks
- `data/`: data assets (`primary`, `derived`, `scenarios`)

## Token-efficient operating rules

- Start with user-mentioned files/paths.
- If no path is provided, route to the most likely directory:
  - domain modeling/parameterisation -> `analysis/<domain>/`
  - shared helper logic -> `tools/`
  - process/how/why questions -> `docs/`
  - scaffolding new metadata/scripts -> `templates/`
  - data-specific tasks -> `data/` (defer unless needed)
- Ask one concise clarification question if domain/path is unclear.
- Use targeted search in the relevant directory before broader traversal.
- Initial exploration budget: inspect up to **5 files** (README/config + directly referenced files first).
- Ask before widening scope (cross-domain tracing, wide refactors, large directory scans).
- Keep responses compact by default: short answer + assumptions + next step.

## Editing workflow in IDE

- Prefer minimal, local edits in the closest relevant file.
- Check `tools/` before introducing duplicate helper code.
- Avoid broad repo restatements unless requested.
- Validate narrowly first (small relevant checks before full test suites).
- Inspect relevant sections/functions before reading whole large files.
- Avoid adding dependencies unless necessary; ask before introducing new ones.
- Avoid full rewrites of notebooks or large data assets.

## Coding conventions

- Keep changes scoped to the requested module/domain.
- Follow existing folder conventions (especially under `analysis/` and `data/`).
- Use relative paths in scripts; avoid machine-specific absolute paths.
- Match language to the touched module (`R` or `Python`).
- If creating a new script without guidance, prefer Python.

## Known issue and workaround

Pre-commit may fail with `Executable 'Rscript' not found`.

- Cause: R hooks (`parsable-R`, `no-browser-statement`, `no-debug-statement`, `air-format`) require `Rscript` on `PATH`.
- Preferred fix: install R (project docs suggest R 4.4+) so `Rscript` is available.
- Temporary for Python/docs-only edits:
  `SKIP=parsable-R,no-browser-statement,no-debug-statement,air-format python -m poetry run pre-commit run --all-files`
