"""Tests for OpenAlex credential loading."""

import importlib.util
import os
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).with_name("openalex_search.py")
SPEC = importlib.util.spec_from_file_location("openalex_search", SCRIPT)
openalex_search = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(openalex_search)


def test_read_setting_uses_windows_user_renviron(tmp_path, monkeypatch):
    """Read credentials from the R user file without exposing their values."""
    documents = tmp_path / "Documents"
    documents.mkdir()
    (documents / ".Renviron").write_text(
        "OPENALEX_API_KEY='test-key'\nOPENALEX_EMAIL=test@example.org\n",
        encoding="utf-8",
    )
    monkeypatch.delenv("OPENALEX_API_KEY", raising=False)
    monkeypatch.delenv("OPENALEX_EMAIL", raising=False)

    with (
        patch.object(Path, "home", return_value=tmp_path),
        patch.object(os, "name", "nt"),
    ):
        assert openalex_search.openalex_access() == (
            "api_key",
            {"api_key": "test-key"},
        )


def test_process_environment_takes_precedence(tmp_path, monkeypatch):
    """Prefer an existing process setting over .Renviron."""
    (tmp_path / ".Renviron").write_text("OPENALEX_API_KEY=file-key\n", encoding="utf-8")
    monkeypatch.setenv("OPENALEX_API_KEY", "environment-key")

    with patch.object(Path, "home", return_value=tmp_path):
        assert openalex_search.read_setting("OPENALEX_API_KEY") == "environment-key"
