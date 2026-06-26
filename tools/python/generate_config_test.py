"""Module to generate test configurations for the virtual ecosystem."""

import bottleneck as bn
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

    Notes
    -----
    This function writes the generated configuration to
    ``mock_config_path`` and does not return the configuration object. It is
    intended to generate a default-value template, not meant to be used with
    ve_run.

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
