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

status: wip

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

# Manually filled functional_group_level5_name values to match species from observed
# data to functional group
species_to_fg_template: list[dict[str, str]] = [
    {
        "species_common_name": "Oriental_small-clawed_otter",
        "species_scientific_name": "Aonyx_cinereus",
        "functional_group_level5_name": "Carnivorous aquatic mammal",
    },
    {
        "species_common_name": "Binturong",
        "species_scientific_name": "Arctictis_binturong",
        "functional_group_level5_name": "Omnivorous arboreal/terrestrial small mammal",
    },
    {
        "species_common_name": "Great_argus",
        "species_scientific_name": "Argusianus_argus",
        "functional_group_level5_name": "Omnivorous terrestrial bird",
    },
    {
        "species_common_name": "Banteng",
        "species_scientific_name": "Bos_javanicus",
        "functional_group_level5_name": "Herbivorous terrestrial medium mammal",
    },
    {
        "species_common_name": "Bay_cat",
        "species_scientific_name": "Catopuma_badia",
        "functional_group_level5_name": (
            "Carnivorous arboreal/terrestrial medium mammal"
        ),
    },
    {
        "species_common_name": "Hose's_civet",
        "species_scientific_name": "Diplogale_hosei",
        "functional_group_level5_name": "Omnivorous arboreal/terrestrial small mammal",
    },
    {
        "species_common_name": "Moon_rat",
        "species_scientific_name": "Echinosorex_gymnura",
        "functional_group_level5_name": "Carnivorous borrowing mammal",
    },
    {
        "species_common_name": "Sun_bear",
        "species_scientific_name": "Helarctos_malayanus",
        "functional_group_level5_name": "Omnivorous arboreal/terrestrial large mammal",
    },
    {
        "species_common_name": "Banded_civet",
        "species_scientific_name": "Hemigalus_derbyanus",
        "functional_group_level5_name": "Omnivorous arboreal/terrestrial small mammal",
    },
    {
        "species_common_name": "Short-tailed_mongoose",
        "species_scientific_name": "Herpestes_brachyurus",
        "functional_group_level5_name": "Omnivorous arboreal/terrestrial small mammal",
    },
    {
        "species_common_name": "Collared_mongoose",
        "species_scientific_name": "Herpestes_semitorquatus",
        "functional_group_level5_name": "Omnivorous arboreal/terrestrial small mammal",
    },
    {
        "species_common_name": "Malay_porcupine",
        "species_scientific_name": "Hystrix_brachyura",
        "functional_group_level5_name": "Herbivorous terrestrial small mammal",
    },
    {
        "species_common_name": "Thick-spined_porcupine",
        "species_scientific_name": "Hystrix_crassispinis",
        "functional_group_level5_name": "Herbivorous terrestrial small mammal",
    },
    {
        "species_common_name": "Bulwer's_pheasant",
        "species_scientific_name": "Lophura_bulweri",
        "functional_group_level5_name": "Omnivorous terrestrial bird",
    },
    {
        "species_common_name": "Crested_fireback",
        "species_scientific_name": "Lophura_ignita",
        "functional_group_level5_name": "Omnivorous terrestrial bird",
    },
    {
        "species_common_name": "Long-tailed_macaque",
        "species_scientific_name": "Macaca_fascicularis",
        "functional_group_level5_name": "Omnivorous arboreal/terrestrial small mammal",
    },
    {
        "species_common_name": "Pig-tailed_macaque",
        "species_scientific_name": "Macaca_nemestrina",
        "functional_group_level5_name": "Omnivorous arboreal/terrestrial small mammal",
    },
    {
        "species_common_name": "Sunda_pangolin",
        "species_scientific_name": "Manis_javanica",
        "functional_group_level5_name": (
            "Carnivorous arboreal/terrestrial medium mammal"
        ),
    },
    {
        "species_common_name": "Yellow-throated_marten",
        "species_scientific_name": "Martes_flavigula",
        "functional_group_level5_name": (
            "Carnivorous arboreal/terrestrial medium mammal"
        ),
    },
    {
        "species_common_name": "Yellow_muntjac",
        "species_scientific_name": "Muntiacus_atherodes",
        "functional_group_level5_name": "Herbivorous terrestrial small mammal",
    },
    {
        "species_common_name": "Red_muntjac",
        "species_scientific_name": "Muntiacus_muntjak",
        "functional_group_level5_name": "Herbivorous terrestrial small mammal",
    },
    {
        "species_common_name": "Malay_weasel",
        "species_scientific_name": "Mustela_nudipes",
        "functional_group_level5_name": "Carnivorous terrestrial/arboreal mammal",
    },
    {
        "species_common_name": "Sunda_stink_badger",
        "species_scientific_name": "Mydaus_javanensis",
        "functional_group_level5_name": "Omnivorous terrestrial mammal",
    },
    {
        "species_common_name": "Sunda_clouded_leopard",
        "species_scientific_name": "Neofelis_diardi",
        "functional_group_level5_name": (
            "Carnivorous arboreal/terrestrial medium mammal"
        ),
    },
    {
        "species_common_name": "Masked_palm_civet",
        "species_scientific_name": "Paguma_larvata",
        "functional_group_level5_name": "Omnivorous arboreal/terrestrial small mammal",
    },
    {
        "species_common_name": "Marbled_cat",
        "species_scientific_name": "Pardofelis_marmorata",
        "functional_group_level5_name": (
            "Carnivorous arboreal/terrestrial medium mammal"
        ),
    },
    {
        "species_common_name": "Bornean_orangutan",
        "species_scientific_name": "Pongo_pygmaeus",
        "functional_group_level5_name": "Omnivorous arboreal primate",
    },
    {
        "species_common_name": "Leopard_cat",
        "species_scientific_name": "Prionailurus_javanensis",
        "functional_group_level5_name": (
            "Carnivorous arboreal/terrestrial medium mammal"
        ),
    },
    {
        "species_common_name": "Tufted_ground_squirrel",
        "species_scientific_name": "Rheithrosciurus_macrotis",
        "functional_group_level5_name": "Omnivorous arboreal small mammal",
    },
    {
        "species_common_name": "Sambar_deer",
        "species_scientific_name": "Rusa_unicolor",
        "functional_group_level5_name": "Herbivorous terrestrial small mammal",
    },
    {
        "species_common_name": "Bearded_pig",
        "species_scientific_name": "Sus_barbatus",
        "functional_group_level5_name": "Omnivorous terrestrial mammal",
    },
    {
        "species_common_name": "Lesser_mouse-deer",
        "species_scientific_name": "Tragulus_kanchil",
        "functional_group_level5_name": "Herbivorous terrestrial small mammal",
    },
    {
        "species_common_name": "Greater_mouse-deer",
        "species_scientific_name": "Tragulus_napu",
        "functional_group_level5_name": "Herbivorous terrestrial small mammal",
    },
    {
        "species_common_name": "Long-tailed_porcupine",
        "species_scientific_name": "Trichys_fasciculata",
        "functional_group_level5_name": "Herbivorous terrestrial small mammal",
    },
    {
        "species_common_name": "Malay_civet",
        "species_scientific_name": "Viverra_tangalunga",
        "functional_group_level5_name": "Omnivorous arboreal/terrestrial small mammal",
    },
]

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
    mapping_columns = [*species_columns, "functional_group_level5_name"]
    species_fg_mapping = pd.DataFrame(
        species_to_fg_template,
        columns=mapping_columns,
    ).copy()

    # Standardize species and functional group columns in the mapping table.
    for column_name in species_columns:
        species_fg_mapping[column_name] = (
            species_fg_mapping[column_name]
            .astype("string")
            .str.strip()
            .str.replace(r"\s+", "_", regex=True)
        )
    species_fg_mapping["functional_group_level5_name"] = (
        species_fg_mapping["functional_group_level5_name"]
        .astype("string")
        .str.strip()
        .replace("", pd.NA)
    )

    # Check for duplicate species_scientific_name entries in the mapping table.
    duplicate_species = species_fg_mapping[
        species_fg_mapping["species_scientific_name"].duplicated(keep=False)
    ]["species_scientific_name"].unique()
    if len(duplicate_species) > 0:
        duplicate_species_list = ", ".join(sorted(map(str, duplicate_species)))
        raise ValueError(
            "Phase 4 mapping has duplicated species_scientific_name entries: "
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
        print("species_to_fg_template = [")
        for row in template_rows.itertuples(index=False):
            print("    {")
            print(f'        "species_common_name": "{row.species_common_name}",')
            print(
                f'        "species_scientific_name": "{row.species_scientific_name}",'
            )
            print('        "functional_group_level5_name": "",')
            print("    },")
        print("]\n")

    # Merge the species reference with the functional group mapping.
    species_mapping = species_reference.merge(
        species_fg_mapping[["species_scientific_name", "functional_group_level5_name"]],
        on="species_scientific_name",
        how="left",
    )

    # Check for FG group names that dont exist in the functional_group_level5_options
    invalid_fg_rows = species_mapping[
        species_mapping["functional_group_level5_name"].notna()
        & ~species_mapping["functional_group_level5_name"].isin(
            functional_group_level5_options
        )
    ]
    if not invalid_fg_rows.empty:
        invalid_fg_list = ", ".join(
            sorted(invalid_fg_rows["functional_group_level5_name"].unique())
        )
        raise ValueError(
            "Phase 4 mapping contains FG names not in "
            f"functional_group_level5_options: {invalid_fg_list}"
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

    # e.g. "Omnivorous arboreal/terrestrial small mammal"
    # -> "omnivorous_arboreal_terrestrial_small_mammal"
    functional_group = (
        wearn_table["functional_group_level5_name"]
        .astype("string")
        .str.strip()
        .str.lower()
        .str.replace("&", "and", regex=False)
        .str.replace(r"[^a-z0-9]+", "_", regex=True)
        .str.strip("_")
    ).replace("", pd.NA)

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
