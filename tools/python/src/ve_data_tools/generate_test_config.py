"""
---
title: Generate test configurations for the virtual ecosystem.

description: |
    This function writes a minimal TOML configuration to
    ``mock_config_path``. It reproduces only the fields used by the R tests
    (soil-CNP pool derivation) using default values from VE, so the tests
    remain stable regardless of changes to ``virtual_ecosystem`` or
    ``pyrealm`` internals.

virtual_ecosystem_module: All

author: Hao Ran Lai

status: final

input_files:

output_files:

package_dependencies:
  - tomli-w

usage_notes: See function documentation below.
---
"""  # noqa: D205, D212

from pathlib import Path

import tomli_w


def generate_test_config(mock_config_path: str | Path) -> None:
    """Write a minimal VE-compatible TOML config file for testing.

    Only the fields accessed by the R soil-CNP tests are included.
    Values match Virtual Ecosystem defaults to keep test expectations stable.

    Args:
        mock_config_path: Path where the TOML configuration will be written.

    """
    _MICROBIAL_GROUPS = [
        "saprotrophic_fungi",
        "ectomycorrhiza",
        "arbuscular_mycorrhiza",
        "bacteria",
    ]

    config: dict = {
        "core": {
            "constants": {
                "microbial_simulation_depth": 0.25,
            },
        },
        "abiotic": {
            "constants": {
                "bulk_density_soil": 1175.0,
            },
        },
        "soil": {
            "microbial_group_definition": [
                {"name": name, "c_n_ratio": 5.2, "c_p_ratio": 16.0}
                for name in _MICROBIAL_GROUPS
            ],
        },
    }

    Path(mock_config_path).write_bytes(tomli_w.dumps(config).encode())
