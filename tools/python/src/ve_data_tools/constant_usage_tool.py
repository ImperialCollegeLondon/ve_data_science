"""Find references to configuration constants in Virtual Ecosystem code.

This module locates where configuration constants are declared and where they
are referenced, then classifies each reference site by usage context.

Approach:
    1. Import-based class detection: identify subclasses of
       ``Configuration`` (including indirect inheritance via MRO).
    2. AST-based attribute and usage analysis: enumerate declared attributes
       and classify reference contexts from syntax.
    3. Jedi reference resolution: find cross-file reference sites.

Usage classification:
    ``computation``:
        Constant is used directly in an expression in the caller.
    ``kwarg_forward`` / ``positional_forward``:
        Constant is forwarded unchanged into another call. The receiving
        callable is stored in ``consumer``.
    ``derived_forward``:
        A derived value (for example ``1 / constants.x``) is forwarded. The
        consumer cannot be resolved reliably, so the site is flagged.
    ``validator``:
        Reference occurs inside a pydantic validator on the owning class.

    Only ``derived_forward`` sites require manual review.

Keying:
    Records are keyed as ``module.Class.attribute`` rather than using
    ``jedi`` ``full_name`` values, which can be inconsistent, duplicated or
    missing.

Output structure:
    Function docstrings are stored once in a top-level ``functions`` table and
    referenced by qualified name from each site.

Test references:
    ``include_tests`` controls whether sites inside ``tests`` directories are
    retained. Because ``jedi`` follows the import graph, test coverage is
    best-effort rather than a guaranteed full textual inventory.

"""

from __future__ import annotations

import ast
import importlib
import subprocess
import sys
import textwrap
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import jedi
import tomli_w

# A frozenset is an immutable set. Membership tests such as ``name in ...`` are
# fast, and no later code can change this fixed group of decorator names.
VALIDATOR_DECORATORS = frozenset(
    {"field_validator", "model_validator", "validator", "root_validator"}
)


@dataclass
class ConstantReference:
    """Represent one reference site for a configuration constant.

    Attributes:
        file: Path to the file containing the reference.
        line: One-based line number of the reference.
        column: Zero-based column position of the reference token.
        caller: Qualified name of the enclosing scope using the constant.
        usage_kind: Classification label for how the constant is used.
        consumer: Qualified name of the receiving callable when forwarded.
        forwarded_as: Parameter name or positional index used for forwarding.
        expression: Source line at the reference site for context.

    """

    file: str
    line: int
    column: int
    caller: str
    usage_kind: str
    consumer: str = ""
    forwarded_as: str = ""
    expression: str = ""

    def to_dict(self) -> dict[str, Any]:
        """Convert the reference record to a TOML-serializable mapping.

        Returns:
            Dictionary of dataclass fields and values.

        """
        return dict(self.__dict__)


@dataclass
class ConstantRecord:
    """Store metadata and references for one configuration constant.

    Attributes:
        name: Unqualified constant attribute name.
        qualified_name: Fully qualified key in ``module.Class.attribute`` form.
        module: Dotted Python module path for the declaring class.
        class_name: Name of the class that declares the constant.
        base_classes: Immediate base class names for the declaring class.
        declaration: Source declaration line for the constant.
        docstring: Attribute-level documentation text.
        default_expression: Source expression for the default value.
        type_annotation: Source expression for the type annotation.
        file: Project-relative file path where the constant is declared.
        line: One-based declaration line number.
        referenced_in: Collected reference sites for this constant.

    """

    name: str
    qualified_name: str
    module: str
    class_name: str
    base_classes: list[str]
    declaration: str
    docstring: str
    default_expression: str
    type_annotation: str
    file: str
    line: int
    referenced_in: list[ConstantReference] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        """Convert the constant record to a TOML-serializable mapping.

        Returns:
            Dictionary representation with nested reference entries converted.

        """
        data = {k: v for k, v in self.__dict__.items() if k != "referenced_in"}
        data["referenced_in"] = [ref.to_dict() for ref in self.referenced_in]
        return data


def _git_commit(project_root: Path) -> str:
    """Return the current commit hash for the analyzed project.

    Args:
        project_root: Root path of the project repository.

    Returns:
        Commit hash string, or an empty string if unavailable.

    """
    return _git(project_root, "rev-parse", "HEAD")


def _git(project_root: Path, *arguments: str) -> str:
    """Run a git command in the project and return trimmed stdout.

    Args:
        project_root: Root path of the project repository.
        *arguments: Positional arguments passed to ``git``.

    Returns:
        Command stdout with surrounding whitespace removed. Returns an empty
        string if git is unavailable or the command fails.

    """
    try:
        result = subprocess.run(
            ["git", *arguments],
            cwd=project_root,
            capture_output=True,
            text=True,
            check=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""

    return result.stdout.strip()


def _source_is_modified(project_root: Path, package_directory: str) -> bool:
    """Report whether analyzed Python sources contain uncommitted changes.

    Args:
        project_root: Root path of the project repository.
        package_directory: Relative package directory to inspect in git status.

    Returns:
        ``True`` if any ``.py`` file under ``package_directory`` is modified,
        added, deleted, or renamed in the working tree; otherwise ``False``.

    """
    status = _git(project_root, "status", "--porcelain", "--", package_directory)
    if not status:
        return False

    for line in status.splitlines():
        # Porcelain format is a two-character status followed by the path.
        path = line[3:].strip().strip('"')
        # Renames are reported as "old -> new"; the destination is what matters.
        _, separator, destination = path.partition(" -> ")
        if separator:
            path = destination

        if path.endswith(".py"):
            return True

    return False


def _upstream_state(project_root: Path) -> dict[str, Any]:
    """Summarize divergence between ``HEAD`` and its upstream branch.

    Args:
        project_root: Root path of the project repository.

    Returns:
        Dictionary containing upstream name, sync flag, and ahead/behind counts.
        If no upstream is configured, returns empty upstream and ``False`` sync.

    """
    upstream = _git(project_root, "rev-parse", "--abbrev-ref", "@{upstream}")
    if not upstream:
        return {"project_upstream": "", "project_upstream_synced": False}

    counts = _git(
        project_root, "rev-list", "--left-right", "--count", "HEAD...@{upstream}"
    )
    ahead, _, behind = counts.partition("\t")

    return {
        "project_upstream": upstream,
        "project_upstream_synced": counts != "" and ahead.strip() == "0",
        "project_commits_ahead_of_upstream": int(ahead) if ahead.strip() else 0,
        "project_commits_behind_upstream": int(behind.strip()) if behind.strip() else 0,
    }


def _project_provenance(
    project_root: Path, package_directory: str = "virtual_ecosystem"
) -> dict[str, Any]:
    """Build provenance metadata for the analyzed source tree.

    Args:
        project_root: Root path of the analyzed repository.
        package_directory: Relative directory containing analyzed Python
            package sources. Changes outside this directory are ignored for
            source-modified checks.

    Returns:
        Dictionary with version, commit, branch, describe output, source
        modification status, and upstream divergence fields.

    """
    version = ""
    pyproject = project_root / "pyproject.toml"
    if pyproject.is_file():
        for line in pyproject.read_text(encoding="utf-8").splitlines():
            stripped = line.strip()
            if stripped.startswith("version"):
                _, _, raw = stripped.partition("=")
                version = raw.strip().strip('"').strip("'")
                break

    provenance = {
        "project_version": version,
        "project_commit": _git_commit(project_root),
        "project_branch": _git(project_root, "rev-parse", "--abbrev-ref", "HEAD"),
        "project_describe": _git(project_root, "describe", "--tags", "--always"),
        "project_source_modified": _source_is_modified(project_root, package_directory),
    }
    provenance.update(_upstream_state(project_root))

    return provenance


def _module_name_from_path(relative_path: Path) -> str:
    """Convert a project-relative ``.py`` path to a dotted module name.

    Args:
        relative_path: Project-relative source file path.

    Returns:
        Dotted module path without file suffix.

    """
    parts = relative_path.with_suffix("").parts
    return ".".join(parts)


def _configuration_classes(module_name: str) -> dict[str, list[str]]:
    """Find configuration subclasses defined directly in a module.

    Args:
        module_name: Dotted module name importable from ``sys.path``.

    Returns:
        Mapping from class name to a list of immediate base class names for
        classes that subclass ``Configuration`` (including indirect inheritance)
        and are defined in ``module_name``.

    """
    from virtual_ecosystem.core.configuration import Configuration

    module = importlib.import_module(module_name)

    classes: dict[str, list[str]] = {}
    for attribute_name in dir(module):
        candidate = getattr(module, attribute_name)
        if not isinstance(candidate, type):
            continue
        if not issubclass(candidate, Configuration) or candidate is Configuration:
            continue
        if candidate.__module__ != module_name:
            continue

        classes[attribute_name] = [base.__name__ for base in candidate.__bases__]

    return classes


def _build_parent_map(tree: ast.AST) -> dict[ast.AST, ast.AST]:
    """Create a reverse AST index from child nodes to parent nodes.

    Args:
        tree: Parsed AST for a source file.

    Returns:
        Dictionary mapping each child node to its immediate parent node.

    """
    parents: dict[ast.AST, ast.AST] = {}
    for node in ast.walk(tree):
        for child in ast.iter_child_nodes(node):
            parents[child] = node

    return parents


def _declared_attributes(
    class_node: ast.ClassDef, source: str
) -> list[tuple[str, ast.AnnAssign]]:
    r"""Extract annotated attributes declared directly in a class body.

    Args:
        class_node: AST class definition node to inspect.
        source: Unused source string, retained for API compatibility.

    Returns:
        List of ``(attribute_name, ann_assign_node)`` tuples for non-dunder
        class attributes declared with annotated assignments.

    """
    attributes = []
    for statement in class_node.body:
        if not isinstance(statement, ast.AnnAssign):
            continue
        if not isinstance(statement.target, ast.Name):
            continue
        if statement.target.id.startswith("__"):
            continue

        attributes.append((statement.target.id, statement))

    return attributes


def _attribute_docstring(class_node: ast.ClassDef, index: int) -> str:
    r"""Read an attribute docstring literal following a class assignment.

    Args:
        class_node: AST class definition containing the attribute.
        index: Index of the attribute statement within ``class_node.body``.

    Returns:
        Trimmed attribute docstring text if present; otherwise an empty string.

    """
    if index + 1 >= len(class_node.body):
        return ""

    following = class_node.body[index + 1]
    if not isinstance(following, ast.Expr):
        return ""
    if not isinstance(following.value, ast.Constant):
        return ""
    if not isinstance(following.value.value, str):
        return ""

    # Attribute docstrings are indented to the class body, but the first line
    # carries no indentation because it follows the opening quotes. Dedent the
    # remainder separately so the text renders cleanly in prompts and reports.
    text = following.value.value
    first, separator, rest = text.partition("\n")
    if separator:
        text = f"{first.strip()}\n{textwrap.dedent(rest)}"

    return text.strip()


def _enclosing_function(
    node: ast.AST, parents: dict[ast.AST, ast.AST]
) -> ast.AST | None:
    r"""Find the nearest enclosing function, async function, or class node.

    Args:
        node: AST node from which to walk upward.
        parents: Child-to-parent mapping for the same AST.

    Returns:
        Enclosing ``ast.FunctionDef``, ``ast.AsyncFunctionDef``, or
        ``ast.ClassDef`` node if found; otherwise ``None``.

    """
    current = parents.get(node)
    while current is not None:
        if isinstance(current, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            return current
        current = parents.get(current)

    return None


def _is_validator(node: ast.AST) -> bool:
    r"""Check whether a function node is decorated as a pydantic validator.

    Args:
        node: AST node expected to represent a function or async function.

    Returns:
        ``True`` if any decorator name matches a known validator decorator;
        otherwise ``False``.

    """
    if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
        return False

    for decorator in node.decorator_list:
        target = decorator.func if isinstance(decorator, ast.Call) else decorator
        name = ""
        if isinstance(target, ast.Name):
            name = target.id
        elif isinstance(target, ast.Attribute):
            name = target.attr

        if name in VALIDATOR_DECORATORS:
            return True

    return False


def _find_reference_node(
    tree: ast.AST, line: int, column: int, name: str
) -> ast.AST | None:
    """Locate the AST node matching a Jedi-reported reference position.

    Args:
        tree: Parsed AST for the referenced file.
        line: One-based line number reported by Jedi.
        column: Zero-based column offset reported by Jedi.
        name: Referenced attribute or keyword name.

    Returns:
        Matching ``ast.Attribute``, ``ast.Name``, or ``ast.keyword`` node if
        found; otherwise ``None``.

    """
    for node in ast.walk(tree):
        if isinstance(node, ast.Attribute) and node.attr == name:
            if node.end_lineno != line:
                continue
            if node.end_col_offset - len(name) == column:
                return node

        if isinstance(node, ast.Name) and node.id == name:
            if node.lineno == line and node.col_offset == column:
                return node

        # A keyword argument name in a call, such as the ``source`` in
        # ``SoilEnzymeClass(source="fungi")``. Jedi reports the position of the
        # parameter name, which is not itself a Name or Attribute node.
        if isinstance(node, ast.keyword) and node.arg == name:
            if node.lineno == line and node.col_offset == column:
                return node

    return None


def _callee_name(call: ast.Call) -> str:
    """Return the source-level callable name for a call node.

    Args:
        call: AST call node.

    Returns:
        Callable name for simple ``Name`` or ``Attribute`` targets, else empty
        string.

    """
    if isinstance(call.func, ast.Name):
        return call.func.id
    if isinstance(call.func, ast.Attribute):
        return call.func.attr

    return ""


def _resolve_callee(script: jedi.Script, call: ast.Call) -> tuple[str, str]:
    r"""Resolve a call target to qualified name and docstring via Jedi.

    Args:
        script: Jedi script for the file containing ``call``.
        call: AST call node whose target should be resolved.

    Returns:
        ``(qualified_name, docstring)`` tuple. Returns ``("", "")`` when
        resolution fails or no definition is found.

    """
    func = call.func
    if isinstance(func, ast.Name):
        line, column = func.lineno, func.col_offset
    elif isinstance(func, ast.Attribute):
        line = func.end_lineno
        column = func.end_col_offset - len(func.attr)
    else:
        return "", ""

    try:
        definitions = script.goto(line=line, column=column, follow_imports=True)
    except Exception:
        return "", ""

    if not definitions:
        return "", ""

    definition = definitions[0]
    return definition.full_name or "", definition.docstring() or ""


def _first_paragraph(docstring: str) -> str:
    r"""Extract summary prose from a longer docstring.

    Args:
        docstring: Raw docstring text, possibly including signature and sections.

    Returns:
        First descriptive paragraph after removing common argument/return
        sections. Returns an empty string if no prose is available.

    """
    if not docstring:
        return ""

    body = docstring
    for section in ("\nArgs:", "\nReturns:", "\nRaises:", "\nTODO"):
        index = body.find(section)
        if index != -1:
            body = body[:index]

    paragraphs = [
        paragraph.strip() for paragraph in body.split("\n\n") if paragraph.strip()
    ]
    if not paragraphs:
        return ""

    # The first paragraph is the signature when jedi has prepended one.
    if len(paragraphs) > 1 and paragraphs[0].startswith(
        (f"{docstring.split('(')[0]}(", "def ")
    ):
        return paragraphs[1]

    return paragraphs[0]


def _classify_reference(
    node: ast.AST,
    parents: dict[ast.AST, ast.AST],
    script: jedi.Script,
    source_lines: list[str],
) -> dict[str, str]:
    """Classify how a constant reference is used at a source location.

    Args:
        node: AST node corresponding to the reference token.
        parents: Child-to-parent mapping for the file AST.
        script: Jedi script for symbol resolution in the same file.
        source_lines: Source file lines (unused in classification logic).

    Returns:
        Dictionary containing at least ``usage_kind`` and optionally
        ``consumer``, ``consumer_docstring``, and ``forwarded_as``.

    """
    enclosing = _enclosing_function(node, parents)
    if _is_validator(enclosing):
        return {"usage_kind": "validator"}

    # The reference is the parameter name in a call that sets the constant, as
    # in ``SoilEnzymeClass(source="fungi")``. This binds a value rather than
    # consuming one, so the owning class is recorded as the consumer.
    if isinstance(node, ast.keyword):
        call = parents.get(node)
        consumer, docstring = ("", "")
        if isinstance(call, ast.Call):
            consumer, docstring = _resolve_callee(script, call)

        return {
            "usage_kind": "instantiation",
            "consumer": consumer,
            "consumer_docstring": docstring,
            "forwarded_as": node.arg or "",
        }

    current: ast.AST = node
    derived = False
    while True:
        parent = parents.get(current)
        if parent is None:
            return {"usage_kind": "computation"}

        # A keyword argument: constants.x passed as f(param=constants.x).
        if isinstance(parent, ast.keyword):
            call = parents.get(parent)
            if not isinstance(call, ast.Call):
                return {"usage_kind": "computation"}

            consumer, docstring = _resolve_callee(script, call)
            kind = "derived_forward" if derived else "kwarg_forward"
            return {
                "usage_kind": kind,
                "consumer": consumer,
                "consumer_docstring": docstring,
                "forwarded_as": parent.arg or "",
            }

        # A positional argument: constants.x passed as f(constants.x).
        if isinstance(parent, ast.Call):
            if current in parent.args:
                consumer, docstring = _resolve_callee(script, parent)
                kind = "derived_forward" if derived else "positional_forward"
                index = parent.args.index(current)
                return {
                    "usage_kind": kind,
                    "consumer": consumer,
                    "consumer_docstring": docstring,
                    "forwarded_as": f"positional_{index}",
                }

            # The constant is part of the callee expression itself.
            return {"usage_kind": "computation"}

        # Any operator or comprehension means the forwarded value is derived.
        if isinstance(
            parent,
            (
                ast.BinOp,
                ast.UnaryOp,
                ast.BoolOp,
                ast.Compare,
                ast.IfExp,
                ast.Subscript,
                ast.comprehension,
            ),
        ):
            derived = True

        # Assignment or return means the value is consumed locally.
        if isinstance(parent, (ast.Assign, ast.AnnAssign, ast.Return)):
            return {"usage_kind": "computation"}

        current = parent


def _expression_at(source_lines: list[str], line: int) -> str:
    """Return stripped source text for a one-based line index.

    Args:
        source_lines: File content split by lines.
        line: One-based target line number.

    Returns:
        Stripped line text when in range; otherwise an empty string.

    """
    if 1 <= line <= len(source_lines):
        return source_lines[line - 1].strip()

    return ""


def get_constant_references(
    target_file_path: str | Path | list[str | Path],
    out_path: str | Path,
    project_root: str | Path,
    include_tests: bool = False,
    progress_callback: Callable[[int, int, str], None] | None = None,
) -> dict[str, dict[str, Any]]:
    """Find and classify configuration constant references, then write TOML.

    Args:
        target_file_path: Path or paths to Python source files to analyze,
            relative to ``project_root`` unless absolute.
        out_path: Output TOML file path. Parent directories are created and the
            file is overwritten.
        project_root: Root directory of the analyzed repository. Used for Jedi
            project resolution and added to ``sys.path`` for imports.
        include_tests: Whether to retain references from paths containing
            ``test`` or ``tests``.
        progress_callback: Optional function called after each target file with
            the completed count, total count, and current file path. When not
            provided, progress is written to standard output.

    Returns:
        Output dictionary with ``metadata``, ``functions``, and ``constants``
        sections. Constant keys use ``module.Class.attribute`` format.

    Raises:
        KeyError: If two constants resolve to the same output key.

    """
    project_root = Path(project_root).resolve()
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    # Normalize one path and many paths to one Python list for shared iteration.
    if isinstance(target_file_path, (str, Path)):
        target_file_paths = [Path(target_file_path)]
    else:
        target_file_paths = [Path(path) for path in target_file_path]

    if str(project_root) not in sys.path:
        sys.path.insert(0, str(project_root))

    project = jedi.Project(project_root)

    # AST caches keyed by absolute path, so each referencing file is parsed once.
    tree_cache: dict[Path, ast.AST] = {}
    parent_cache: dict[Path, dict[ast.AST, ast.AST]] = {}
    lines_cache: dict[Path, list[str]] = {}
    script_cache: dict[Path, jedi.Script] = {}

    def load(path: Path) -> tuple[ast.AST, dict[ast.AST, ast.AST], list[str]]:
        """Parse and cache AST-related structures for a source file.

        Args:
            path: Absolute file path to parse.

        Returns:
            Tuple of parsed AST, parent map, and source lines.

        Notes:
            This helper exists only while ``get_constant_references`` runs.
            It is not available as a separate Python console function.

        """
        if path not in tree_cache:
            source = path.read_text(encoding="utf-8")
            tree_cache[path] = ast.parse(source)
            parent_cache[path] = _build_parent_map(tree_cache[path])
            lines_cache[path] = source.splitlines()

        return tree_cache[path], parent_cache[path], lines_cache[path]

    def script_for(path: Path) -> jedi.Script:
        """Build or fetch a cached Jedi script for a source file.

        Args:
            path: Absolute file path used to initialize Jedi.

        Returns:
            Cached ``jedi.Script`` instance for ``path``.

        Notes:
            This helper exists only while ``get_constant_references`` runs.
            It is not available as a separate Python console function.

        """
        if path not in script_cache:
            script_cache[path] = jedi.Script(path=path, project=project)

        return script_cache[path]

    records: dict[str, ConstantRecord] = {}
    functions: dict[str, str] = {}

    total_targets = len(target_file_paths)
    show_progress = total_targets > 1
    if show_progress and progress_callback is None:
        sys.stdout.write(f"Scanning constant usage in {total_targets} files...\n")
        sys.stdout.flush()

    def _progress_update(index: int, path: Path) -> None:
        """Send progress to a callback or write it to stdout.

        Args:
            index: One-based file index currently being processed.
            path: Current file path being analyzed.

        """
        if not show_progress:
            return

        display_path = path.as_posix()
        if progress_callback is not None:
            progress_callback(index, total_targets, display_path)
            return

        max_path_length = 72
        if len(display_path) > max_path_length:
            display_path = f"...{display_path[-(max_path_length - 3) :]}"

        sys.stdout.write(f"[{index}/{total_targets}] {display_path}\n")
        sys.stdout.flush()

    for index, relative_path in enumerate(target_file_paths, start=1):
        full_path = (
            relative_path
            if relative_path.is_absolute()
            else project_root / relative_path
        )
        module_name = _module_name_from_path(full_path.relative_to(project_root))

        tree, _, source_lines = load(full_path)
        script = script_for(full_path)
        configuration_classes = _configuration_classes(module_name)

        class_nodes = {
            node.name: node for node in ast.walk(tree) if isinstance(node, ast.ClassDef)
        }

        for class_name, base_classes in configuration_classes.items():
            class_node = class_nodes.get(class_name)
            if class_node is None:
                continue

            attributes = _declared_attributes(class_node, "")
            body_index = {
                id(statement): index for index, statement in enumerate(class_node.body)
            }

            for attribute_name, statement in attributes:
                key = f"{module_name}.{class_name}.{attribute_name}"
                if key in records:
                    raise KeyError(f"Duplicate constant key: {key}")

                target = statement.target
                docstring = _attribute_docstring(class_node, body_index[id(statement)])
                default = ast.unparse(statement.value) if statement.value else ""

                record = ConstantRecord(
                    name=attribute_name,
                    qualified_name=key,
                    module=module_name,
                    class_name=class_name,
                    base_classes=base_classes,
                    declaration=_expression_at(source_lines, target.lineno),
                    docstring=docstring,
                    default_expression=default,
                    type_annotation=ast.unparse(statement.annotation),
                    file=str(full_path.relative_to(project_root).as_posix()),
                    line=target.lineno,
                )

                references = script.get_references(
                    line=target.lineno, column=target.col_offset
                )

                for reference in references:
                    if reference.is_definition():
                        continue

                    reference_path = Path(reference.module_path or "")
                    if not reference_path.is_file():
                        continue

                    if not include_tests:
                        parts = reference_path.parts
                        if "tests" in parts or "test" in parts:
                            continue

                    ref_tree, ref_parents, ref_lines = load(reference_path)
                    ref_script = script_for(reference_path)

                    node = _find_reference_node(
                        ref_tree,
                        reference.line,
                        reference.column,
                        attribute_name,
                    )

                    parent_scope = reference.parent()
                    caller = ""
                    if parent_scope is not None:
                        caller = parent_scope.full_name or ""
                        if caller and caller not in functions:
                            functions[caller] = _first_paragraph(
                                parent_scope.docstring() or ""
                            )

                    if node is None:
                        classification = {"usage_kind": "unresolved"}
                    else:
                        classification = _classify_reference(
                            node, ref_parents, ref_script, ref_lines
                        )

                    # Move the consumer docstring into the shared table.
                    consumer_docstring = classification.pop("consumer_docstring", "")
                    consumer = classification.get("consumer", "")
                    if consumer and consumer not in functions:
                        functions[consumer] = _first_paragraph(consumer_docstring)

                    try:
                        relative_reference = reference_path.relative_to(
                            project_root
                        ).as_posix()
                    except ValueError:
                        relative_reference = str(reference_path)

                    record.referenced_in.append(
                        ConstantReference(
                            file=relative_reference,
                            line=reference.line,
                            column=reference.column,
                            caller=caller,
                            expression=_expression_at(ref_lines, reference.line),
                            **classification,
                        )
                    )

                records[key] = record

        _progress_update(index, full_path)

    output: dict[str, Any] = {
        "metadata": {
            "generated_at": datetime.now(UTC).isoformat(),
            "project_root": str(project_root),
            **_project_provenance(project_root),
            "jedi_version": jedi.__version__,
            "python_version": sys.version.split()[0],
            "include_tests": include_tests,
            "target_files": [str(Path(p).as_posix()) for p in target_file_paths],
            "constant_count": len(records),
            "function_count": len(functions),
        },
        "functions": functions,
        "constants": {key: record.to_dict() for key, record in records.items()},
    }

    if show_progress and progress_callback is None:
        sys.stdout.write("Completed scanning constant usage.\n")
        sys.stdout.flush()

    # Avoid relying on mutable function attributes so reticulate reloads are safe.
    with open(out_path, "wb") as stream:
        tomli_w.dump(output, stream)

    return output
