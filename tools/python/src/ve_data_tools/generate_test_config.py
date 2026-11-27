"""
---
title: Generate test configurations for the virtual ecosystem.

description: |
    This function generates a TOML configuration using Virtual Ecosystem
    defaults and a temporary microbial-group CSV with fixed values for the
    R soil-CNP tests. Revisit the CSV adaptation when VE's configuration
    format changes.

virtual_ecosystem_module: All

author: Hao Ran Lai

status: final

input_files:

output_files:

package_dependencies:
  - virtual_ecosystem

usage_notes: See function documentation below.
---
"""  # noqa: D205, D212

import csv
from pathlib import Path

from virtual_ecosystem.core.config_builder import generate_configuration


def generate_test_config(mock_config_path: str | Path) -> None:
    """Write a VE-generated TOML config file for testing.

    Microbial ratios are fixed to keep soil-CNP test expectations stable.

    Args:
        mock_config_path: Path where the TOML configuration will be written.

    """
    # Temporary test fixture: revisit when VE changes microbial configuration.
    microbial_groups = [
        {"name": "saprotrophic_fungi", "c_n_ratio": 7.0, "c_p_ratio": 21.0},
        {"name": "ectomycorrhiza", "c_n_ratio": 9.0, "c_p_ratio": 31.0},
        {"name": "arbuscular_mycorrhiza", "c_n_ratio": 11.0, "c_p_ratio": 41.0},
        {"name": "bacteria", "c_n_ratio": 13.0, "c_p_ratio": 51.0},
    ]

    groups_path = Path(mock_config_path).with_name("mock_microbial_groups.csv")
    with groups_path.open("w", newline="", encoding="utf-8") as groups_file:
        writer = csv.DictWriter(
            groups_file, fieldnames=["name", "c_n_ratio", "c_p_ratio"]
        )
        writer.writeheader()
        writer.writerows(microbial_groups)

    models = {
        "core": {},
        "abiotic": {},
        "hydrology": {},
        "soil": {"microbial_group_definition_path": str(groups_path)},
        "plants": {},
        "animal": {},
    }
    generate_configuration(models).export_toml(mock_config_path)
