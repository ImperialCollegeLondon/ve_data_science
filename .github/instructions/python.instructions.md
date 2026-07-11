---
description: 'Python language guidance for ve_data_science analysis, wrangling tools, and tests.'
applyTo: '**/*.py, **/*.pyw, **/*.pyi'
---

<!-- markdownlint-disable MD013 -->
# Python Programming Language Instructions

## Purpose

Guide Copilot to generate Python code for this repository with emphasis on:
1) analysis and visualisation scripts,
2) reusable data-wrangling and derivation tools used by those scripts,
3) tests.

## Style Baseline

- **Python version:** Target Python 3.12+.
- **Formatting/linting:** Ruff (`ruff-check` + `ruff-format`) via pre-commit.
- **Docstrings:** Use Google-style sections (`Args`, `Returns`, `Raises`) when relevant.
- **Imports:** Use explicit imports and consistent grouping.

## Core Coding Conventions

- **Match local file patterns first.** Follow existing naming, structure, and API usage.
- **Use modern type hints:** `list[str]`, `dict[str, Any]`, `Path | None`, etc.
- **Prefer explicit types** on public function signatures and key intermediate values.
- **Naming:** `snake_case` (functions/variables), `PascalCase` (classes), `UPPER_CASE` (constants).
- **Paths:** Use `pathlib.Path` and project-relative paths.
- **Use f-strings** unless another style is already dominant in-file.

## Analysis and Visualisation Scripts

- Prefer clear pipeline-style functions over a single long top-level script body.
- Use `numpy`/`xarray`/`pandas` vectorized operations for numeric/data workloads.
- Keep plotting code readable: setup, styling, then save/export.
- Validate input files/columns/shapes before heavy computation.
- Keep executable script logic under `if __name__ == "__main__":`.

## Data Wrangling and Derivation Tools

- Keep transformations modular (e.g., conversion, aggregation, reshaping, export).
- Use explicit config dictionaries/dataclasses over hidden global configuration.
- Return deterministic typed outputs (`DataFrame`, `Dataset`, arrays).
- Keep helpers reusable by analysis scripts and notebook workflows.

## Docstring and Metadata Conventions

- Keep module docstrings where already used in this repository.
- For public functions/classes/methods, document `Args`, `Returns`, and `Raises`.
- For metadata-heavy scripts, preserve the existing front-matter-style module docstring.
- Avoid comments that restate obvious code; explain non-obvious decisions only.

## Error Handling and Logging

- Raise specific exceptions (`ValueError`, `TypeError`, `RuntimeError`, etc.).
- Avoid broad catches unless re-raising with clear context.
- Do not silently swallow errors.
- Follow the tooling logging pattern (as seen in trophic mass-flow tooling):
  - create a logger using `logging.getLogger(__name__)`,
  - attach a `logging.StreamHandler()` when script-style console logging is intended,
  - emit `LOGGER.info(...)` at key processing stages.
- Log important failure context before raising when users need actionable diagnostics.

## Testing Guidance

- Use `pytest` and name test files/functions with `test_*`.
- Test per-stage behavior for analysis tools (conversion, grouping, pivoting, plotting/export).
- Use compact in-memory fixtures/dataframes for deterministic tests.
- For file outputs (plots/netCDF/csv), write to temp paths and assert artifact creation.
- Include negative-path tests for validation and error handling.

## Security and Safety

- Avoid `eval()`/`exec()` on untrusted input.
- Prefer `subprocess.run([...], check=True)` with argument lists over shell strings.
- Validate user-provided paths before file operations.
- Never hardcode credentials; use environment variables or secure external config.

## Copilot-Specific Guidance

- Reuse existing helpers/patterns before adding new utilities.
- Prioritise readability and type safety over dense one-liners.
- Keep comments focused on **why**, not **what**.
- When adding tools, include concise logging milestones and test hooks from the start.

---

## Minimal Example (tool logging + wrangling style)

```python
import logging

import pandas as pd


class AnalysisTool:
    """Simple data-processing tool with explicit logging.

    Args:
        df: Input data containing numeric values.
    """

    def __init__(self, df: pd.DataFrame) -> None:
        self.logger = logging.getLogger(__name__)
        if not self.logger.handlers:
            self.logger.addHandler(logging.StreamHandler())
        self.df = df

    def process(self) -> pd.DataFrame:
        """Process the input data and return a derived table."""
        self.logger.info("Converting units")
        out = self.df.assign(value_kg=self.df["value_g"] / 1000.0)
        self.logger.info("Aggregating by group")
        return out.groupby("group", as_index=False)["value_kg"].sum()
```
