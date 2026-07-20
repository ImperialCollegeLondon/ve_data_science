"""Static analysis tool to find usages of configuration constants across model files.

This module uses `jedi` to statically analyse Python source files from the
``virtual_ecosystem`` project, identifying every place in the codebase where a
configuration constant (an attribute of a class that inherits from
``Configuration``) is referenced.  Results are written to a TOML file, keyed by
the fully-qualified constant name, and include the caller's fully-qualified name
and docstring for each reference site.

Key assumptions
---------------
- Configuration classes are identified by the presence of ``"(Configuration)"``
  in the class definition line.  Classes that inherit from ``Configuration``
  indirectly (i.e. through an intermediate base class) will **not** be detected.
- Each class attribute is expected to appear exactly once as a definition; the
  first result returned by ``jedi.Script.get_references`` with
  ``is_definition() == True`` is treated as the canonical definition, and all
  remaining results are treated as usage sites.
- ``project_root`` must point to a directory that ``jedi`` can use as the project
  root (i.e. the root of the installed/editable package source tree) so that
  cross-file references are resolved correctly. It is expected that you clone
  the `virtual_ecosystem` repo to a sibling folder as the `ve_data_science` repo.
"""

from pathlib import Path

import jedi
import tomli_w


def get_constant_references(
    target_file_path,
    out_path,
    project_root=None,
):
    """Find usages of configuration constants in target file(s) and write to TOML.

    Scans each target file for classes that inherit from ``Configuration``,
    collects every attribute defined on those classes, and uses ``jedi`` to find
    all reference sites across the project.  All results are merged into a single
    TOML file at ``out_path``.

    Parameters
    ----------
    target_file_path : str, Path, or list of str/Path
        Path(s) to the Python source file(s) to analyse, given relative to
        ``project_root``. For example, if ``project_root`` is
        ``/path/to/virtual_ecosystem``, then pass
        ``virtual_ecosystem/models/soil/model_config.py``. Accepts a single path
        or a list of paths; results are merged into one output.
    out_path : str or Path
        Destination path for the TOML output file.  The file is always overwritten.
    project_root : str or Path, optional
        Root directory of the ``virtual_ecosystem`` repository, passed to
        ``jedi.Project`` so that cross-file name resolution works correctly.
        Defaults to ``Path("../virtual_ecosystem").resolve()``, which resolves
        relative to the current working directory and assumes the ``virtual_ecosystem``
        repo is a sibling of ``ve_data_science``.

    Returns
    -------
    dict
        Mapping of fully-qualified constant names (e.g.
        ``"virtual_ecosystem.models.soil.soil_model.SoilConsts.Dzs"``) to dicts
        with the following keys:

        ``name``
            The bare attribute name.
        ``description``
            The jedi description string for the definition site.
        ``docstring``
            The docstring attached to the definition, if any.
        ``referenced_in``
            List of dicts, each with ``caller`` (fully-qualified name of the
            enclosing scope) and ``docstring`` (docstring of that scope).

    Examples
    --------
    Analyse a single file and write results to ``output.toml``:

    >>> refs = get_constant_references(
    ...     target_file_path="virtual_ecosystem/models/soil/model_config.py",
    ...     out_path="output.toml",
    ... )

    Analyse several model configuration files in one pass:

    >>> config_files = [
    ...     "virtual_ecosystem/models/soil/model_config.py",
    ...     "virtual_ecosystem/models/plants/model_config.py",
    ...     "virtual_ecosystem/models/animals/model_config.py",
    ... ]
    >>> refs = get_constant_references(
    ...     target_file_path=config_files,
    ...     out_path="all_constants.toml",
    ...     project_root="../virtual_ecosystem",
    ... )

    From R via reticulate, pass a character vector for multiple files:

    .. code-block:: r

        library(reticulate)
        tool <- import_from_path("constant_usage_tool", path = "analysis/soil/llm")
        config_files <- c(
            "virtual_ecosystem/models/soil/model_config.py",
            "virtual_ecosystem/models/plants/model_config.py"
        )
        refs <- tool$get_constant_references(
            target_file_path = config_files,
            out_path = "all_constants.toml"
        )

    """
    if project_root is None:
        project_root = Path("../virtual_ecosystem").resolve()

    project_root = Path(project_root)
    out_path = Path(out_path)

    # Normalise to a list so the loop below works for both single and multiple paths
    if isinstance(target_file_path, (str, Path)):
        target_file_paths = [Path(target_file_path)]
    else:
        target_file_paths = [Path(p) for p in target_file_path]

    project = jedi.Project(project_root)

    # Collect references across all target files into a single dictionary
    script_references = {}

    for file_path in target_file_paths:
        # Resolve file path relative to project_root if it's relative
        if not file_path.is_absolute():
            full_file_path = project_root / file_path
        else:
            full_file_path = file_path

        # Initialize a jedi Script with the source, path, and project scope
        with open(full_file_path) as f:
            source_code = f.read()

        script = jedi.Script(code=source_code, path=full_file_path, project=project)

        # Get the top level names in the config - only some of these are config objects
        script_names = script.get_names()

        for name in script_names:
            # Detect Configuration classes - there must be a way to do this from the name object
            if (name.type != "class") or (
                "(Configuration)" not in name.get_line_code()
            ):
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
                reference_list = []
                for ref in references:
                    parent = ref.parent()
                    # jedi may return None for full_name or docstring; convert to empty
                    # string to ensure TOML serialization doesn't fail with NoneType
                    reference_list.append(
                        dict(
                            caller=parent.full_name or "",
                            docstring=parent.docstring() or "",
                        )
                    )

                # Save the references and attribute details.
                # Use 'or ""' for all jedi-returned fields to handle None values,
                # which tomli_w cannot serialize to TOML format.
                script_references[definition.full_name] = dict(
                    name=definition.name or "",
                    description=definition.description or "",
                    docstring=definition.docstring() or "",
                    referenced_in=reference_list,
                )

    # Save output as TOML
    with open(out_path, "wb") as f:
        tomli_w.dump(script_references, f)

    return script_references
