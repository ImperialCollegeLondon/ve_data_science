"""Extract constant-to-callee documentation mappings from Python source.

This module parses a Python file with ``ast`` and inspects a specific caller
function. It finds keyword arguments where scoped constants are passed into
callees, then returns a column-oriented mapping that is directly compatible
with ``reticulate::py_to_r() |> tibble::as_tibble()``.
"""

from __future__ import annotations

import ast
import re
from collections import defaultdict
from typing import Any

OUTPUT_COLUMNS = (
    "constant",
    "caller",
    "callee",
    "callee_param",
    "function_doc",
    "param_doc",
)


def _rows_to_columns(rows: list[dict[str, Any]]) -> dict[str, list[Any]]:
    """Convert row-wise dictionaries to a column-oriented mapping.

    Args:
        rows: List of row dictionaries containing output fields.

    Returns:
        Dictionary where keys are output column names and values are lists.

    """
    columns = {name: [] for name in OUTPUT_COLUMNS}

    for row in rows:
        for col in OUTPUT_COLUMNS:
            columns[col].append(row.get(col))

    return columns


def _extract_param_doc_from_google_args(
    docstring: str | None, param_name: str
) -> str | None:
    """Extract one parameter's description from a Google-style ``Args:`` block.

    Args:
        docstring: Full function docstring.
        param_name: Parameter name to retrieve documentation for.

    Returns:
        Parameter description when found, otherwise ``None``.

    """
    if not docstring:
        return None

    lines = docstring.splitlines()

    args_start = None
    for i, line in enumerate(lines):
        if re.match(r"^\s*Args\s*:\s*$", line):
            args_start = i + 1
            break

    if args_start is None:
        return None

    args_lines = []
    for line in lines[args_start:]:
        if re.match(r"^\s*[A-Za-z][A-Za-z_ ]*:\s*$", line):
            break
        args_lines.append(line)

    parsed: dict[str, str] = {}
    current_param: str | None = None

    for line in args_lines:
        match = re.match(r"^\s{4}([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$", line)
        if match:
            current_param = match.group(1)
            parsed[current_param] = match.group(2).strip()
            continue

        if current_param is not None and re.match(r"^\s{8,}\S", line):
            continuation = line.strip()
            if continuation:
                parsed[current_param] = (
                    parsed[current_param] + " " + continuation
                ).strip()

    return parsed.get(param_name)


def extract_constant_call_doc_map(
    file_path: str,
    constants: list[str],
    caller_qualified_name: str,
) -> dict[str, list[Any]]:
    """Find constant usages in one caller and map them to callee docs.

    Args:
        file_path: Python file to parse.
        constants: Constant names to track.
        caller_qualified_name: Qualified name of caller to inspect,
            for example ``"SoilPools.calculate_all_pool_updates"``.

    Returns:
        Column-oriented mapping with fields in ``OUTPUT_COLUMNS``.

    """
    with open(file_path, encoding="utf-8") as f:
        source = f.read()

    tree = ast.parse(source)
    constants_set = set(constants)

    funcs_by_qname: dict[str, ast.AST] = {}
    funcs_by_name: dict[str, list[tuple[str, ast.AST]]] = defaultdict(list)

    class DefCollector(ast.NodeVisitor):
        """Collect function definitions indexed by qualified and simple name."""

        def __init__(self) -> None:
            """Initialize class stack for qualified name tracking."""
            self.class_stack: list[str] = []

        def visit_ClassDef(self, node: ast.ClassDef) -> None:
            """Track nested class context while visiting members."""
            self.class_stack.append(node.name)
            self.generic_visit(node)
            self.class_stack.pop()

        def visit_FunctionDef(self, node: ast.FunctionDef) -> None:
            """Register synchronous function definitions."""
            qname = (
                ".".join([*self.class_stack, node.name])
                if self.class_stack
                else node.name
            )
            funcs_by_qname[qname] = node
            funcs_by_name[node.name].append((qname, node))
            self.generic_visit(node)

        def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> None:
            """Register asynchronous function definitions."""
            qname = (
                ".".join([*self.class_stack, node.name])
                if self.class_stack
                else node.name
            )
            funcs_by_qname[qname] = node
            funcs_by_name[node.name].append((qname, node))
            self.generic_visit(node)

    DefCollector().visit(tree)

    caller_node = funcs_by_qname.get(caller_qualified_name)
    if caller_node is None:
        return _rows_to_columns([])

    rows: list[dict[str, Any]] = []

    for node in ast.walk(caller_node):
        if not isinstance(node, ast.Call):
            continue

        if isinstance(node.func, ast.Name):
            callee_name = node.func.id
        elif isinstance(node.func, ast.Attribute):
            callee_name = node.func.attr
        else:
            continue

        callee_candidates = funcs_by_name.get(callee_name, [])
        if not callee_candidates:
            continue

        callee_qname, callee_node = sorted(
            callee_candidates,
            key=lambda x: ("." in x[0], x[0]),
        )[0]

        for kw in node.keywords:
            if kw.arg is None:
                continue

            value = kw.value
            if isinstance(value, ast.Attribute) and value.attr in constants_set:
                constant = value.attr
                callee_param = kw.arg

                function_doc = ast.get_docstring(callee_node, clean=True)
                param_doc = _extract_param_doc_from_google_args(
                    function_doc, callee_param
                )

                rows.append(
                    {
                        "constant": constant,
                        "caller": caller_qualified_name,
                        "callee": callee_qname,
                        "callee_param": callee_param,
                        "function_doc": function_doc,
                        "param_doc": param_doc,
                    }
                )

    seen = set()
    deduped: list[dict[str, Any]] = []
    for row in rows:
        key = (
            row["constant"],
            row["caller"],
            row["callee"],
            row["callee_param"],
        )
        if key not in seen:
            seen.add(key)
            deduped.append(row)

    return _rows_to_columns(deduped)
