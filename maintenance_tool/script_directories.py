"""Module to maintain scripts in the analysis directories."""

import re
from pathlib import Path

import yaml


def non_hidden_files(root):
    """Filter function for hidden files."""
    for path in root.glob("*"):
        if not path.name.startswith("."):
            if path.is_file():
                yield path
            else:
                yield from non_hidden_files(path)


def read_script_metadata(file_path: Path) -> dict:
    """Check VE data science script and notebook metadata.

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

    """

    if not file_path.exists():
        raise ValueError("File path not found.")

    # For R Markdown files, can just use the standard YAML parser
    match file_path.suffix.lower():
        case ".rmd":
            pass
            # yaml <- rmarkdown::yaml_front_matter(file_path)
        case ".r":
            # Load the file contents
            with open(file_path) as file:
                content = file.readlines()

            # Locate the YAML document blocks
            document_markers = [
                idx for idx, val in enumerate(content) if val.startswith("#' ---")
            ]
            n_doc_markers = len(document_markers)

            # Check there are two...
            if n_doc_markers != 2:
                raise ValueError(f"Found {n_doc_markers} not 2 YAML metadata markers.")

            # And that the first one is at the start of the file
            if document_markers[0] != 0:
                raise ValueError(
                    "First YAML metadata markers is not at the file start."
                )

            # Extract the block and strip the comments
            yaml_block = content[document_markers[0] : document_markers[1]]
            comment_re = re.compile("^#' ?")
            yaml_block = [comment_re.sub("", line) for line in yaml_block]

            try:
                yaml.safe_load("".join(yaml_block))
            except yaml.error.YAMLError:
                raise

    return yaml
