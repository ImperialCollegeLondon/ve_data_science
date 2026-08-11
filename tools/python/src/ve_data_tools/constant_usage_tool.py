"""Find usages of configuration constants across Virtual Ecosystem model files.

This module locates every place in the ``virtual_ecosystem`` codebase where a
configuration constant is referenced, and classifies *how* each reference site
uses the constant.

Two complementary techniques are combined:

- **Import-based class detection.** Configuration classes are found by importing
  each target module and testing ``issubclass(cls, Configuration)``. This
  resolves the full method resolution order (MRO), so classes that inherit from
  ``Configuration`` indirectly are detected.
- **AST-based attribute enumeration and usage classification.** Attributes
  *declared* in each class body are read from the syntax tree, giving exact
  source positions and avoiding double-counting of inherited fields. The AST is
  also used to classify each reference site syntactically.
- **Jedi reference resolution.** ``jedi`` finds reference sites across the whole
  project, including other modules.

Usage classification
--------------------

Static analysis resolves symbols, not values, so a constant passed into another
function as an argument is attributed to the *enclosing* scope rather than the
function that consumes it. Rather than silently mis-attributing these sites,
each reference is labelled with a ``usage_kind``:

``computation``
    The constant is used directly in an expression within the caller.
``kwarg_forward`` / ``positional_forward``
    The constant is passed unmodified as an argument to another function. The
    callee is resolved and recorded in ``consumer``, so the function that
    actually uses the value is captured.
``derived_forward``
    A *derived* value (for example ``1 / constants.x``) is passed to another
    function. The consumer cannot be resolved reliably and the site is flagged
    for manual review.
``validator``
    The reference occurs inside a pydantic validator on the owning class.

Only ``derived_forward`` sites require human attention; the rest are resolved
deterministically.

Keying
------

Entries are keyed by ``module.Class.attribute`` constructed by this module, not
by ``jedi``'s ``full_name``. Several Virtual Ecosystem configuration classes
declare attributes with the same bare name (for example ``turnover_rate`` on
both ``SoilEnzymeClass`` and ``SoilMicrobialGroup``), and ``jedi`` returns
inconsistent or ``None`` full names. Constructing the key locally guarantees
uniqueness and makes collisions detectable.
"""

from __future__ import annotations

import ast
import importlib
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import jedi
import tomli_w

VALIDATOR_DECORATORS = frozenset(
    {"field_validator", "model_validator", "validator", "root_validator"}
)


@dataclass
class ConstantReference:
    """One site where a configuration constant is referenced."""

    file: str
    line: int
    column: int
    caller: str
    caller_docstring: str
    usage_kind: str
    consumer: str = ""
    consumer_docstring: str = ""
    forwarded_as: str = ""
    expression: str = ""

    def to_dict(self) -> dict[str, Any]:
        """Return a TOML-serialisable mapping with no ``None`` values."""
        return {key: value for key, value in self.__dict__.items()}


@dataclass
class ConstantRecord:
    """A configuration constant and every site that references it."""

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
        """Return a TOML-serialisable mapping."""
        data = {k: v for k, v in self.__dict__.items() if k != "referenced_in"}
        data["referenced_in"] = [ref.to_dict() for ref in self.referenced_in]
        return data


def _git_commit(project_root: Path) -> str:
    """Return the current git commit of the analysed project, if available."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=project_root,
            capture_output=True,
            text=True,
            check=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""

    return result.stdout.strip()


def _module_name_from_path(relative_path: Path) -> str:
    """Convert a project-relative file path to a dotted module name."""
    parts = relative_path.with_suffix("").parts
    return ".".join(parts)


def _configuration_classes(module_name: str) -> dict[str, list[str]]:
    """Return classes in a module that subclass ``Configuration``.

    Detection uses ``issubclass``, which resolves the full MRO and therefore
    catches classes inheriting from ``Configuration`` indirectly. Only classes
    genuinely defined in the module are returned, so imported classes are not
    attributed to the importing module.

    Args:
        module_name: Dotted module name, importable on ``sys.path``.

    Returns:
        Mapping of class name to the names of its immediate base classes.

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
    """Map each AST node to its parent, so reference sites can be walked up."""
    parents: dict[ast.AST, ast.AST] = {}
    for node in ast.walk(tree):
        for child in ast.iter_child_nodes(node):
            parents[child] = node

    return parents


def _declared_attributes(
    class_node: ast.ClassDef, source: str
) -> list[tuple[str, ast.AnnAssign]]:
    """Return annotated attributes declared directly in a class body.

    Only ``AnnAssign`` nodes are returned, which is how pydantic fields are
    written throughout Virtual Ecosystem. Inherited fields are deliberately
    excluded so that each constant is recorded once, against the class that
    declares it.
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
    """Return the string expression immediately following an attribute.

    Virtual Ecosystem documents configuration constants with a bare string
    literal placed after the assignment, which is the Sphinx convention for
    attribute docstrings. These are not accessible at runtime, so they are read
    from the syntax tree.
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

    return following.value.value.strip()


def _enclosing_function(
    node: ast.AST, parents: dict[ast.AST, ast.AST]
) -> ast.AST | None:
    """Return the innermost function or class enclosing a node."""
    current = parents.get(node)
    while current is not None:
        if isinstance(current, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            return current
        current = parents.get(current)

    return None


def _is_validator(node: ast.AST) -> bool:
    """Return whether a function node carries a pydantic validator decorator."""
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
    """Locate the AST node corresponding to a jedi reference position.

    Jedi reports the position of the *name token*. For ``constants.foo`` this is
    the position of ``foo`` within an ``ast.Attribute`` node, whose own
    ``col_offset`` points at ``constants``. The attribute token position is
    therefore derived from the node's end position.
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
    """Return the source-level name of a call's target."""
    if isinstance(call.func, ast.Name):
        return call.func.id
    if isinstance(call.func, ast.Attribute):
        return call.func.attr

    return ""


def _resolve_callee(script: jedi.Script, call: ast.Call) -> tuple[str, str]:
    """Resolve a call target to a qualified name and docstring using jedi.

    Args:
        script: Jedi script for the file containing the call.
        call: The call node whose target should be resolved.

    Returns:
        Tuple of qualified name and docstring. Empty strings if resolution
        fails, which jedi may do for dynamically constructed callables.

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


def _classify_reference(
    node: ast.AST,
    parents: dict[ast.AST, ast.AST],
    script: jedi.Script,
    source_lines: list[str],
) -> dict[str, str]:
    """Classify how a reference site uses the constant.

    Walks up from the reference node towards the nearest enclosing call. If the
    constant reaches that call unmodified, the callee is resolved and recorded
    as the consumer. If an operator or nested call intervenes, the value is
    derived and the site is flagged for review.
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
    """Return the stripped source line at a reference site, for context."""
    if 1 <= line <= len(source_lines):
        return source_lines[line - 1].strip()

    return ""


def get_constant_references(
    target_file_path: str | Path | list[str | Path],
    out_path: str | Path,
    project_root: str | Path,
    include_tests: bool = False,
) -> dict[str, dict[str, Any]]:
    """Find usages of configuration constants and write results to TOML.

    Args:
        target_file_path: Path(s) to Python source file(s) to analyse, relative
            to ``project_root``. Accepts a single path or a list of paths;
            results are merged into one output.
        out_path: Destination for the TOML output. Parent directories are
            created if needed and the file is always overwritten.
        project_root: Root directory of the ``virtual_ecosystem`` repository.
            Passed to ``jedi.Project`` so cross-file references resolve, and
            added to ``sys.path`` so target modules can be imported.
        include_tests: Whether to retain reference sites located inside a
            ``tests`` directory. Defaults to ``False``, since test usage does
            not describe how a constant functions in the model.

    Returns:
        Mapping of ``module.Class.attribute`` to constant records. Each record
        carries the declaration, docstring, default expression, and a list of
        classified reference sites.

    Raises:
        KeyError: If two constants resolve to the same key, which would
            otherwise silently discard one of them.

    """
    project_root = Path(project_root).resolve()
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)

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
        """Parse and cache a source file."""
        if path not in tree_cache:
            source = path.read_text(encoding="utf-8")
            tree_cache[path] = ast.parse(source)
            parent_cache[path] = _build_parent_map(tree_cache[path])
            lines_cache[path] = source.splitlines()

        return tree_cache[path], parent_cache[path], lines_cache[path]

    def script_for(path: Path) -> jedi.Script:
        """Build and cache a jedi script for a file."""
        if path not in script_cache:
            script_cache[path] = jedi.Script(path=path, project=project)

        return script_cache[path]

    records: dict[str, ConstantRecord] = {}

    for relative_path in target_file_paths:
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
                    caller_docstring = ""
                    if parent_scope is not None:
                        caller = parent_scope.full_name or ""
                        caller_docstring = parent_scope.docstring() or ""

                    if node is None:
                        classification = {"usage_kind": "unresolved"}
                    else:
                        classification = _classify_reference(
                            node, ref_parents, ref_script, ref_lines
                        )

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
                            caller_docstring=caller_docstring,
                            expression=_expression_at(ref_lines, reference.line),
                            **classification,
                        )
                    )

                records[key] = record

    output: dict[str, Any] = {
        "metadata": {
            "generated_at": datetime.now(UTC).isoformat(),
            "project_root": str(project_root),
            "project_commit": _git_commit(project_root),
            "jedi_version": jedi.__version__,
            "python_version": sys.version.split()[0],
            "include_tests": include_tests,
            "target_files": [str(Path(p).as_posix()) for p in target_file_paths],
            "constant_count": len(records),
        },
        "constants": {key: record.to_dict() for key, record in records.items()},
    }

    with open(out_path, "wb") as stream:
        tomli_w.dump(output, stream)

    return output["constants"]
