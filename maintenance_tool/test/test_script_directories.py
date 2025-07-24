"""Test the script_directories module."""

from importlib import resources

import pytest


def test_read_r_script_metadata():
    """Test read_r_script_metadata."""
    from maintenance_tool.script_directories import read_r_script_metadata

    path = resources.files("maintenance_tool.test.script_files")
    metadata = read_r_script_metadata(path / "script.R")

    assert isinstance(metadata, dict)


def test_read_py_script_metadata():
    """Test read_py_script_metadata."""
    from maintenance_tool.script_directories import read_py_script_metadata

    path = resources.files("maintenance_tool.test.script_files")
    metadata = read_py_script_metadata(path / "script.py")

    assert isinstance(metadata, dict)


@pytest.mark.parametrize(argnames="file_name", argvalues=("script.Rmd", "script.md"))
def test_read_markdown_notebook_metadata(file_name):
    """Test read_rmd_script_metadata."""
    from maintenance_tool.script_directories import read_markdown_notebook_metadata

    path = resources.files("maintenance_tool.test.script_files")
    metadata = read_markdown_notebook_metadata(path / file_name)

    assert isinstance(metadata, dict)


@pytest.mark.parametrize(
    argnames="filename", argvalues=("script.R", "script.py", "script.Rmd", "script.md")
)
def test_validate_script_metadata(filename):
    """Test the validation function."""
    from maintenance_tool.script_directories import (
        ScriptMetadata,
        validate_script_metadata,
    )

    path = resources.files("maintenance_tool.test.script_files")
    metadata = validate_script_metadata(path / filename)

    assert isinstance(metadata, ScriptMetadata)
