"""---
title: Refresh the Virtual Ecosystem constant inventory

description: |
  Stage a configuration and validated trait inventory from a clean VE clone,
  compare qualified names with the maintained TOML, and replace it only with
  --apply. A matching commit and current schema leave the asset unchanged.

virtual_ecosystem_module: All
status: final
input_files:
  - name: Virtual Ecosystem Python package
    path: ../virtual_ecosystem/virtual_ecosystem/
    description: Configuration and validated trait input declarations and uses.
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
  VE code comes from that clone and installed Python sources match it. It
  rejects dirty VE package source, but changes outside the package need review.
---
"""  # noqa: D205, D400, D415

from __future__ import annotations

import argparse
import ast
import csv
import hashlib
import importlib.util
import re
import subprocess
import sys
import tempfile
import tomllib
from dataclasses import fields
from pathlib import Path
from typing import Any

import tomli_w

ROOT = Path(__file__).resolve().parents[4]
ASSET = ROOT / ".github/skills/ve-constant-search/assets/ve_constant_usage.toml"
TOOL_DIR = ROOT / "tools/python/src/ve_data_tools"
SCHEMA_VERSION = 2


def verify_installed_source(ve_root: Path) -> None:
    """Reject a VE environment whose Python source differs from the chosen clone."""
    spec = importlib.util.find_spec("virtual_ecosystem")
    if spec is None or spec.origin is None:
        raise ValueError("VE is not installed; prepare the matching uv environment")

    def digests(root: Path) -> dict[str, str]:
        return {
            path.relative_to(root).as_posix(): hashlib.sha256(
                path.read_bytes()
            ).hexdigest()
            for path in root.rglob("*.py")
        }

    if digests(Path(spec.origin).parent) != digests(ve_root / "virtual_ecosystem"):
        raise ValueError("Installed VE Python source does not match the selected clone")


def add_trait_metadata(ve_root: Path, staged: dict[str, dict[str, Any]]) -> None:
    """Check soil trait coverage and retain examples separately from defaults."""
    from virtual_ecosystem.models.soil import microbial_groups

    if not hasattr(microbial_groups, "SoilMicrobe"):
        return  # Older VE revisions still declare these parameters in model_config.

    module = microbial_groups.__name__
    enzyme_file = "virtual_ecosystem/example_data/data/example_enzyme_parameters.csv"
    microbe_file = "virtual_ecosystem/example_data/data/example_microbial_groups.csv"
    enzymes = microbial_groups.load_enzymes(ve_root / enzyme_file)
    microbial_groups.load_microbes(ve_root / microbe_file, enzymes)
    schemas = (
        (
            "SoilMicrobe",
            {item.name for item in fields(microbial_groups.SoilMicrobe) if item.init},
            microbe_file,
            "SoilMicrobialGroup",
        ),
        (
            "SoilEnzyme",
            set(microbial_groups.SoilEnzyme.model_fields),
            enzyme_file,
            "SoilEnzymeClass",
        ),
    )
    aliases: dict[str, list[str]] = {}
    for class_name, names, filename, legacy_class in schemas:
        path = ve_root / filename
        with path.open(encoding="utf-8", newline="") as stream:
            reader = csv.DictReader(stream)
            if reader.fieldnames is None or set(reader.fieldnames) != names:
                raise ValueError(
                    f"Example CSV headers do not match {class_name}: {path}"
                )
            rows = list(reader)
        expected = {f"{module}.{class_name}.{name}" for name in names}
        missing = expected - staged["constants"].keys()
        if missing:
            raise ValueError(
                f"Trait input fields missing from inventory: {sorted(missing)}"
            )
        for name in sorted(names):
            key = f"{module}.{class_name}.{name}"
            record = staged["constants"][key]
            record["input_kind"] = "trait_table"
            units = re.findall(r"\[([^\]]+)\]", record["docstring"])
            record["model_unit"] = units[0] if units else ""
            record["example_file"] = filename
            record["example_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
            record["example_values"] = [
                {
                    "group": (
                        row["name"]
                        if class_name == "SoilMicrobe"
                        else f"{row['source']}_{row['substrate']}"
                    ),
                    "value": row[name],
                }
                for row in rows
            ]
            legacy_name = (
                "enzyme_production" if name.startswith("enzyme_production_") else name
            )
            old_key = (
                f"virtual_ecosystem.models.soil.model_config."
                f"{legacy_class}.{legacy_name}"
            )
            aliases.setdefault(old_key, []).append(key)
    staged["aliases"] = aliases


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
        and current["metadata"].get("inventory_schema_version") == SCHEMA_VERSION
        and "virtual_ecosystem/core/configuration.py"
        in current["metadata"].get("target_files", [])
    ):
        return f"Current inventory already matches VE commit {commit}; no changes."

    verify_installed_source(ve_root)
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
    trait_path = "virtual_ecosystem/models/soil/microbial_groups.py"
    if (ve_root / trait_path).is_file():
        targets.append(trait_path)

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
        add_trait_metadata(ve_root, staged)
        staged["metadata"]["inventory_schema_version"] = SCHEMA_VERSION
        staged_path.write_text(tomli_w.dumps(staged), encoding="utf-8")
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
