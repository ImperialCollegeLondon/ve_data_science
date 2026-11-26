# Animal functional-group builder

Run from the repository root:

```bash
uv run streamlit run analysis/animal/functional_group_builder/app.py \
  --server.address 127.0.0.1 --browser.gatherUsageStats false
```

The [Streamlit app](app.py) uses the repository-relative SAFE CSV under
`data/primary/animal/functional_group/`. The sidebar allows another SAFE-format
path and an explicit encoding (the supplied CSV uses `cp1252`). The tool reads
the metadata before the `field_name` header and checks that `BodyMass` is in
grams. It never writes to the source or existing scenario files.

Reusable parsing, filtering and export logic lives in
[animal_fg_builder.py](../../../tools/python/src/ve_data_tools/animal_fg_builder.py).
The app adds the repository's tools source directory to its import path, so
the run command above needs no separate package installation or `PYTHONPATH`.
Tests live in
[test_animal_fg_builder.py](../../../tools/python/tests/test_animal_fg_builder.py).

## Building groups

1. Choose a supported animal **class** and tick the **required** VE-taxa
   confirmation.
   Optionally refine with cascading order, family, genus and species dropdowns.
   Optional levels allow custom entries. There is no fallback to broader
   taxonomy: a custom entry without matches requires a manual adult mass in kg.
2. Select at least one **stratum**.
3. Choose an exclusive broad diet: carnivore, herbivore, omnivore, saprophage,
   parasite or parasitoid. Specific **VE diet tags are optional**: leaving the
   selection empty exports all observed mapped tags and retains every row
   matching taxonomy, strata and broad diet for the mass calculation.
4. Inspect the mass contributors and supply a mass if none are available.
5. Choose the name and other trait values, then add the group.

**Observed mapped tags** are the union of VE tags found in at least one
matching SAFE row, not tags found in every row. Review them for mismatches.
When you choose specific tags, the output diet contains only those tags.
Tick **Also require to match every selected detailed diet** to additionally
narrow the mass records to those matching all your selected tags. Otherwise,
specific choices affect only the output diet. Alternative SAFE columns for a
single VE tag match with OR; selected tags and strata match with AND.
If there are no observed tags (e.g. a custom taxon with no matches), you must
provide specific tags to make a non-empty VE output diet.

Create any number of groups. Select a saved group to edit or remove it.
Renaming also updates offspring references. If removal leaves an offspring
reference unresolved, fix it before downloading. Choose another existing group
as offspring for metamorphosis, or self for direct development.

Download the group CSV when finished. It has exactly the 15 columns of
the Maliau level-3 reference CSV. **Birth mass remains blank: this is a draft,
not a run-ready VE input.** Supply birth masses before simulation. Optional
density is blank unless entered. Thermal columns are not added.

The optional **included-taxa and mass log** has one record per contributing
taxon per saved group. Manual masses are labelled `user`, without inventing a
SAFE taxon. Renamed/removed groups are reflected in the download.

## Mass calculation and missing values

Only species and morphospecies contribute to the median. Species use the
`species` field (falling back to `taxon_name`); morphospecies use `taxon_name`
with taxonomic lineage to avoid merging distinct taxa. This is not a synonym
resolver. Numeric NA is missing; categorical NA and zero mean absence.
The first positive finite mass per identity in source order is retained.
Conflicting masses, duplicate records and exclusions are reported. Equal masses
from different taxa are **not** deduplicated. Grams are converted to kilograms.

## Approved mappings and limitations

- Aves, Mammalia, Reptilia and Amphibia map to bird, mammal, reptile and
  amphibian respectively. Non-chordate animal classes map to invertebrate.
  Fish and missing/unsupported classes are not offered.
- Soil maps to `StraSub`; ground to `StraTerr` or `StraUnd`; canopy to `StraArb`
  or `StraAer`. Aquatic occupancy has no supported mapping.
- Carnivore and herbivore exclude each other; omnivore requires both flags.
  These three exclude saprophage, parasite and parasitoid flags. Saprophage,
  parasite and parasitoid each require their own flag and exclude every other
  trophic flag. Mixed/unclassified records match no broad category.
- `DietCop` maps to waste; Det to detritus; Pisc to fish; Vert to vertebrates;
  Invert to invertebrates; Alg to algae; Xylo/Sapro to wood; Nec to nectar;
  Necro to carcasses; Gran to seeds; Frug to fruit; Foli/Rhyzo/Phloe to foliage;
  Flor/Paly to flowers; Hema to blood; Bact to bacteria; Myco to fungi;
  Soil to pom.
- Broad SAFE diet and VE's coarse diet classification are distinct: VE only
  has herbivore/carnivore/omnivore coarse categories. The tool warns about
  mismatches for those three choices; the final VE classification comes from
  the selected detailed tags. Suggested tags require biological review.

TODO: review understory-as-ground and aerial-as-canopy approximations.
TODO: revisit dead wood, fungi, soil, root, phloem and pollen mappings if VE
introduces finer diet categories. TODO: size bins and optional JSON provenance
for full filter/mapping/exclusion histories.

Trait dropdowns use installed VE enums rather than copying documentation
typos. Developed against VE 0.2.3: the sibling documentation table omits
`development_status`, misspells `uricotelic`, and lists extra optional thermal
fields. The installed parser is the accepted-values authority for this tool.

## Tests

```bash
uv run pytest tools/python/tests/test_animal_fg_builder.py
```
