# AGENTS.md

## Project overview

This repository contains data science workflows used to parameterize and run the
Virtual Ecosystem model. It is a mixed-language project with analysis and
utility code in R and Python, plus MkDocs documentation.

The main working areas are [analysis/](analysis/), [tools/](tools/),
[tests/testthat/](tests/testthat/), [docs/](docs/), and [data/](data/). The
repository is not a Python package (`package-mode = false` in
[pyproject.toml](pyproject.toml)); it is a research/workflow codebase.

## Tech stack and key config

Python dependencies and QA tooling are configured in
[pyproject.toml](pyproject.toml). R package requirements are tracked lightly in
[r_requirements.R](r_requirements.R). Pre-commit hooks are configured in
[.pre-commit-config.yaml](.pre-commit-config.yaml). Documentation build settings
are in [mkdocs.yml](mkdocs.yml).

Primary tooling and conventions:

- Python 3.12+
- Poetry for Python environment/dependency management
- R 4.4+ expected for local workflows
- pre-commit for QA checks
- Ruff for Python linting/formatting (line length 88)
- Air for R formatting (line width 80, 2-space indent)
- markdownlint for Markdown (line length 88)

## Setup commands

Run from repository root.

```bash
git clone https://github.com/ImperialCollegeLondon/ve_data_science.git
cd ve_data_science
```

Install Python tooling with Poetry:

```bash
poetry install
```

Install pre-commit hooks:

```bash
poetry run pre-commit install
```

Ensure R is installed and available on `PATH` as `Rscript`.

Install commonly required R packages (based on CI workflow):

```r
install.packages(c(
  "here", "testthat", "withr", "reticulate", "toml", "tidync",
  "purrr", "RNetCDF", "dplyr", "stringr", "cli", "sessioninfo"
))
```

## Development workflow

For routine development, run targeted checks before broad checks.

Run pre-commit on all files:

```bash
poetry run pre-commit run --all-files
```

Run only Python hooks when iterating on Python files:

```bash
poetry run pre-commit run ruff-check ruff-format --all-files
```

Run only R-related hooks when iterating on R files (requires `Rscript`):

```bash
poetry run pre-commit run parsable-R no-browser-statement no-debug-statement air-format --all-files
```

Known local issue: if pre-commit reports `Executable 'Rscript' not found`,
install/configure R so `Rscript` is on `PATH`. For Python/docs-only commits,
temporary skipping of R hooks is documented in
[.github/copilot-instructions.md](.github/copilot-instructions.md).

## Testing instructions

### R tests (primary CI test suite)

R tests live in [tests/testthat/](tests/testthat/) and are run in CI via
[.github/workflows/r-tests.yml](.github/workflows/r-tests.yml).

Run all R tests locally:

```r
testthat::test_dir(
  here::here("tests/testthat"),
  reporter = "progress",
  stop_on_failure = TRUE
)
```

Equivalent one-liner:

```bash
Rscript -e "testthat::test_dir(here::here('tests/testthat'), reporter='progress', stop_on_failure=TRUE)"
```

Run a specific R test file:

```bash
Rscript -e "testthat::test_file('tests/testthat/test-get_derived_variables.R')"
```

### Python tests

Python tests are present in module locations such as
[tools/python/animal/test_trophic_mass_flow.py](tools/python/animal/test_trophic_mass_flow.py).

Run a specific Python test module:

```bash
poetry run pytest tools/python/animal/test_trophic_mass_flow.py
```

If `pytest` is unavailable in the environment, install it in the active Python
environment before running module tests.

## Code style and file conventions

Follow existing local style in the file you are editing.

### R

Use `lower_snake_case`. Avoid `setwd()`. Prefer project-relative paths (for
example `here::here()`). Keep formatting compatible with Air
([air.toml](air.toml)): 2-space indentation and 80-character line width. Keep R
scripts domain-scoped under [analysis/](analysis/) or shared utilities under
[tools/R/](tools/R/).

### Python

Target Python 3.12+. Use explicit imports, modern type hints, and Google-style
docstrings where docstrings are used. Keep formatting/linting compatible with
Ruff settings in [pyproject.toml](pyproject.toml) (88-character line width).

### Markdown and docs

Keep Markdown line length at 88 where possible (see
[.markdownlint.yaml](.markdownlint.yaml)). Documentation content lives under
[docs/](docs/), built with MkDocs Material.

## Build and documentation deployment

Local docs preview:

```bash
poetry run mkdocs serve
```

Deploy docs (same command pattern as CI in
[.github/workflows/gh_deploy.yml](.github/workflows/gh_deploy.yml)):

```bash
poetry run mkdocs gh-deploy --force
```

## CI/CD notes

R test workflow: [.github/workflows/r-tests.yml](.github/workflows/r-tests.yml).

Documentation deploy workflow:
[.github/workflows/gh_deploy.yml](.github/workflows/gh_deploy.yml).

The R test workflow currently detects `uv.lock` and uses `uv` when present,
otherwise falls back to Poetry for Python dependency setup.

## Pull request and change guidelines

Before opening or updating a PR, run local QA and relevant tests:

```bash
poetry run pre-commit run --all-files
```

```bash
Rscript -e "testthat::test_dir(here::here('tests/testthat'), reporter='progress', stop_on_failure=TRUE)"
```

When changing Python modules with colocated tests, run the closest relevant
`pytest` module(s).

Keep changes scoped to the target domain/module, prefer minimal edits, and reuse
helpers in [tools/](tools/) instead of duplicating logic.

## Security and safety considerations

Never commit secrets or credentials. Use environment variables or external
secret management.

Avoid machine-specific absolute paths in committed code. Validate file paths and
inputs before destructive operations.

Do not use unsafe dynamic execution patterns on untrusted input (`eval`, `exec`,
or shell-string command execution in Python/R).

## Agent navigation tips

Use these directories first when routing work:

- Domain modeling and parameterization: [analysis/](analysis/)
- Shared helper logic: [tools/](tools/)
- Tests: [tests/testthat/](tests/testthat/) and module-local Python tests
- Documentation/process questions: [docs/](docs/)
- Data assets and scenarios: [data/](data/)

When adding new scripts without explicit location guidance, place them in the
closest domain folder or in [tools/](tools/) if they are reusable across
domains.

## Script metadata header guidance

When asked to document a script with a metadata header, start from the
appropriate template in [templates/](templates/) rather than writing headers
from scratch. Use [templates/README.md](templates/README.md) to choose the
correct template, including
[templates/R_script_template.r](templates/R_script_template.r),
[templates/python_script_template.py](templates/python_script_template.py), and
[templates/yaml_metadata_specification.yaml](templates/yaml_metadata_specification.yaml).
