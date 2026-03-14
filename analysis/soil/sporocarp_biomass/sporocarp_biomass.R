#| ---
#| title: Very crude estimation of fungal fruiting body (sporocarp) biomass
#|
#| description: |
#|     This is a very crude estimation of sporocarp biomass for the
#|     initialisation of Maliau scenario. It had been extremely hard to find
#|     reliable value from tropical forests, so I had to rely on a
#|     Mediterranean study(!) by Alday et al. (2017) DOI: 10.1038/srep45824
#|     The author did not share data, and their main figure was hard to extract
#|     data from (data point obscured by regression lines). I took the reported
#|     maximum biomass in the main text; I think using the max value from a
#|     Mediterranean study is justifiable for our tropical rainforest scenario
#|     because the former has a much drier climate than the latter, so I assume
#|     that their maximum is a reasonable guess for our mean.
#|
#| virtual_ecosystem_module:
#|   - Soil
#|
#| author:
#|   - Hao Ran Lai
#|
#| status: wip
#|
#| input_files:
#|
#| output_files:
#|
#| package_dependencies:
#|
#| usage_notes: |
#|     Sporocarp biomass in tropical forest will likely be hard to find until
#|     someone publish in the area.
#| ---

# Maximum sporocarp biomass from a Mediterranean study (Alday et al. 2017)
# https://doi.org/10.1038/srep45824
# unit is kg ha^-1
sporocarp_biomass_mean <- 255

# convert unit to kg m^-2
# = 0.0255 kg m^-2
sporocarp_biomass_mean <- sporocarp_biomass_mean / 1e4

# standard error to simulate spatial variation across Maliau grids
sporocarp_biomass_sd <- 35 / 1e4
