---
description: 'Python language: coding standards and Copilot guidance for idiomatic, safe, and consistent code generation.'
applyTo: '**/*.py'
---

<!-- markdownlint-disable MD013 -->
# Python Programming Language Instructions

## Purpose

Help GitHub Copilot generate idiomatic, safe, and maintainable Python code across projects.

## Core Conventions

- **Match the file's style.** Follow existing patterns and naming in the module.
- **Prefer clear, typed code.** Add type hints for function signatures and key variables.
- **Naming:** `snake_case` for variables/functions, `PascalCase` for classes, `UPPER_CASE` for constants.
- **Imports:** Keep imports explicit and grouped (standard library, third-party, local).
- **Paths:** Avoid hardcoded absolute paths; use `pathlib.Path` and project-relative paths.
- **Reproducibility:** Seed stochastic workflows locally (`numpy.random.default_rng(seed)`).
- **Validation:** Validate external or user inputs early with clear error messages.
- **Safety:** Avoid `eval()`/`exec()` on untrusted input and shell command strings built from unchecked data.

## Tooling & Quality

- **Python version:** Target Python 3.12+ (`pyproject.toml`).
- **Linting/formatting:** Use `ruff-check` and `ruff-format` via pre-commit.
- **Line length:** 88 characters (`tool.ruff.line-length`).
- **Docstrings:** Use Google-style docstrings for public functions and classes.
- **Design:** Prefer small, composable functions with minimal side effects.

## Data & Scientific Workflows

- Prefer `numpy`/`xarray` vectorized operations over Python loops for array workloads.
- Keep I/O explicit and typed; validate schema/coordinate assumptions when reading data.
- Use descriptive variable names for scientific quantities and include units in names when helpful.
- Keep transformations deterministic and avoid hidden global state.

## Error Handling

- Raise specific exceptions (`ValueError`, `TypeError`, `FileNotFoundError`, etc.).
- Avoid broad `except Exception` unless re-raising with additional context.
- Fail loudly on invalid states; do not silently swallow errors.

## Security Best Practices

- **Command execution:** Prefer `subprocess.run([...], check=True)` with argument lists (not shell strings).
- **File paths:** Normalize and validate user-provided paths before access.
- **Secrets:** Never hardcode credentials; use environment variables or secret managers.
- **Serialization:** Avoid loading untrusted pickles.

## Copilot-Specific Guidance

- Prefer type-safe suggestions and standard library solutions before adding dependencies.
- Reuse existing helpers in the repository before introducing new utilities.
- Suggest readable implementations first, then optimize based on measured bottlenecks.
- Keep comments focused on *why* when logic is non-obvious.

---

## Minimal Examples

```python
from pathlib import Path

import numpy as np


def read_positive_values(path: Path) -> np.ndarray:
    """Load numeric values and return strictly positive entries."""
    if not path.exists():
        raise FileNotFoundError(f"Input file not found: {path}")

    values = np.loadtxt(path, dtype=float)
    return values[values > 0]
```
