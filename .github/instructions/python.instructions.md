---
description: 'Python language: guidance aligned with Virtual Ecosystem code style and tooling.'
applyTo: '**/*.py, **/*.pyw, **/*.pyi'
---

<!-- markdownlint-disable MD013 -->
# Python Programming Language Instructions

## Purpose

Guide Copilot to generate Python code consistent with the style used in the
`virtual_ecosystem` and `ve_data_science` repositories.

## Style Baseline

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
import logging
from pathlib import Path


LOGGER = logging.getLogger(__name__)
if not LOGGER.handlers:
    LOGGER.addHandler(logging.StreamHandler())


def load_text_file(path: Path) -> str:
    """Load a required text file.

    Args:
        path: Path to the input text file.

    Returns:
        File contents as a string.

    Raises:
        ValueError: If the file is missing.
        RuntimeError: If the file cannot be decoded as UTF-8.
    """

    LOGGER.info("Reading input file: %s", path)
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as excep:
        raise ValueError(f"Required input file does not exist: {path}") from excep
    except UnicodeDecodeError as excep:
        raise RuntimeError(f"Input file is not valid UTF-8: {path}") from excep


def summarise_counts(values: list[int]) -> dict[str, float]:
    """Compute simple summary statistics.

    Args:
        values: A list of integer counts.

    Returns:
        A dictionary with item count and mean value.

    Raises:
        ValueError: If no values are provided.
    """

    if not values:
        raise ValueError("values must not be empty")

    total = sum(values)
    return {"n": float(len(values)), "mean": total / len(values)}
```
