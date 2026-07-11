---
description: 'Python language: guidance aligned with Virtual Ecosystem code style and tooling.'
applyTo: '**/*.py, **/*.pyw, **/*.pyi'
---

<!-- markdownlint-disable MD013 -->
# Python Programming Language Instructions

## Purpose

Guide Copilot to generate Python code consistent with the style used in the local
`virtual_ecosystem` repository.

## Style Baseline (from `virtual_ecosystem`)

- **Python version:** Target Python 3.12+.
- **Formatting/linting:** Ruff (`ruff-check` + `ruff-format`) via pre-commit.
- **Typing checks:** mypy is part of pre-commit; code should be type-check friendly.
- **Docstrings:** pydocstyle with **Google convention** (`Args`, `Returns`, `Raises`).
- **Imports:** Prefer explicit imports and clear grouping.

## Core Coding Conventions

- **Match local file patterns first.** Follow existing naming, structure, and API usage.
- **Use modern type hints:** `list[str]`, `dict[str, Any]`, `Path | None`, etc.
- **Prefer explicit types** on public function signatures and key intermediate values.
- **Naming:** `snake_case` (functions/variables), `PascalCase` (classes), `UPPER_CASE` (constants).
- **Paths:** Use `pathlib.Path`; avoid machine-specific absolute paths.
- **Use f-strings** for interpolation unless another style is already dominant in-file.

## Docstring Conventions

- Use module docstrings at the top of files for public modules.
- For public functions/methods/classes, use Google-style sections as needed:
  - `Args:`
  - `Returns:`
  - `Raises:`
- Keep docstrings descriptive and behavior-focused; avoid repeating obvious code.
- In class APIs, document constructor parameters on the class docstring when that is the
  existing pattern.

## Error Handling and Logging

- Raise specific exceptions (`ValueError`, `TypeError`, `RuntimeError`, etc.).
- Avoid broad catches unless re-raising with clear context.
- Do not silently swallow errors.
- Preserve exception chaining with `raise ... from excep` when converting exception types.
- For tool/script logging, follow a consistent standard:
  - create loggers with `logging.getLogger(__name__)`,
  - attach a `logging.StreamHandler()` for console-oriented runs when needed,
  - use `LOGGER.info(...)` for key pipeline milestones.

## Scientific/Data Workflow Guidance

- Prefer vectorized NumPy/xarray operations for array-heavy work.
- Keep transformations deterministic and explicit.
- Validate assumptions around shapes, dimensions, units, and coordinate systems.
- Avoid hidden global state; keep functions composable and testable.

## Security and Safety

- Avoid `eval()`/`exec()` on untrusted inputs.
- Prefer `subprocess.run([...], check=True)` with argument lists over shell strings.
- Validate user-provided paths before file operations.
- Never hardcode credentials; use environment variables or external secret storage.

## Copilot-Specific Guidance

- Reuse existing helpers and patterns in the repository before introducing new utilities.
- Prefer readability and type safety over clever or dense one-liners.
- Keep comments rare and focused on **why**, not **what**.
- For API-facing modules, keep docstrings complete and consistent with Google style.

---

## Minimal Examples

```python
from pathlib import Path

from virtual_ecosystem.core.exceptions import ConfigurationError
from virtual_ecosystem.core.logger import LOGGER


def require_existing_file(path: Path) -> None:
    """Validate that a required input file exists.

    Args:
        path: Path to the required input file.

    Raises:
        ConfigurationError: If the provided path does not exist.
    """

    if not path.exists():
        to_raise = ConfigurationError(f"Input file not found: {path}")
        LOGGER.critical(to_raise)
        raise to_raise
```
