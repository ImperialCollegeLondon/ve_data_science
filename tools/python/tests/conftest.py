"""Shared pytest fixtures for tools/python tests."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
SRC_DIR = PROJECT_ROOT / "src"
TESTING_DATA_DIR = PROJECT_ROOT / "testing_data"

if not SRC_DIR.is_dir():
    raise RuntimeError(f"Expected src directory not found: {SRC_DIR}")

if str(SRC_DIR) not in sys.path:
    sys.path.insert(0, str(SRC_DIR))


@pytest.fixture(scope="session")
def project_root() -> Path:
    """Return the root directory for the tools/python test project."""
    return PROJECT_ROOT


@pytest.fixture(scope="session")
def testing_data_dir() -> Path:
    """Return the directory containing shared test input files."""
    return TESTING_DATA_DIR
