"""Module to maintain scripts in the analysis directories."""

import ast
import re
from dataclasses import field
from pathlib import Path
from typing import ClassVar

import yaml
from marshmallow import Schema, ValidationError
from marshmallow_dataclass import dataclass
from yaml.error import YAMLError

from maintenance_tool import LOGGER, REPOSITORY_ROOT


@dataclass
class ScriptFileDetails:
    """Data class and schema for input and output file data."""

    name: str
    path: str
    description: str


@dataclass
class ScriptMetadata:
    """Data class and schema for required script metadata."""

    title: str
    description: str
    author: list[str]
    virtual_ecosystem_module: list[str]
    status: str
    package_dependencies: list[str]
    usage_notes: str
    input_files: list[ScriptFileDetails] = field(default_factory=list)
    output_files: list[ScriptFileDetails] = field(default_factory=list)

    # Type the Schema attribute
    Schema: ClassVar[type[Schema]]


def non_hidden_files(root):
    """Filter function for hidden files."""
    for path in root.glob("*"):
        if not path.name.startswith("."):
            if path.is_file():
                yield path
            else:
                yield from non_hidden_files(path)


def validate_script_metadata(file_path: Path) -> ScriptMetadata:
    """Validate VE data science script and notebook metadata.

    Checks that a script file or notebook contains expected metadata. It raises an
    error if the file is missing metadata, if the metadata is badly formatted or if
    it contains unexpected values.

    Arg:
        file_path The path to the file to be checked

    Return:
        The function returns the YAML metadata if it can be read cleanly.

    Raises:
        ValueError: If the YAML block cannot be extracted from the file successfully.
        YAMLError: if the YAML block cannot be read correctly.
        ValidationError: if the YAML contents does not match the ScriptMetadata schema.

    """

    if not file_path.exists():
        raise ValueError("File path not found.")

    match file_path.suffix.lower():
        case ".rmd":
            loader = read_markdown_notebook_metadata
        case ".r":
            loader = read_r_script_metadata
        case ".py":
            loader = read_py_script_metadata
        case ".md":
            loader = read_markdown_notebook_metadata

    try:
        yaml_content = loader(file_path=file_path)
    except (ValueError, YAMLError):
        raise

    # This is because yaml imports empty maps as None - this might be more cleanly
    # tackled with some custom logic in the schema. I think the tag has to be present,
    # but might be empty.
    for allowed_empty in ("input_files", "output_files"):
        if allowed_empty in yaml_content and yaml_content[allowed_empty] is None:
            yaml_content[allowed_empty] = []

    try:
        metadata = ScriptMetadata.Schema().load(yaml_content)
    except ValidationError as excep:
        raise ValueError(f"Could not validate metadata in {file_path}" + str(excep))

    return metadata


def read_r_script_metadata(file_path: Path) -> dict:
    """Read metadata from an R file.

    The metadata should be provided as a set of commented lines at the start of the file
    starting and ending with `#| ---`. The lines in between should be commented `#| `
    and everything to the right of that terminal space is expected to be valid YAML.

    It might be cleaner to:
    * Have this as a multiline comment, but R doesn't have such things.
    * Have this as a named string in the file, but then we need to parse and evaluate
      the code to get the contents.

    Args:
        file_path: The path of the R code file

    """

    # Load the file contents
    with open(file_path) as file:
        content = file.readlines()

    yaml_document_marker = "#| ---\n"

    # Locate the YAML document blocks
    document_markers = [
        idx for idx, val in enumerate(content) if val == yaml_document_marker
    ]

    n_doc_markers = len(document_markers)

    # Do we have at least two markers?
    if n_doc_markers < 2:
        raise ValueError("YAML block not contained within document markers.")

    # And that the first one is at the start of the file
    if document_markers[0] != 0:
        raise ValueError("First YAML metadata markers is not at the file start.")

    # Extract the block. This intentionally omits the trailing document marker, which
    # technically indicates the start of a second document.
    yaml_lines = content[document_markers[0] : document_markers[1]]

    # Check for consistent YAML marker use
    marked_correctly = [line.startswith("#| ") or line == "#|\n" for line in yaml_lines]
    if not all(marked_correctly):
        raise ValueError("Inconsistent use of YAML line comment within YAML block.")

    # Strip the comment line markers and compile into a YAML document - need to escape
    # pipe character in regex as it is used as a conditional
    comment_re = re.compile("^#\\| ?")
    yaml_lines = [comment_re.sub("", line) for line in yaml_lines]
    yaml_document = "".join(yaml_lines)

    try:
        yaml_contents = yaml.safe_load(yaml_document)
    except YAMLError:
        raise

    return yaml_contents


def read_py_script_metadata(file_path: Path) -> dict:
    """Read metadata from a Python file.

    The metadata should be provided within the body of the file docstring. It is parsed
    using the ast module.

    Args:
        file_path: The path of the python code file

    """

    # Get the AST representation of the file and extract the docstring
    with open(file_path) as file:
        file_ast = ast.parse(file.read())
        contents = ast.get_docstring(file_ast, clean=False)

    if contents is None:
        raise ValueError("Missing docstring in python script")

    # Strip the trailing document marker, which technically indicates the start of a
    # second YAML document
    contents = re.sub("[\n-]+$", "\n", contents)

    # Try and parse the YAML document
    try:
        yaml_contents = yaml.safe_load(contents)
    except YAMLError:
        raise

    return yaml_contents


def read_markdown_notebook_metadata(file_path: Path) -> dict:
    """Read metadata from an markdown document.

    The metadata should be provided as a YAML block at the start of the markdown
    document. This handles both MyST and R Markdown files, both of which already use
    YAML frontmatter: the metadata for the repo must be in a separate `ve_data_science`
    section of that YAML.

    Args:
        file_path: The path of the markdown file.

    """

    # Load the file contents
    with open(file_path) as file:
        content = file.readlines()

    # Locate the YAML document blocks
    document_markers = [idx for idx, val in enumerate(content) if val.startswith("---")]
    n_doc_markers = len(document_markers)

    # Check there are two...
    if n_doc_markers != 2:
        raise ValueError(f"Found {n_doc_markers} not 2 YAML metadata markers.")

    # And that the first one is at the start of the file
    if document_markers[0] != 0:
        raise ValueError("First YAML metadata markers is not at the file start.")

    # Extract the block
    yaml_block = content[document_markers[0] : document_markers[1]]

    try:
        yaml_contents = yaml.safe_load("".join(yaml_block))
    except YAMLError:
        raise

    # Look for and return the ve_data_science metadata
    if "ve_data_science" not in yaml_contents:
        raise ValueError(f"ve_data_science metadata not found in {file_path}")

    return yaml_contents["ve_data_science"]


def check_script_directory(
    directory: Path,
    check_file_locations: bool = True,
    repository_root: Path = REPOSITORY_ROOT,
    ignore_files: list[str] = ["__init__.py", "README.md"],
) -> bool:
    """Validate a script directory.

    This function checks that a directory contains script files that provide
    valid metadata.

    The function logs the validation process and returns True or False to indicate
    success or failure of the validation.

    Arg:
        directory: A path to a data directory.
        repository_root: The repository root, used to check paths in manifest.
    """

    LOGGER.info(f"Script checking {directory}")

    if not directory.is_absolute():
        directory = repository_root / directory

    # Do we have a directory to validate
    if not directory.exists():
        LOGGER.error(" X Directory not found")
        return False

    if not directory.is_dir():
        LOGGER.error(" X Directory path is a file not a directory")
        return False

    # Get the directory contents and partition into script files and other files
    actual_files = {
        f for f in directory.iterdir() if not f.name.startswith(".") and f.is_file()
    }
    script_files = {
        f
        for f in actual_files
        if f.suffix.lower() in (".r", ".py", ".md", ".rmd")
        and f.name not in ignore_files
    }

    # TODO - anything on other files?
    # other_files = actual_files - script_files

    LOGGER.info(
        f" - Found {len(actual_files)} files including {len(script_files)} script files"
    )

    # Check each of the script files, recording if the process has logged errors
    return_value = True

    for file in script_files:
        # Validate the script metadata
        try:
            yaml_contents = validate_script_metadata(file_path=file)
        except (ValueError, YAMLError, ValidationError) as excep:
            LOGGER.error(
                f"   X {file.name} did not pass metadata validation.\n" + str(excep)
            )
            return_value = False
            continue

        LOGGER.info(f"   - {file.name} contains valid metadata")

        if check_file_locations:
            # Validate any named input and output paths
            inputs = [Path(file.path) / file.name for file in yaml_contents.input_files]

            for file in inputs:
                if not file.exists():
                    LOGGER.error(f"     X Input file not found: {file!s}")
                    return_value = False
                else:
                    LOGGER.error(f"     - Input file found: {file!s}")

            outputs = [
                Path(file.path) / file.name for file in yaml_contents.output_files
            ]

            for file in outputs:
                if not file.exists():
                    LOGGER.error(f"     X Output file not found: {file!s}")
                    return_value = False
                else:
                    LOGGER.error(f"     - Output file found: {file!s}")

            # TODO - other validation? required packages in requirement/pyproject.toml

    return return_value
