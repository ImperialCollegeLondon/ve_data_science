"""Static analysis tool using jedi to find usage of constants."""

from pathlib import Path

import jedi
import tomli_w


def get_constant_references(
    target_file_path,
    out_path,
    project_root=None,
):
    """Find usages of configuration constants in a target file and write to TOML.

    Parameters
    ----------
    target_file_path : str or Path
        Path to the Python source file to analyse (e.g. a model_config.py).
    out_path : str or Path
        Destination path for the TOML output file.
    project_root : str or Path, optional
        Root of the virtual_ecosystem project. Defaults to
        ``Path("../virtual_ecosystem").resolve()``.

    Returns
    -------
    dict
        Mapping of fully-qualified constant names to their reference details.
    """
    if project_root is None:
        project_root = Path("../virtual_ecosystem").resolve()

    project_root = Path(project_root)
    target_file_path = Path(target_file_path)
    out_path = Path(out_path)

    project = jedi.Project(project_root)

    # Initialize a jedi Script with the source, path, and project scope
    with open(target_file_path) as f:
        source_code = f.read()

    script = jedi.Script(code=source_code, path=target_file_path, project=project)

    # Get the top level names in the config - only some of these are config objects
    script_names = script.get_names()

    # Collect references in this file into a dictionary
    script_references = {}

    for name in script_names:
        # Detect Configuration classes - there must be a way to do this from the name object
        if "(Configuration)" not in name.get_line_code():
            continue

        # Get the config class attributes
        attributes = name.defined_names()

        # Loop over attributes
        for attr in attributes:
            # Look for references to the attribute given the location in the file
            references = script.get_references(line=attr.line, column=attr.column)

            # Split into definition and reference and get reference details.
            references.sort(key=lambda x: not x.is_definition())
            definition = references.pop(0)
            reference_list = [
                dict(caller=ref.parent().full_name, docstring=ref.parent().docstring())
                for ref in references
            ]

            # Save the references and attribute details
            script_references[definition.full_name] = dict(
                name=definition.name,
                description=definition.description,
                docstring=definition.docstring(),
                referenced_in=reference_list,
            )

    # Save output as TOML
    with open(out_path, "wb") as f:
        tomli_w.dump(script_references, f)

    return script_references
