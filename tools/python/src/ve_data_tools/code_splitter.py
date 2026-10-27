"""
---
title: Export context-preserving Python chunks for Ragnar

description: |
  Split Python source files with LlamaIndex CodeSplitter and enrich each chunk
  with source ranges and enclosing qualified-symbol context. Write the records
  as JSON Lines for review in Python and ingestion by an R Ragnar workflow.

virtual_ecosystem_module: Soil

author:
  - Hao Ran Lai

status: wip

input_files:
  - name: Python source tree
    path: Supplied with --source-root
    description: Python files recursively included in the retrieval corpus.

output_files:
  - name: Contextual code chunks
    path: Supplied with --output
    description: JSON Lines records consumed by analysis/soil/llm/rag.R.

package_dependencies:
  - llama-index-core
  - tree-sitter-language-pack

usage_notes: |
  Run this module directly or import export_code_chunks(). Source paths in the
  output are relative to the supplied source root.
---
"""  # noqa: D205, D212, D400, D415

from __future__ import annotations

import argparse
import hashlib
import json
from collections.abc import Iterator
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from llama_index.core.node_parser import CodeSplitter
from tree_sitter_language_pack import get_parser

DEFINITION_TYPES = {"class_definition", "function_definition"}


@dataclass(frozen=True)
class Definition:
    """Describe a class, function, or method in a Python source file."""

    name: str
    qualified_name: str
    kind: str
    start_byte: int
    end_byte: int
    start_line: int
    end_line: int


@dataclass(frozen=True)
class ChunkRecord:
    """Represent one exported Python source chunk."""

    chunk_id: str
    text: str
    context: str
    source_path: str
    module: str
    symbol: str
    qualified_symbol: str
    symbol_kind: str
    start_line: int
    end_line: int
    chunk_index: int
    chunk_count: int
    symbol_fragment: int
    symbol_fragments: int
    language: str
    max_chars: int


def _node_text(node: Any, source: bytes) -> str:
    """Return source text covered by a Tree-sitter node."""
    return source[node.start_byte : node.end_byte].decode("utf-8")


def _unwrap_definition(node: Any) -> Any:
    """Return the class or function wrapped by a decorated definition."""
    if node.type != "decorated_definition":
        return node

    return next(
        (child for child in node.children if child.type in DEFINITION_TYPES),
        node,
    )


def _definition_kind(node: Any, depth: int) -> str:
    """Return a retrieval-oriented definition kind."""
    if node.type == "class_definition":
        return "class"
    if depth > 0:
        return "method"
    return "function"


def _collect_definitions(
    node: Any,
    source: bytes,
    *,
    depth: int = 0,
    parent: str = "",
) -> list[Definition]:
    """Collect definitions recursively with qualified names and source ranges."""
    definitions: list[Definition] = []

    for child in node.children:
        if child.type in DEFINITION_TYPES | {"decorated_definition"}:
            target = _unwrap_definition(child)
            name_node = target.child_by_field_name("name")
            if name_node is None:
                continue

            name = _node_text(name_node, source)
            qualified_name = f"{parent}.{name}" if parent else name
            definitions.append(
                Definition(
                    name=name,
                    qualified_name=qualified_name,
                    kind=_definition_kind(target, depth),
                    start_byte=child.start_byte,
                    end_byte=child.end_byte,
                    start_line=child.start_point[0] + 1,
                    end_line=child.end_point[0] + 1,
                )
            )
            definitions.extend(
                _collect_definitions(
                    target,
                    source,
                    depth=depth + 1,
                    parent=qualified_name,
                )
            )
        else:
            definitions.extend(
                _collect_definitions(child, source, depth=depth, parent=parent)
            )

    return definitions


def _find_chunk_spans(source: str, chunks: list[str]) -> list[tuple[int, int]]:
    """Locate CodeSplitter chunks as byte ranges in their source file."""
    spans: list[tuple[int, int]] = []
    cursor = 0

    for chunk in chunks:
        start_character = source.find(chunk, cursor)
        if start_character < 0:
            raise ValueError("Could not locate a generated chunk in its source file.")

        start_byte = len(source[:start_character].encode("utf-8"))
        end_byte = start_byte + len(chunk.encode("utf-8"))
        spans.append((start_byte, end_byte))
        cursor = start_character + len(chunk)

    return spans


def _smallest_enclosing_definition(
    definitions: list[Definition], start_byte: int, end_byte: int
) -> Definition | None:
    """Find the narrowest definition that fully contains a chunk."""
    enclosing = [
        definition
        for definition in definitions
        if definition.start_byte <= start_byte and definition.end_byte >= end_byte
    ]
    if not enclosing:
        return None

    return min(
        enclosing,
        key=lambda definition: definition.end_byte - definition.start_byte,
    )


def _line_range(source: bytes, start_byte: int, end_byte: int) -> tuple[int, int]:
    """Convert a byte range to inclusive one-based line numbers."""
    start_line = source[:start_byte].count(b"\n") + 1
    end_line = source[:end_byte].count(b"\n") + 1
    return start_line, end_line


def _module_name(path: Path) -> str:
    """Derive a fully qualified module name from Python package markers."""
    parts = [] if path.name == "__init__.py" else [path.stem]
    parent = path.parent
    while (parent / "__init__.py").is_file():
        parts.insert(0, parent.name)
        parent = parent.parent
    return ".".join(parts)


def _context(
    *,
    source_path: str,
    module: str,
    qualified_symbol: str,
    symbol_kind: str,
    start_line: int,
    end_line: int,
    symbol_fragment: int,
    symbol_fragments: int,
) -> str:
    """Build concise context that ragnar prepends during embedding."""
    lines = [
        f"File: {source_path}",
        f"Module: {module}",
        f"Symbol: {qualified_symbol}",
        f"Kind: {symbol_kind}",
        f"Lines: {start_line}-{end_line}",
    ]
    if symbol_fragments > 1:
        lines.append(f"Symbol fragment: {symbol_fragment}/{symbol_fragments}")
    return "\n".join(lines)


def chunk_file(
    path: Path,
    *,
    source_root: Path,
    splitter: CodeSplitter,
    max_chars: int,
) -> list[ChunkRecord]:
    """Split one Python file and return context-enriched records."""
    source = "\n".join(
        line.rstrip() for line in path.read_text(encoding="utf-8").splitlines()
    )
    source_bytes = source.encode("utf-8")
    parser = get_parser("python")
    tree = parser.parse(source_bytes)
    if tree.root_node.has_error:
        raise ValueError(f"Tree-sitter could not parse {path} without errors.")

    chunks = splitter.split_text(source)
    spans = _find_chunk_spans(source, chunks)
    definitions = _collect_definitions(tree.root_node, source_bytes)
    relative_path = path.relative_to(source_root)
    source_path = relative_path.as_posix()
    module = _module_name(path)

    enclosing = [
        _smallest_enclosing_definition(definitions, start, end) for start, end in spans
    ]
    fragment_totals: dict[str, int] = {}
    for definition in enclosing:
        key = definition.qualified_name if definition else module
        fragment_totals[key] = fragment_totals.get(key, 0) + 1

    fragment_indices: dict[str, int] = {}
    records: list[ChunkRecord] = []
    for chunk_index, (text, span, definition) in enumerate(
        zip(chunks, spans, enclosing, strict=True),
        start=1,
    ):
        start_byte, end_byte = span
        start_line, end_line = _line_range(source_bytes, start_byte, end_byte)
        symbol = definition.name if definition else module
        qualified_symbol = definition.qualified_name if definition else module
        symbol_kind = definition.kind if definition else "module"
        fragment_indices[qualified_symbol] = (
            fragment_indices.get(qualified_symbol, 0) + 1
        )
        symbol_fragment = fragment_indices[qualified_symbol]
        symbol_fragments = fragment_totals[qualified_symbol]
        identity = f"{source_path}:{start_byte}:{end_byte}:{chunk_index}"
        chunk_id = hashlib.sha256(identity.encode()).hexdigest()[:16]

        records.append(
            ChunkRecord(
                chunk_id=chunk_id,
                text=text,
                context=_context(
                    source_path=source_path,
                    module=module,
                    qualified_symbol=qualified_symbol,
                    symbol_kind=symbol_kind,
                    start_line=start_line,
                    end_line=end_line,
                    symbol_fragment=symbol_fragment,
                    symbol_fragments=symbol_fragments,
                ),
                source_path=source_path,
                module=module,
                symbol=symbol,
                qualified_symbol=qualified_symbol,
                symbol_kind=symbol_kind,
                start_line=start_line,
                end_line=end_line,
                chunk_index=chunk_index,
                chunk_count=len(chunks),
                symbol_fragment=symbol_fragment,
                symbol_fragments=symbol_fragments,
                language="python",
                max_chars=max_chars,
            )
        )

    return records


def iter_code_chunks(
    source_root: str | Path, *, max_chars: int = 8000
) -> Iterator[ChunkRecord]:
    """Yield chunk records for all Python files under a source root."""
    root = Path(source_root).resolve()
    splitter = CodeSplitter.from_defaults(
        language="python",
        max_chars=max_chars,
        count_mode="char",
    )

    for path in sorted(root.rglob("*.py")):
        yield from chunk_file(
            path,
            source_root=root,
            splitter=splitter,
            max_chars=max_chars,
        )


def export_code_chunks(
    source_root: str | Path,
    output_path: str | Path,
    *,
    max_chars: int = 8000,
) -> Path:
    """Write context-enriched Python chunks as JSON Lines."""
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    with output.open("w", encoding="utf-8", newline="\n") as stream:
        for record in iter_code_chunks(source_root, max_chars=max_chars):
            stream.write(json.dumps(asdict(record), ensure_ascii=False) + "\n")

    return output


def _parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Export context-preserving Python chunks as JSON Lines."
    )
    parser.add_argument("source_root", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--max-chars", type=int, default=8000)
    return parser.parse_args()


def main() -> None:
    """Run the command-line exporter."""
    args = _parse_args()
    export_code_chunks(args.source_root, args.output, max_chars=args.max_chars)


if __name__ == "__main__":
    main()
