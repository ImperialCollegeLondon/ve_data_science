"""Focused checks for new evidence records and preservation of pilot history."""

import csv
import importlib.util
import tomllib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = ROOT / ".github/skills/ve-constant-search/scripts"
spec = importlib.util.spec_from_file_location(
    "validate_constant_results", SCRIPTS / "validate_constant_results.py"
)
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)
NAME = "virtual_ecosystem.models.soil.microbial_groups.SoilMicrobe.c_n_ratio"


def write_csv(path, rows):
    """Write fixture records with named columns."""
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


@pytest.fixture
def evidence(tmp_path):
    """Provide synthetic evidence, not scientific findings."""
    assets = SCRIPTS.parent / "assets"
    inventory = tomllib.loads(validator.ASSET.read_text(encoding="utf-8"))
    with (assets / "soil_constant_literature_values.csv").open() as stream:
        row = dict.fromkeys(next(csv.reader(stream)), "")
    row.update(
        qualified_name=NAME,
        ve_commit=inventory["metadata"]["project_commit"],
        retrieved_at="2026-11-14T00:00:00+00:00",
        status="value_found",
        rationale="Synthetic fixture only.",
        suggested_value="7.2",
        unit="unitless",
        quote="Synthetic test quotation, not published evidence.",
        source_location="Synthetic table 1",
        measurement_conditions="Synthetic bacterial fixture",
        confidence="high",
        name="c_n_ratio",
        group="bacteria",
        doi="10.0000/synthetic",
    )
    with (assets / "constant_search_log.csv").open() as stream:
        log = dict.fromkeys(next(csv.reader(stream)), "")
    log.update(
        qualified_name=NAME,
        ve_commit=row["ve_commit"],
        search_status="success",
        full_text_status="verified",
        doi=row["doi"],
    )
    values_path = tmp_path / "values.csv"
    log_path = tmp_path / "log.csv"
    write_csv(values_path, [row])
    write_csv(log_path, [log])
    return row, log, values_path, log_path


def test_traceable_value_and_no_doi_pdf(evidence):
    """Full-text links accept an exact DOI or a retained PDF checksum."""
    row, log, values, logs = evidence
    assert validator.validate_results(values, logs, {NAME}) == 1
    row["doi"] = log["doi"] = ""
    row["rationale"] = "Synthetic source sha256=" + "a" * 64
    log["notes"] = row["rationale"]
    write_csv(values, [row])
    write_csv(logs, [log])
    assert validator.validate_results(values, logs, {NAME}) == 1


@pytest.mark.parametrize(
    ("field", "value", "message"),
    [
        ("group", "", "trait group"),
        ("group", "pooled", "trait group"),
        ("ve_commit", "stale", "commit does not match"),
        ("model_default", "5.2", "no model default"),
        ("quote", "", "full-text evidence field"),
        ("source_location", "", "full-text evidence field"),
        ("unit", "mol/mol", "Unit does not match"),
        ("suggested_value", "nan", "Non-finite"),
    ],
)
def test_reject_incomplete_or_misaligned_evidence(evidence, field, value, message):
    """Failures must not pass as complete proposals."""
    row, _, values, logs = evidence
    row[field] = value
    write_csv(values, [row])
    with pytest.raises(ValueError, match=message):
        validator.validate_results(values, logs, {NAME})


def test_abstract_does_not_verify_a_value(evidence):
    """A quotation field alone is not a verified source link."""
    _, log, values, logs = evidence
    log["full_text_status"] = "abstract_only"
    write_csv(logs, [log])
    with pytest.raises(ValueError, match="matching verified full-text"):
        validator.validate_results(values, logs, {NAME})


def test_gap_has_no_numbers_and_needs_successful_coverage(evidence):
    """Failed discovery is not a successful evidence gap."""
    row, log, values, logs = evidence
    row["status"] = "no_evidence"
    write_csv(values, [row])
    with pytest.raises(ValueError, match="Unsupported numeric"):
        validator.validate_results(values, logs, {NAME})
    row["suggested_value"] = ""
    write_csv(values, [row])
    assert validator.validate_results(values, logs, {NAME}) == 1
    log["search_status"] = "failed"
    write_csv(logs, [log])
    with pytest.raises(ValueError, match="Failed searches"):
        validator.validate_results(values, logs, {NAME})


def test_history_survives_schema_extension_and_stale_commit(evidence, tmp_path):
    """Baseline rows retain their fields and commit without revalidation."""
    row, _, values, logs = evidence
    old = {
        key: value
        for key, value in row.items()
        if key not in {"group", "source_location"}
    }
    old["ve_commit"] = "historical"
    baseline = tmp_path / "baseline.csv"
    write_csv(baseline, [old])
    write_csv(values, [{**old, "group": "", "source_location": ""}, row])
    assert (
        validator.validate_results(values, logs, {NAME}, baseline_values=baseline) == 1
    )
    old["rationale"] = "Changed without approval"
    write_csv(values, [{**old, "group": "", "source_location": ""}, row])
    with pytest.raises(ValueError, match="Prior rows removed or changed"):
        validator.validate_results(values, logs, {NAME}, baseline_values=baseline)


def test_preserve_unrelated_rows_and_append_only_logs(evidence, tmp_path):
    """Approval to replace one parameter never covers another or its old log."""
    row, log, values, logs = evidence
    other = {**row, "qualified_name": "other.parameter"}
    baseline = tmp_path / "baseline.csv"
    write_csv(baseline, [other])
    with pytest.raises(ValueError, match="Prior rows"):
        validator.validate_results(
            values, logs, {NAME}, baseline_values=baseline, replace_names={NAME}
        )
    baseline_log = tmp_path / "baseline-log.csv"
    write_csv(baseline_log, [{**log, "notes": "Original log"}])
    with pytest.raises(ValueError, match="append-only"):
        validator.validate_results(values, logs, {NAME}, baseline_log=baseline_log)
