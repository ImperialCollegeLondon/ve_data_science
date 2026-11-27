"""Offline checks for safe VE inventory refresh."""

import hashlib
import importlib.util
import sys
import tomllib
from dataclasses import fields
from pathlib import Path
from unittest.mock import patch

import pytest

SCRIPTS = (
    Path(__file__).resolve().parents[3] / ".github/skills/ve-constant-search/scripts"
)
spec = importlib.util.spec_from_file_location(
    "refresh_constant_metadata",
    SCRIPTS / "refresh_constant_metadata.py",
)
refresh = importlib.util.module_from_spec(spec)
spec.loader.exec_module(refresh)


def test_matching_commit_skips_scan(tmp_path):
    """A current inventory is not regenerated or overwritten."""
    ve = tmp_path / "ve"
    (ve / "virtual_ecosystem").mkdir(parents=True)
    asset = tmp_path / "inventory.toml"
    asset.write_text(
        '[metadata]\nproject_commit = "abc"\nproject_source_modified = false\n'
        "inventory_schema_version = 2\n"
        'target_files = ["virtual_ecosystem/core/configuration.py"]\n',
        encoding="utf-8",
    )
    with (
        patch.object(refresh, "ASSET", asset),
        patch.object(refresh, "git", side_effect=["abc", ""]),
    ):
        assert "no changes" in refresh.refresh(ve)
    assert 'project_commit = "abc"' in asset.read_text(encoding="utf-8")


def test_matching_commit_with_old_schema_requires_refresh(tmp_path):
    """The pre-trait inventory cannot skip regeneration at a matching commit."""
    ve = tmp_path / "ve"
    (ve / "virtual_ecosystem").mkdir(parents=True)
    asset = tmp_path / "inventory.toml"
    asset.write_text(
        '[metadata]\nproject_commit = "abc"\nproject_source_modified = false\n'
        'target_files = ["virtual_ecosystem/core/configuration.py"]\n',
        encoding="utf-8",
    )
    with (
        patch.object(refresh, "ASSET", asset),
        patch.object(refresh, "git", side_effect=["abc", ""]),
        patch.object(
            refresh,
            "verify_installed_source",
            side_effect=ValueError("matching environment required"),
        ),
    ):
        with pytest.raises(ValueError, match="matching environment required"):
            refresh.refresh(ve)


def test_asset_is_packaged_with_skill():
    """The maintained inventory is part of the skill and includes shared fields."""

    assert refresh.ASSET.parent == SCRIPTS.parent / "assets"
    inventory = tomllib.loads(refresh.ASSET.read_text(encoding="utf-8"))
    assert (
        "virtual_ecosystem/core/configuration.py"
        in inventory["metadata"]["target_files"]
    )
    for name in (
        "ModelConfigurationRoot.static",
        "DisturbanceConfigurationRoot.run_at",
        "DisturbanceConfigurationRoot.run_every",
        "DisturbanceConfigurationRoot.priority",
    ):
        assert f"virtual_ecosystem.core.configuration.{name}" in inventory["constants"]


def test_dirty_source_blocks_apply(tmp_path):
    """Never replace inventory when the VE source is dirty."""
    ve = tmp_path / "ve"
    (ve / "virtual_ecosystem").mkdir(parents=True)
    with patch.object(refresh, "git", side_effect=["abc", " M source.py"]):
        with pytest.raises(ValueError, match="uncommitted changes"):
            refresh.refresh(ve, apply=True)


def test_microbe_inventory_matches_validated_inputs():
    """All CSV inputs, but no internal/computed fields, survive discovery."""
    from virtual_ecosystem.models.soil.microbial_groups import SoilMicrobe

    inventory = tomllib.loads(refresh.ASSET.read_text(encoding="utf-8"))
    prefix = f"{SoilMicrobe.__module__}.SoilMicrobe."
    records = {
        key.removeprefix(prefix): value
        for key, value in inventory["constants"].items()
        if key.startswith(prefix)
    }
    assert records.keys() == {item.name for item in fields(SoilMicrobe) if item.init}
    assert len(records) == 22
    assert all(record["required"] for record in records.values())
    assert all(record["default_expression"] == "" for record in records.values())
    assert records["turnover_rate"]["model_unit"] == "day-1"
    assert {
        row["group"]: row["value"] for row in records["turnover_rate"]["example_values"]
    } == {
        "bacteria": "0.005",
        "saprotrophic_fungi": "0.002",
        "arbuscular_mycorrhiza": "0.0012",
        "ectomycorrhiza": "0.0012",
    }
    aliases = inventory["aliases"]
    assert set(
        aliases[
            "virtual_ecosystem.models.soil.model_config."
            "SoilMicrobialGroup.enzyme_production"
        ]
    ) == {prefix + "enzyme_production_pom", prefix + "enzyme_production_maom"}


def test_discovery_keeps_configuration_and_validated_dataclass():
    """Ordinary runtime dataclasses do not become trait schemas."""
    sys.path.insert(0, str(refresh.TOOL_DIR))
    from constant_usage_tool import _configuration_classes

    names = _configuration_classes("virtual_ecosystem.models.soil.microbial_groups")
    assert set(names) == {"SoilMicrobe", "SoilEnzyme"}
    names = _configuration_classes("virtual_ecosystem.models.soil.model_config")
    assert "SoilConstants" in names
    assert "SoilConfiguration" in names


def test_generated_microbe_records_exclude_internal_fields(tmp_path):
    """Generation filters InitVars/computed fields and keeps required inputs."""
    from virtual_ecosystem.models.soil import microbial_groups

    sys.path.insert(0, str(refresh.TOOL_DIR))
    import constant_usage_tool

    source = Path(microbial_groups.__file__).parents[3]
    with patch.object(constant_usage_tool, "_get_script") as script:
        script.return_value.get_references.return_value = []
        generated = constant_usage_tool.get_constant_references(
            "virtual_ecosystem/models/soil/microbial_groups.py",
            tmp_path / "inventory.toml",
            source,
        )
    records = {
        key: value
        for key, value in generated["constants"].items()
        if ".SoilMicrobe." in key
    }
    assert len(records) == 22
    assert not any(
        name.endswith((".enzyme_classes", ".synthesis_nutrient_ratios"))
        for name in records
    )
    assert all(record["required"] for record in records.values())
    assert all(not record["default_expression"] for record in records.values())


def test_installed_source_mismatch_is_rejected(tmp_path):
    """Refreshing cannot mask a released/pinned environment mismatch."""
    (tmp_path / "virtual_ecosystem").mkdir()
    with pytest.raises(ValueError, match="does not match"):
        refresh.verify_installed_source(tmp_path)


def test_trait_examples_require_complete_inventory(tmp_path):
    """Example CSV headers, hashes and input coverage are checked."""
    from virtual_ecosystem.models.soil import microbial_groups

    source = Path(microbial_groups.__file__).parents[3]
    # Git installations include packaged example CSVs beside the Python sources.
    staged = {"constants": {}}
    with pytest.raises(ValueError, match="Trait input fields missing"):
        refresh.add_trait_metadata(source, staged)
    inventory = tomllib.loads(refresh.ASSET.read_text(encoding="utf-8"))
    record = inventory["constants"][
        f"{microbial_groups.__name__}.SoilMicrobe.c_n_ratio"
    ]
    assert (
        record["example_sha256"]
        == hashlib.sha256((source / record["example_file"]).read_bytes()).hexdigest()
    )
