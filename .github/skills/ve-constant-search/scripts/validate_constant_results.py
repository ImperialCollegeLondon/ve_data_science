"""Check approved evidence rows without changing research or historical records."""

from __future__ import annotations

import argparse
import csv
import math
import re
import tomllib
from collections import Counter
from datetime import UTC, datetime
from pathlib import Path

ASSET = Path(__file__).resolve().parents[1] / "assets/ve_constant_usage.toml"
NUMERIC_FIELDS = (
    "suggested_value",
    "value_low",
    "value_high",
    "original_value",
    "conversion_factor",
)
IDENTIFIERS = {"name", "taxonomic_group", "source", "substrate"}


def read_rows(path: Path) -> list[dict[str, str]]:
    """Read named CSV columns, rejecting malformed records and duplicate headers."""
    with path.open(encoding="utf-8", newline="") as stream:
        reader = csv.DictReader(stream)
        if not reader.fieldnames or len(set(reader.fieldnames)) != len(
            reader.fieldnames
        ):
            raise ValueError(f"Missing or duplicate CSV headers: {path}")
        rows = list(reader)
    if any(None in row or None in row.values() for row in rows):
        raise ValueError(f"Misaligned CSV columns: {path}")
    return rows


def preserve_rows(
    current: list[dict[str, str]],
    baseline: list[dict[str, str]],
    *,
    replace_names: set[str],
) -> None:
    """Require prior rows outside explicitly approved replacements to remain intact."""
    columns = sorted({key for row in (*current, *baseline) for key in row})

    def counts(rows: list[dict[str, str]]) -> Counter[tuple[str, ...]]:
        return Counter(
            tuple(row.get(column, "") for column in columns)
            for row in rows
            if row["qualified_name"] not in replace_names
        )

    if counts(baseline) - counts(current):
        raise ValueError("Prior rows removed or changed outside approved replacements")


def validate_results(
    values: Path,
    log: Path,
    qualified_names: set[str],
    *,
    inventory_path: Path = ASSET,
    baseline_values: Path | None = None,
    baseline_log: Path | None = None,
    replace_names: set[str] | None = None,
) -> int:
    """Check selected proposals; never certify scientific validity."""
    inventory = tomllib.loads(inventory_path.read_text(encoding="utf-8"))
    commit = inventory["metadata"]["project_commit"]
    records = inventory["constants"]
    for name in qualified_names:
        if name not in records:
            raise ValueError(f"Qualified name absent from current inventory: {name}")
        if records[name]["name"] in IDENTIFIERS:
            raise ValueError(f"Identifier is not an empirical parameter: {name}")
    replacements = replace_names or set()
    if not replacements <= qualified_names:
        raise ValueError("Replacements must be selected, user-approved qualified names")
    rows = read_rows(values)
    searches = read_rows(log)
    baseline = read_rows(baseline_values) if baseline_values is not None else []
    if baseline_values is not None:
        preserve_rows(rows, baseline, replace_names=replacements)
    if baseline_log is not None:
        old_searches = read_rows(baseline_log)
        if searches[: len(old_searches)] != old_searches:
            raise ValueError(
                "Search log must preserve the baseline prefix (append-only)"
            )
    previous = Counter(
        tuple(sorted((key, value) for key, value in row.items() if value))
        for row in baseline
    )
    selected = []
    for row in rows:
        identity = tuple(sorted((key, value) for key, value in row.items() if value))
        if previous[identity] and row["qualified_name"] not in replacements:
            previous[identity] -= 1
            continue
        if row["qualified_name"] in qualified_names:
            selected.append(row)
        elif baseline_values is not None:
            raise ValueError("New result rows outside selected qualified names")
    if not selected:
        raise ValueError("No result rows for selected qualified names")
    for row in selected:
        name = row["qualified_name"]
        record = records[name]
        if row["ve_commit"] != commit:
            raise ValueError(f"Result VE commit does not match inventory: {name}")
        if not row["retrieved_at"] or not row["rationale"]:
            raise ValueError(f"Missing retrieval time or rationale: {name}")
        retrieved_at = datetime.fromisoformat(row["retrieved_at"])
        if retrieved_at.tzinfo is None or retrieved_at.utcoffset() != UTC.utcoffset(
            None
        ):
            raise ValueError(f"Retrieval time must include UTC timezone: {name}")
        if row["name"] != record["name"]:
            raise ValueError(f"Result name does not match inventory: {name}")
        if record["required"] and row["model_default"]:
            raise ValueError(f"Required input has no model default: {name}")
        if record["input_kind"] == "trait_table":
            groups = {example["group"] for example in record["example_values"]}
            if row.get("group") not in groups:
                raise ValueError(f"Missing or invalid explicit trait group: {name}")
        numeric: dict[str, float] = {}
        for field in NUMERIC_FIELDS:
            if row[field]:
                numeric[field] = float(row[field])
                if not math.isfinite(numeric[field]):
                    raise ValueError(f"Non-finite evidence value: {name}.{field}")
        relevant_searches = [
            item
            for item in searches
            if item["qualified_name"] == name and item["ve_commit"] == commit
        ]
        if not relevant_searches:
            raise ValueError(f"Missing current-version search log: {name}")
        if row["status"] == "no_evidence":
            if numeric:
                raise ValueError(f"Unsupported numeric evidence in gap row: {name}")
            if not any(
                item["search_status"] == "success" for item in relevant_searches
            ):
                raise ValueError(
                    f"Failed searches cannot establish an evidence gap: {name}"
                )
        elif row["status"] == "value_found":
            if "suggested_value" not in numeric and not (
                "value_low" in numeric and "value_high" in numeric
            ):
                raise ValueError(f"Missing proposed value or complete range: {name}")
            if ("value_low" in numeric) != ("value_high" in numeric):
                raise ValueError(f"Incomplete proposed range: {name}")
            if numeric.get("value_low", 0) > numeric.get("value_high", 0):
                raise ValueError(f"Reversed proposed range: {name}")
            for field in (
                "quote",
                "source_location",
                "measurement_conditions",
                "confidence",
                "unit",
            ):
                if not row.get(field):
                    raise ValueError(
                        f"Missing full-text evidence field: {name}.{field}"
                    )
            if row["confidence"] not in {"high", "medium", "low"}:
                raise ValueError(f"Invalid evidence confidence: {name}")
            if record.get("model_unit") and row["unit"] != record["model_unit"]:
                raise ValueError(f"Unit does not match inventory model_unit: {name}")
            hashes = set(re.findall(r"sha256=([0-9a-f]{64})", row["rationale"]))
            verified = [
                item
                for item in relevant_searches
                if item["full_text_status"] == "verified"
                and item["search_status"] == "success"
                and (
                    (
                        row["doi"]
                        and item["doi"].removeprefix("https://doi.org/")
                        == row["doi"].removeprefix("https://doi.org/")
                    )
                    or (
                        not row["doi"]
                        and (
                            (
                                item["source_url"]
                                and item["source_url"] in row["rationale"]
                            )
                            or hashes.intersection(
                                re.findall(
                                    r"sha256=([0-9a-f]{64})",
                                    item["query"] + " " + item["notes"],
                                )
                            )
                        )
                    )
                )
            ]
            if not verified:
                raise ValueError(
                    f"No matching verified full-text source in log: {name}"
                )
        else:
            raise ValueError(f"Invalid result status: {name}")
    return len(selected)


def main() -> None:
    """Validate selected approved rows and optional baseline preservation."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--values", type=Path, required=True)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--qualified-name", action="append", required=True)
    parser.add_argument("--inventory", type=Path, default=ASSET)
    parser.add_argument("--baseline-values", type=Path)
    parser.add_argument("--baseline-log", type=Path)
    parser.add_argument("--replace-approved", action="append", default=[])
    args = parser.parse_args()
    count = validate_results(
        args.values,
        args.log,
        set(args.qualified_name),
        inventory_path=args.inventory,
        baseline_values=args.baseline_values,
        baseline_log=args.baseline_log,
        replace_names=set(args.replace_approved),
    )
    print(f"Validated {count} proposed result rows; scientific review still required.")


if __name__ == "__main__":
    main()
