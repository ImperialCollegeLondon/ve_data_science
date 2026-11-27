"""
---
title: Preprocess Wearn 2022 density data for Maliau and SAFE validation

description: |
  Preprocessing Wearn et al. (2022) density estimates
  into a valdb-ready functional-level table for the animal module.
  In the article, the old-growth forest site is Maliau Basin Conservation
  Area and the logged forest site is the SAFE landscape, so old-growth
  estimates are labelled maliau and logged estimates safe.

virtual_ecosystem_module: animal

author:
  - Nicholas Wei Cheng Tan

status: final

input_files:
    - name: wearn_2022_Table_S3.1.csv
        path: data/primary/animal/wearn_2022/
    description: |
      Raw supplementary table containing species density estimates across
      old-growth (Maliau) and logged (SAFE) forest habitats, according to
      the article. See https://doi.org/10.1111/2041-210X.13930
  - name: animal_functional_groups_Maliau_level5.csv
    path: data/primary/animal/functional_group/
    description: |TODO
      Temporary placeholder for level 5 FG - should be replaced later
      by master input file - and script updated accordingly.

output_files:
    - name: wearn_2022_density.csv
    path: data/derived/animal/wearn_2022/
    description: |
      Wide table with one row per site (maliau, safe) and one column per
      metric and functional group, e.g.
      density_median_per_km2_<functional_group>. sample_size_n is the density
      sample size pooled across both habitats, as reported by Wearn et al.

package_dependencies:
  - pandas

usage_notes: |
    Phases:
        1. Configure input/output paths and functional-group mappings.
        2. Read and clean species names and sample sizes.
        3. Parse Maliau and SAFE density estimates and confidence intervals.
        4. Map species to functional groups and validate the mappings.
        5. Aggregate by functional group and export the CSV. Sample sizes are
             summed, medians summed, and confidence intervals retained only for
             groups containing one species. The result is pivoted to one row
             per site with <metric>_<functional_group> columns.

    Fill functional_group_level5_name values in species_to_fg_template before
    running the script.
---
"""  # noqa: D205, D212, D400, D415

from pathlib import Path

import pandas as pd

module_name = "animal"
repo_root = Path(__file__).resolve().parents[3]

# Phase 1: Configure input/output paths and functional-group mappings.
input_file = (
    repo_root
    / "data"
    / "primary"
    / module_name
    / "wearn_2022"
    / "wearn_2022_Table_S3.1.csv"
)

output_dir = repo_root / "data" / "derived" / module_name / "wearn_2022"
output_file = output_dir / "wearn_2022_density.csv"
## TODO: Change to master input csv and update the script accordingly.

functional_group_level5_options: list[str] = (
    pd.read_csv(
        repo_root
        / "data"
        / "primary"
        / module_name
        / "functional_group"
        / "animal_functional_groups_Maliau_level5.csv",
        usecols=["name"],
    )["name"]
    .dropna()
    .tolist()
)

# Manually map observed species to the exact FG identifiers in the input CSV.
species_to_fg_template: dict[str, list[str]] = {
    "carnivorous_aquatic_mammal": [
        "Oriental_small-clawed_otter",
    ],
    "omnivorous_terrestrial_small_mammal": [
        "Short-tailed_mongoose",
        "Collared_mongoose",
        "Sunda_stink_badger",
        "Tufted_ground_squirrel",
    ],
    "omnivorous_terrestrial_large_mammal": [
        "Bearded_pig",
    ],
    "omnivorous_arboreal_small_mammal": ["Binturong", "Masked_palm_civet"],
    "omnivorous_terrestrial_bird": [
        "Great_argus",
        "Bulwer's_pheasant",
        "Crested_fireback",
    ],
    "herbivorous_terrestrial_large_mammal": [
        "Banteng",
    ],
    "herbivorous_terrestrial_medium_mammal": [
        "Yellow_muntjac",
        "Red_muntjac",
        "Sambar_deer",
    ],
    "herbivorous_terrestrial_small_mammal": [
        "Malay_porcupine",
        "Thick-spined_porcupine",
        "Lesser_mouse-deer",
        "Greater_mouse-deer",
        "Long-tailed_porcupine",
    ],
    "carnivorous_arboreal_terrestrial_medium_mammal": [
        "Bay_cat",
        "Sunda_clouded_leopard",
        "Malay_weasel",
        "Marbled_cat",
        "Leopard_cat",
    ],
    "carnivorous_terrestrial_arboreal_mammal": [
        "Hose's_civet",
        "Banded_civet",
        "Sunda_pangolin",
    ],
    "omnivorous_arboreal_terrestrial_small_mammal": [
        "Malay_civet",
        "Yellow-throated_marten",
    ],
    "omnivorous_arboreal_terrestrial_large_mammal": [
        "Sun_bear",
    ],
    "omnivorous_arboreal_primate": [
        "Bornean_orangutan",
        "Long-tailed_macaque",
        "Pig-tailed_macaque",
    ],
    "carnivorous_burrowing_mammal": ["Moon_rat"],
}


settings = {
    "module_name": module_name,
    "input_file": input_file,
    "output_dir": output_dir,
    "output_file": output_file,
    "functional_group_level5_options": functional_group_level5_options,
    "species_to_fg_template": species_to_fg_template,
}

# Run this code to create the output directory and print the settings.
# this code block below only runs when the script is executed directly
if __name__ == "__main__":
    output_dir.mkdir(parents=True, exist_ok=True)
    print(settings)

    species_columns = ["species_common_name", "species_scientific_name"]

    # Phase 2: read and clean species names and sample sizes.
    wearn_table = pd.read_csv(
        input_file,
        header=None,
        skiprows=10,
        # Density sample size, old-growth (Maliau) and logged (SAFE) estimates.
        usecols=[0, 1, 8, 9, 10],
        names=[
            "species_common_name",
            "species_scientific_name",
            "density_sample_size_n",
            "density_maliau_text",
            "density_safe_text",
        ],
        dtype="string",
    )

    # Filter out rows with missing or empty species_common_name
    wearn_table = wearn_table[
        wearn_table["species_common_name"].notna()
        & (wearn_table["species_common_name"] != "")
    ].copy()

    # Strip white spaces and replace them with underscores.
    for column_name in species_columns:
        wearn_table[column_name] = (
            wearn_table[column_name].str.strip().str.replace(r"\s+", "_", regex=True)
        )

    # Convert the density sample size column string to numeric, coercing errors to NaN.
    wearn_table["density_sample_size_n"] = pd.to_numeric(
        wearn_table["density_sample_size_n"].str.strip(),
        errors="coerce",
    )

    # Phase 3: parse densities and confidence intervals, one block of rows per site.
    site_text_columns = {
        "maliau": "density_maliau_text",
        "safe": "density_safe_text",
    }
    site_tables = []
    for site, text_column in site_text_columns.items():
        density_parsed = (
            wearn_table[text_column]
            .str.strip()
            .str.extract(
                r"^\s*(?P<density_median>-?\d+(?:\.\d+)?)"
                r"\s*\(\s*(?P<density_ci95_lower>-?\d+(?:\.\d+)?)"
                r"\s*-\s*(?P<density_ci95_upper>-?\d+(?:\.\d+)?)\s*\)\s*$"
            )
            .apply(pd.to_numeric, errors="coerce")
        )
        site_tables.append(
            pd.concat(
                [
                    wearn_table[[*species_columns, "density_sample_size_n"]],
                    density_parsed,
                ],
                axis=1,
            ).assign(site=site)
        )
    wearn_table = pd.concat(site_tables, ignore_index=True)

    parsed_rows_by_site = wearn_table.groupby("site")["density_median"].count()
    failed_rows = int(wearn_table["density_median"].isna().sum())

    # Phase 4: map species to level-5 functional groups.
    # Many species may map to one FG, and not all FG options need to be used.
    # Missing FG mappings are allowed and carried through as NA.
    mapped_species_names = [
        species_name
        for species_names in species_to_fg_template.values()
        for species_name in species_names
    ]
    # Ensure that each species maps to only one functional group.
    if len(mapped_species_names) != len(set(mapped_species_names)):
        raise ValueError("Each species common name must map to one functional group.")

    invalid_functional_groups = sorted(
        set(species_to_fg_template).difference(functional_group_level5_options)
    )
    if invalid_functional_groups:
        raise ValueError(
            "Functional groups not found in the input CSV: "
            + ", ".join(invalid_functional_groups)
        )

    # Create mapping table
    species_fg_mapping = pd.DataFrame(
        [
            {
                "species_common_name": species_name,
                "functional_group_level5_name": functional_group,
            }
            for functional_group, species_names in species_to_fg_template.items()
            for species_name in species_names
        ]
    )

    # Standardize species names to match the source table.
    for column_name in species_columns:
        if column_name in species_fg_mapping:
            species_fg_mapping[column_name] = (
                species_fg_mapping[column_name]
                .astype("string")
                .str.strip()
                .str.replace(r"\s+", "_", regex=True)
            )
    species_fg_mapping["species_common_name"] = (
        species_fg_mapping["species_common_name"].astype("string").str.strip()
    )

    # Check for duplicate species entries in the mapping table.
    duplicate_species = species_fg_mapping[
        species_fg_mapping["species_common_name"].duplicated(keep=False)
    ]["species_common_name"].unique()
    if len(duplicate_species) > 0:
        duplicate_species_list = ", ".join(sorted(map(str, duplicate_species)))
        raise ValueError(
            "Phase 4 mapping has duplicated species_common_name entries: "
            f"{duplicate_species_list}"
        )

    # Create a reference table of unique species from the wearn_table.
    species_reference = (
        wearn_table[species_columns]
        .drop_duplicates()
        .sort_values("species_scientific_name")
        .reset_index(drop=True)
    )

    # If the species_to_fg_template is empty, generate template to copy and fill in
    if len(species_to_fg_template) == 0:
        template_rows = species_reference.assign(functional_group_level5_name="")
        print("\nPhase 4 template helper")
        print("Copy this block into species_to_fg_template and fill only")
        print("functional_group_level5_name values:\n")
        print("species_to_fg_template = {")
        for row in template_rows.itertuples(index=False):
            print(f'    "": ["{row.species_common_name}"],')
        print("}\n")

    # Merge the species reference with the functional group mapping.
    species_mapping = species_reference.merge(
        species_fg_mapping,
        on="species_common_name",
        how="left",
        validate="many_to_one",
    )

    # Merge the functional group information back into the main wearn_table
    wearn_table = wearn_table.merge(
        species_mapping[["species_scientific_name", "functional_group_level5_name"]],
        on="species_scientific_name",
        how="left",
        validate="many_to_one",
    )

    # Phase 5: shape the final output table and export.
    required_output_inputs = {
        "site",
        "species_common_name",
        "species_scientific_name",
        "functional_group_level5_name",
        "density_sample_size_n",
        "density_median",
        "density_ci95_lower",
        "density_ci95_upper",
    }
    missing_output_columns = sorted(
        required_output_inputs.difference(wearn_table.columns)
    )
    if missing_output_columns:
        missing_output_columns_list = ", ".join(missing_output_columns)
        raise ValueError(
            f"output columns missing from wearn_table: {missing_output_columns_list}"
        )

    final_columns = [
        "site",
        "species_common_name",
        "scientific_name",
        "sample_size_n",
        "functional_group",
        "density_median_per_km2",
        "ci95_lower",
        "ci95_upper",
    ]
    rename_map = {
        "species_scientific_name": "scientific_name",
        "density_sample_size_n": "sample_size_n",
        "density_median": "density_median_per_km2",
        "density_ci95_lower": "ci95_lower",
        "density_ci95_upper": "ci95_upper",
    }

    functional_group = wearn_table["functional_group_level5_name"].astype("string")

    species_level_output = (
        wearn_table.assign(functional_group=functional_group)
        .rename(columns=rename_map)[final_columns]
        .sort_values("scientific_name")
        .reset_index(drop=True)
    )

    # One row per site and functional group; unmapped species drop out.
    fg_long_table = (
        species_level_output.groupby(["site", "functional_group"], as_index=False)
        .agg(
            species_count=("scientific_name", "nunique"),
            sample_size_n=("sample_size_n", lambda values: values.sum(min_count=1)),
            density_median_per_km2=(
                "density_median_per_km2",
                lambda values: values.sum(min_count=1),
            ),
            ci95_lower=("ci95_lower", "first"),
            ci95_upper=("ci95_upper", "first"),
        )
        # Only retain ci95_lower and ci95_upper values for rows with a single species.
        .assign(
            ci95_lower=lambda table: table["ci95_lower"].where(
                table["species_count"] == 1,
                pd.NA,
            ),
            ci95_upper=lambda table: table["ci95_upper"].where(
                table["species_count"] == 1,
                pd.NA,
            ),
        )[
            [
                "site",
                "functional_group",
                "species_count",
                "sample_size_n",
                "density_median_per_km2",
                "ci95_lower",
                "ci95_upper",
            ]
        ]
        .sort_values(["site", "functional_group"])
        .reset_index(drop=True)
    )

    # Wide layout: one row per site, one column per metric and functional group.
    wide_metrics = [
        "density_median_per_km2",
        "ci95_lower",
        "ci95_upper",
        "species_count",
        "sample_size_n",
    ]
    final_output_table = fg_long_table.pivot(
        index="site", columns="functional_group", values=wide_metrics
    )
    final_output_table.columns = [
        f"{metric}_{fg}" for metric, fg in final_output_table.columns
    ]
    # CI columns of multi-species groups are entirely NA.
    final_output_table = final_output_table.dropna(axis=1, how="all").reset_index()
    final_output_table.to_csv(output_file, index=False)

    print(f"parsed density rows by site:\n{parsed_rows_by_site.to_string()}")
    print(f"failed density rows: {failed_rows}")
    print(f"functional groups: {fg_long_table['functional_group'].nunique()}")
    print(f"output columns: {len(final_output_table.columns)}")
    mapped_species = int(species_mapping["functional_group_level5_name"].notna().sum())
    unmapped_species = int(species_mapping["functional_group_level5_name"].isna().sum())
    print(f"mapped species: {mapped_species}")
    print(f"unmapped species: {unmapped_species}")
    print(f"output rows: {len(final_output_table)}")
    print(f"Parsed and wrote: {output_file}")
