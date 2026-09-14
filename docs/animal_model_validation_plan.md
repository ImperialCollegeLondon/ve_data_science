# Animal-model validation plan

This is a draft plan for validating the animal model outputs in the VE project
with the help of Copilot. It is intended to be a living document that will be
updated as the model and its outputs evolve, as well as new validation datasets
are identified. Currently, the document is written for Maliau and SAFE scenarios.

Notes:

- Perhaps some of the sections can be split into smaller sections or subsections
  with lesser variables?

## 1. Scope and rules

1. Animal-model validation only, including cross-module outputs when they
   directly
  support animal interpretation.
2. Validation metrics are computed from exported outputs and post-processing
   only.
3. Targets are organised into 1) site-specific emergent or derived targets and
   2) global emergent pattern checks (Madingley based).

## 2. Secondary validation targets (emergent or derived from outputs)

Targets in this section are site specific.

### 2.1 Population and biomass density structure by functional group

*Derivation:* Derive post-model population density and biomass density from
functional group abundance, occupancy, territory, and elemental mass.

*Inputs:* individuals, functional_group, occupancy_proportion, territory_size,
mass_carbon, mass_nitrogen, mass_phosphorus, is_mature.

*Validation approach:* Compare equilibrium density ranges and biomass density
against published empirical datasets in Maliau or SAFE. Stratify by body-mass
class and diet class where available.

TODO: Align with Arne how we approach verifying against spatially variable density.

*Datasets needed:* Site-level abundance or density datasets, biomass density
datasets, including live mammals trapping from Chapman et al. (2018), camera
trap data from Wearn et al. (2016) and Wearn et al. (2017), and the 2011-13
density estimate from Wearn et al. (2022). Also check Joshua March or Sarah Luke
for termite density and the Sri Rao thesis for earthworm density in SAFE Zenodo.

TODO: contact Ollie Wearn and Phil Chapman.

### 2.6 Nutrient-return flux contributions from animals

*Derivation:* Excrement and carcass proxies from consumed stoichiometry,
assimilation efficiency assumptions, and mortality estimates.

*Inputs:* decomposed_excrement_cnp, decomposed_carcasses_cnp,
herbivory_waste_leaf_cnp, C, N, P, cohort_id, time_index, is_alive, individuals.

*Validation approach:* Compare decomposed excrement, carcass loss, and herbivory
waste fluxes against empirical nutrient-return studies and litterfall or
carcass-decomposition datasets.

*Datasets needed:* Excretion datasets, carcass decomposition studies,
nutrient-return studies, and herbivory waste measurements. Sui has carcass decomposition
data from Danum and oil palm plantations - can be used only if appropriate and we found
solution for spatial mismatch.

### 2.7 Aggregated consumption partitions and assimilation-flow consistency

*Derivation:* Aggregate trophic interaction records and consumption outputs to
habitat-, guild-, or functional-group-level rates and proportions, then compare
those derived quantities with observed energetic partitions and assimilation
behaviour.

*Inputs:* resource_kind, C, N, P from animal_trophic_interactions.csv;
animal_pom_consumption_cnp, animal_bacteria_consumption,
animal_saprotrophic_fungi_consumption, animal_ectomycorrhiza_consumption,
animal_arbuscular_mycorrhiza_consumption, litter_consumed_above_metabolic_cnp,
litter_consumed_above_structural_cnp, litter_consumed_woody_cnp,
litter_consumed_below_metabolic_cnp, litter_consumed_below_structural_cnp,
total_animal_respiration, decomposed_excrement_cnp, decomposed_carcasses_cnp,
mass_carbon, mass_nitrogen, and mass_phosphorus.

*Validation approach:* Compare derived habitat- or guild-level consumption
partitions, total intake, and assimilation-flow consistency against published
intake partitioning studies and animal energetics datasets. For the Malhi
supplementary tables, use AnimalGroup_Habitat as the habitat key when matching
food-group energetics, because the ForestType labels in
MOESM7_ESM__Energetics_byFoodGroup.csv are internally inconsistent for logged
versus old-growth forest rows. Treat this target as emergent because it depends
on post-processing, aggregation, and comparison of derived rates rather than
direct exported records.

*Datasets needed:* Resource-specific intake studies, assimilation efficiency
datasets, animal energy-budget studies, stoichiometric balance datasets, and
Malhi supplementary habitat-, guild-, and food-group energetics tables.

### 2.8 Coupled plant-animal productivity linkage

*Derivation:* Animal intake and biomass response versus plant productivity,
plant allocation, and plant-supported intake ratios.

*Inputs:* canopy_foliage_cnp, subcanopy_vegetation_biomass,
plant_ammonium_uptake, plant_nitrate_uptake, plant_phosphorus_uptake,
canopy_foliage_cnp_consumed, canopy_seed_cnp_consumed,
canopy_fruit_cnp_consumed, subcanopy_vegetation_cnp_consumed,
subcanopy_seedbank_cnp_consumed, mass_carbon, individuals, functional_group,
occupancy_proportion, territory_size.

*Validation approach:* Compare modelled habitat-level animal intake as a
fraction of plant productivity against observed energetic intake as %NPP from
the Malhi habitat tables. Then test whether between-habitat shifts in intake
composition follow observed habitat differences in plant allocation. Plant
ammonium, nitrate, and phosphorus uptake are already exported as areal daily
uptake rates, so no rooting-depth conversion is required.

*Datasets needed:* Plant productivity datasets, herbivory impact datasets,
coupled plant-animal interaction studies, and Malhi supplementary NPP and
habitat energetics tables.

### 2.9 Space-use and territory-use realism

*Derivation:* Build occupancy-weighted territory and location-use summaries by
cohort and functional group through time.

*Inputs:* occupancy_proportion, territory_size, centroid_key, territory,
location_status, individuals, functional_group, time_index.

*Validation approach:* Compare occupancy and territory-use distributions,
persistence, and movement signatures against telemetry, home-range, and
territory-use datasets for comparable taxa and body-size classes.

*Datasets needed:* Home-range studies, telemetry datasets, territory-size
summaries, and movement ecology datasets. Wearn et al. (2022) estimated
home-range from camera trap, Brasington 2019 thesis estimated small mammal
home ranges from live mammal traps. Estimates from both literature
are species level and site-level.

## 3. Global validation relationships (Madingley emergent pattern checks)

Bracketed numbers in this section refer to the numbered source references used
by Harfoot et al. (2014) to support each comparison dataset. Targets in this
section are global and not specific to any site.

### 3.1 Body mass versus growth rate

*Relationship type:* Individual-level allometric scaling.

*Inputs:* cohort_id, time_index, age, mass_carbon, mass_nitrogen,
mass_phosphorus, largest_mass_achieved.

*Reference anchor:* Harfoot et al. (2014), Figure 3A.

*Validation approach:* Compare emergent growth-rate scaling against observed
growth data for terrestrial vertebrates and invertebrates.

*Datasets needed:* Growth datasets for reptiles, mammals, birds, and terrestrial
invertebrates from Case (1978), Ricklefs (1968, 1973), and related compiled
sources [46–48]. Where growth rates were derived from body length, use the
length-mass conversions cited by Harfoot et al. [58–61].

### 3.2 Body mass versus time to maturity

*Relationship type:* Individual-level allometric scaling.

*Inputs:* time_to_maturity, largest_mass_achieved, is_mature.

*Reference anchor:* Harfoot et al. (2014), Figure 3B.

*Validation approach:* Compare modelled age at maturity against published
maturation datasets and check that larger-bodied cohorts mature later.

*Datasets needed:* Maturation and life-history datasets for invertebrates,
reptiles, mammals, and birds [49–53,57], with length-mass conversions where
necessary [58–60].

### 3.3 Body mass versus mortality rate

*Relationship type:* Individual-level allometric scaling.

*Inputs:* cohort_id, time_index, is_alive, individuals.

*Reference anchor:* Harfoot et al. (2014), Figure 3C.

*Validation approach:* Compare estimated mortality scaling against published
natural mortality datasets and inspect whether the model reproduces the observed
decline in mortality with increasing body mass.

*Datasets needed:* Natural mortality datasets for invertebrates, mammals, and
birds from terrestrial mortality compilations and trait syntheses.

### 3.4 Body mass versus lifetime reproductive success

*Relationship type:* Individual-level allometric scaling.

*Inputs:* cohort_id, time_index, is_mature, reproductive_mass_carbon,
reproductive_mass_nitrogen, reproductive_mass_phosphorus.

*Reference anchor:* Harfoot et al. (2014), Figure 3D.

*Validation approach:* Compare predicted lifetime reproductive success against
trait and demographic datasets, checking for the broad body-mass scaling seen in
the paper.

*Datasets needed:* Mammal, bird, and insect reproductive success datasets
compiled from PanTHERIA, bird reproductive studies, and insect life-history
studies [63–71].

### 3.5 Biomass density and abundance-density scaling

*Relationship type:* Community-level allometric scaling.

*Inputs:* mass_carbon, individuals, functional_group, occupancy_proportion,
territory_size.

*Reference anchor:* Harfoot et al. (2014), Figures 4B, 4D, and S5.

*Validation approach:* Compare density-body-mass slopes and biomass density of
large herbivores against observed community assemblages.

*Datasets needed:* Biomass and abundance estimates for large African herbivores
in Uganda [72], terrestrial herbivore-to-producer biomass summaries [73], and
terrestrial assemblage abundance-density datasets.

### 3.6 Biomass pyramids and herbivore:producer ratios

*Relationship type:* Community-level trophic structure.

*Inputs:* mass_carbon, mass_nitrogen, mass_phosphorus, individuals,
functional_group, canopy_foliage_cnp, subcanopy_vegetation_biomass.

*Reference anchor:* Harfoot et al. (2014), Figure 4A and 4C, Tables S3 and S5.

*Validation approach:* Compare terrestrial biomass pyramids and
herbivore-to-producer biomass ratios against geographically located terrestrial
ecosystem summaries.

*Datasets needed:* Terrestrial subsets of the Cebrian et al. global ecosystem
structure dataset [73], plus the terrestrial benchmark summaries used for Table
S5 [80].

### 3.7 Trophic structure along productivity gradients

*Relationship type:* Macroecological gradient pattern.

*Inputs:* mass_carbon, individuals, functional_group, occupancy_proportion,
territory_size, canopy_foliage_cnp, subcanopy_vegetation_biomass,
plant_ammonium_uptake, plant_nitrate_uptake, plant_phosphorus_uptake.

*Reference anchor:* Harfoot et al. (2014), Figure 6 and Figure S6.

*Validation approach:* Compare modelled changes in trophic structure along
terrestrials productivity gradients against empirical terrestrial community
trophic-structure datasets.

*Datasets needed:* Productivity-gradient datasets from terrestrial forest,
woodland, and grassland communities, together with observed NPP as the basal
resource proxy [97].

### 3.8 Global biomass patterns and latitudinal structure

*Relationship type:* Macroecological global pattern.

*Inputs:* x, y, mass_carbon, individuals, functional_group,
occupancy_proportion, territory_size, canopy_foliage_cnp,
subcanopy_vegetation_biomass.

*Reference anchor:* Harfoot et al. (2014), Figures 7 and S7, plus Table 8.

*Validation approach:* Compare global heterotroph biomass density,
herbivore:autotroph ratios, and latitudinal variation in biomass density against
broad empirical and prior-model estimates.

*Datasets needed:* Global terrestrial trophic-structure summaries from Cebrian
et al. [73], global terrestrial NPP data [97], and prior terrestrial biomass
estimates from terrestrial macroecological compilations.

## 4. Target summary table

<!-- markdownlint-disable MD013 -->

| Target ID | Scope | Target | Category | Variables used | Output source | Validation approach | Datasets needed | Reference |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2.1 | Site-specific | Population and biomass density structure by functional group | Emergent | individuals, functional_group, occupancy_proportion, territory_size, mass_carbon, mass_nitrogen, mass_phosphorus, is_mature | animal_cohort_data.csv | Derive post-spin-up density and biomass density by functional group and compare against empirical density ranges, stratified by body-mass and diet class where available | Site-level abundance or density datasets, biomass density datasets, mammal-trap and camera-trap studies | Chapman et al. (2018), Wearn et al. (2016), Wearn et al. (2017), Wearn et al. (2022) |
| 2.6 | Site-specific | Nutrient-return flux contributions from animals | Emergent | decomposed_excrement_cnp, decomposed_carcasses_cnp, herbivory_waste_leaf_cnp, C, N, P, cohort_id, time_index, is_alive, individuals | output.zarr, animal_trophic_interactions.csv, animal_cohort_data.csv | Compare decomposed excrement, carcass loss, and herbivory waste fluxes against empirical nutrient-return studies and litterfall or carcass-decomposition datasets | Excretion datasets, carcass decomposition studies, nutrient-return studies, herbivory waste measurements | Sui dataset of carcass decomposition |
| 2.7 | Site-specific | Aggregated consumption partitions and assimilation-flow consistency | Emergent | resource_kind, C, N, P, animal_pom_consumption_cnp, animal_bacteria_consumption, animal_saprotrophic_fungi_consumption, animal_ectomycorrhiza_consumption, animal_arbuscular_mycorrhiza_consumption, litter_consumed_above_metabolic_cnp, litter_consumed_above_structural_cnp, litter_consumed_woody_cnp, litter_consumed_below_metabolic_cnp, litter_consumed_below_structural_cnp, total_animal_respiration, decomposed_excrement_cnp, decomposed_carcasses_cnp, mass_carbon, mass_nitrogen, mass_phosphorus | animal_trophic_interactions.csv, output.zarr | Compare derived habitat- or guild-level consumption partitions, intake totals, and assimilation-flow consistency against energetics and intake-partitioning studies; use AnimalGroup_Habitat when matching Malhi food-group tables | Intake partitioning studies, assimilation efficiency datasets, animal energy-budget studies, Malhi habitat-, guild-, and food-group energetics tables | Malhi et al. (2022) |
| 2.8 | Site-specific | Plant-animal productivity linkage | Emergent | canopy_foliage_cnp, subcanopy_vegetation_biomass, plant_ammonium_uptake, plant_nitrate_uptake, plant_phosphorus_uptake, canopy_foliage_cnp_consumed, canopy_seed_cnp_consumed, canopy_fruit_cnp_consumed, subcanopy_vegetation_cnp_consumed, subcanopy_seedbank_cnp_consumed, mass_carbon, individuals, functional_group, occupancy_proportion, territory_size | output.zarr, animal_cohort_data.csv | Compare habitat-level animal intake as a fraction of plant productivity and plant allocation against coupled herbivory-productivity datasets; use plant uptake directly as areal daily rates | Plant productivity datasets, herbivory impact datasets, coupled interaction studies, Malhi NPP and habitat energetics tables | Malhi et al. (2022) |
| 2.9 | Site-specific | Space-use and territory-use realism | Emergent | occupancy_proportion, territory_size, centroid_key, territory, location_status, individuals, functional_group, time_index | animal_cohort_data.csv | Compare occupancy and territory-use distributions, persistence, and movement signatures against home-range and telemetry evidence | Home-range studies, telemetry datasets, territory-use summaries, movement ecology datasets, species- and site-level estimates from camera traps and live trapping | Wearn et al. (2013), Wearn et al. (2022), Brasington (2019) |
| 3.1 | Global | Growth rate versus body mass | Emergent | cohort_id, time_index, age, mass_carbon, mass_nitrogen, mass_phosphorus, largest_mass_achieved | animal_cohort_data.csv | Compare emergent growth-rate scaling with terrestrial vertebrate and invertebrate growth datasets | Growth datasets for reptiles, mammals, birds, and terrestrial invertebrates; length-mass conversions where needed | Case (1978), Ricklefs (1968, 1973), Harfoot et al. (2014) |
| 3.2 | Global | Time to maturity versus body mass | Emergent | time_to_maturity, largest_mass_achieved, is_mature | animal_cohort_data.csv | Compare modelled age at maturity against compiled maturation datasets | Maturation and life-history datasets for invertebrates, reptiles, mammals, and birds; length-mass conversions where needed | Millar and Zammuto (1983), Sæther (1987), Shine and Iverson (1995), Shine and Charnov (1992), Blakley and Goodner (1978), Harfoot et al. (2014) |
| 3.3 | Global | Mortality versus body mass | Emergent | cohort_id, time_index, is_alive, individuals | animal_cohort_data.csv | Compare mortality scaling with natural mortality datasets | Natural mortality datasets for invertebrates, mammals, and birds | Harfoot et al. (2014) |
| 3.4 | Global | Lifetime reproductive success versus body mass | Emergent | cohort_id, time_index, is_mature, reproductive_mass_carbon, reproductive_mass_nitrogen, reproductive_mass_phosphorus | animal_cohort_data.csv | Compare reproductive success scaling with mammal, bird, and insect datasets | Mammal, bird, and insect reproductive success datasets | Jones et al. (2009), Clutton-Brock (1988), Fedigan et al. (1986), Holland and Yalden (1994), Krüger and Lindström (2001), Merila and Sheldon (2000), Newton (1989), Oring et al. (1991), Schubert et al. (2007), Harfoot et al. (2014) |
| 3.5 | Global | Biomass density and abundance-density scaling | Emergent | mass_carbon, individuals, functional_group, occupancy_proportion, territory_size | animal_cohort_data.csv | Compare community biomass and density scaling with terrestrial herbivore assemblage datasets | Biomass and abundance estimates for large African herbivores in Uganda; terrestrial herbivore-to-producer biomass summaries; terrestrial assemblage abundance-density datasets | Coe (1976), Harfoot et al. (2014) |
| 3.6 | Global | Biomass pyramids and herbivore:producer ratios | Emergent | mass_carbon, mass_nitrogen, mass_phosphorus, individuals, functional_group, canopy_foliage_cnp, subcanopy_vegetation_biomass | output.zarr, animal_cohort_data.csv | Compare terrestrial trophic pyramids and herbivore:producer ratios with cross-site terrestrial ecosystem summaries | Terrestrial subsets of the global ecosystem structure dataset from Cebrian et al. plus terrestrial benchmark summaries | Cebrian et al. (2009), Begon et al. (2006), Harfoot et al. (2014) |
| 3.7 | Global | Trophic structure along productivity gradients | Emergent | mass_carbon, individuals, functional_group, occupancy_proportion, territory_size, canopy_foliage_cnp, subcanopy_vegetation_biomass, plant_ammonium_uptake, plant_nitrate_uptake, plant_phosphorus_uptake | output.zarr, animal_cohort_data.csv | Compare gradient patterns with terrestrial community datasets along terrestrial productivity gradients | Productivity-gradient datasets from terrestrial forest, woodland, and grassland communities; observed terrestrial productivity proxies | Field (1998), Chase (2003), Harfoot et al. (2014) |
| 3.8 | Global | Global biomass patterns and latitudinal structure | Emergent | x, y, mass_carbon, individuals, functional_group, occupancy_proportion, territory_size, canopy_foliage_cnp, subcanopy_vegetation_biomass | output.zarr, animal_cohort_data.csv | Compare terrestrial biomass and latitudinal structure with empirical and prior-model estimates | Global terrestrial trophic-structure summaries, terrestrial productivity proxies, prior terrestrial biomass estimates | Cebrian et al. (2009), Field (1998), Harfoot et al. (2014) |

<!-- markdownlint-disable MD013 -->

## 5. Data-source mapping deliverable

### 5.1 Target registry fields

Build a target registry with one row per target including:

- target_id
- definition
- category (direct or emergent)
- variables_used
- source_file_names
- derivation_method (none for direct)
- external_reference
- notes_on_assumptions

### 5.2 Expected source files to map

- animal_cohort_data.csv.
- animal_trophic_interactions.csv.
- resource_pool_data.csv.
- output.zarr data variables for cross-module flux coupling.
- Functional-group definition table used for the run (includes metabolic_type,
  t_opt, t_max_crit, t_min_crit).
  - Animal model constants and run configuration metadata (for example tau_f and
    timestep duration).

### 5.3 Units and transformation rules

Units below are taken from model metadata in data_variables.toml and the
cohort/trophic exporter schema. Where run-level Zarr attrs differ from the registry
unit, treat the run-level attrs as the value used in analysis and record the override
in the target registry notes

<!-- markdownlint-disable MD013 -->

| Variable(s) | Source | Unit in exported data | Transformation used for validation |
| --- | --- | --- | --- |
| cohort_id, consumer_cohort_id, resource_id | animal_cohort_data.csv, animal_trophic_interactions.csv | identifier (UUID or string id) | Use as join keys only; no arithmetic operations |
| resource_cell_id, centroid_key, territory, x, y | animal_trophic_interactions.csv, animal_cohort_data.csv, output.zarr | integer grid index or list of grid indices | Map to grid metadata before spatial summaries; do not treat as continuous physical units |
| functional_group, resource_kind, location_status | animal_cohort_data.csv, animal_trophic_interactions.csv | categorical | Encode as categories for grouping, faceting, and mixed-effects terms |
| is_alive, is_mature | animal_cohort_data.csv | boolean | Cast to 0/1 for survival, maturity, and transition-rate calculations |
| time, time_index | animal_cohort_data.csv, animal_trophic_interactions.csv | datetime stamp; integer timestep index | Use time_index for differencing and window summaries; use time for calendar grouping |
| age, time_to_maturity, time_since_maturity | animal_cohort_data.csv | days | Convert to years when comparison datasets are annual or life-stage based: years = days / 365.25 |
| individuals | animal_cohort_data.csv | count of individuals | Use as abundance weight in all cohort-to-community aggregations |
| occupancy_proportion | animal_cohort_data.csv | unitless proportion [0,1] | Use as within-cell weighting factor for effective abundance |
| territory_size | animal_cohort_data.csv | m^2 | Use for area-normalised density calculations and occupancy checks |
| largest_mass_achieved | animal_cohort_data.csv | kg (body mass per individual) | Convert to log10 mass for allometric regressions |
| mass_carbon, mass_nitrogen, mass_phosphorus | animal_cohort_data.csv | kg element per individual | Convert to cohort-level elemental mass by multiplying by individuals |
| reproductive_mass_carbon, reproductive_mass_nitrogen, reproductive_mass_phosphorus | animal_cohort_data.csv | kg element per individual | Difference over timesteps for reproductive allocation rates; multiply by individuals for cohort totals |
| C, N, P | animal_trophic_interactions.csv | kg element per interaction record (per update step) | Aggregate by cell/time/consumer group; divide by timestep duration for daily rates where needed |
| net_radiation | output.zarr | W m^-2 | Aggregate by mean or integral over the same window as biological response variables |
| wind_speed | output.zarr | m s^-1 | Aggregate by mean, quantiles, or threshold exceedance frequency |
| decomposed_excrement_cnp, decomposed_carcasses_cnp | output.zarr | kg m^-2 day^-1 | Integrate over timestep window: mass = flux x days |
| herbivory_waste_leaf_cnp | output.zarr | kg | Divide by grid-cell area for areal comparisons when needed |
| litter_consumed_above_metabolic_cnp, litter_consumed_above_structural_cnp, litter_consumed_woody_cnp, litter_consumed_below_metabolic_cnp, litter_consumed_below_structural_cnp | output.zarr | registry: kg (some runs may expose kg m^-2 attrs) | If unit is kg, divide by area for areal comparisons; if unit is kg m^-2, integrate directly over area/time as needed |
| animal_pom_consumption_cnp | output.zarr | kg m^-3 day^-1 | Convert to areal flux using active soil depth: kg m^-2 day^-1 = kg m^-3 day^-1 x depth_m |
| animal_bacteria_consumption, animal_saprotrophic_fungi_consumption, animal_ectomycorrhiza_consumption, animal_arbuscular_mycorrhiza_consumption | output.zarr | kg C m^-3 day^-1 | Convert to areal carbon flux using active soil depth, then aggregate by cell/time |
| canopy_foliage_cnp, canopy_foliage_cnp_consumed, canopy_seed_cnp_consumed, canopy_fruit_cnp_consumed | output.zarr | kg | Use element-specific slices where required (for example carbon-only summaries) |
| subcanopy_vegetation_biomass | output.zarr | kg C m^-2 | Use directly for areal producer-carbon metrics |
| subcanopy_vegetation_cnp_consumed, subcanopy_seedbank_cnp_consumed | output.zarr | kg C m^-2 | Aggregate by cell and timestep; convert to period totals via integration over time |
| plant_ammonium_uptake, plant_nitrate_uptake | output.zarr | kg N m^-2 day^-1 | Already an areal daily uptake rate; aggregate directly by cell and timestep for productivity-gradient comparisons |
| plant_phosphorus_uptake | output.zarr | kg P m^-2 day^-1 | Already an areal daily uptake rate; aggregate directly by cell and timestep for productivity-gradient comparisons |
| timestep duration | Run configuration metadata | days | Use as \(\Delta t\) in all rate-to-total and differencing calculations |

<!-- markdownlint-disable MD013 -->

### 5.4 Derivation formulas for emergent targets

The derivation formulas below were generated by Copilot and should be reviewed.

Notation:

- $i$: cohort index
- $g$: functional group index
- $c$: grid-cell index
- $t$: timestep index
- $\Delta t$: timestep duration in days
- $A_c$: area of grid cell $c$ in m$^2$
- $N_{i,t}$: individuals for cohort $i$ at time $t$
- $w_{i,t}$: occupancy_proportion for cohort $i$ at time $t$
- $m^e_{i,t}$: per-individual cohort mass of element $e \in \{C,N,P\}$

Effective abundance in a cell:

$$
N^{eff}_{i,t} = N_{i,t} \cdot w_{i,t}
$$

Functional-group density (for 2.1a, 3.5):

$$
D_{g,c,t} = \frac{\sum_{i \in (g,c)} N^{eff}_{i,t}}{A_c}
$$

Element-specific cohort biomass and functional-group biomass density
(for 2.1, 3.5, 3.6):

$$
B^e_{i,c,t} = N^{eff}_{i,t} \cdot m^e_{i,t}
$$

$$
\rho^e_{g,c,t} = \frac{\sum_{i \in (g,c)} B^e_{i,c,t}}{A_c}
$$

Cohort growth rate (for 3.1):

$$
G^e_{i,t} = \frac{m^e_{i,t+1} - m^e_{i,t}}{\Delta t}
$$

and relative growth rate:

$$
g^e_{i,t} = \frac{m^e_{i,t+1} - m^e_{i,t}}{m^e_{i,t} \cdot \Delta t}
$$

Trophic intake aggregation from interaction records (for 2.7, 2.8, and the intake
term used in 2.5a):

$$
I^e_{c,t} = \sum_{k \in (c,t)} e_k
$$

Per-day intake rate:

$$
\dot{I}^e_{c,t} = \frac{I^e_{c,t}}{\Delta t}
$$

Soil consumption volumetric-to-areal conversion (for 2.6, 2.7):

$$
F^{e,areal}_{c,t} = F^{e,vol}_{c,t} \cdot z_{soil}
$$

with $z_{soil}$ as the active soil depth in metres.

Plant-supported intake ratio for plant-animal productivity linkage (for 2.8):

$$
Q_h = \frac{I^{plant}_h}{NPP_h}
$$

where $I^{plant}_h$ is habitat-level intake from plant-derived resources and $NPP_h$
is habitat-level net primary productivity. Plant ammonium, nitrate, and phosphorus
uptake are already exported as areal daily rates, so no rooting-depth conversion is
required for this comparison.

Occupancy-weighted territory size and resident persistence (for 2.9):

$$
\bar{T}_{g,c,t} = \frac{\sum_{i \in (g,c)}
\left(w_{i,t}\cdot territory\_size_{i,t}\right)}
{\sum_{i \in (g,c)} w_{i,t}}
$$

$$
P^{res}_{g,c,t} = \frac{\sum_{i \in (g,c)}
\mathbf{1}(location\_status_{i,t}=\mathrm{resident})}{n_{g,c,t}}
$$

Nutrient return flux to soil (for 2.6):

$$
NR^e_{c,t} = decomposed\_excrement\_cnp^e_{c,t}
+ decomposed\_carcasses\_cnp^e_{c,t}
+ \frac{herbivory\_waste\_leaf\_cnp^e_{c,t}}{A_c}
$$

Biomass pyramid and herbivore:producer ratio (for 3.6):

$$
B^{C}_{H,c,t} = \sum_{i \in H} N^{eff}_{i,t} \cdot m^C_{i,t}
$$

$$
B^{C}_{P,c,t} = canopy\_foliage\_cnp^{C}_{c,t} + subcanopy\_vegetation\_biomass_{c,t}
$$

$$
R_{H:P,c,t} = \frac{B^{C}_{H,c,t}}{B^{C}_{P,c,t}}
$$

Allometric density scaling regression (for 3.5):

$$
\log D_{g,c,t} = \alpha + \beta \log \bar{M}_{g,c,t} + \varepsilon
$$

where $\bar{M}_{g,c,t}$ can be represented by mean largest_mass_achieved or mean
carbon mass per individual in group $g$.

## 6. Notes on references and implementation boundaries

1. Non-Madingley targets should prioritise SAFE-linked empirical references during
  implementation, with target-specific citations added as the validation database
  is populated.
2. Madingley-style emergent checks should use Harfoot et al. (2014) as the core
  pattern-validation anchor.
3. All calculations in this plan are post-processing targets and should be
  implemented without changing ecological process code unless a required output is
  unavailable.
4. Defer validation of reproduction, survival and mortality rates as we do not have
detailed demographic models at the moment. Maybe possible with advanced statistical
models such as the Cormack-Jolly-Seber (CJS) model.
5. Defer validation of activity-window and respiration as there is no data, and they
can be circular.
TODO: confirm whether we would use camera trap data to be used for diel activity estimate
in functional group parameter.
