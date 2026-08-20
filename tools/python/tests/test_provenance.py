"""Contract tests for project provenance metadata."""

from __future__ import annotations

from pathlib import Path

from ve_data_tools import provenance


def test_project_provenance_field_names_and_types(monkeypatch, tmp_path: Path):
    """Lock expected provenance metadata fields and their value types."""
    pyproject = tmp_path / "pyproject.toml"
    pyproject.write_text('version = "0.9.1"\n', encoding="utf-8")

    def fake_git(project_root: Path, *arguments: str) -> str:
        if arguments == ("rev-parse", "HEAD"):
            return "abc123def456"
        if arguments == ("rev-parse", "--abbrev-ref", "HEAD"):
            return "feature/provenance"
        if arguments == ("describe", "--tags", "--always"):
            return "v0.9.1-3-gabc123d"
        if arguments == ("rev-parse", "--abbrev-ref", "@{upstream}"):
            return "origin/main"
        if arguments == (
            "rev-list",
            "--left-right",
            "--count",
            "HEAD...@{upstream}",
        ):
            return "2\t1"
        return ""

    monkeypatch.setattr(provenance, "_git", fake_git)
    monkeypatch.setattr(provenance, "_source_is_modified", lambda *_: True)

    result = provenance.project_provenance(tmp_path, package_directory="virtual_ecosystem")

    expected_keys = {
        "project_version",
        "project_commit",
        "project_branch",
        "project_describe",
        "project_source_modified",
        "project_upstream",
        "project_upstream_synced",
        "project_commits_ahead_of_upstream",
        "project_commits_behind_upstream",
    }

    assert set(result.keys()) == expected_keys
    assert isinstance(result["project_version"], str)
    assert isinstance(result["project_commit"], str)
    assert isinstance(result["project_branch"], str)
    assert isinstance(result["project_describe"], str)
    assert isinstance(result["project_source_modified"], bool)
    assert isinstance(result["project_upstream"], str)
    assert isinstance(result["project_upstream_synced"], bool)
    assert isinstance(result["project_commits_ahead_of_upstream"], int)
    assert isinstance(result["project_commits_behind_upstream"], int)
