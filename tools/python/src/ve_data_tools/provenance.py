"""---
title: Project provenance helpers.

description: |
  Builds repository provenance metadata for analyses that depend on a Git-backed
  project tree.

  The module reads the project version from ``pyproject.toml`` and queries Git
  for commit, branch, describe output, source modification state, and upstream
  divergence. It is intended for workflows that need lightweight, reproducible
  source provenance without importing the analyzed project.

virtual_ecosystem_module: All

author: Hao Ran Lai

status: final

input_files:
  - name: Project ``pyproject.toml``
    path: ``project_root``/pyproject.toml
    description: |
      Optional project metadata file used to read the analyzed project version.

output_files:
  - name: Provenance metadata dictionary
    path: Returned in memory by ``project_provenance()``
    description: |
      Dictionary containing project version, Git identity, source modification
      status, and upstream divergence fields for downstream analysis outputs.

package_dependencies:
  - subprocess
  - pathlib
  - typing

usage_notes: |
  Git-derived fields return empty strings or default values when Git is not
  available, the target path is not a repository, or no upstream branch is
  configured. Source modification checks only inspect Python files under the
  provided ``package_directory``.
---
"""  # noqa: D205

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Any


def _git_commit(project_root: Path) -> str:
    """Return the current commit hash for the analyzed project.

    Args:
        project_root: Root path of the project repository.

    Returns:
        Commit hash string, or an empty string if unavailable.

    """
    return _git(project_root, "rev-parse", "HEAD")


def _git(project_root: Path, *arguments: str) -> str:
    """Run a git command in the project and return trimmed stdout.

    Args:
        project_root: Root path of the project repository.
        *arguments: Positional arguments passed to ``git``.

    Returns:
        Command stdout with surrounding whitespace removed. Returns an empty
        string if git is unavailable or the command fails.

    """
    try:
        result = subprocess.run(
            ["git", *arguments],
            cwd=project_root,
            capture_output=True,
            text=True,
            check=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""

    return result.stdout.strip()


def _source_is_modified(project_root: Path, package_directory: str) -> bool:
    """Report whether analyzed Python sources contain uncommitted changes.

    Args:
        project_root: Root path of the project repository.
        package_directory: Relative package directory to inspect in git status.

    Returns:
        ``True`` if any ``.py`` file under ``package_directory`` is modified,
        added, deleted, or renamed in the working tree; otherwise ``False``.

    """
    status = _git(project_root, "status", "--porcelain", "--", package_directory)
    if not status:
        return False

    for line in status.splitlines():
        # Porcelain format is a two-character status followed by the path.
        path = line[3:].strip().strip('"')
        # Renames are reported as "old -> new"; the destination is what matters.
        _, separator, destination = path.partition(" -> ")
        if separator:
            path = destination

        if path.endswith(".py"):
            return True

    return False


def _upstream_state(project_root: Path) -> dict[str, Any]:
    """Summarize divergence between ``HEAD`` and its upstream branch.

    Args:
        project_root: Root path of the project repository.

    Returns:
        Dictionary containing upstream name, sync flag, and ahead/behind counts.
        If no upstream is configured, returns empty upstream and ``False`` sync.

    """
    upstream = _git(project_root, "rev-parse", "--abbrev-ref", "@{upstream}")
    if not upstream:
        return {
            "project_upstream": "",
            "project_upstream_synced": False,
            "project_commits_ahead_of_upstream": 0,
            "project_commits_behind_upstream": 0,
        }

    counts = _git(
        project_root,
        "rev-list",
        "--left-right",
        "--count",
        "HEAD...@{upstream}",
    )
    ahead, _, behind = counts.partition("\t")

    return {
        "project_upstream": upstream,
        "project_upstream_synced": counts != "" and ahead.strip() == "0",
        "project_commits_ahead_of_upstream": int(ahead) if ahead.strip() else 0,
        "project_commits_behind_upstream": int(behind.strip()) if behind.strip() else 0,
    }


def project_provenance(
    project_root: Path,
    package_directory: str = "virtual_ecosystem",
) -> dict[str, Any]:
    """Build provenance metadata for the analyzed source tree.

    Args:
        project_root: Root path of the analyzed repository.
        package_directory: Relative directory containing analyzed Python
            package sources. Changes outside this directory are ignored for
            source-modified checks.

    Returns:
        Dictionary with version, commit, branch, describe output, source
        modification status, and upstream divergence fields.

    """
    version = ""
    pyproject = project_root / "pyproject.toml"
    if pyproject.is_file():
        for line in pyproject.read_text(encoding="utf-8").splitlines():
            stripped = line.strip()
            if stripped.startswith("version"):
                _, _, raw = stripped.partition("=")
                version = raw.strip().strip('"').strip("'")
                break

    provenance = {
        "project_version": version,
        "project_commit": _git_commit(project_root),
        "project_branch": _git(project_root, "rev-parse", "--abbrev-ref", "HEAD"),
        "project_describe": _git(project_root, "describe", "--tags", "--always"),
        "project_source_modified": _source_is_modified(project_root, package_directory),
    }
    provenance.update(_upstream_state(project_root))

    return provenance
