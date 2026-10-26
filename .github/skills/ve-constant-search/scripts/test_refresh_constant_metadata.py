"""Offline checks for safe VE inventory refresh."""

import importlib.util
import tomllib
from pathlib import Path
from unittest.mock import patch

import pytest

spec = importlib.util.spec_from_file_location(
    "refresh_constant_metadata",
    Path(__file__).with_name("refresh_constant_metadata.py"),
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
        'target_files = ["virtual_ecosystem/core/configuration.py"]\n',
        encoding="utf-8",
    )
    with (
        patch.object(refresh, "ASSET", asset),
        patch.object(refresh, "git", side_effect=["abc", ""]),
    ):
        assert "no changes" in refresh.refresh(ve)
    assert 'project_commit = "abc"' in asset.read_text(encoding="utf-8")


def test_asset_is_packaged_with_skill():
    """The maintained inventory is part of the skill and includes shared fields."""

    assert refresh.ASSET.parent == Path(__file__).parents[1] / "assets"
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
