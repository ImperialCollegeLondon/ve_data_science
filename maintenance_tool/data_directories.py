"""Module to maintain data directories."""

from pathlib import Path
from pprint import pformat
from textwrap import indent
from typing import ClassVar

import yaml
from marshmallow import Schema, validates_schema
from marshmallow.exceptions import ValidationError
from marshmallow_dataclass import dataclass
from marshmallow_dataclass.typing import Url

from maintenance_tool import LOGGER


@dataclass
class ManifestFile:
    """A dataclass for file details in data directory manifests."""

    name: str
    url: Url | None = None
    script: str | None = None
    md5: str | None = None

    @validates_schema
    def validate_url_or_schema(self, data, **kwargs):
        """Further validation of loaded data."""
        if not ((data["url"] is None) ^ (data["script"] is None)):
            raise ValidationError(f"{data['name']}: provide _one_ of url or script")


@dataclass
class Manifest:
    """A validation schema for data directory manifests."""

    directory: str
    files: list[ManifestFile]

    # Type the Schema attribute
    Schema: ClassVar[type[Schema]]


def check_data_directory(directory: Path, repository_root: Path = Path.cwd()) -> bool:
    """Validate a data directory.

    This function checks that a data directory has a MANIFEST.yaml file and that the
    contents of the manifest are congruent with the directory contents and provide
    complete metadata.

    The function logs the validation process and returns True or False to indicate
    success or failure of the validation.

    Arg:
        directory: A path to a data directory.
        repository_root: The repository root, used to check paths in manifest.
    """

    LOGGER.info(f"Checking {directory}")

    if not directory.is_absolute():
        directory = repository_root / directory

    # Do we have a directory to validate
    if not directory.exists():
        LOGGER.error(" - Directory not found")
        return False

    if not directory.is_dir():
        LOGGER.error(" - Directory path is a file not a directory")
        return False

    # Get the directory contents
    actual_files = {
        f.name
        for f in directory.iterdir()
        if not f.name.startswith(".") and f.is_file()
    }

    LOGGER.info(f" - Found {len(actual_files)} files.")

    # Check the MANIFEST.yaml file is present and that it can be read
    if "MANIFEST.yaml" not in actual_files:
        LOGGER.error(" - MANIFEST.yaml not found")
        return False

    with open(directory / "MANIFEST.yaml") as manifest_io:
        try:
            manifest_data: dict = yaml.safe_load(manifest_io)
        except yaml.error.YAMLError as excep:
            LOGGER.error(" - Cannot parse MANIFEST.yaml")
            LOGGER.error(excep)
            return False

    # Does it conform to the Schema
    try:
        manifest: Manifest = Manifest.Schema().load(data=manifest_data)
    except ValidationError as excep:
        LOGGER.error(" - MANIFEST.yaml structure incorrect:")
        LOGGER.error(indent(pformat(excep.messages, indent=1, compact=True), "   "))
        return False

    # Are the contents valid and complete.
    # - These checks should all run before returning to give a complete assessment.
    return_value = True

    # - Does the directory name match the entry in the manifest?
    if (repository_root / manifest.directory) != directory:
        LOGGER.error(
            f" - MANIFEST.yaml directory name does not match: {manifest.directory}"
        )
        return_value = False

    # - Does the manifest list all of the files?
    actual_files.remove("MANIFEST.yaml")
    manifest_files = {entry.name for entry in manifest.files}

    if not manifest_files == actual_files:
        only_in_manifest = manifest_files.difference(actual_files)
        only_in_directory = actual_files.difference(manifest_files)

        LOGGER.error(" - MANIFEST.yaml files do not match directory contents:")

        if only_in_manifest:
            LOGGER.error(f"   Only in manifest: {', '.join(only_in_manifest)}")
        if only_in_directory:
            LOGGER.error(f"   Only in directory: {', '.join(only_in_directory)}")

        return_value = False

    if return_value is True:
        LOGGER.info(" - Directory validated")
    else:
        LOGGER.error(" - Directory manifest contains errors")

    return return_value


def check_all_data_directories(
    data_root: Path = Path("data"), repository_root: Path = Path.cwd()
):
    """Recursively check all data directories."""
    LOGGER.info(f"Checking all data directories within : {data_root}")

    if not data_root.is_absolute():
        data_root = repository_root / data_root

    # Walk the directories. Future note pathlib.Path.walk() in 3.12+
    directories = [path for path in data_root.rglob("*") if path.is_dir()]
    directories.insert(0, data_root)

    for each_dir in directories:
        check_data_directory(directory=each_dir)
