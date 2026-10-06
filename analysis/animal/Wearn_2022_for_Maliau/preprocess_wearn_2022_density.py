"""
---
title: Preprocess Wearn 2022 density data for Maliau validation

description: |
  Preprocessing Wearn et al. (2022) density estimates
  into a valdb-ready species-level table for the animal module.

  TODO: need to change description later on

virtual_ecosystem_module: animal

author:
  - Nicholas Wei Cheng Tan

status: wip

input_files:
  - name: Wearn_et_al_2022_Density.csv
    path: data/primary/animal/Wearn_2022/
    description: |
      Raw supplementary table containing species density estimates across
      old-growth and logged forest habitats.
  - name: VE_ANIMAL_functionalgroups_model_level5_0250730.csv
    path: data/primary/animal/Functional_group_Anna/
    description: |TODO
      Level-5 functional group reference list used to populate the in-script
      options for manual species-to-group curation.THIS needs updating!

output_files:
  - name: Wearn_2022_density_old_growth_fg_species_rows.csv
    path: data/derived/animal/Wearn_2022_Maliau/
    description: |
      Target species-row output with functional-group-specific density
      columns derived from old-growth estimates.

package_dependencies:
  - pandas

usage_notes: |
  This file currently includes Phase 1 setup, Phase 2 source parsing, and
  Phase 3 parsing of old-growth density text into numeric values and
  Phase 4 species-to-functional-group mapping.

  Update the
  species_to_fg_template table in this script by filling the
  functional_group_level5_name values before final output generation.
---
"""  # noqa: D205, D212, D400, D415

from pathlib import Path

import pandas as pd

module_name = "animal"
repo_root = Path(__file__).resolve().parents[3]

input_file = (
    repo_root
    / "data"
    / "primary"
    / module_name
    / "Wearn_2022"
    / ("Wearn_et_al_2022_Density.csv")
)

output_dir = repo_root / "data" / "derived" / module_name / "Wearn_2022_Maliau"
output_file = output_dir / "Wearn_2022_density_old_growth_fg_species_rows.csv"

# Functional group level 5 from VE_ANIMAL_functionalgroups_model_level5_0250730.csv in
# data/primary/animal/Functional_group_Anna/
# TODO: Check if all functional group level 5 with the reference CSV.
functional_group_level5_options: list[str] = [
    "Carnivorous arboreal birds",
    "Insectivorous arboreal bats",
    "Insectivorous arboreal birds",
    "Omnivorous terrestrial ants",
    "Herbivorous terrestrial termites",
    "Herbivorous terrestrial beetles & crickets",
    "Herbivorous terrestrial & subterranean larva",
    "Carnivorous flying insects",
    "Arboreal reptiles",
    "Arboreal amphibians",
    "Carnivorous terrestrial ants",
    "Omnivorous terrestrial beetles",
    "Omnivorous terrestrial larva",
    "Herbivorous arboreal bees",
    "Herbivorous arboreal bugs",
    "Herbivorous arboreal butterflies & moths",
    "Carnivorous arboreal spiders",
    "Herbivorous arboreal larva",
    "Non-Feeding semelparous flying insects",
    "Carnivorous semelparous flies",
    "Herbivorous terrestrial large mammal",
    "Herbivorous terrestrial medium mammal",
    "Herbivorous terrestrial small mammal",
    "Omnivorous arboreal birds",
    "Terrestrial amphibians",
    "Terrestrial reptiles",
    "Omnivorous arboreal ants",
    "Carnivorous terrestrial larva",
    "Carnivorous predatory beetles",
    "Omnivorous terrestrial semelparous flying insects",
    "Herbivorous arboreal primates",
    "Omnivorous terrestrial mammal",
    "Herbivorous terrestrial semelparous flies",
    "Arboreal snakes",
    "Herbivorous terrestrial insects",
    "Herbivorous arboreal insects",
    "Carnivorous borrowing mammal",
    "Carnivorous arboreal mammal",
    "Carnivorous arboreal/terrestrial medium mammal",
    "Omnivorous arboreal primate",
    "Omnivorous arboreal small mammal",
    "Herbivorous arboreal bats",
    "Herbivorous arboreal birds",
    "Herbivorous arboreal semelparous larva",
    "Carnivorous terrestrial/arboreal mammal",
    "Herbivorous terrestrial semelparous larva",
    "Carnivorous riparian birds",
    "Carnivorous aquatic mammal",
    "Omnivorous arboreal/terrestrial large mammal",
    "Omnivorous arboreal/terrestrial small mammal",
    "Carnivorous aquatic snakes",
    "Carnivorous terrestrial snakes",
    "Omnivorous terrestrial bird",
    "Carnivorous terrestrial birds",
    "Omnivorous flying wasps",
    "Detrital soil macrofauna",
    "Carnivorous soil macrofauna",
    "Soil-feeding soil macrofauna",
    "Soil-feeding soil mesofauna",
    "Soil-feeding soil microfauna",
]


# Fill functional_group_level5_name values in later phases.
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

    # Import and read the Wearn 2022 density data
    wearn_table = pd.read_csv(
        input_file,
        header=None,
        skiprows=10,
        # Get only the relevant columns for density in old growth
        usecols=[0, 1, 8, 9],
        # Rename the columns for clarity
        names=[
            "species_common_name",
            "species_scientific_name",
            "density_sample_size_n",
            "density_old_growth_text",
        ],
        dtype="string",
    )

    # Filter out rows with missing or empty species_common_name
    wearn_table = wearn_table[
        wearn_table["species_common_name"].notna()
        & (wearn_table["species_common_name"] != "")
    ].copy()

    # Strip white spaces and replace them with underscores.
    wearn_table["species_common_name"] = (
        wearn_table["species_common_name"]
        .str.strip()
        .str.replace(r"\s+", "_", regex=True)
    )
    wearn_table["species_scientific_name"] = (
        wearn_table["species_scientific_name"]
        .str.strip()
        .str.replace(r"\s+", "_", regex=True)
    )

    # Convert the density sample size column string to numeric, coercing errors to NaN.
    wearn_table["density_sample_size_n"] = pd.to_numeric(
        wearn_table["density_sample_size_n"].str.strip(),
        errors="coerce",
    )

    # Parse old-growth density text into numeric median and CI bounds.
    density_parsed = (
        wearn_table["density_old_growth_text"]
        .str.strip()
        .str.extract(
            r"^\s*(?P<density_old_growth_median>-?\d+(?:\.\d+)?)"
            r"\s*\(\s*(?P<density_old_growth_ci95_lower>-?\d+(?:\.\d+)?)"
            r"\s*-\s*(?P<density_old_growth_ci95_upper>-?\d+(?:\.\d+)?)\s*\)\s*$"
        )
        .apply(pd.to_numeric, errors="coerce")
    )
    # Concatenate the parsed density columns back to the original table.
    wearn_table = pd.concat([wearn_table, density_parsed], axis=1)

    # Count the number of successfully parsed and failed rows.
    parsed_rows = int(wearn_table["density_old_growth_median"].notna().sum())
    failed_rows = len(wearn_table) - parsed_rows

    # Phase 4: map species to level-5 functional groups.
    # Many species may map to one FG, and not all FG options need to be used.
    # Missing FG mappings are allowed and carried through as NA.
    mapping_columns = [
        "species_common_name",
        "species_scientific_name",
        "functional_group_level5_name",
    ]
    species_fg_mapping = pd.DataFrame(
        species_to_fg_template,
        columns=mapping_columns,
    ).copy()

    # Standardize species and functional group columns in the mapping table.
    for column_name in ["species_common_name", "species_scientific_name"]:
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
        wearn_table[["species_common_name", "species_scientific_name"]]
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

    print(f"parsed rows: {len(wearn_table)}")
    print(
        wearn_table[
            [
                "species_common_name",
                "species_scientific_name",
                "density_sample_size_n",
                "density_old_growth_text",
                "density_old_growth_median",
                "density_old_growth_ci95_lower",
                "density_old_growth_ci95_upper",
                "functional_group_level5_name",
            ]
        ].head(5)
    )
    print(f"Phase 3 parsed old-growth rows: {parsed_rows}")
    print(f"Phase 3 failed old-growth rows: {failed_rows}")
    mapped_species = int(species_mapping["functional_group_level5_name"].notna().sum())
    unmapped_species = int(species_mapping["functional_group_level5_name"].isna().sum())
    print(f"Phase 4 mapped species: {mapped_species}")
    print(f"Phase 4 unmapped species: {unmapped_species}")
