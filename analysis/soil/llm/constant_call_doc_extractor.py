"""Extract constant-to-callee mappings (including nested call chains) from Python source.

This module parses Python source with :mod:`ast`, starting from a specific caller
function. It tracks selected constants as they are passed into callee parameters,
then recursively follows those parameters through subsequent local calls.

The output is a long-format, column-oriented mapping compatible with
``reticulate::py_to_r() |> tibble::as_tibble()``.

Public API:
    - :func:`extract_constant_call_doc_map`
"""

from __future__ import annotations

import ast
import re
from collections import defaultdict, deque
from dataclasses import dataclass
from typing import Any

OUTPUT_COLUMNS = (
    "constant",
    "caller",
    "callee",
    "callee_param",
    "depth",
    "callee_doc",
    "callee_param_doc",
)

# Explicitly expose the intended user-facing entrypoint.
__all__ = ["extract_constant_call_doc_map"]


@dataclass(frozen=True)
class TraversalState:
    """Unique traversal state for cycle/duplication control in BFS.

    Attributes:
        caller_qname: Qualified caller name currently being analyzed.
        tracked_symbols_key: Hashable representation of symbol->constants mapping.
        depth: Current traversal depth.
    """

    caller_qname: str
    tracked_symbols_key: tuple[tuple[str, tuple[str, ...]], ...]
    depth: int


def _is_function_node(node: ast.AST | None) -> bool:
    """Return ``True`` when ``node`` is a function definition node."""
    return isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))


def _rows_to_columns(rows: list[dict[str, Any]]) -> dict[str, list[Any]]:
    """Convert row-wise dictionaries to a column-oriented mapping."""
    columns = {name: [] for name in OUTPUT_COLUMNS}

    for row in rows:
        for col in OUTPUT_COLUMNS:
            columns[col].append(row.get(col))

    return columns


def _deduplicate_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Deduplicate by ``(constant, caller, callee, callee_param)`` key."""
    seen = set()
    deduped: list[dict[str, Any]] = []

    for row in rows:
        key = (
            row["constant"],
            row["caller"],
            row["callee"],
            row["callee_param"],
        )
        if key in seen:
            continue
        seen.add(key)
        deduped.append(row)

    return deduped


def _extract_param_doc_from_google_args(
    docstring: str | None, param_name: str | None
) -> str | None:
    """Extract one parameter description from a Google-style ``Args:`` block."""
    if not docstring or not param_name:
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
        # Stop at the next top-level section like "Returns:".
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


def _collect_functions(
    tree: ast.AST,
) -> tuple[dict[str, ast.AST], dict[str, list[tuple[str, ast.AST]]]]:
    """Collect function definitions indexed by qualified and simple names."""
    funcs_by_qname: dict[str, ast.AST] = {}
    funcs_by_name: dict[str, list[tuple[str, ast.AST]]] = defaultdict(list)

    class DefCollector(ast.NodeVisitor):
        """Track class nesting so methods get ``ClassName.method`` qnames."""

        def __init__(self) -> None:
            self.class_stack: list[str] = []

        def visit_ClassDef(self, node: ast.ClassDef) -> None:
            self.class_stack.append(node.name)
            self.generic_visit(node)
            self.class_stack.pop()

        def _register_function(self, node: ast.AST, name: str) -> None:
            qname = ".".join([*self.class_stack, name]) if self.class_stack else name
            funcs_by_qname[qname] = node
            funcs_by_name[name].append((qname, node))

        def visit_FunctionDef(self, node: ast.FunctionDef) -> None:
            self._register_function(node, node.name)
            self.generic_visit(node)

        def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> None:
            self._register_function(node, node.name)
            self.generic_visit(node)

    DefCollector().visit(tree)
    return funcs_by_qname, funcs_by_name


def _resolve_callee(
    node: ast.Call,
    funcs_by_name: dict[str, list[tuple[str, ast.AST]]],
) -> tuple[str | None, ast.AST | None]:
    """Resolve a call node to one local callee definition when available.

    Note:
        When multiple local functions share a simple name, the resolver picks a
        stable best-effort candidate using deterministic sorting. This keeps
        output reproducible, but it is still a heuristic.
    """
    if isinstance(node.func, ast.Name):
        callee_name = node.func.id
    elif isinstance(node.func, ast.Attribute):
        callee_name = node.func.attr
    else:
        return None, None

    callee_candidates = funcs_by_name.get(callee_name, [])
    if not callee_candidates:
        return None, None

    callee_qname, callee_node = sorted(
        callee_candidates,
        key=lambda x: ("." in x[0], x[0]),
    )[0]
    return callee_qname, callee_node


def _callee_param_names(callee_node: ast.AST | None) -> list[str]:
    """Return positional and keyword parameter names from a callee node."""
    if not _is_function_node(callee_node):
        return []

    args = callee_node.args
    params = [*args.posonlyargs, *args.args, *args.kwonlyargs]
    return [p.arg for p in params]


def _constants_from_expr(
    expr: ast.AST,
    tracked_symbols: dict[str, set[str]],
    constants_set: set[str],
) -> set[str]:
    """Infer which tracked constants an argument expression carries.

    Currently supported patterns:
        1. Direct attribute access where attribute name is a target constant,
           for example ``self.model_constants.arrhenius_reference_temp``.
        2. Variable reference to symbols already tracked from a parent call.
    """
    if isinstance(expr, ast.Attribute) and expr.attr in constants_set:
        return {expr.attr}

    if isinstance(expr, ast.Name):
        return set(tracked_symbols.get(expr.id, set()))

    return set()


def _collect_argument_constant_bindings(
    call_node: ast.Call,
    callee_param_names: list[str],
    tracked_symbols: dict[str, set[str]],
    constants_set: set[str],
) -> dict[str, set[str]]:
    """Map each callee parameter to constants found in call arguments."""
    callee_param_constants: dict[str, set[str]] = defaultdict(set)

    for idx, arg in enumerate(call_node.args):
        if idx >= len(callee_param_names):
            continue
        callee_param = callee_param_names[idx]
        constants_found = _constants_from_expr(arg, tracked_symbols, constants_set)
        if constants_found:
            callee_param_constants[callee_param].update(constants_found)

    for kw in call_node.keywords:
        # kw.arg is None for **kwargs expansion; skip because no direct target name.
        if kw.arg is None:
            continue
        constants_found = _constants_from_expr(
            kw.value, tracked_symbols, constants_set
        )
        if constants_found:
            callee_param_constants[kw.arg].update(constants_found)

    return callee_param_constants


def _state_key(
    tracked_symbols: dict[str, set[str]],
) -> tuple[tuple[str, tuple[str, ...]], ...]:
    """Create a hashable representation of tracked symbol->constant mapping."""
    return tuple(
        sorted(
            (symbol, tuple(sorted(constants)))
            for symbol, constants in tracked_symbols.items()
        )
    )


def extract_constant_call_doc_map(
    file_path: str,
    constants: list[str],
    caller_qualified_name: str,
    max_depth: int = 10,
) -> dict[str, list[Any]]:
    """User-facing API: track constants across nested caller->callee chains.

    Args:
        file_path: Python file to parse.
        constants: Constant names to track.
        caller_qualified_name: Qualified name of entry-point caller,
            for example ``"SoilPools.calculate_all_pool_updates"``.
        max_depth: Maximum recursive call depth to follow.

    Returns:
        Long-format, column-oriented mapping with fields in ``OUTPUT_COLUMNS``.

    Example:
        >>> result = extract_constant_call_doc_map(
        ...     file_path="virtual_ecosystem/models/soil/pools.py",
        ...     constants=["arrhenius_reference_temp", "activation_energy_microbial_uptake"],
        ...     caller_qualified_name="SoilPools.calculate_all_pool_updates",
        ...     max_depth=5,
        ... )
        >>> result["constant"][:3]
        ['arrhenius_reference_temp', 'activation_energy_microbial_uptake', ...]
    """
    with open(file_path, encoding="utf-8") as f:
        source = f.read()

    tree = ast.parse(source)
    constants_set = set(constants)
    funcs_by_qname, funcs_by_name = _collect_functions(tree)

    if caller_qualified_name not in funcs_by_qname:
        return _rows_to_columns([])

    rows: list[dict[str, Any]] = []
    queue: deque[tuple[str, dict[str, set[str]], int]] = deque()
    queue.append((caller_qualified_name, {}, 0))
    seen_states: set[TraversalState] = set()

    while queue:
        caller_qname, tracked_symbols, depth = queue.popleft()
        state = TraversalState(
            caller_qname=caller_qname,
            tracked_symbols_key=_state_key(tracked_symbols),
            depth=depth,
        )
        if state in seen_states:
            continue
        seen_states.add(state)

        caller_node = funcs_by_qname.get(caller_qname)
        if not _is_function_node(caller_node):
            continue

        for call_node in ast.walk(caller_node):
            if not isinstance(call_node, ast.Call):
                continue

            callee_qname, callee_node = _resolve_callee(call_node, funcs_by_name)
            if callee_qname is None:
                continue

            callee_param_names = _callee_param_names(callee_node)
            callee_param_constants = _collect_argument_constant_bindings(
                call_node=call_node,
                callee_param_names=callee_param_names,
                tracked_symbols=tracked_symbols,
                constants_set=constants_set,
            )

            if not callee_param_constants:
                continue

            callee_doc = ast.get_docstring(callee_node, clean=True)
            for callee_param, constants_found in callee_param_constants.items():
                callee_param_doc = _extract_param_doc_from_google_args(
                    callee_doc, callee_param
                )
                for constant in sorted(constants_found):
                    rows.append(
                        {
                            "constant": constant,
                            "caller": caller_qname,
                            "callee": callee_qname,
                            "callee_param": callee_param,
                            "depth": depth + 1,
                            "callee_doc": callee_doc,
                            "callee_param_doc": callee_param_doc,
                        }
                    )

            if depth < max_depth and _is_function_node(callee_node):
                # Carry forward only parameter names bound in this call.
                next_symbols = {
                    param: set(constants_found)
                    for param, constants_found in callee_param_constants.items()
                }
                queue.append((callee_qname, next_symbols, depth + 1))

    return _rows_to_columns(_deduplicate_rows(rows))
