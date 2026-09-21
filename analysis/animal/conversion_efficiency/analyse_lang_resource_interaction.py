"""
---
title: Analyse Lang resource-interaction conversion efficiency for Virtual Ecosystem

description: |
  Analyse the Lang et al. (2017) assimilation-efficiency observations mapped to
  current Virtual Ecosystem (VE) animal DietType resources and derive candidate
  resource-level conversion efficiency (CE) values for the animal module.

  This is the second script in the Lang-to-VE workflow. It reads the mapped
  observation table produced by the extraction/mapping script, calculates
  source-study-balanced CE estimates for each current VE atomic resource type,
  evaluates the strength and mapping sensitivity of the Lang evidence, and
  writes a compact developer-facing recommendation table.

virtual_ecosystem_module:
  - Animal

author:
  - Siti Nor Baizurah

status: wip

input_files:
  - name: Lang_et_al_2017_VE_mapped_observations.csv
    path: Required local path supplied with --input
    description: |
      Observation-level Lang et al. (2017) assimilation-efficiency data mapped to
      current VE DietType resources by the first Lang-to-VE extraction script.

output_files:
  - name: Lang_et_al_2017_VE_CE_recommendations.csv
    path: By default, written beside the mapped input CSV; override with --output
    description: |
      Compact resource-level CE recommendation table for VE developers. Direct
      Lang mappings define the primary estimate; inferred mappings are used only
      for sensitivity checks and proxy mappings are excluded from CE estimation.

package_dependencies:
  - argparse
  - dataclasses
  - pathlib
  - pandas
  - virtual-ecosystem

usage_notes: |
  Run the Lang-to-VE extraction/mapping script first and pass the resulting
  mapped observation CSV explicitly with --input. The data can remain outside
  the Git repository, for example in a local Globus-managed data folder.

  Current VE atomic resources are read directly from
  virtual_ecosystem.models.animal.animal_traits.DietType. This avoids maintaining
  a duplicated resource list in this script.

  For each VE resource, the primary Lang CE is the median across original
  source-study medians from direct mappings. Inferred mappings are used only to
  assess mapping sensitivity, and proxy mappings are reported but excluded from
  CE estimation.

  The evidence and mapping-sensitivity thresholds are transparent screening
  defaults, not biological cut-offs. They can be changed from the command line
  without editing this script.

  Lang et al. (2017) is an ectotherm-focused dataset. Resulting values should be
  treated as resource-level CE baselines rather than evidence that CE is
  identical across ectothermic and endothermic consumers.

  Example:
    uv run python analysis/animal/analyse_lang_resource_interaction_CE.py \
      --input C:/path/to/Globus/Lang_et_al_2017_VE_mapped_observations.csv
---
"""  # noqa: D400, D212, D205, D415

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

import pandas as pd


DEFAULT_OUTPUT_BASENAME = "Lang_et_al_2017_VE_CE_recommendations.csv"

REQUIRED_COLUMNS = {
    "taxonomic.name",
    "taxonomic.group.consumer",
    "resource",
    "consumer.type",
    "temperature.degree.C",
    "assimilation.efficiency",
    "reference.original",
    "ve_diet_type",
    "mapping_status",
}

VALID_MAPPING_STATUSES = {"direct", "inferred", "proxy", "exclude", "unmapped"}


@dataclass(frozen=True)
class ScreeningRules:
    """Configurable evidence and mapping-sensitivity screening rules."""

    strong_min_direct_studies: int = 3
    strong_min_direct_species: int = 3
    moderate_min_direct_studies: int = 2
    moderate_min_direct_species: int = 2
    low_sensitivity_max_delta: float = 0.05
    moderate_sensitivity_max_delta: float = 0.10

    def validate(self) -> None:
        """Validate rule ordering and ranges."""
        count_values = [
            self.strong_min_direct_studies,
            self.strong_min_direct_species,
            self.moderate_min_direct_studies,
            self.moderate_min_direct_species,
        ]
        if any(value < 1 for value in count_values):
            raise ValueError("All evidence-count thresholds must be >= 1.")
        if self.strong_min_direct_studies < self.moderate_min_direct_studies:
            raise ValueError("Strong study threshold must be >= moderate threshold.")
        if self.strong_min_direct_species < self.moderate_min_direct_species:
            raise ValueError("Strong species threshold must be >= moderate threshold.")
        if self.low_sensitivity_max_delta < 0:
            raise ValueError("Low sensitivity delta must be >= 0.")
        if self.moderate_sensitivity_max_delta < self.low_sensitivity_max_delta:
            raise ValueError(
                "Moderate sensitivity delta must be >= low sensitivity delta."
            )


def get_atomic_ve_resource_types() -> list[str]:
    """Read current atomic animal resource types directly from VE DietType."""
    try:
        from virtual_ecosystem.models.animal.animal_traits import DietType
    except ImportError as exc:
        raise ImportError(
            "Could not import Virtual Ecosystem DietType. Run this script from the "
            "ve_data_science environment (for example with `uv run python ...`) "
            "so the `virtual-ecosystem` dependency is available."
        ) from exc

    excluded = {"HERBIVORE", "CARNIVORE", "OMNIVORE", "NONFEEDING"}
    resources: list[str] = []

    for name, member in DietType.__members__.items():
        if name in excluded:
            continue
        value = int(member.value)
        if value > 0 and value & (value - 1) == 0:
            resources.append(name.upper())

    if not resources:
        raise RuntimeError("No atomic VE DietType resources could be identified.")

    return resources


def load_mapped_data(path: Path, resource_types: list[str]) -> pd.DataFrame:
    """Load and validate the mapped Lang observation table."""
    if not path.exists():
        raise FileNotFoundError(
            f"Mapped Lang file not found: {path}\nCheck the path supplied with --input."
        )

    data = pd.read_csv(path)
    missing = sorted(REQUIRED_COLUMNS - set(data.columns))
    if missing:
        raise ValueError(
            "Mapped Lang file is missing required columns:\n  - "
            + "\n  - ".join(missing)
        )

    data = data.copy()
    data["ve_diet_type"] = data["ve_diet_type"].astype("string").str.strip().str.upper()
    data["mapping_status"] = (
        data["mapping_status"].astype("string").str.strip().str.lower()
    )
    data["assimilation.efficiency"] = pd.to_numeric(
        data["assimilation.efficiency"], errors="coerce"
    )
    data["temperature.degree.C"] = pd.to_numeric(
        data["temperature.degree.C"], errors="coerce"
    )

    invalid_statuses = sorted(
        set(data["mapping_status"].dropna().astype(str)) - VALID_MAPPING_STATUSES
    )
    if invalid_statuses:
        raise ValueError(
            "Mapped Lang file contains unknown mapping_status values: "
            + ", ".join(invalid_statuses)
        )

    invalid_ae = data[
        data["assimilation.efficiency"].notna()
        & ~data["assimilation.efficiency"].between(0, 1, inclusive="both")
    ]
    if not invalid_ae.empty:
        raise ValueError(
            f"Found {len(invalid_ae)} assimilation-efficiency values outside 0-1."
        )

    known_resources = set(resource_types)
    observed_resources = set(data["ve_diet_type"].dropna().astype(str))
    unknown_resources = sorted(observed_resources - known_resources)
    if unknown_resources:
        raise ValueError(
            "Mapped Lang file contains VE resource types that are not current atomic "
            "DietType resources: " + ", ".join(unknown_resources)
        )

    return data


def lang_source_balanced_estimate(data: pd.DataFrame) -> dict[str, float | int | None]:
    """Calculate a source-study-balanced CE estimate for one resource subset."""
    usable = data.dropna(
        subset=["assimilation.efficiency", "reference.original"]
    ).copy()

    if usable.empty:
        return {
            "estimate": None,
            "study_q25": None,
            "study_q75": None,
            "study_min": None,
            "study_max": None,
            "n_studies_with_ce": 0,
        }

    study_medians = usable.groupby("reference.original")[
        "assimilation.efficiency"
    ].median()

    return {
        "estimate": float(study_medians.median()),
        "study_q25": float(study_medians.quantile(0.25)),
        "study_q75": float(study_medians.quantile(0.75)),
        "study_min": float(study_medians.min()),
        "study_max": float(study_medians.max()),
        "n_studies_with_ce": int(study_medians.size),
    }


def unique_text(values: pd.Series) -> str:
    """Return sorted unique non-empty values as a compact semicolon list."""
    cleaned = {
        str(value).strip()
        for value in values.dropna()
        if str(value).strip() and str(value).strip().lower() != "nan"
    }
    return "; ".join(sorted(cleaned))


def classify_evidence(
    n_direct_studies: int,
    n_direct_species: int,
    n_direct: int,
    rules: ScreeningRules,
) -> str:
    """Assign an evidence class using configurable screening rules."""
    if (
        n_direct_studies >= rules.strong_min_direct_studies
        and n_direct_species >= rules.strong_min_direct_species
    ):
        return "strong"

    if (
        n_direct_studies >= rules.moderate_min_direct_studies
        and n_direct_species >= rules.moderate_min_direct_species
    ):
        return "moderate"

    if n_direct > 0:
        return "weak"

    return "unsupported"


def classify_mapping_sensitivity(
    direct_ce: float | None,
    direct_plus_inferred_ce: float | None,
    n_inferred: int,
    rules: ScreeningRules,
) -> tuple[float | None, str]:
    """Describe how much inferred mappings change the resource CE estimate."""
    if n_inferred == 0:
        return None, "not_applicable_no_inferred_rows"
    if direct_ce is None:
        return None, "cannot_test_no_direct_baseline"
    if direct_plus_inferred_ce is None:
        return None, "cannot_test"

    delta = abs(float(direct_plus_inferred_ce) - float(direct_ce))

    if delta <= rules.low_sensitivity_max_delta:
        level = "low"
    elif delta <= rules.moderate_sensitivity_max_delta:
        level = "moderate"
    else:
        level = "high"

    return delta, level


def literature_decision(evidence: str, sensitivity: str) -> tuple[str, str]:
    """Return literature need and recommendation status."""
    if evidence == "strong":
        if sensitivity == "high":
            return (
                "targeted_check_recommended",
                "provisional_lang_value_mapping_sensitive",
            )
        return (
            "not_required_for_lang_baseline_but_external_validation_recommended",
            "lang_supported_candidate",
        )

    if evidence == "moderate":
        return (
            "targeted_check_recommended_before_finalising",
            "provisional_pending_targeted_literature",
        )

    if evidence == "weak":
        return (
            "required_before_final_recommendation",
            "insufficient_for_final_ce",
        )

    return (
        "required_no_direct_lang_support",
        "no_lang_ce_recommendation",
    )


def recommendation_reason(
    evidence: str,
    n_direct: int,
    n_direct_studies: int,
    n_direct_species: int,
    n_inferred: int,
    n_proxy: int,
    sensitivity: str,
) -> str:
    """Generate a human-readable reason suitable for sharing with developers."""
    base = (
        f"{n_direct} direct Lang observations from {n_direct_studies} original "
        f"source study/studies and {n_direct_species} consumer species; "
        f"evidence={evidence}."
    )

    extras: list[str] = []
    if n_inferred:
        extras.append(
            f"{n_inferred} inferred observations used only for sensitivity "
            f"({sensitivity})."
        )
    if n_proxy:
        extras.append(
            f"{n_proxy} proxy observations reported but excluded from CE estimation."
        )

    if evidence == "unsupported":
        extras.append("No direct Lang observations can define this VE resource CE.")
    elif evidence == "weak":
        extras.append("Lang coverage is too limited for a final VE CE.")
    elif evidence == "moderate":
        extras.append(
            "Lang provides a provisional value; targeted literature should confirm it."
        )
    elif sensitivity == "high":
        extras.append(
            "The estimate is sensitive to inferred mappings; review/add literature."
        )
    else:
        extras.append("Lang can support a baseline resource-level CE candidate.")

    return " ".join([base] + extras)


def summarise_resource(
    data: pd.DataFrame,
    resource_type: str,
    rules: ScreeningRules,
) -> dict[str, object]:
    """Summarise one VE resource type and apply the recommendation logic."""
    resource = data[data["ve_diet_type"].eq(resource_type)].copy()

    direct = resource[resource["mapping_status"].eq("direct")].copy()
    inferred = resource[resource["mapping_status"].eq("inferred")].copy()
    proxy = resource[resource["mapping_status"].eq("proxy")].copy()
    excluded = resource[
        resource["mapping_status"].isin(["exclude", "unmapped"])
    ].copy()
    direct_plus_inferred = pd.concat([direct, inferred], ignore_index=True)

    n_total = int(len(resource))
    n_direct = int(len(direct))
    n_inferred = int(len(inferred))
    n_proxy = int(len(proxy))
    n_excluded = int(len(excluded))
    n_direct_studies = int(direct["reference.original"].dropna().nunique())
    n_direct_species = int(direct["taxonomic.name"].dropna().nunique())

    direct_stats = lang_source_balanced_estimate(direct)
    support_stats = lang_source_balanced_estimate(direct_plus_inferred)
    direct_ce = direct_stats["estimate"]
    support_ce = support_stats["estimate"]

    delta, sensitivity = classify_mapping_sensitivity(
        direct_ce,
        support_ce,
        n_inferred,
        rules,
    )
    evidence = classify_evidence(
        n_direct_studies,
        n_direct_species,
        n_direct,
        rules,
    )
    literature_need, status = literature_decision(evidence, sensitivity)

    recommended_ce = direct_ce if evidence in {"strong", "moderate"} else None

    direct_ae = direct["assimilation.efficiency"].dropna()
    direct_temp = direct["temperature.degree.C"].dropna()

    return {
        "ve_resource_type": resource_type,
        "recommended_ce": recommended_ce,
        "recommendation_status": status,
        "evidence_strength": evidence,
        "lang_primary_ce_direct_study_balanced": direct_ce,
        "lang_support_ce_direct_plus_inferred": support_ce,
        "mapping_sensitivity_abs_delta": delta,
        "ce_sensitivity_to_inferred_mappings": sensitivity,
        "direct_study_ce_q25": direct_stats["study_q25"],
        "direct_study_ce_q75": direct_stats["study_q75"],
        "direct_study_ce_min": direct_stats["study_min"],
        "direct_study_ce_max": direct_stats["study_max"],
        "direct_observation_mean": (
            float(direct_ae.mean()) if not direct_ae.empty else None
        ),
        "direct_observation_median": (
            float(direct_ae.median()) if not direct_ae.empty else None
        ),
        "n_total_mapped_rows": n_total,
        "n_direct": n_direct,
        "n_inferred": n_inferred,
        "n_proxy": n_proxy,
        "n_excluded_or_unmapped": n_excluded,
        "n_direct_studies": n_direct_studies,
        "n_lang_consumer_species": n_direct_species,
        "direct_taxonomic_groups": unique_text(direct["taxonomic.group.consumer"]),
        "direct_consumer_types": unique_text(direct["consumer.type"]),
        "direct_temperature_median_C": (
            float(direct_temp.median()) if not direct_temp.empty else None
        ),
        "direct_temperature_min_C": (
            float(direct_temp.min()) if not direct_temp.empty else None
        ),
        "direct_temperature_max_C": (
            float(direct_temp.max()) if not direct_temp.empty else None
        ),
        "additional_literature_needed": literature_need,
        "recommendation_reason": recommendation_reason(
            evidence,
            n_direct,
            n_direct_studies,
            n_direct_species,
            n_inferred,
            n_proxy,
            sensitivity,
        ),
        "lang_scope": "ectotherm_consumers",
        "scope_caveat": (
            "Resource-level Lang baseline only; does not demonstrate identical CE "
            "across ectothermic and endothermic consumers."
        ),
        "primary_estimate_rule": (
            "median across original source-study medians from direct Lang mappings"
        ),
    }


SHARE_COLUMNS = [
    "ve_resource_type",
    "recommended_ce",
    "lang_source_study_ce_iqr",
    "evidence_strength",
    "n_lang_source_studies",
    "n_lang_consumer_species",
    "ce_sensitivity_to_inferred_mappings",
    "additional_literature_needed",
    "recommendation_reason",
]


def build_analysis(
    data: pd.DataFrame,
    resource_types: list[str],
    rules: ScreeningRules,
) -> pd.DataFrame:
    """Build the compact VE resource-interaction recommendation table."""
    rows = [summarise_resource(data, resource, rules) for resource in resource_types]
    result = pd.DataFrame(rows)

    evidence_order = {
        "strong": 0,
        "moderate": 1,
        "weak": 2,
        "unsupported": 3,
    }
    result["_sort"] = result["evidence_strength"].map(evidence_order).fillna(9)
    result = result.sort_values(
        ["_sort", "ve_resource_type"], ascending=[True, True]
    ).drop(columns="_sort")

    result["recommended_ce"] = pd.to_numeric(
        result["recommended_ce"], errors="coerce"
    ).round(4)

    def format_iqr(row: pd.Series) -> str:
        q25 = row.get("direct_study_ce_q25")
        q75 = row.get("direct_study_ce_q75")
        if pd.isna(q25) or pd.isna(q75):
            return ""
        return f"{float(q25):.4f}-{float(q75):.4f}"

    result["lang_source_study_ce_iqr"] = result.apply(format_iqr, axis=1)
    result["n_lang_source_studies"] = result["n_direct_studies"]
    result["ce_sensitivity_to_inferred_mappings"] = result[
        "ce_sensitivity_to_inferred_mappings"
    ].replace(
        {
            "not_applicable_no_inferred_rows": "not applicable",
            "cannot_test_no_direct_baseline": "cannot test",
            "cannot_test": "cannot test",
        }
    )

    return result[SHARE_COLUMNS].copy()


def write_csv_safely(result: pd.DataFrame, output_path: Path) -> Path:
    """Write the recommendation table, using a numbered fallback if locked."""
    output_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        result.to_csv(output_path, index=False)
        return output_path
    except PermissionError:
        number = 1
        while True:
            fallback = output_path.with_name(
                f"{output_path.stem}_{number}{output_path.suffix}"
            )
            if fallback.exists():
                number += 1
                continue
            result.to_csv(fallback, index=False)
            print(
                "\nWARNING: Could not overwrite the requested output file. "
                "It may be open in another program."
            )
            print(f"Saved instead as:\n  {fallback}")
            return fallback


def print_summary(result: pd.DataFrame, input_path: Path, output_path: Path) -> None:
    """Print a compact decision summary to the terminal."""
    print(f"Input used:\n  {input_path}")
    print(f"\nVE resource types assessed: {len(result)}")

    print("\nEvidence strength:")
    print(result["evidence_strength"].value_counts().to_string())

    display_cols = [
        "ve_resource_type",
        "recommended_ce",
        "evidence_strength",
        "n_lang_source_studies",
        "n_lang_consumer_species",
        "ce_sensitivity_to_inferred_mappings",
        "additional_literature_needed",
    ]
    print("\nResource-interaction CE decision table:")
    print(result[display_cols].to_string(index=False))

    needs_literature = result[
        result["additional_literature_needed"].isin(
            [
                "targeted_check_recommended",
                "targeted_check_recommended_before_finalising",
                "required_before_final_recommendation",
                "required_no_direct_lang_support",
            ]
        )
    ]

    print("\nResources needing targeted/additional literature:")
    if needs_literature.empty:
        print("  None under the current screening rules.")
    else:
        for _, row in needs_literature.iterrows():
            print(
                f"  - {row['ve_resource_type']}: "
                f"{row['additional_literature_needed']}"
            )

    print(f"\nCSV written:\n  {output_path}")


def parse_args() -> argparse.Namespace:
    """Parse input/output paths and configurable screening rules."""
    parser = argparse.ArgumentParser(
        description=(
            "Analyse mapped Lang assimilation-efficiency observations and derive "
            "resource-level VE CE recommendations."
        )
    )
    parser.add_argument(
        "--input",
        type=Path,
        required=True,
        help=(
            "Local path to the mapped observation CSV produced by "
            "extract_lang_assimilation_to_VE.py."
        ),
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help=(
            "Recommendation CSV. If omitted, write "
            "Lang_et_al_2017_VE_CE_recommendations.csv beside the input file."
        ),
    )
    parser.add_argument(
        "--strong-min-studies",
        type=int,
        default=3,
        help="Minimum direct source studies for strong evidence (default: 3).",
    )
    parser.add_argument(
        "--strong-min-species",
        type=int,
        default=3,
        help="Minimum direct consumer species for strong evidence (default: 3).",
    )
    parser.add_argument(
        "--moderate-min-studies",
        type=int,
        default=2,
        help="Minimum direct source studies for moderate evidence (default: 2).",
    )
    parser.add_argument(
        "--moderate-min-species",
        type=int,
        default=2,
        help="Minimum direct consumer species for moderate evidence (default: 2).",
    )
    parser.add_argument(
        "--low-sensitivity-max-delta",
        type=float,
        default=0.05,
        help="Maximum absolute CE delta classified as low sensitivity (default: 0.05).",
    )
    parser.add_argument(
        "--moderate-sensitivity-max-delta",
        type=float,
        default=0.10,
        help=(
            "Maximum absolute CE delta classified as moderate sensitivity "
            "(default: 0.10)."
        ),
    )
    return parser.parse_args()


def main() -> None:
    """Run the Lang resource-interaction CE screening analysis."""
    args = parse_args()
    input_path = args.input.expanduser().resolve()
    requested_output = (
        args.output.expanduser().resolve()
        if args.output is not None
        else input_path.with_name(DEFAULT_OUTPUT_BASENAME)
    )

    rules = ScreeningRules(
        strong_min_direct_studies=args.strong_min_studies,
        strong_min_direct_species=args.strong_min_species,
        moderate_min_direct_studies=args.moderate_min_studies,
        moderate_min_direct_species=args.moderate_min_species,
        low_sensitivity_max_delta=args.low_sensitivity_max_delta,
        moderate_sensitivity_max_delta=args.moderate_sensitivity_max_delta,
    )
    rules.validate()

    resource_types = get_atomic_ve_resource_types()
    data = load_mapped_data(input_path, resource_types)
    result = build_analysis(data, resource_types, rules)
    output_path = write_csv_safely(result, requested_output)

    print(
        "VE resources: current atomic DietType values read directly from "
        "virtual_ecosystem."
    )
    print(
        "Screening rules: "
        f"strong >= {rules.strong_min_direct_studies} studies and "
        f"{rules.strong_min_direct_species} species; "
        f"moderate >= {rules.moderate_min_direct_studies} studies and "
        f"{rules.moderate_min_direct_species} species; "
        f"sensitivity deltas <= {rules.low_sensitivity_max_delta} / "
        f"{rules.moderate_sensitivity_max_delta}."
    )
    print_summary(result, input_path, output_path)


if __name__ == "__main__":
    main()
