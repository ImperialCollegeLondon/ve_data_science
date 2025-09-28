#| ---
#| title: Calculate the C:N and C:P ratios of fungal fruiting body (sporocarp)
#|
#| description: |
#|     This R script converts the C:N:P molar stoichiometry from a meta-analysis
#|     to mass stoichiometry. I am not doing any analysis and will simply rely
#|     on the estimated median values from the study.
#|
#| virtual_ecosystem_module: Soil
#|
#| author:
#|   - Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|
#| output_files:
#|
#| package_dependencies:
#|     - biogas
#|
#| usage_notes: |
#|   This is a global meta-analysis that should suffice at this stage. In the
#|   future we should also check a slightly newer study (but on saprotrophic and
#|   ectomycorrhizal fungi only): https://doi.org/10.1111/nph.15380.
#| ---

library(biogas)

# https://doi.org/10.3389/fmicb.2017.01281
# Median C:N:P stoichiometry for fungi was 250:16:1 (molar)
# convert molar to mass ratios
CN_ratio <- 250 * molMass("C") / 16 * molMass("N")
CP_ratio <- 250 * molMass("C") / 1 * molMass("P")
