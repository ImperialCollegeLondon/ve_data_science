"""
---
title: Generate test configurations for the virtual ecosystem.

description: |
    This function writes the generated configuration to
    ``mock_config_path`` and does not return the configuration object. It is
    intended to generate a default-value template, not meant to be used with
    ve_run.

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

from virtual_ecosystem.core.config_builder import generate_configuration


def generate_test_config(mock_config_path):
    """Generate and export a test configuration as a TOML file.

    Parameters
    ----------
    mock_config_path : str or pathlib.Path
        Path where the generated TOML configuration will be written.

    Returns
    -------
    None

    """
    models = {
        "core": {},
        "abiotic": {},
        "hydrology": {},
        "soil": {},
        "plants": {},
        "animal": {},
    }

    config = generate_configuration(models)
    config.export_toml(mock_config_path)
