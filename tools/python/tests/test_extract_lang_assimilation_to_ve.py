"""Tests for the Lang assimilation-efficiency extraction workflow."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path
from types import ModuleType

import pandas as pd
import pytest

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT_PATH = (
    REPO_ROOT
    / "analysis"
    / "animal"
    / "lang_assimilation"
    / "extract_lang_assimilation_to_VE.py"
)


def load_script_module() -> ModuleType:
    """Load the Lang extraction script as a Python module for testing."""

    spec = importlib.util.spec_from_file_location(
        "extract_lang_assimilation", SCRIPT_PATH
    )
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load script module from {SCRIPT_PATH}")

    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


LANG_SCRIPT = load_script_module()


def write_lang_csv(csv_path: Path, rows: list[dict[str, object]]) -> None:
    """Write a test Lang CSV with the documented metadata row and header row."""

    frame = pd.DataFrame(rows)
    metadata_row = ",".join(["Lang et al. staged test data"] * len(frame.columns))
    csv_path.write_text(
        metadata_row + "\n" + frame.to_csv(index=False, lineterminator="\n"),
        encoding="utf-8",
        newline="\n",
    )


@pytest.fixture
def sample_rows() -> list[dict[str, object]]:
    """Provide representative Lang observations for testing."""

    return [
        {
            "taxonomic.name": "Species B",
            "taxonomic.group.consumer": "Insect",
            "resource": "Animal",
            "consumer.type": "Predator",
            "body.size.gram": 3.2,
            "temperature.degree.C": 21.0,
            "assimilation.efficiency": 0.8,
            "reference.short": "Ref B",
            "reference.original": "Reference B",
            "comments": "Animal prey resource",
        },
        {
            "taxonomic.name": "Species A",
            "taxonomic.group.consumer": "Insect",
            "resource": "Leaves",
            "consumer.type": "Herbivore",
            "body.size.gram": 1.1,
            "temperature.degree.C": 20.0,
            "assimilation.efficiency": 0.4,
            "reference.short": "Ref A",
            "reference.original": "Reference A",
            "comments": "Plant resource",
        },
        {
            "taxonomic.name": "Species C",
            "taxonomic.group.consumer": "Insect",
            "resource": "Detritus",
            "consumer.type": "Detritivore",
            "body.size.gram": 2.4,
            "temperature.degree.C": 18.0,
            "assimilation.efficiency": 0.3,
            "reference.short": "Ref C",
            "reference.original": "Reference C",
            "comments": "Should remain explicitly unmapped",
        },
        {
            "taxonomic.name": "Species D",
            "taxonomic.group.consumer": "Insect",
            "resource": "Leaves",
            "consumer.type": "Herbivore",
            "body.size.gram": 4.5,
            "temperature.degree.C": 22.0,
            "assimilation.efficiency": -1000,
            "reference.short": "Ref D",
            "reference.original": "Reference D",
            "comments": "Filtered out by Lang threshold",
        },
    ]


def test_extract_filters_lang_threshold_and_preserves_output_columns(
    tmp_path: Path, sample_rows: list[dict[str, object]]
) -> None:
    """Retain only valid Lang observations and keep the documented columns."""

    input_path = tmp_path / LANG_SCRIPT.EXPECTED_INPUT_NAME
    output_path = tmp_path / "mapped" / LANG_SCRIPT.DEFAULT_OUTPUT_NAME
    write_lang_csv(input_path, sample_rows)

    LANG_SCRIPT.main(["--input", str(input_path), "--output", str(output_path)])

    written = pd.read_csv(output_path)
    assert len(written) == 3
    assert list(written.columns) == LANG_SCRIPT.OUTPUT_COLUMNS
    assert written["assimilation.efficiency"].tolist() == [0.4, 0.8, 0.3]


def test_retained_values_must_be_between_zero_and_one(tmp_path: Path) -> None:
    """Reject retained assimilation efficiencies outside the valid range."""

    input_path = tmp_path / LANG_SCRIPT.EXPECTED_INPUT_NAME
    rows = [
        {
            "taxonomic.name": "Species A",
            "taxonomic.group.consumer": "Insect",
            "resource": "Leaves",
            "consumer.type": "Herbivore",
            "body.size.gram": 1.1,
            "temperature.degree.C": 20.0,
            "assimilation.efficiency": 1.2,
            "reference.short": "Ref A",
            "reference.original": "Reference A",
            "comments": "Invalid retained value",
        }
    ]
    write_lang_csv(input_path, rows)

    with pytest.raises(ValueError, match="must fall within 0 to 1"):
        LANG_SCRIPT.main(["--input", str(input_path)])


def test_input_header_order_must_match_documented_schema(tmp_path: Path) -> None:
    """Reject staged CSV files that reorder the documented Lang header."""

    input_path = tmp_path / LANG_SCRIPT.EXPECTED_INPUT_NAME
    rows = [
        {
            "resource": "Leaves",
            "taxonomic.name": "Species A",
            "taxonomic.group.consumer": "Insect",
            "consumer.type": "Herbivore",
            "body.size.gram": 1.1,
            "temperature.degree.C": 20.0,
            "assimilation.efficiency": 0.4,
            "reference.short": "Ref A",
            "reference.original": "Reference A",
            "comments": "Header order should fail",
        }
    ]
    write_lang_csv(input_path, rows)

    with pytest.raises(ValueError, match="expected header order"):
        LANG_SCRIPT.main(["--input", str(input_path)])


def test_context_check_recommended_uses_consumer_and_reference_counts(
    tmp_path: Path,
) -> None:
    """Flag resources that appear with multiple consumers or references."""

    input_path = tmp_path / LANG_SCRIPT.EXPECTED_INPUT_NAME
    output_path = tmp_path / LANG_SCRIPT.DEFAULT_OUTPUT_NAME
    rows = [
        {
            "taxonomic.name": "Species A",
            "taxonomic.group.consumer": "Insect",
            "resource": "Leaves",
            "consumer.type": "Herbivore",
            "body.size.gram": 1.0,
            "temperature.degree.C": 20.0,
            "assimilation.efficiency": 0.3,
            "reference.short": "Ref A",
            "reference.original": "Reference A",
            "comments": "First leaf record",
        },
        {
            "taxonomic.name": "Species B",
            "taxonomic.group.consumer": "Insect",
            "resource": "Leaves",
            "consumer.type": "Herbivore",
            "body.size.gram": 2.0,
            "temperature.degree.C": 21.0,
            "assimilation.efficiency": 0.5,
            "reference.short": "Ref B",
            "reference.original": "Reference B",
            "comments": "Second leaf record",
        },
        {
            "taxonomic.name": "Species C",
            "taxonomic.group.consumer": "Insect",
            "resource": "Fruit",
            "consumer.type": "Herbivore",
            "body.size.gram": 3.0,
            "temperature.degree.C": 22.0,
            "assimilation.efficiency": 0.6,
            "reference.short": "Ref C",
            "reference.original": "Reference C",
            "comments": "Single fruit record",
        },
    ]
    write_lang_csv(input_path, rows)

    LANG_SCRIPT.main(["--input", str(input_path), "--output", str(output_path)])
    written = pd.read_csv(output_path)

    leaf_flags = written.loc[
        written["resource"] == "Leaves", "context_check_recommended"
    ].tolist()
    fruit_flags = written.loc[
        written["resource"] == "Fruit", "context_check_recommended"
    ].tolist()

    assert leaf_flags == [True, True]
    assert fruit_flags == [False]


def test_unmapped_resources_remain_explicitly_flagged(
    tmp_path: Path, sample_rows: list[dict[str, object]]
) -> None:
    """Keep unmapped resource labels in the output with explicit review flags."""

    input_path = tmp_path / LANG_SCRIPT.EXPECTED_INPUT_NAME
    output_path = tmp_path / LANG_SCRIPT.DEFAULT_OUTPUT_NAME
    write_lang_csv(input_path, sample_rows)

    LANG_SCRIPT.main(["--input", str(input_path), "--output", str(output_path)])
    written = pd.read_csv(output_path)

    unmapped_row = written.loc[written["resource"] == "Detritus"].iloc[0]
    assert pd.isna(unmapped_row["ve_diet_type"])
    assert unmapped_row["mapping_status"] == "unmapped"
    assert bool(unmapped_row["manual_review_required"]) is True
    assert "manual review" in unmapped_row["mapping_note"].lower()


def test_context_overrides_are_applied_when_configured(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Apply a context-specific override before falling back to direct mapping."""

    monkeypatch.setitem(
        LANG_SCRIPT.CONTEXT_OVERRIDES,
        ("detritus", "detritivore", "ref d"),
        LANG_SCRIPT.MappingRecord(
            "herbivore",
            "Project-specific override retained as a reproducibility record.",
        ),
    )

    row = pd.Series(
        {
            "resource": "Detritus",
            "consumer.type": "Detritivore",
            "reference.short": "Ref D",
        }
    )

    mapped = LANG_SCRIPT.apply_mapping(row)

    assert mapped["ve_diet_type"] == "herbivore"
    assert mapped["mapping_status"] == "context_override"
    assert bool(mapped["manual_review_required"]) is True


def test_default_output_path_uses_current_working_directory(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    sample_rows: list[dict[str, object]],
) -> None:
    """Write the default output in the current working directory when omitted."""

    input_path = tmp_path / LANG_SCRIPT.EXPECTED_INPUT_NAME
    write_lang_csv(input_path, sample_rows)
    monkeypatch.chdir(tmp_path)

    LANG_SCRIPT.main(["--input", str(input_path)])

    output_path = tmp_path / LANG_SCRIPT.DEFAULT_OUTPUT_NAME
    assert output_path.is_file()


def test_main_prints_audit_summary(
    tmp_path: Path,
    capsys: pytest.CaptureFixture[str],
    sample_rows: list[dict[str, object]],
) -> None:
    """Emit the checksum and audit summary fields documented for the workflow."""

    input_path = tmp_path / LANG_SCRIPT.EXPECTED_INPUT_NAME
    output_path = tmp_path / LANG_SCRIPT.DEFAULT_OUTPUT_NAME
    write_lang_csv(input_path, sample_rows)

    LANG_SCRIPT.main(["--input", str(input_path), "--output", str(output_path)])
    captured = capsys.readouterr().out

    assert "Input file:" in captured
    assert "Input SHA-256:" in captured
    assert "Raw rows loaded:" in captured
    assert "Assimilation-efficiency rows retained:" in captured
    assert "Mapping status counts:" in captured
    assert "Rows requiring manual review:" in captured
    assert "Rows with recommended context checks:" in captured
    assert "Output written:" in captured


def test_deterministic_output_sorting_and_utf8_newlines(
    tmp_path: Path, sample_rows: list[dict[str, object]]
) -> None:
    """Write deterministically sorted UTF-8 output with Unix line endings."""

    input_path = tmp_path / LANG_SCRIPT.EXPECTED_INPUT_NAME
    first_output = tmp_path / "run1.csv"
    second_output = tmp_path / "nested" / "run2.csv"
    write_lang_csv(input_path, list(reversed(sample_rows)))

    LANG_SCRIPT.main(["--input", str(input_path), "--output", str(first_output)])
    LANG_SCRIPT.main(["--input", str(input_path), "--output", str(second_output)])

    assert first_output.read_text(encoding="utf-8") == second_output.read_text(
        encoding="utf-8"
    )
    assert "\r\n" not in first_output.read_text(encoding="utf-8")


def test_write_csv_safely_uses_suffixed_fallback_when_target_is_locked(
    tmp_path: Path,
) -> None:
    """Write a suffixed fallback file when the requested path raises PermissionError."""

    output_path = tmp_path / "mapped.csv"
    fallback_path = tmp_path / "mapped_1.csv"
    data = pd.DataFrame({"value": [1, 2]})
    original_to_csv = pd.DataFrame.to_csv
    calls: list[Path] = []

    def fake_to_csv(self, path_or_buf=None, *args, **kwargs):
        if isinstance(path_or_buf, Path):
            target_path = path_or_buf
        elif hasattr(path_or_buf, "name"):
            target_path = Path(path_or_buf.name)
        else:
            target_path = Path(path_or_buf)
        calls.append(target_path)
        if target_path == output_path:
            raise PermissionError("File is locked")
        return original_to_csv(self, path_or_buf, *args, **kwargs)

    with pytest.MonkeyPatch.context() as patch:
        patch.setattr(pd.DataFrame, "to_csv", fake_to_csv)
        written_path = LANG_SCRIPT.write_csv_safely(data, output_path)

    assert written_path == fallback_path
    assert calls[0] == output_path
    assert fallback_path.is_file()


def test_write_csv_safely_skips_existing_suffixes(tmp_path: Path) -> None:
    """Advance to the next suffix when the first fallback filename is occupied."""

    output_path = tmp_path / "mapped.csv"
    occupied_fallback_path = tmp_path / "mapped_1.csv"
    final_fallback_path = tmp_path / "mapped_2.csv"
    occupied_fallback_path.write_text("occupied\n", encoding="utf-8")

    data = pd.DataFrame({"value": [1, 2]})
    original_to_csv = pd.DataFrame.to_csv
    calls: list[Path] = []

    def fake_to_csv(self, path_or_buf=None, *args, **kwargs):
        if isinstance(path_or_buf, Path):
            target_path = path_or_buf
        elif hasattr(path_or_buf, "name"):
            target_path = Path(path_or_buf.name)
        else:
            target_path = Path(path_or_buf)
        calls.append(target_path)
        if target_path == output_path:
            raise PermissionError("File is locked")
        return original_to_csv(self, path_or_buf, *args, **kwargs)

    with pytest.MonkeyPatch.context() as patch:
        patch.setattr(pd.DataFrame, "to_csv", fake_to_csv)
        written_path = LANG_SCRIPT.write_csv_safely(data, output_path)

    assert written_path == final_fallback_path
    assert calls[0] == output_path
    assert final_fallback_path.is_file()


def test_input_filename_validation(
    tmp_path: Path, sample_rows: list[dict[str, object]]
) -> None:
    """Reject staged files that do not preserve the expected Lang filename."""

    input_path = tmp_path / "renamed_lang_input.csv"
    write_lang_csv(input_path, sample_rows)

    with pytest.raises(ValueError, match="Expected the staged Lang input file"):
        LANG_SCRIPT.main(["--input", str(input_path)])
