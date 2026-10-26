"""---
title: Refresh the Virtual Ecosystem constant inventory

description: |
  Stage a configuration constant inventory from a clean sibling VE clone,
  compare qualified names with the maintained TOML, and replace it only with
  --apply. A matching commit leaves the asset unchanged.

virtual_ecosystem_module: All
status: final
input_files:
  - name: Virtual Ecosystem Python package
    path: ../virtual_ecosystem/virtual_ecosystem/
    description: Configuration declarations and their reference sites.
  - name: ve_constant_usage.toml
    path: .github/skills/ve-constant-search/assets/
    description: Current inventory and recorded VE commit.
output_files:
  - name: ve_constant_usage.toml
    path: .github/skills/ve-constant-search/assets/
    description: Replaced only after --apply passes provenance checks.
imported_files:
  - name: constant_usage_tool.py
    path: tools/python/src/ve_data_tools/
    description: Builds the inventory using VE classes and reference resolution.
package_dependencies:
  - virtual-ecosystem
  - jedi
  - tomli-w
usage_notes: |
  Run from the repository root using uv. Review the dry-run diff before
  --apply. --ve-root selects another clone; the script checks that imported
  VE configuration code comes from that clone. It rejects dirty VE package
  source, but changes outside the package need separate review.
---
"""  # noqa: D205, D400, D415

from __future__ import annotations

import argparse
import ast
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
ASSET = ROOT / ".github/skills/ve-constant-search/assets/ve_constant_usage.toml"
TOOL_DIR = ROOT / "tools/python/src/ve_data_tools"


def git(ve_root: Path, *args: str) -> str:
    """Run Git in the VE clone; fail if provenance cannot be checked."""
    return subprocess.check_output(
        ["git", "-C", str(ve_root), *args], text=True
    ).strip()


def refresh(ve_root: Path, apply: bool = False) -> str:
    """Stage an inventory and apply it only after a source and record check."""
    if not (ve_root / "virtual_ecosystem").is_dir():
        raise ValueError(f"Missing VE package: {ve_root}")
    commit = git(ve_root, "rev-parse", "HEAD")
    dirty = git(
        ve_root,
        "status",
        "--porcelain",
        "--untracked-files=all",
        "--",
        "virtual_ecosystem",
    )
    if dirty:
        raise ValueError(f"VE source has uncommitted changes:\n{dirty}")

    current = (
        tomllib.loads(ASSET.read_text(encoding="utf-8")) if ASSET.exists() else None
    )
    if (
        current
        and current["metadata"]["project_commit"] == commit
        and not current["metadata"].get("project_source_modified", True)
        and "virtual_ecosystem/core/configuration.py"
        in current["metadata"].get("target_files", [])
    ):
        return f"Current inventory already matches VE commit {commit}; no changes."

    sys.path.insert(0, str(TOOL_DIR))
    sys.path.insert(0, str(ve_root))
    from constant_usage_tool import get_constant_references
    from virtual_ecosystem.core import configuration

    if not Path(configuration.__file__).resolve().is_relative_to(ve_root):
        raise ValueError("Imported VE does not match the selected local clone")

    targets = sorted(
        path.relative_to(ve_root).as_posix()
        for path in (ve_root / "virtual_ecosystem").rglob("model_config.py")
    )
    if not targets:
        raise ValueError("No VE model_config.py files found")

    # Include shared settings declared in the configuration base classes.
    base_path = ve_root / "virtual_ecosystem/core/configuration.py"
    base_tree = ast.parse(base_path.read_text(encoding="utf-8"))
    shared_fields = {
        node.name: {
            statement.target.id
            for statement in node.body
            if isinstance(statement, ast.AnnAssign)
            and isinstance(statement.target, ast.Name)
            and not statement.target.id.startswith("_")
        }
        for node in base_tree.body
        if isinstance(node, ast.ClassDef)
        and node.name in {"ModelConfigurationRoot", "DisturbanceConfigurationRoot"}
    }
    if set(shared_fields) != {"ModelConfigurationRoot", "DisturbanceConfigurationRoot"}:
        raise ValueError("VE shared configuration classes are missing")
    targets = [base_path.relative_to(ve_root).as_posix(), *targets]
    with tempfile.TemporaryDirectory() as directory:
        staged_path = Path(directory) / "ve_constant_usage.toml"
        staged = get_constant_references(
            target_paths=targets,
            out_path=staged_path,
            project_root=ve_root,
            include_tests=False,
        )
        if (
            staged["metadata"]["project_commit"] != commit
            or staged["metadata"]["project_source_modified"]
        ):
            raise ValueError("VE source changed during scan; discard staged inventory")
        expected_shared = {
            f"virtual_ecosystem.core.configuration.{class_name}.{field}"
            for class_name, fields in shared_fields.items()
            for field in fields
        }
        missing_shared = expected_shared - staged["constants"].keys()
        if missing_shared:
            raise ValueError(
                f"Shared VE fields missing from inventory: {sorted(missing_shared)}"
            )
        if git(
            ve_root,
            "status",
            "--porcelain",
            "--untracked-files=all",
            "--",
            "virtual_ecosystem",
        ):
            raise ValueError("VE source changed during scan; discard staged inventory")
        before = current["constants"] if current else {}
        after = staged["constants"]
        added = sorted(after.keys() - before.keys())
        removed = sorted(before.keys() - after.keys())
        changed = sorted(
            key for key in before.keys() & after.keys() if before[key] != after[key]
        )
        summary = (
            f"VE {commit}: {len(added)} added, {len(removed)} removed, "
            f"{len(changed)} changed constant records.\n"
            f"Added: {added}\nRemoved: {removed}\nChanged: {changed}"
        )
        if apply:
            ASSET.parent.mkdir(parents=True, exist_ok=True)
            # Stage on the destination volume for an atomic replacement.
            with tempfile.NamedTemporaryFile(
                dir=ASSET.parent, suffix=".toml", delete=False
            ) as staged_destination:
                destination = Path(staged_destination.name)
                staged_destination.write(staged_path.read_bytes())
            try:
                destination.replace(ASSET)
            finally:
                destination.unlink(missing_ok=True)
            return summary + "\nInventory replaced; review changes before using it."
        return (
            summary
            + "\nDry run; inventory unchanged. Re-run with --apply after review."
        )


def main() -> None:
    """Check a local VE clone and optionally update the maintained asset."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--ve-root", type=Path, default=ROOT.parent / "virtual_ecosystem"
    )
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    print(refresh(args.ve_root.resolve(), args.apply))


if __name__ == "__main__":
    main()
