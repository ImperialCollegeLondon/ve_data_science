# Thresholds vs ecological realism: Animal functional group

## Purpose of this page

As we move from Level 1 to Level 5, FG classification becomes more complex, and there are questions that do not always have clear answers. Some criteria are not well defined or documented, while others require assumptions or simplifications because of how the model currently works. I want to be able to capture the mental map including the gaps, limitations, uncertainties, and assumptions along the way.

Not everything here is necessarily a problem or something that needs fixing. Some may become GitHub issues, some might end up as broader discussion while others are simply analytical decisions, model simplifications, or notes for future reference.

The idea is to keep these discussions and decisions in one place, so we can refer back to them, revisit them when needed, and use agreed decisions to update the FG documentation and module documentation templates. Most importantly, I want to make sure the reasoning behind our choices is not lost over time, and that others can understand why certain decisions were made, even years from now.

Decisions are summarised in the [decision log](#decision-log) at the end. Agreed
criteria should also be added to the VE
[functional group data](https://virtual-ecosystem.readthedocs.io/en/latest/using_the_ve/model_details/animal/functional_group_data.html)
documentation and to
[ve_data_science#718](https://github.com/ImperialCollegeLondon/ve_data_science/issues/718).

Topics:

1. [Vertical strata](#1-vertical-strata)
2. [Habitat ("terrestrial")](#2-habitat-terrestrial)
3. [Diet tags](#3-diet-tags)
4. [Development type](#4-development-type-direct-vs-indirect)
5. [Birth mass](#5-birth-mass)
6. [Body size](#6-body-size)
7. [Adult mass](#7-adult-mass)

## 1. Vertical strata

### What the model does

Currently, VE has three strata, `soil`, `ground` and `canopy` (in `animal_traits.py`), which FGs can combine (e.g. `ground_canopy`, or all three as `soil_ground_canopy`). The
strata are not defined in writing, but the code defines them implicitly. Each
stratum is linked to a climate layer (`get_stratum_climate()` in
`animal_cohorts.py`), and food pool is assigned to a stratum.

A stratum gives an FG three things: access to the food in that stratum, exposure to
predators in that stratum, and that stratum's temperature. An FG can eat from a pool
or prey on another FG if they share any stratum. There is no splitting, an FG in
`ground_canopy` can eat everything on the ground and everything in the canopy, as if
it were in both all the time. Only temperature is averaged across strata.

Carcasses and dung are handled differently. There's currently no stratum check for either, and both are treated as ground-level resources.
([virtual_ecosystem#1952](https://github.com/ImperialCollegeLondon/virtual_ecosystem/issues/1952)).

### Approach for Level 5

These are the rules we've been using so far to assign strata, especially in Level 5. They're
based on what we know about the representative and on how the VE handles strata and food
pools at the time of writing. Still provisional, and open to change.

* **How we pick strata:** We go by where the animal is documented feeding and
  regularly active mostly (evidence-based), not one-off sightings. In the VE, the stratum decides what an FG can eat, what can eat it, and what temperature it experiences, so that's what we're trying to capture. Where there isn't much evidence, the uncertainty needs to be recorded. We haven't set a frequency threshold, because we don't have behavioural data for every species and it is more complicated trying to map it to FG.
* **Leaf-litter and soil invertebrates:** FGs that feed on leaf litter include `ground`, because fallen leaves end up in the above-ground litter pools, which are `ground`. FGs that feed in the soil are classified as `soil`. They eat root litter and soil resources (POM, bacteria and fungi), but not leaf litter.
* **Understorey species:** `ground`, if they feed on subcanopy plants, since the VE
  puts those at ground level. If a species clearly feeds or spend considerable time (again, evidence-based) both on the ground and in the canopy, we'd go with `ground_canopy`. That gives it full access to both stratum.
* **Dung feeders:** `ground` layer as there's only one dung pool per grid cell and
  it's on the ground. Jacob's view is that canopy dung should be treated as ending
  up on the ground (virtual_ecosystem#1952). This means the arboreal dung
  beetles (Davis et al., 1997) aren't represented. We've noted that as a limitation.

### Open questions

1. Where does animal use of the canopy begin? This isn’t documented anywhere. Does any tree-associated use (saplings, lower trunks, mid-storey) count as canopy? I also cannot find any height bands for canopy.
2. Choosing stratum: nesting versus foraging activity. For a context, ants nest in soil or litter, forage on the ground and climb to collect honeydew-producing insects. How should we define this, as ground_canopy (where they feed) or soil_ground_canopy (where they live)? Adding soil would let them feed on soil resources, make them available to soil predators, and pull their climate towards topsoil temperature. This affects FG like, Omnivorous_arboreal_ants.
3. FG that use a stratum only temporarily or seasonally:
   (e.g. canopy frogs moving lower to breed or semi-arboreal mammals or cicada), which is essential to an animal's life cycle without being a major part of where it spends its time. Listing only the main stratum ignores the temporary but critical use, but listing every stratum gives full access (resources pool, predation exposure, prey access) to all of them. Another limitation that should be recorded?

## 2. Habitat ("terrestrial")

### What the model does

The VE has no habitat trait. "Terrestrial" appears in only two places:

* `reproductive_environment` (`terrestrial` or `aquatic`), which describes where
  offspring start life, not where adults live;
* the ectotherm temperature-tolerance constants (`m_tol`, `c_tol` in
  `model_config.py`), which are terrestrial values from Madingley applied to all
  ectothermic FGs.

### Approach for Level 5

Some Level 5 FG names include "terrestrial" or "arboreal" (e.g.
`herbivorous_terrestrial_small_mammal`, "Omnivorous arboreal/terrestrial small
mammal"). These words are labels only and have no effect in the model but then overlap
with `vertical_occupancy`.

### Open questions

1. Should "terrestrial" and "arboreal" be removed from FG names, given that strata
   are already captured by `vertical_occupancy`?
2. If they are kept, what do they mean, and how do they relate to the strata?

## 3. Diet tags

### What the model does

Diet tags are defined in `DietType` in `animal_traits.py`. A tag works as a switch:
if an FG has it, the matching food becomes part of its regular diet. There is no way
to mark a food as occasional.

Further points matter when choosing tags:

* **Foraging time is split by the number of diet tags.** Each tag (e.g. `foliage`,
  `fruit`, `seeds`) counts separately, so adding a tag reduces the time spent on
  every other food type (`forage_cohort()` in `animal_cohorts.py`).
* **Prey choice depends on body mass.** With `vertebrates` or `invertebrates`, every
  FG of that type in a shared stratum is eligible prey, within a fixed mass window of
  0.1 g to 1,000 kg (`prey_group_selection()` in `scaling_functions.py`).

### Approach for Level 5

No decisions have been made yet. Few issues have come up as stated below.

**Some foods do not fit the current tags:**

* plant sap (phloem or xylem), e.g. cicadas, planthoppers, aphids and scale insects;
* honeydew, e.g. ants, some butterflies and wasps;
* plant gum and exudates, e.g. the slow loris.

**Some foods have no resource pools:**
* `nectar`, `flowers`, `wood` and `algae` are
valid diet tags, but the VE has no food pool for them. Several FGs that rely only on these (e.g. bees, adult butterflies, cicada nymphs) are expected to starve in FG level 5.

**Occasional feeding becomes regular feeding.** For example:

* An Asian forest tortoise (\~10 kg, ground) mostly eats plants but opportunistically eats carrion (evidence-based). Adding `carcasses` makes it scavenge every time step, competing with true scavengers, and reduces its time for plant foraging.
* If the same tortoise were given `vertebrates`, its capture success would be highest for prey of about 2.6 kg, so the lesser mouse deer (\~2 kg) would be among
  its most likely prey, more than a rat (\~0.2 kg) and neither is realistic.
* Meanwhile, having `invertebrates` in the diet tags, means that it can't realistically catch any prey on ground (ideal prey is around 2.6 kg, based on capture success) as our largest invertebrate is around 8g.

### Open questions

1. Should sap, honeydew and gum be mapped to existing tags (e.g. sap to foliage, honeydew to nectar)? If so, which mapping, and where should it be recorded?
2. Where do we draw the line between occasional and regular food? Should minor foods be left out, or kept, or recorded as a limitation?

## 4. Development type (direct vs indirect)

### What the model does

Indirect developers produce offspring of a separate larval FG, which feeds and
grows on its own before turning into the adult FG. Direct developers produce
offspring of the same FG. FGs with `reproductive_environment = aquatic` send new
offspring away from the active community for a set time before they join it. Note: The time away and the mortality on return are currently toy values.

### Approach for Level 5

*Current implementation:* some FGs that develop indirectly in reality are entered as direct
developers (`development_type = direct`, offspring = self):

* **Aquatic-juvenile FGs** (frogs and toads, dragonflies, mosquitoes): their larvae
  live in water, but VE has no aquatic habitat. A separate larval FG (imagine a tadpole) would have to be placed in soil, ground or canopy and given a terrestrial diet, which would be ecologically wrong.
* **Social insects** (ants, termites, bees and hornets): brood develop inside the
  colony and are fed by workers, so they do not forage independently. A separate
  larval FG would misrepresent this.
  Hence, `direct` for both cases.

This keeps these FGs ecologically sensible within what the VE can represent. The
trade-off is that their larval stages are not part of the food web, as either
consumers or prey.

### Open questions

1. Does the team agree with this approach?
2. Should it be recorded as a known limitation in the VE functional group data
   documentation, so future users understand why these FGs are coded as direct?

## 5. Birth mass

### What the model does

`birth_mass` is the mass at which a new cohort enters the simulation.

### Approach for Level 5

*Decided:* for bird FGs, `birth_mass` is hatchling (chick) mass, not egg mass.

Values were taken from empirical datasets that matches species present in Maliau, and if its not available, we derived it based on the most direct source available, in this order:

1. **Species value from a trait database.** For mammals: neonate body mass from
   PanTHERIA (Jones et al. 2009) or birth weight from the Amniote database
   (Myhrvold et al. 2015). For reptiles: hatching weight from the Amniote database.
2. **Close relative (proxy).** Where the species had no value, a congener or sister
   species was used (e.g. *Sus scrofa* for the bearded pig, *Neofelis nebulosa* for
   the Sunda clouded leopard).
3. **Birds.** Hatchling mass = egg mass × the median hatchling-to-egg mass ratio for
   the bird's order. The ratio comes from Amniote database species that report both
   values (e.g. Passeriformes 0.808, n = 220; Accipitriformes 0.663, n = 54). Egg
   mass came from the Amniote database (species or congener) or, where missing, from
   the Aves egg-mass allometry in Hendriks & Mulder (2008, Table 3; from Blueweiss et
   al. 1978).
4. **Allometric equations.** Where no direct value existed, birth mass was
   calculated from adult mass using the taxon-specific equations compiled in
   Hendriks & Mulder (2008, Table 3): Reptilia and Mammalia (from Blueweiss et al.
   1978), Araneomorphae (Marshall & Gittleman 1994) and Diptera (Berrigan 1991).
   *Caveat:* these equations give egg or offspring mass, often with modest fit
   (e.g. Diptera r² = 0.19), and the general equation used for groups without a
   taxon-specific line ("organisms in general") has not yet been found in the paper
   (it is not in Table 3).
5. **Insects: egg mass.** Egg volume from the Church et al. (2019) insect egg
   dataset, taken at the closest taxonomic level available (species → genus → tribe
   → subfamily → family), converted to mass assuming a density of 1 mg mm⁻³.
6. **Amphibians: metamorph mass.** No measured weights exist for newly
  metamorphosed froglets of our species, so we estimated them from body length.
  We used published length–weight relationships for frogs (Santini et al. 2018):
  the toad (Bufonidae) relationship for the toad, and the arboreal frog
  relationship for the arboreal frog. Three cautions apply: (1) the froglet
  lengths we used (9 and 15 mm) are typical values, not yet referenced,
  (2) the relationships were built from adult frogs, and froglets may be shaped
  differently (3) our froglets are smaller than any species in the original
  data, so the estimates go beyond the range the relationships were tested on.
7. **Larval FGs.** For insects with a larval stage, `birth_mass` is the egg mass,
   estimated once for the adult FG and copied to the paired larval FG. Both must be equal because VE counts offspring using the adult's `birth_mass` but creates them at the larva's `birth_mass`.

### Open questions

1. Nick's suggested incorportating this in the model instead of doing it manually or separate script.

## 6. Body size

### What the model does

Size labels (small, medium, large) are not used in VE calculations, which rely on
`adult_mass` and `birth_mass`. However, the labels decide which species are grouped
into each FG, and therefore which representative masses are used.

### Approach for Level 5

Some Level 5 FGs share the same traits but differ by size category, for example:

* `herbivorous_terrestrial_small_mammal`
* `herbivorous_terrestrial_medium_mammal`
* `herbivorous_terrestrial_large_mammal`

No thresholds are documented. so how big is large, how tiny is small mammal? Some cases are clear: the lesser mouse deer (\~2 kg)
is small and the Bornean elephant (\~2,000 kg) is large. Others are not:

| Species | Approximate adult mass | Possible category |
| --- | --- | --- |
| Malayan porcupine | \~15 kg | small or medium? |
| Bearded pig | \~100 kg | medium or large? |
| Sambar deer | \~150–200 kg | medium or large? |

The effect of a borderline choice depends on how the species sets the FG's
representative mass:

### Open questions

1. When should FG be split by size (ie: small, medium, large mammals)?

## 7. Adult mass

### What the model does

The VE has no sexes as input data, so each FG has a single `adult_mass`. A cohort grows from
`birth_mass` until it reaches `adult_mass`, and only then becomes mature and able to
reproduce. A higher `adult_mass` therefore means a longer time growing before the
first breeding.

### Approach for Level 5

`adult_mass` comes from literature review, field guides. Most of the time trait databases (PHYLACINE,
EltonTraits, Amniote), give one value per species without saying
whether it is male or female.  For *V. salvator*, the Amniote value (4.345 kg)
happens to be close to the female mass.

### Open questions

1. For species/group (which represents the FG) with strong sexual size dimorphism (SSD), the value of `adult_mass`
depends on whose mass we use. For example, monitor lizard ie: *Varanus salvator* females average about 4 kg and
males about 10 kg. Using the male value would mean cohorts have to grow to about
2.5 times the mass before they can breed.
In this case, which value should
   `adult_mass` represent: female mass (since females limit reproduction), male mass,
   or the mean of both?

## Decision log

| # | Topic | Item | Status | Notes / depends on |
| --- | --- | --- | --- | --- |
| 1 | Strata | `Omnivorous_arboreal_ants` as `ground_canopy` (nesting + foraging) | Pending | Revise once nesting vs foraging is decided (#9) |
| 2 | Strata | `Omnivorous_terrestrial_beetles` as `soil_ground` (bury dung in soil) | Pending | Revise once nesting vs foraging is decided (#9) |
| 3 | Strata | Level 5 stratum rules: evidence-based choice; leaf-litter feeders `ground`, soil feeders `soil`; understorey `ground` (or `ground_canopy` with evidence); dung feeders `ground` | Needs confirmation | Provisional. Arboreal dung beetles not represented (limitation; virtual_ecosystem#1952) |
| 4 | Development type | Aquatic-juvenile FGs (frogs, toads, dragonflies, mosquitoes) and social insects (ants, termites, bees, hornets) coded as `direct` | Needs confirmation | Also decide whether to record as a known limitation in the VE FG documentation |
| 5 | Birth mass | For birds, `birth_mass` is hatchling mass, not egg mass | Needs confirmation | Marked "Decided" as agreed with Nick.  |
| 6 | Birth mass | Source hierarchy for `birth_mass` (steps 1–7 in section 5) | Needs confirmation | Method currently in use |
| 7 | Birth mass | Larval FG `birth_mass` equals adult FG `birth_mass` (egg mass) | Needs confirmation | Required by how VE creates offspring, may only need recording as a rule |
| 8 | Strata | Where does canopy use begin? | Open | No height bands found in code or docs |
| 9 | Strata | Nesting vs foraging: which one determines stratum? | Open | Blocks #1 and #2 |
| 10 | Strata | Temporary or seasonal stratum use that critical for life cycle: include, or main stratum only and record limitation? | Open | e.g. canopy frogs breeding lower, cicadas, semi-arboreal mammals |
| 11 | Habitat | Remove "terrestrial"/"arboreal" from FG names? | Open | Labels have no model effect and seems to overlap with `vertical_occupancy` |
| 12 | Diet | Map sap, honeydew and gum to existing tags? Which mapping, recorded where? | Open | |
| 13 | Diet | Line between occasional and regular food: leave out, keep, or record as limitation? | Open | Potential limitation |
| 14 | Diet | FGs relying only on `nectar`, `flowers`, `wood` or `algae` (no food pool) are expected to starve | Open | e.g. bees, adult butterflies, cicada nymphs  in level 5. Pending |
| 15 | Birth mass | Calculate `birth_mass` within the model rather than in a separate script | Open | Nick's suggestion |
| 16 | Birth mass | Froglet lengths (9 and 15 mm) pending reference | Open | Currently "normal-range" values |
| 17 | Body size | When should an FG be split by size, and what thresholds should be used? | Open | Borderline cases: Malayan porcupine, banteng, sambar deer |
| 18 | Adult mass | Strong sexual size dimorphism: female, male or mean mass? | Open | e.g. *Varanus salvator* (~4 kg female, ~10 kg male) |
