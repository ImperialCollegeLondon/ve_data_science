"""Test the data_directories module."""

from contextlib import nullcontext as does_not_raise
from logging import ERROR, INFO
from pathlib import Path

import pytest
from marshmallow.exceptions import ValidationError

from .conftest import record_found_in_log


@pytest.mark.parametrize(
    argnames="input, outcome, messages",
    argvalues=[
        pytest.param(
            {"name": "file.txt", "url": "https://file.txt"},
            does_not_raise(),
            None,
            id="good_url",
        ),
        pytest.param(
            {"name": "file.txt", "script": "script.py"},
            does_not_raise(),
            None,
            id="good_script",
        ),
        pytest.param(
            {"name": "file.txt", "url": "https://file.txt", "script": "script.py"},
            pytest.raises(ValidationError),
            (("_schema", ["file.txt: provide _one_ of url or script"]),),
            id="bad_url_and_script",
        ),
        pytest.param(
            {"naem": "file.txt", "script": "script.py"},
            pytest.raises(ValidationError),
            (
                ("name", ["Missing data for required field."]),
                ("naem", ["Unknown field."]),
            ),
            id="bad_key_typo",
        ),
    ],
)
def test_ManifestFile(input, outcome, messages):
    """Test the ManifestFile dataclass."""
    from maintenance_tool.data_directories import ManifestFile

    with outcome as excep:
        _ = ManifestFile.Schema().load(input)

    if excep:
        for msg_key, msg_list in messages:
            assert excep.value.messages[msg_key] == msg_list


@pytest.mark.parametrize(
    argnames="directory_path, directory_content, expected_result, expected_log",
    argvalues=(
        pytest.param(
            "data/primary/carbon_use_efficiency",
            (
                (
                    "MANIFEST.yaml",
                    """directory: data/primary/carbon_use_efficiency
files:
  - name: data_file1.csv
    url: https://example.org
    md5: e1e72bc35b6a23f3937d507623c1177f
  - name: data_file2.csv
    url: https://example.org
    md5: e1e72bc35b6a23f3937d507623c1177f
""",
                ),
                ("data_file1.csv", ""),
                ("data_file2.csv", ""),
            ),
            True,
            ((INFO, " - Directory validated"),),
            id="all_good",
        ),
        pytest.param(
            "data/primary/carbon_use_efficiency",
            (
                ("data_file1.csv", ""),
                ("data_file2.csv", ""),
            ),
            False,
            ((ERROR, " - MANIFEST.yaml not found"),),
            id="no_manifest",
        ),
        pytest.param(
            "data/primary/carbon_use_efficiency",
            (
                (
                    "MANIFEST.yaml",
                    """ - this: is\n   not; valid YAML""",
                ),
            ),
            False,
            ((ERROR, " - Cannot parse MANIFEST.yaml"),),
            id="yaml_invalid",
        ),
        pytest.param(
            "data/primary/carbon_use_efficiency",
            (
                (
                    "MANIFEST.yaml",
                    """directory_name: data/primary/carbon_use_efficiency
files:
  - name: data_file1.csv
    url: https://example.org
    md5: e1e72bc35b6a23f3937d507623c1177f
""",
                ),
            ),
            False,
            ((ERROR, " - MANIFEST.yaml structure incorrect:"),),
            id="yaml_directory_misnamed",
        ),
        pytest.param(
            "data/primary/carbon_use_efficiency",
            (
                (
                    "MANIFEST.yaml",
                    """directory: data/primary/carbon_use_efficiency""",
                ),
            ),
            False,
            ((ERROR, " - MANIFEST.yaml structure incorrect:"),),
            id="yaml_no_files",
        ),
        pytest.param(
            "data/primary/carbon_use_efficiency",
            (
                (
                    "MANIFEST.yaml",
                    """directory: data/primary/soil/carbon_use_efficiency
files:
  - name: data_file1.csv
    url: https://example.org
    md5: e1e72bc35b6a23f3937d507623c1177f
                    """,
                ),
                ("data_file1.csv", ""),
            ),
            False,
            (
                (
                    ERROR,
                    " - MANIFEST.yaml directory name does not match: "
                    "data/primary/soil/carbon_use_efficiency",
                ),
            ),
            id="directory_mismatch",
        ),
        pytest.param(
            "data/primary/carbon_use_efficiency",
            (
                (
                    "MANIFEST.yaml",
                    """directory: data/primary/carbon_use_efficiency
files:
  - name: data_file3.csv
    url: https://example.org
    md5: e1e72bc35b6a23f3937d507623c1177f
  - name: data_file2.csv
    url: https://example.org
    md5: e1e72bc35b6a23f3937d507623c1177f
""",
                ),
                ("data_file1.csv", ""),
                ("data_file2.csv", ""),
            ),
            False,
            (
                (ERROR, " - MANIFEST.yaml files do not match directory contents:"),
                (ERROR, "   Only in manifest: data_file3.csv"),
                (ERROR, "   Only in directory: data_file1.csv"),
            ),
            id="file_list_issues",
        ),
        pytest.param(
            "data/primary/carbon_use_efficiency",
            (
                (
                    "MANIFEST.yaml",
                    """directory: data/primary/carbon_use_efficiency
files:
  - name: data_file3.csv
    md5: e1e72bc35b6a23f3937d507623c1177f
""",
                ),
                ("data_file3.csv", ""),
            ),
            False,
            ((ERROR, " - MANIFEST.yaml structure incorrect:"),),
            id="no_url_or_schema",
        ),
    ),
)
def test_check_data_directory(
    caplog, tmp_path, directory_path, directory_content, expected_result, expected_log
):
    """Test the check_data_directory function."""

    from maintenance_tool.data_directories import check_data_directory

    # Deploy test payload to a temporary directory
    data_relative_path = Path(directory_path)
    test_dir = tmp_path / data_relative_path
    test_dir.mkdir(parents=True)

    for file_name, file_contents in directory_content:
        with open(test_dir / file_name, "w") as test_file:
            test_file.write(file_contents)

    # Test the function
    result = check_data_directory(
        directory=data_relative_path, repository_root=tmp_path
    )

    assert result == expected_result

    for entry in expected_log:
        assert record_found_in_log(caplog, entry)
