"""Tests for the VE-generated R test configuration."""

import csv
import tomllib
from pathlib import Path

from ve_data_tools.generate_test_config import generate_test_config


def test_generate_test_config(tmp_path: Path) -> None:
    """Export VE defaults and a fixed microbial-groups fixture."""
    config_path = tmp_path / "mock_config.toml"
    generate_test_config(config_path)

    with config_path.open("rb") as config_file:
        config = tomllib.load(config_file)
    assert set(config) == {"core", "abiotic", "hydrology", "soil", "plants", "animal"}
    assert config["core"]["constants"]["microbial_simulation_depth"] == 0.25
    assert config["abiotic"]["constants"]["bulk_density_soil"] == 1175.0
    groups_path = Path(config["soil"]["microbial_group_definition_path"])
    assert groups_path == tmp_path / "mock_microbial_groups.csv"
    with groups_path.open(newline="", encoding="utf-8") as groups_file:
        groups = list(csv.DictReader(groups_file))
    assert [
        (group["name"], group["c_n_ratio"], group["c_p_ratio"]) for group in groups
    ] == [
        ("saprotrophic_fungi", "7.0", "21.0"),
        ("ectomycorrhiza", "9.0", "31.0"),
        ("arbuscular_mycorrhiza", "11.0", "41.0"),
        ("bacteria", "13.0", "51.0"),
    ]
