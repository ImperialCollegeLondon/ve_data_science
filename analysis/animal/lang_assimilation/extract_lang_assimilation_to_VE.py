"""
---
title: Extract Lang et al. assimilation-efficiency observations mapped to VE diet types

description: |
  Extract valid assimilation-efficiency observations from the Lang et al. (2017)
  dataset and map each retained resource label to the nearest reproducible
  Virtual Ecosystem diet type.

  The raw dataset is not stored in this repository. It must be obtained through
  the project-approved Globus source and staged locally before running this
  script. The embedded resource mappings and context-specific overrides are
  version-controlled so that the transformation remains auditable.

  The input file is expected to contain one metadata row followed by the column
  header row, so the CSV is read with ``header=1``. Observations are retained
  only when ``assimilation.efficiency > -999``. Retained assimilation
  efficiencies must lie between 0 and 1 inclusive.

virtual_ecosystem_module:
  - Animal

author:
  - Imperial College London Virtual Ecosystem team

status: wip

input_files:
  - name: Lang_et_al_2017_data.csv
    path: Globus-staged local file supplied with --input
    description: |
      Lang et al. (2017) source dataset staged locally from the approved Globus
      collection. The file must preserve the expected filename and schema,
      including one metadata row before the true header row. No machine-specific
      paths, credentials, access tokens, or other secrets are stored here.

output_files:
  - name: Lang_et_al_2017_VE_mapped_observations.csv
    path: User-specified local output path
    description: |
      Assimilation-efficiency observations retained from the Lang dataset after
      filtering and mapped to VE diet types. The output also records mapping
      status, notes, manual review flags, and context-review recommendations.

imported_files: []

package_dependencies:
  - argparse
  - hashlib
  - pathlib
  - pandas

usage_notes: |
  Stage ``Lang_et_al_2017_data.csv`` locally from Globus, then run from the
  repository root:

      uv run python \
          analysis/animal/lang_assimilation/extract_lang_assimilation_to_VE.py \
          --input /path/to/Lang_et_al_2017_data.csv \
          --output /path/to/Lang_et_al_2017_VE_mapped_observations.csv

  The script prints the input SHA-256 checksum and summary counts so each run
  can be audited after Globus transfer. Do not store Globus credentials, access
  tokens, or raw data files in this repository.
---
"""  # noqa: D205, D212, D400, D415

from __future__ import annotations

import argparse
import hashlib
import os
import tempfile
from collections.abc import Sequence
from pathlib import Path
from typing import NamedTuple

import pandas as pd

EXPECTED_INPUT_NAME = "Lang_et_al_2017_data.csv"
DEFAULT_OUTPUT_NAME = "Lang_et_al_2017_VE_mapped_observations.csv"

REQUIRED_INPUT_COLUMNS = [
    "taxonomic.name",
    "taxonomic.group.consumer",
    "resource",
    "consumer.type",
    "body.size.gram",
    "temperature.degree.C",
    "assimilation.efficiency",
    "reference.short",
    "reference.original",
    "comments",
]

OUTPUT_COLUMNS = [
    "taxonomic.name",
    "taxonomic.group.consumer",
    "resource",
    "consumer.type",
    "body.size.gram",
    "temperature.degree.C",
    "assimilation.efficiency",
    "reference.short",
    "reference.original",
    "comments",
    "ve_diet_type",
    "mapping_status",
    "mapping_note",
    "manual_review_required",
    "context_check_recommended",
]

SORT_COLUMNS = [
    "reference.original",
    "reference.short",
    "taxonomic.group.consumer",
    "taxonomic.name",
    "resource",
    "consumer.type",
    "body.size.gram",
    "temperature.degree.C",
    "assimilation.efficiency",
]


class MappingRecord(NamedTuple):
    """Store a reproducible VE mapping decision for a Lang resource label."""

    ve_diet_type: str
    mapping_note: str


RESOURCE_MAP: dict[str, MappingRecord] = {
    "algae": MappingRecord(
        "herbivore",
        "Direct resource mapping from algae to the VE herbivore diet type.",
    ),
    "animal": MappingRecord(
        "carnivore",
        "Direct resource mapping from animal tissue to the VE carnivore diet type.",
    ),
    "animals": MappingRecord(
        "carnivore",
        "Direct resource mapping from animal tissue to the VE carnivore diet type.",
    ),
    "arthropod": MappingRecord(
        "carnivore",
        "Direct resource mapping from arthropod prey to the VE carnivore diet type.",
    ),
    "arthropods": MappingRecord(
        "carnivore",
        "Direct resource mapping from arthropod prey to the VE carnivore diet type.",
    ),
    "carrion": MappingRecord(
        "carnivore",
        "Direct resource mapping from carrion to the VE carnivore diet type.",
    ),
    "egg": MappingRecord(
        "carnivore",
        "Direct resource mapping from eggs to the VE carnivore diet type.",
    ),
    "eggs": MappingRecord(
        "carnivore",
        "Direct resource mapping from eggs to the VE carnivore diet type.",
    ),
    "flower": MappingRecord(
        "herbivore",
        "Direct resource mapping from flowers to the VE herbivore diet type.",
    ),
    "flowers": MappingRecord(
        "herbivore",
        "Direct resource mapping from flowers to the VE herbivore diet type.",
    ),
    "foliage": MappingRecord(
        "herbivore",
        "Direct resource mapping from foliage to the VE herbivore diet type.",
    ),
    "fruit": MappingRecord(
        "herbivore",
        "Direct resource mapping from fruit to the VE herbivore diet type.",
    ),
    "fruits": MappingRecord(
        "herbivore",
        "Direct resource mapping from fruit to the VE herbivore diet type.",
    ),
    "grass": MappingRecord(
        "herbivore",
        "Direct resource mapping from grass to the VE herbivore diet type.",
    ),
    "leaf": MappingRecord(
        "herbivore",
        "Direct resource mapping from leaves to the VE herbivore diet type.",
    ),
    "leaves": MappingRecord(
        "herbivore",
        "Direct resource mapping from leaves to the VE herbivore diet type.",
    ),
    "nectar": MappingRecord(
        "herbivore",
        "Direct resource mapping from nectar to the VE herbivore diet type.",
    ),
    "pollen": MappingRecord(
        "herbivore",
        "Direct resource mapping from pollen to the VE herbivore diet type.",
    ),
    "root": MappingRecord(
        "herbivore",
        "Direct resource mapping from roots to the VE herbivore diet type.",
    ),
    "roots": MappingRecord(
        "herbivore",
        "Direct resource mapping from roots to the VE herbivore diet type.",
    ),
    "sap": MappingRecord(
        "herbivore",
        "Direct resource mapping from sap to the VE herbivore diet type.",
    ),
    "seed": MappingRecord(
        "herbivore",
        "Direct resource mapping from seeds to the VE herbivore diet type.",
    ),
    "seeds": MappingRecord(
        "herbivore",
        "Direct resource mapping from seeds to the VE herbivore diet type.",
    ),
    "vertebrate": MappingRecord(
        "carnivore",
        "Direct resource mapping from vertebrate prey to the VE carnivore diet type.",
    ),
    "vertebrates": MappingRecord(
        "carnivore",
        "Direct resource mapping from vertebrate prey to the VE carnivore diet type.",
    ),
    "wood": MappingRecord(
        "herbivore",
        "Direct resource mapping from wood to the VE herbivore diet type.",
    ),
}

CONTEXT_OVERRIDES: dict[tuple[str, str, str], MappingRecord] = {}


def parse_arguments(argv: Sequence[str] | None = None) -> argparse.Namespace:
    """Parse command-line arguments for the Lang mapping workflow.

    Args:
        argv: Optional command-line arguments for testing.

    Returns:
        Parsed command-line arguments.

    """

    parser = argparse.ArgumentParser(
        description=(
            "Extract Lang et al. assimilation-efficiency observations and map "
            "their resources to Virtual Ecosystem diet types."
        )
    )
    parser.add_argument(
        "--input",
        type=Path,
        required=True,
        help="Path to the staged Lang_et_al_2017_data.csv file.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(DEFAULT_OUTPUT_NAME),
        help=(
            "Path for the mapped output CSV. Defaults to "
            f"{DEFAULT_OUTPUT_NAME} in the current working directory."
        ),
    )
    return parser.parse_args(argv)


def normalise_text(value: object) -> str:
    """Normalise free-text fields used in reproducibility mappings.

    Args:
        value: Value to normalise.

    Returns:
        A lowercase, trimmed string with repeated whitespace collapsed.

    """

    if pd.isna(value):
        return ""

    return " ".join(str(value).strip().lower().split())


def calculate_sha256(path: Path) -> str:
    """Calculate the SHA-256 checksum of a file.

    Args:
        path: Path to the file to hash.

    Returns:
        SHA-256 checksum as a hexadecimal string.

    """

    digest = hashlib.sha256()

    with path.open("rb") as input_file:
        for block in iter(lambda: input_file.read(1024 * 1024), b""):
            digest.update(block)

    return digest.hexdigest()


def validate_input_path(input_path: Path) -> Path:
    """Validate that the staged Lang CSV matches reproducibility expectations.

    Args:
        input_path: Path supplied on the command line.

    Returns:
        The resolved input path.

    Raises:
        FileNotFoundError: If the input file does not exist.
        ValueError: If the path is not the expected staged CSV file.

    """

    resolved_path = input_path.expanduser().resolve()

    if not resolved_path.is_file():
        raise FileNotFoundError(f"Input file does not exist: {resolved_path}")

    if resolved_path.name != EXPECTED_INPUT_NAME:
        raise ValueError(
            "Expected the staged Lang input file to be named "
            f"{EXPECTED_INPUT_NAME}, got {resolved_path.name!r}."
        )

    return resolved_path


def load_raw_data(input_path: Path) -> pd.DataFrame:
    """Load and validate the staged Lang dataset.

    Args:
        input_path: Path to the staged input CSV.

    Returns:
        Raw Lang dataset loaded from CSV.

    Raises:
        ValueError: If required columns are missing.

    """

    resolved_path = validate_input_path(input_path)
    raw_data = pd.read_csv(resolved_path, header=1)

    missing_columns = sorted(set(REQUIRED_INPUT_COLUMNS) - set(raw_data.columns))
    if missing_columns:
        raise ValueError(
            "Lang input file is missing required columns: " + ", ".join(missing_columns)
        )

    return raw_data


def extract_assimilation_efficiency(raw_data: pd.DataFrame) -> pd.DataFrame:
    """Filter the Lang dataset to valid assimilation-efficiency observations.

    Args:
        raw_data: Raw Lang dataset.

    Returns:
        Filtered observations with numeric assimilation efficiencies.

    Raises:
        ValueError: If retained values are not numeric or fall outside 0 to 1.

    """

    observations = raw_data.copy()
    observations["assimilation.efficiency"] = pd.to_numeric(
        observations["assimilation.efficiency"], errors="coerce"
    )

    retained = observations.loc[
        observations["assimilation.efficiency"] > -999,
        REQUIRED_INPUT_COLUMNS,
    ].copy()

    if retained["assimilation.efficiency"].isna().any():
        raise ValueError(
            "Retained assimilation-efficiency values must be numeric after "
            "applying the Lang > -999 filter."
        )

    within_bounds = retained["assimilation.efficiency"].between(0, 1, inclusive="both")
    if not within_bounds.all():
        invalid_values = retained.loc[
            ~within_bounds, "assimilation.efficiency"
        ].tolist()
        raise ValueError(
            "Retained assimilation-efficiency values must fall within 0 to 1. "
            f"Invalid values: {invalid_values}"
        )

    return retained


def add_resource_context_counts(observations: pd.DataFrame) -> pd.DataFrame:
    """Count unique consumers and references per resource label.

    Args:
        observations: Filtered Lang observations.

    Returns:
        Observations with per-resource context counts attached.

    """

    context_counts = (
        observations.groupby("resource", dropna=False)
        .agg(
            resource_n_consumers=("taxonomic.name", "nunique"),
            resource_n_references=("reference.original", "nunique"),
        )
        .reset_index()
    )

    return observations.merge(context_counts, on="resource", how="left")


def lookup_resource_mapping(resource_label: object) -> MappingRecord | None:
    """Look up a direct mapping from a Lang resource label to a VE diet type.

    Args:
        resource_label: Resource label from the Lang dataset.

    Returns:
        Mapping record when a direct mapping is known, otherwise ``None``.

    """

    normalised_label = normalise_text(resource_label)
    return RESOURCE_MAP.get(normalised_label)


def apply_mapping(row: pd.Series) -> pd.Series:
    """Map a Lang observation to a VE diet type or flag it for review.

    Args:
        row: One Lang observation row.

    Returns:
        Mapping columns to append to the output table.

    """

    override_key = (
        normalise_text(row["resource"]),
        normalise_text(row["consumer.type"]),
        normalise_text(row["reference.short"]),
    )

    if override_key in CONTEXT_OVERRIDES:
        override = CONTEXT_OVERRIDES[override_key]
        return pd.Series(
            {
                "ve_diet_type": override.ve_diet_type,
                "mapping_status": "context_override",
                "mapping_note": override.mapping_note,
                "manual_review_required": True,
            }
        )

    resource_mapping = lookup_resource_mapping(row["resource"])
    if resource_mapping is not None:
        return pd.Series(
            {
                "ve_diet_type": resource_mapping.ve_diet_type,
                "mapping_status": "direct",
                "mapping_note": resource_mapping.mapping_note,
                "manual_review_required": False,
            }
        )

    return pd.Series(
        {
            "ve_diet_type": pd.NA,
            "mapping_status": "unmapped",
            "mapping_note": (
                "No direct VE diet-type mapping is recorded for resource "
                f"{row['resource']!r}; manual review is required."
            ),
            "manual_review_required": True,
        }
    )


def finalise_output(mapped_data: pd.DataFrame) -> pd.DataFrame:
    """Prepare the deterministic final output table.

    Args:
        mapped_data: Filtered observations with mapping columns attached.

    Returns:
        Final output data frame in stable column and row order.

    """

    output = mapped_data.assign(
        context_check_recommended=(
            (mapped_data["resource_n_consumers"] > 1)
            | (mapped_data["resource_n_references"] > 1)
        )
    )[OUTPUT_COLUMNS].copy()

    return output.sort_values(
        by=SORT_COLUMNS,
        kind="mergesort",
        na_position="last",
        ignore_index=True,
    )


def write_fallback_csv(data: pd.DataFrame, output_path: Path) -> Path | None:
    """Write to a suffixed fallback path when the preferred output is unavailable.

    Args:
        data: Output data frame to write.
        output_path: Preferred output path whose stem is used for suffixes.

    Returns:
        The fallback path that was written, or ``None`` if no fallback succeeded.

    Raises:
        PermissionError: If an unexpected permission issue occurs while cleaning
            up temporary files.

    """

    for number in range(1, 1000):
        fallback = output_path.with_name(
            f"{output_path.stem}_{number}{output_path.suffix}"
        )
        try:
            reserved_file_descriptor = os.open(
                fallback,
                os.O_CREAT | os.O_EXCL | os.O_WRONLY,
            )
        except (FileExistsError, PermissionError):
            continue

        os.close(reserved_file_descriptor)

        temporary_output = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="w",
                encoding="utf-8",
                newline="\n",
                delete=False,
                dir=output_path.parent,
                prefix=f"{fallback.stem}_",
                suffix=fallback.suffix,
            ) as output_file:
                temporary_output = Path(output_file.name)
                data.to_csv(
                    output_file,
                    index=False,
                    encoding="utf-8",
                    lineterminator="\n",
                )
            temporary_output.replace(fallback)
        except PermissionError:
            fallback.unlink(missing_ok=True)
            if temporary_output is not None:
                temporary_output.unlink(missing_ok=True)
            continue
        except Exception:
            fallback.unlink(missing_ok=True)
            if temporary_output is not None:
                temporary_output.unlink(missing_ok=True)
            raise
        finally:
            if temporary_output is not None and temporary_output.exists():
                temporary_output.unlink(missing_ok=True)

        return fallback

    return None


def write_csv_safely(data: pd.DataFrame, output_path: Path) -> Path:
    """Write the output CSV and fall back to suffixed filenames if needed.

    Args:
        data: Output data frame to write.
        output_path: Preferred output path.

    Returns:
        The path that was written.

    Raises:
        PermissionError: If the requested path appears to be locked and no
            suffixed fallback filename is available.

    """

    output_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        data.to_csv(
            output_path,
            index=False,
            encoding="utf-8",
            lineterminator="\n",
        )
        return output_path
    except PermissionError:
        fallback = write_fallback_csv(data, output_path)
        if fallback is None:
            raise PermissionError(
                f"Could not save {output_path.name}; the target appears to be locked "
                "and no fallback filename was available."
            ) from None

        print(
            "\nWARNING: Could not overwrite the requested output file. "
            "It may currently be open in another program."
        )
        print(f"Saved the output instead as:\n  {fallback}")
        return fallback


def print_run_summary(
    input_path: Path,
    raw_data: pd.DataFrame,
    mapped_output: pd.DataFrame,
    written_output: Path,
) -> None:
    """Print checksum and mapping summaries for run auditing.

    Args:
        input_path: Path to the input CSV.
        raw_data: Raw input dataset.
        mapped_output: Final mapped output data frame.
        written_output: Path written by the workflow.

    """

    unmapped_resources = (
        mapped_output.loc[mapped_output["mapping_status"] == "unmapped", "resource"]
        .dropna()
        .drop_duplicates()
        .sort_values()
        .tolist()
    )

    print(f"Input file: {input_path}")
    print(f"Input SHA-256: {calculate_sha256(input_path)}")
    print(f"Raw rows loaded: {len(raw_data)}")
    print(f"Assimilation-efficiency rows retained: {len(mapped_output)}")
    print("\nMapping status counts:")
    print(mapped_output["mapping_status"].value_counts(dropna=False).to_string())
    print(
        "\nRows requiring manual review: "
        f"{int(mapped_output['manual_review_required'].sum())}"
    )
    print(
        "Rows with recommended context checks: "
        f"{int(mapped_output['context_check_recommended'].sum())}"
    )

    if unmapped_resources:
        print("\nExplicitly unmapped resources:")
        for resource in unmapped_resources:
            print(f"  - {resource}")

    print(f"\nOutput written:\n  {written_output}")


def main(argv: Sequence[str] | None = None) -> None:
    """Run the Lang assimilation-efficiency extraction workflow.

    Args:
        argv: Optional command-line arguments for testing.

    """

    arguments = parse_arguments(argv)
    input_path = validate_input_path(arguments.input)

    raw_data = load_raw_data(input_path)
    observations = extract_assimilation_efficiency(raw_data)
    observations = add_resource_context_counts(observations)

    mapped_columns = observations.apply(apply_mapping, axis=1)
    mapped_data = pd.concat(
        [
            observations.reset_index(drop=True),
            mapped_columns.reset_index(drop=True),
        ],
        axis=1,
    )

    mapped_output = finalise_output(mapped_data)
    output_path = arguments.output.expanduser()
    written_output = write_csv_safely(mapped_output, output_path)
    print_run_summary(input_path, raw_data, mapped_output, written_output)


if __name__ == "__main__":
    main()
