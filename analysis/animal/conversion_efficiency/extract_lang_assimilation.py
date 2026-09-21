"""
---

title: Extract Lang assimilation efficiency observations and map to VE resources

description: |
  Extract assimilation-efficiency observations from Lang et al. (2017),
  classify their resources using Virtual Ecosystem resource types, and write
  a review-ready CSV for the animal resource-specific assimilation-efficiency
  workflow.

  Direct observations are separated from inferred, proxy, excluded, and
  unmapped records. Resource labels are normalised internally while the
  original Lang labels are retained in the output for traceability.

virtual_ecosystem_module:
  - Animal

author:
  - Siti Nor Baizurah

status: final

input_files:
  - name: Lang_et_al_2017_data.csv
    path: Required local path supplied with --input (for example, a Globus-managed data folder)
    description: |
      Lang et al. (2017) assimilation-efficiency dataset. The first row
      contains metadata and the column headers begin on the second row. The raw
      data can remain outside the Git repository; the script only needs a local
      filesystem path to the transferred or mounted file.

output_files:
  - name: Lang_et_al_2017_VE_mapped_observations.csv
    path: By default, written beside the input dataset; override with --output
    description: |
      Assimilation-efficiency observations mapped to Virtual Ecosystem
      resource types, with mapping status and manual-review flags.

package_dependencies:
  - argparse
  - pathlib
  - pandas

usage_notes: |
  The assimilation-efficiency subset follows the original Lang workflow:
  assimilation.efficiency > -999.

  Only records with mapping_status == "direct" should be used for the main
  direct-evidence estimates. Inferred and proxy records are retained for
  sensitivity analysis and targeted manual review.

  The raw Lang dataset does not need to be stored in Git. Supply the local path
  to the data explicitly, for example after transferring it from Globus.

  Example:
    python extract_lang_assimilation.py --input C:/path/to/Globus/Lang_et_al_2017_data.csv

  If --output is omitted, the mapped observation CSV is written beside the
  input dataset. Use --output to write it elsewhere.

---
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

import pandas as pd


DEFAULT_OUTPUT_BASENAME = "Lang_et_al_2017_VE_mapped_observations.csv"


REQUIRED_COLUMNS = {
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
}


def normalise_resource_label(resource: Any) -> str | None:
    """Return a stable lookup key for a Lang resource label.

    Args:
        resource: Resource label from the Lang dataset.

    Returns:
        A stripped, case-folded resource label, or None for a missing label.
    """
    if pd.isna(resource):
        return None

    normalised = " ".join(str(resource).strip().split())
    return normalised.casefold() or None


def normalise_context_value(value: Any) -> str | None:
    """Return a stable lookup key for a context value."""
    if pd.isna(value):
        return None

    normalised = " ".join(str(value).strip().split())
    return normalised.casefold() or None


def make_mapping(
    ve_diet_type: str | None,
    mapping_status: str,
    ve_use_flag: str,
    mapping_note: str,
) -> dict[str, str | None]:
    """Create a consistent resource-mapping record."""
    return {
        "ve_diet_type": ve_diet_type,
        "mapping_status": mapping_status,
        "ve_use_flag": ve_use_flag,
        "mapping_note": mapping_note,
    }


def build_resource_map() -> dict[str, dict[str, str | None]]:
    """Build reviewed Lang-resource to VE-resource mappings.

    The keys are normalised internally, while the original Lang resource
    labels remain unchanged in the output data.
    """
    resource_map: dict[str, dict[str, str | None]] = {}

    direct_resources = {
        "Metapenaeus monoceros": ("invertebrates", "Named shrimp prey."),
        "Squid": ("invertebrates", "Squid is an invertebrate prey resource."),
        "Chlamydomonas": ("algae", "Named green alga."),
        "oak litter": ("detritus", "Resource explicitly recorded as litter."),
        "lettuce": (
            "foliage",
            "Leafy plant tissue; closest direct VE resource is foliage.",
        ),
        "Nephtys hombergii": ("invertebrates", "Named polychaete prey."),
        "algae": ("algae", "Resource explicitly recorded as algae."),
        "leaf litter": (
            "detritus",
            "Resource explicitly recorded as leaf litter.",
        ),
        "Simulium sp.": (
            "invertebrates",
            "Named invertebrate prey (dipteran).",
        ),
        "Ulva lactuca": ("algae", "Named green macroalga."),
        "Lepidocephalichthys thermalis": (
            "fish",
            "Named fish prey; mapped to the current VE fish diet type.",
        ),
        "Artemia salina": ("invertebrates", "Named crustacean prey."),
        "ash litter": ("detritus", "Resource explicitly recorded as litter."),
        "Cladophora": ("algae", "Named filamentous alga."),
        "Drosophila": ("invertebrates", "Named insect prey."),
        "Hydropsyche sp": (
            "invertebrates",
            "Named invertebrate prey (caddisfly).",
        ),
        "Dunaliella marina": ("algae", "Named microalga."),
        "Idotea": ("invertebrates", "Named isopod prey."),
        "crickets": ("invertebrates", "Invertebrate prey."),
        "Cystoseira": ("algae", "Named macroalga."),
        "Lonchocarpus pentaphyllus immature leaves": (
            "foliage",
            "Resource explicitly recorded as leaves.",
        ),
        "maggots": ("invertebrates", "Invertebrate prey."),
        "Picea abies litter": (
            "detritus",
            "Resource explicitly recorded as litter.",
        ),
        "Pinus nigra litter": (
            "detritus",
            "Resource explicitly recorded as litter.",
        ),
        "Pinus silvestris litter": (
            "detritus",
            "Resource explicitly recorded as litter.",
        ),
        "Pinus strobus litter": (
            "detritus",
            "Resource explicitly recorded as litter.",
        ),
        "Enteromorpha": ("algae", "Named green macroalga."),
        "reed detritus": (
            "detritus",
            "Resource explicitly recorded as detritus.",
        ),
        "Stenotomus": (
            "fish",
            "Named fish prey; mapped to the current VE fish diet type.",
        ),
        "Acer saccharum litter": (
            "detritus",
            "Resource explicitly recorded as litter.",
        ),
        "Acheta domesticus": (
            "invertebrates",
            "Named cricket prey.",
        ),
        "beech litter": (
            "detritus",
            "Resource explicitly recorded as litter.",
        ),
        "Chironomus sp": (
            "invertebrates",
            "Named invertebrate prey (chironomid).",
        ),
        "Codium": ("algae", "Named green macroalga."),
        "Gammarus sp.": ("invertebrates", "Named amphipod prey."),
        "hazel litter": (
            "detritus",
            "Resource explicitly recorded as litter.",
        ),
        "Lebistes sp.": (
            "fish",
            "Named fish prey; mapped to the current VE fish diet type.",
        ),
        "maple litter": (
            "detritus",
            "Resource explicitly recorded as litter.",
        ),
        "Mytilus": ("invertebrates", "Named bivalve prey."),
        "Notropis sp": (
            "fish",
            "Named fish prey; mapped to the current VE fish diet type.",
        ),
        "Phaseolus lunatus leaves": (
            "foliage",
            "Resource explicitly recorded as leaves.",
        ),
        "plant detritus": (
            "detritus",
            "Resource explicitly recorded as plant detritus.",
        ),
        "Tubifex sp.": ("invertebrates", "Named oligochaete prey."),
        "Tubifex tubifex": ("invertebrates", "Named oligochaete prey."),
        "Ulmus americana litter": (
            "detritus",
            "Resource explicitly recorded as litter.",
        ),
    }

    for resource, (diet_type, note) in direct_resources.items():
        resource_map[normalise_resource_label(resource)] = make_mapping(
            diet_type,
            "direct",
            "usable",
            note,
        )

    inferred_resources = {
        "alder leaves": (
            "detritus",
            "Lang classifies the consumer as detritivore; likely "
            "dead or conditioned leaf material, but the resource label "
            "itself only says leaves.",
        ),
        "Calotropis gigantea": (
            "foliage",
            "Plant species consumed by herbivorous butterfly larvae; "
            "the tissue type is not specified.",
        ),
        "Lactuca sativa": (
            "foliage",
            "Living lettuce or plant tissue; closest current VE resource "
            "is foliage.",
        ),
        "Ononis repens": (
            "foliage",
            "Plant species fed to an herbivorous snail; the tissue type "
            "is not specified.",
        ),
        "eukalyptus": (
            "foliage",
            "Eucalyptus plant material consumed by an herbivorous insect; "
            "the tissue type is not explicitly stated.",
        ),
        "Taraxacum officinale": (
            "foliage",
            "Plant species fed to herbivores; the tissue type is not "
            "specified.",
        ),
        "Morus alba": (
            "foliage",
            "Plant species fed to an herbivorous insect; the tissue type "
            "is not specified.",
        ),
        "Acer saccharinum": (
            "foliage",
            "Plant species used as herbivore food; the tissue type is "
            "not specified.",
        ),
        "Antirrhinum majus": (
            "foliage",
            "Plant species used as herbivore food; the tissue type is "
            "not specified.",
        ),
        "cannibalism": (
            "invertebrates",
            "The consumer is Arachnida; cannibalism therefore implies "
            "invertebrate prey.",
        ),
        "Chenopodium album": (
            "foliage",
            "Plant species used as herbivore food; the tissue type is "
            "not specified.",
        ),
        "Ipomoea batatas": (
            "foliage",
            "Plant species used as herbivore food; the tissue type is "
            "not specified.",
        ),
        "Lactues sp.": (
            "foliage",
            "Plant material fed to grass carp; closest current VE "
            "resource is foliage.",
        ),
        "Lycopersicon esculentum": (
            "foliage",
            "Plant species used as herbivore food; the tissue type is "
            "not specified.",
        ),
        "Phaseolus vulgaris": (
            "foliage",
            "Plant species used as herbivore food; the tissue type is "
            "not specified.",
        ),
        "Phytolacca americana": (
            "foliage",
            "Plant species used as herbivore food; the tissue type is "
            "not specified.",
        ),
        "Solanum tuberosum": (
            "foliage",
            "Plant species used as herbivore food; the tissue type is "
            "not specified.",
        ),
        "Spinacia oleracea": (
            "foliage",
            "Plant species used as herbivore food; the tissue type is "
            "not specified.",
        ),
        "Ulmus pumila": (
            "foliage",
            "Plant species used as herbivore food; the tissue type is "
            "not specified.",
        ),
    }

    for resource, (diet_type, note) in inferred_resources.items():
        resource_map[normalise_resource_label(resource)] = make_mapping(
            diet_type,
            "inferred",
            "usable_after_mapping_review",
            note,
        )

    proxy_resources = {
        "goat liver": (
            "vertebrates",
            "Vertebrate tissue, but liver is not whole-prey biomass; "
            "retain as proxy only.",
            "proxy_only",
        ),
        "soil": (
            "pom",
            "Earthworm assimilation from ingested soil; not equivalent "
            "to isolated VE POM, so retain as proxy only.",
            "proxy_only",
        ),
        "Zostera": (
            "foliage",
            "Seagrass or macrophyte tissue; closest current VE plant "
            "resource category is foliage.",
            "usable_with_caution",
        ),
        "Tilapia mossambica muscle": (
            "fish",
            "Fish tissue; mapped to the current VE fish diet type, but retained "
            "as a proxy because it is muscle-only rather than whole fish.",
            "usable_with_caution",
        ),
        "Egeria sp.": (
            "foliage",
            "Aquatic macrophyte; closest current VE plant-resource "
            "category is foliage.",
            "usable_with_caution",
        ),
        "Hydrilla verticellata": (
            "foliage",
            "Aquatic macrophyte; closest current VE plant-resource "
            "category is foliage.",
            "usable_with_caution",
        ),
    }

    for resource, (diet_type, note, use_flag) in proxy_resources.items():
        resource_map[normalise_resource_label(resource)] = make_mapping(
            diet_type,
            "proxy",
            use_flag,
            note,
        )

    resource_map[normalise_resource_label("synthetic diet")] = make_mapping(
        None,
        "exclude",
        "exclude",
        "Artificial diet has no direct VE resource equivalent.",
    )

    return resource_map


RESOURCE_MAP = build_resource_map()


# Context-specific corrections are keyed by normalised values:
#
# (
#     normalised_resource,
#     normalised_consumer_name,
#     normalised_reference_short,
# )
#
# Example:
#
# CONTEXT_OVERRIDES = {
#     (
#         normalise_resource_label("Example plant"),
#         normalise_context_value("Example consumer"),
#         normalise_context_value("Example.1975"),
#     ): make_mapping(
#         "foliage",
#         "direct",
#         "usable",
#         "Reference explicitly identifies leaves as the food.",
#     ),
# }
CONTEXT_OVERRIDES: dict[
    tuple[str | None, str | None, str | None],
    dict[str, str | None],
] = {}


def load_raw_data(path: Path) -> pd.DataFrame:
    """Load and validate the raw Lang et al. dataset."""
    if not path.exists():
        raise FileNotFoundError(
            f"Raw Lang dataset not found: {path}\n"
            "Check the path supplied with --input."
        )

    # The first row contains metadata; headers begin on the second row.
    data = pd.read_csv(path, header=1)

    missing = REQUIRED_COLUMNS - set(data.columns)
    if missing:
        raise ValueError(
            "Raw Lang dataset is missing required columns: "
            + ", ".join(sorted(missing))
        )

    return data


def extract_assimilation_efficiency(data: pd.DataFrame) -> pd.DataFrame:
    """Keep valid Lang assimilation-efficiency observations."""
    assimilation_efficiency = pd.to_numeric(
        data["assimilation.efficiency"],
        errors="coerce",
    )

    observations = data.loc[assimilation_efficiency > -999].copy()
    observations["assimilation.efficiency"] = assimilation_efficiency.loc[
        observations.index
    ]

    invalid = observations.loc[
        ~observations["assimilation.efficiency"].between(
            0,
            1,
            inclusive="both",
        )
    ]

    if not invalid.empty:
        raise ValueError(
            f"Found {len(invalid)} assimilation-efficiency values outside 0-1."
        )

    return observations


def apply_mapping(row: pd.Series) -> pd.Series:
    """Apply the default resource mapping and context override."""
    resource_key = normalise_resource_label(row["resource"])
    decision = RESOURCE_MAP.get(resource_key)

    if decision is None:
        decision = make_mapping(
            None,
            "unmapped",
            "review_required",
            "No embedded VE mapping exists for this resource.",
        )
    else:
        decision = decision.copy()

    context_key = (
        resource_key,
        normalise_context_value(row["taxonomic.name"]),
        normalise_context_value(row["reference.short"]),
    )

    if context_key in CONTEXT_OVERRIDES:
        decision = CONTEXT_OVERRIDES[context_key].copy()

    mapping_status = str(
        decision.get("mapping_status", "")
    ).strip().lower()

    return pd.Series(
        {
            "ve_diet_type": decision.get("ve_diet_type"),
            "mapping_status": decision.get("mapping_status"),
            "ve_use_flag": decision.get("ve_use_flag"),
            "mapping_note": decision.get("mapping_note"),
            "manual_review_required": mapping_status != "direct",
        }
    )


def write_csv_safely(data: pd.DataFrame, output_path: Path) -> Path:
    """Write a CSV, using a numbered fallback when the target is locked."""
    output_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        data.to_csv(output_path, index=False)
        return output_path
    except PermissionError:
        for number in range(1, 1000):
            fallback = output_path.with_name(
                f"{output_path.stem}_{number}{output_path.suffix}"
            )

            if fallback.exists():
                continue

            data.to_csv(fallback, index=False)

            print(
                "\nWARNING: Could not overwrite the normal output file. "
                "It may be open in Excel or another program."
            )
            print(f"Saved the new output instead as:\n  {fallback.name}")

            return fallback

        raise PermissionError(
            f"Could not save {output_path.name}; the target appears to be "
            "locked and no fallback filename was available."
        )



def parse_args() -> argparse.Namespace:
    """Parse required input data path and optional output path."""
    parser = argparse.ArgumentParser(
        description=(
            "Extract Lang assimilation-efficiency observations and map reviewed "
            "resource labels to current VE resource types."
        )
    )
    parser.add_argument(
        "--input",
        type=Path,
        required=True,
        help=(
            "Local path to the raw Lang et al. CSV, for example a file in a "
            "Globus-managed data folder. The raw CSV does not need to be in Git."
        ),
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help=(
            "Mapped observation CSV. If omitted, write "
            "Lang_et_al_2017_VE_mapped_observations.csv beside the input file."
        ),
    )
    return parser.parse_args()


def print_mapping_qc(mapped_output: pd.DataFrame) -> None:
    """Print a compact mapping-status and VE-resource QC summary."""
    print("\nMapping status:")
    print(mapped_output["mapping_status"].value_counts(dropna=False).to_string())

    qc = (
        mapped_output.assign(
            ve_diet_type=mapped_output["ve_diet_type"].fillna("UNMAPPED")
        )
        .groupby(["ve_diet_type", "mapping_status"], dropna=False)
        .size()
        .unstack(fill_value=0)
    )
    print("\nMapping QC by VE resource:")
    print(qc.to_string())


def main() -> None:
    """Run the Lang-to-VE assimilation-efficiency workflow."""
    args = parse_args()
    input_path = args.input.expanduser().resolve()
    output_path = (
        args.output.expanduser().resolve()
        if args.output is not None
        else input_path.with_name(DEFAULT_OUTPUT_BASENAME)
    )

    raw = load_raw_data(input_path)
    observations = extract_assimilation_efficiency(raw)
    mapping_columns = observations.apply(apply_mapping, axis=1)

    mapped = pd.concat(
        [
            observations.reset_index(drop=True),
            mapping_columns.reset_index(drop=True),
        ],
        axis=1,
    )

    output_columns = [
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
        "ve_use_flag",
        "mapping_note",
        "manual_review_required",
    ]

    mapped_output = mapped[output_columns].copy()
    written_output = write_csv_safely(mapped_output, output_path)

    print(f"Input used:\n  {input_path}")
    print(f"Raw rows: {len(raw)}")
    print(f"Assimilation-efficiency rows retained: {len(mapped_output)}")
    print_mapping_qc(mapped_output)

    print(
        "\nRows with non-direct mappings to review: "
        f"{int(mapped_output['manual_review_required'].sum())}"
    )

    unmapped = mapped_output["mapping_status"].eq("unmapped")
    if unmapped.any():
        resources = sorted(
            mapped_output.loc[unmapped, "resource"]
            .dropna()
            .astype(str)
            .unique()
        )
        print("\nWARNING: Unmapped resource labels:")
        for resource in resources:
            print(f"  - {resource}")

    print(f"\nOutput written:\n  {written_output.name}")
    print(f"Full path:\n  {written_output}")
    print(
        "\nReview recommendations:"
        "\n  1. Use mapping_status == 'direct' for the main direct-evidence estimate."
        "\n  2. Review inferred, proxy, excluded, and unmapped records before changing "
        "their use in CE estimation."
    )


if __name__ == "__main__":
    main()
