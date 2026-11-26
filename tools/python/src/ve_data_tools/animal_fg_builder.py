"""Build traceable animal functional groups using trait-matrix evidence."""

import csv
import io
import math
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path

import pandas as pd
from virtual_ecosystem.models.animal.animal_traits import (
    DevelopmentStatus,
    DevelopmentType,
    DietType,
    ExcretionType,
    MetabolicType,
    MigrationType,
    ReproductiveEnvironment,
    ReproductiveType,
    TaxaType,
    VerticalOccupancy,
)

ROOT = Path(__file__).resolve().parents[4]
SOURCE = ROOT / (
    "data/primary/animal/functional_group/"
    "TraitMatrix_SAFE_Functional_Groups_template.csv"
)
SCHEMA = ROOT / (
    "data/scenarios/maliau/maliau_2/data/animal_functional_groups_Maliau_level3.csv"
)
TAXON_LEVELS = ("class", "order", "family", "genus", "species")
TEMPERATURE_FIELDS = ("t_opt", "t_max_crit", "t_min_crit")
STRATA = {
    "soil": ("StraSub",),
    "ground": ("StraTerr", "StraUnd"),
    "canopy": ("StraArb", "StraAer"),
}
DIETS = {
    "waste": ("DietCop",),
    "detritus": ("DietDet",),
    "fish": ("DietPisc",),
    "vertebrates": ("DietVert",),
    "invertebrates": ("DietInvert",),
    "algae": ("DietAlg",),
    "wood": ("DietXylo", "DietSapro"),
    "nectar": ("DietNec",),
    "carcasses": ("DietNecro",),
    "seeds": ("DietGran",),
    "fruit": ("DietFrug",),
    "foliage": ("DietFoli", "DietRhyzo", "DietPhloe"),
    "flowers": ("DietFlor", "DietPaly"),
    "blood": ("DietHema",),
    "bacteria": ("DietBact",),
    "fungi": ("DietMyco",),
    "pom": ("DietSoil",),
}
BROAD_DIETS = (
    "carnivore",
    "herbivore",
    "omnivore",
    "saprophage",
    "parasite",
    "parasitoid",
)
TRAITS: dict[str, type[Enum]] = {
    "metabolic_type": MetabolicType,
    "reproductive_environment": ReproductiveEnvironment,
    "reproductive_type": ReproductiveType,
    "development_type": DevelopmentType,
    "development_status": DevelopmentStatus,
    "excretion_type": ExcretionType,
    "migration_type": MigrationType,
}
MISSING = {"", "na", "none", "nan"}
PROVENANCE_COLUMNS = (
    "functional_group",
    "mass_source",
    "taxon_identity",
    "taxon_name",
    "taxon_level",
    "source_row",
    "mass_g",
    "mass_kg",
)
Row = dict[str, str | float | None]


@dataclass
class MassSummary:
    """Median mass, retained source records and explicit exclusion diagnostics."""

    median_kg: float | None
    contributors: pd.DataFrame
    warnings: list[str]


@dataclass
class BuiltGroup:
    """An exported row with its corresponding filter and mass evidence snapshot.

    The diets field stores explicit user choices, possibly empty; row["diet"]
    stores the resolved output tags, including observed tags in automatic mode.
    """

    row: Row
    taxonomy: dict[str, str]
    strata: list[str]
    broad_diet: str
    diets: list[str]
    filter_diets: bool
    contributors: pd.DataFrame = field(default_factory=pd.DataFrame)


def load_safe(path: Path, encoding: str = "cp1252") -> pd.DataFrame:
    """Read a SAFE CSV, validating metadata, shape and required fields."""
    with path.open(encoding=encoding, newline="") as handle:
        rows = list(csv.reader(handle, strict=True))
    header_index = next(
        (i for i, row in enumerate(rows) if row and row[0] == "field_name"), None
    )
    if header_index is None:
        raise ValueError("SAFE CSV has no field_name header.")
    header = rows[header_index]
    if len(set(header)) != len(header):
        raise ValueError("SAFE CSV contains duplicate column names.")
    required = {
        *TAXON_LEVELS,
        "kingdom",
        "phylum",
        "taxon_name",
        "taxon_level",
        "BodyMass",
        "TrophCarn",
        "TrophHerb",
        "TrophSap",
        "TrophPara",
        "TrophToid",
        *(col for cols in STRATA.values() for col in cols),
        *(col for cols in DIETS.values() for col in cols),
    }
    missing = required.difference(header)
    if missing:
        raise ValueError(f"SAFE CSV is missing columns: {', '.join(sorted(missing))}")
    units = next((row for row in rows[:header_index] if row and row[0] == "units"), [])
    mass_index = header.index("BodyMass")
    if len(units) <= mass_index or units[mass_index].strip() != "g":
        raise ValueError("SAFE BodyMass metadata must specify grams (g).")
    records = []
    for line, row in enumerate(rows[header_index + 1 :], start=header_index + 2):
        if not row or not any(row):
            continue
        if len(row) != len(header):
            raise ValueError(f"SAFE CSV line {line} has an incorrect column count.")
        records.append([value.strip() for value in row])
    if not records:
        raise ValueError("SAFE CSV has no records.")
    return pd.DataFrame(records, columns=header)


def flag(data: pd.DataFrame, column: str) -> pd.Series:
    """Interpret SAFE categorical NA and zero as absence."""
    return ~data[column].str.lower().isin(MISSING | {"0", "0.0", "false"})


def any_flag(data: pd.DataFrame, columns: tuple[str, ...]) -> pd.Series:
    """Match alternative SAFE columns representing the same VE tag."""
    return pd.concat([flag(data, col) for col in columns], axis=1).any(axis=1)


def class_taxa(data: pd.DataFrame) -> dict[str, str]:
    """Map supported animal classes to VE taxa, omitting fish and unknown classes."""
    animals = data[data["kingdom"] == "Animalia"]
    vertebrates = {
        "Aves": "bird",
        "Mammalia": "mammal",
        "Reptilia": "reptile",
        "Amphibia": "amphibian",
    }
    mapping = {}
    for name, rows in animals.groupby("class"):
        if name.lower() in MISSING or name == "Animalia":
            continue
        if name in vertebrates:
            mapping[name] = vertebrates[name]
        elif not rows["phylum"].str.lower().isin(MISSING | {"chordata"}).any():
            mapping[name] = "invertebrate"
    return mapping


def taxonomic_options(data: pd.DataFrame, level: str) -> list[str]:
    """Return existing non-missing taxonomic dropdown values."""
    return sorted(
        value for value in data[level].unique() if value.lower() not in MISSING
    )


def broad_mask(data: pd.DataFrame, category: str) -> pd.Series:
    """Apply six exclusive SAFE categories; omnivore alone permits two flags.

    Saprophage, parasite and parasitoid each require their own flag and no
    other trophic flag. These source categories are distinct from VE's coarse
    diet classification, which is derived from the exported resource tags.
    """
    carn, herb, sap, para, toid = (
        flag(data, col)
        for col in ("TrophCarn", "TrophHerb", "TrophSap", "TrophPara", "TrophToid")
    )
    masks = {
        "carnivore": carn & ~herb & ~sap & ~para & ~toid,
        "herbivore": herb & ~carn & ~sap & ~para & ~toid,
        "omnivore": carn & herb & ~sap & ~para & ~toid,
        "saprophage": sap & ~para & ~carn & ~herb & ~toid,
        "parasite": para & ~sap & ~carn & ~herb & ~toid,
        "parasitoid": toid & ~sap & ~para & ~carn & ~herb,
    }
    if category not in masks:
        raise ValueError(f"Unknown broad diet: {category}")
    return masks[category]


def observed_diets(data: pd.DataFrame) -> list[str]:
    """Return the union of mapped VE tags present in at least one matching row.

    These are suggestions, not a claim that each tag occurs in every row.
    With no explicit detailed selection, this union supplies the output diet
    without narrowing the rows used for the mass median.
    """
    return [diet for diet, cols in DIETS.items() if any_flag(data, cols).any()]


def filter_safe(
    data: pd.DataFrame,
    taxonomy: dict[str, str],
    strata: list[str],
    broad_diet: str,
    diets: list[str] | None = None,
) -> pd.DataFrame:
    """Require all selected filters; allow alternatives within a mapped VE tag."""
    if not taxonomy.get("class") or not strata:
        raise ValueError("Class and at least one stratum are required.")
    result = data[data["kingdom"] == "Animalia"]
    for level, value in taxonomy.items():
        if level not in TAXON_LEVELS:
            raise ValueError(f"Unsupported taxonomic level: {level}")
        result = result[result[level] == value]
    for stratum in strata:
        if stratum not in STRATA:
            raise ValueError(f"Unsupported stratum: {stratum}")
        result = result[any_flag(result, STRATA[stratum])]
    result = result[broad_mask(result, broad_diet)]
    for diet in diets or []:
        if diet not in DIETS:
            raise ValueError(f"No SAFE mapping for detailed diet: {diet}")
        result = result[any_flag(result, DIETS[diet])]
    return result.copy()


def summarise_mass(data: pd.DataFrame) -> MassSummary:
    """Use the first valid mass per species or morphospecies, then take the median."""
    eligible = data[data["taxon_level"].isin(["species", "morphospecies"])].copy()
    warnings = []
    if len(eligible) != len(data):
        warnings.append(f"Excluded {len(data) - len(eligible)} higher-rank records.")
    identities = []
    for _, row in eligible.iterrows():
        name = row["species"] if row["taxon_level"] == "species" else row["taxon_name"]
        if name.lower() in MISSING:
            name = row["taxon_name"]
        if name.lower() in MISSING:
            identities.append("")
        elif row["taxon_level"] == "species":
            identities.append(f"species:{name}")
        else:
            lineage = "|".join(row[col] for col in TAXON_LEVELS[:-1])
            identities.append(f"morphospecies:{lineage}|{name}")
    eligible["taxon_identity"] = identities
    numeric = pd.to_numeric(eligible["BodyMass"], errors="coerce")
    valid = numeric.notna() & numeric.gt(0) & numeric.lt(float("inf"))
    invalid = ~valid & ~eligible["BodyMass"].str.lower().isin(MISSING)
    if invalid.any():
        warnings.append(f"Excluded {int(invalid.sum())} invalid/non-positive masses.")
    if (~valid & ~invalid).any():
        warnings.append(f"Excluded {int((~valid & ~invalid).sum())} missing masses.")
    if (eligible["taxon_identity"] == "").any():
        warnings.append(
            "Excluded records without an identifiable species/morphospecies."
        )
    eligible["mass_g"] = numeric
    eligible = eligible[valid & eligible["taxon_identity"].ne("")]
    conflicts = eligible.groupby("taxon_identity")["mass_g"].nunique()
    for identity in conflicts[conflicts > 1].index:
        warnings.append(
            f"Conflicting masses for {identity}: using first valid source mass."
        )
    contributors = eligible.drop_duplicates("taxon_identity", keep="first").copy()
    duplicates = len(eligible) - len(contributors)
    if duplicates:
        warnings.append(f"Removed {duplicates} repeated taxon records.")
    contributors["mass_kg"] = contributors["mass_g"] / 1000
    median = float(contributors["mass_kg"].median()) if len(contributors) else None
    return MassSummary(median, contributors, warnings)


def diet_options() -> list[str]:
    """Expose only atomic tags supported by the installed VE parser."""
    return sorted(member.name.lower() for member in DietType)


def validate_row(row: Row) -> None:
    """Validate a draft row while permitting intentionally blank birth mass."""
    if not isinstance(row.get("name"), str) or not str(row["name"]).strip():
        raise ValueError("A non-empty functional-group name is required.")
    TaxaType(row["taxa"])
    for column, enum in TRAITS.items():
        enum(row[column])
    DietType.parse(str(row["diet"]))
    VerticalOccupancy.parse(str(row["vertical_occupancy"]))
    mass = row.get("adult_mass")
    if not isinstance(mass, (float, int)) or not math.isfinite(mass) or mass <= 0:
        raise ValueError("Adult mass must be a positive finite value in kilograms.")
    density = row.get("density_individuals_m2")
    if density is not None and (
        not isinstance(density, (float, int))
        or not math.isfinite(density)
        or density < 0
    ):
        raise ValueError("Density must be blank or a non-negative finite value.")
    for column in TEMPERATURE_FIELDS:
        temperature = row.get(column)
        if temperature is not None and (
            not isinstance(temperature, (float, int)) or not math.isfinite(temperature)
        ):
            raise ValueError(
                f"{column} must be blank or a finite temperature in Celsius."
            )
    if not row.get("offspring_functional_group"):
        raise ValueError("Choose an offspring functional group.")


def export_groups(groups: list[BuiltGroup], schema: Path = SCHEMA) -> str:
    """Export reference columns plus optional, user-supplied VE temperatures."""
    with schema.open(encoding="utf-8-sig", newline="") as handle:
        columns = next(csv.reader(handle))
    columns.extend(column for column in TEMPERATURE_FIELDS if column not in columns)
    names = [str(group.row["name"]) for group in groups]
    if len(set(names)) != len(names):
        raise ValueError("Functional-group names must be unique.")
    for group in groups:
        validate_row(group.row)
        if set(group.row).difference(columns) or set(columns).difference(
            group.row
        ).difference(TEMPERATURE_FIELDS):
            raise ValueError("Group fields do not match the reference CSV schema.")
        if group.row["offspring_functional_group"] not in names:
            raise ValueError(
                f"{group.row['name']} references a missing offspring group."
            )
    return pd.DataFrame(
        [{column: group.row.get(column) for column in columns} for group in groups],
        columns=columns,
    ).to_csv(index=False)


def export_provenance(groups: list[BuiltGroup]) -> str:
    """Export evidence, without attributing manual masses to SAFE taxa."""
    records = []
    for group in groups:
        if group.contributors.empty:
            records.append(
                {
                    "functional_group": group.row["name"],
                    "mass_source": "user",
                    "mass_kg": group.row["adult_mass"],
                }
            )
        for _, taxon in group.contributors.iterrows():
            records.append(
                {
                    "functional_group": group.row["name"],
                    "mass_source": "SAFE",
                    "taxon_identity": taxon["taxon_identity"],
                    "taxon_name": taxon["taxon_name"],
                    "taxon_level": taxon["taxon_level"],
                    "source_row": taxon["field_name"],
                    "mass_g": taxon["mass_g"],
                    "mass_kg": taxon["mass_kg"],
                }
            )
    return pd.DataFrame(records, columns=PROVENANCE_COLUMNS).to_csv(index=False)


def rename_references(groups: list[BuiltGroup], old: str, new: str) -> None:
    """Keep offspring references consistent when a retained group is renamed."""
    for group in groups:
        if group.row["offspring_functional_group"] == old:
            group.row["offspring_functional_group"] = new


def csv_preview(text: str) -> pd.DataFrame:
    """Read generated CSV text without changing blank values."""
    return pd.read_csv(io.StringIO(text), keep_default_na=False)
