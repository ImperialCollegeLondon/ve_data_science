"""
---
title: Preprocess Wearn 2022 density data for Maliau validation

description: |
  Phase 1 scaffold for preprocessing Wearn et al. (2022) density estimates
  into a valdb-ready species-level table for the animal module.

  This phase defines input/output contracts and an in-script functional-group
  template table with a functional_group_level5_name column for manual
  curation.

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
    description: |
      Level-5 functional group reference list used to populate the in-script
      options for manual species-to-group curation.

output_files:
  - name: Wearn_2022_density_old_growth_fg_species_rows.csv
    path: data/derived/animal/Wearn_2022_Maliau/
    description: |
      Target species-row output with functional-group-specific density
      columns derived from old-growth estimates.

package_dependencies:
  - pandas

usage_notes: |
  This file currently includes Phase 1 setup and Phase 2 source parsing.

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
    "Carnivorous aboreal/terrestrial medium mammal",
    "Omnivorous arboreal primate",
    "Omnivorous arboreal small mammal",
    "Herbivorous arboreal bats",
    "Herbivorous arboreal birds",
    "Herbivorous arboreal semelparous larva",
    "Carnivorous terrestrial/arboreal mammal",
    "Herbivorous terrestrial semelparous  larva",
    "Carnivorous riparian birds",
    "Carnivorous aquatic mammal",
    "Omnivorous aboreal/terrestrial large mammal",
    "Omnivorous aboreal/terrestrial small mammal",
    "Carnivorous aquatic snakes",
    "Carnivorous terrestrial snakes",
    "Omnivorous terrestrial birds",
    "Carnivorous terrestrial birds",
    "Omnivorous flying wasps",
    "Detrital soil macrofauna",
    "Carnivorous soil macrofauna",
    "Soil-feeding soil macrofauna",
    "Soil-feeding soil mesofauna",
    "Soil-feeding soil microfauna",
]


# Fill functional_group_level5_name values in later phases.
species_to_fg_template: list[dict[str, str]] = []

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

    wearn_table["density_sample_size_n"] = pd.to_numeric(
        wearn_table["density_sample_size_n"].str.strip(),
        errors="coerce",
    )

    print(f"Phase 2 parsed rows: {len(wearn_table)}")
    print(
        wearn_table[
            [
                "species_common_name",
                "species_scientific_name",
                "density_sample_size_n",
                "density_old_growth_text",
            ]
        ].head(5)
    )
