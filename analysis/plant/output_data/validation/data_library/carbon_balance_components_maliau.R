#| ---
#| title: carbon_balance_components_maliau
#|
#| description: |
#|   This script prepares and cleans the primary SAFE carbon balance
#|   components dataset (SAFE_CarbonBalanceComponents.xlsx) for the Maliau
#|   Basin old-growth forest plots MLA-01 (Belian) and MLA-02 (Seraya).
#|   It filters for these two plots and selects variables relevant for
#|   Virtual Ecosystem plant module output comparison (biomass carbon
#|   stocks, primary productivity components, autotrophic respiration, and
#|   observational standard errors), exporting the curated data to CSV.
#|
#| virtual_ecosystem_module:
#|   - Plant
#|
#| author:
#|   - Arne Scheire
#|
#| status: final
#|
#| input_files:
#|   - name: SAFE_CarbonBalanceComponents.xlsx
#|     path: data/primary/plant/carbon_balance_components
#|     description: |
#|       https://doi.org/10.5281/zenodo.7307449
#|       Riutta et al. (2021)
#|       Components of the complete carbon budget for SAFE intensive carbon
#|       plots. Measured components of total carbon budget across 1-ha plots,
#|       including productivity, respiration, and biomass carbon stocks.
#|
#| output_files:
#|   - name: carbon_balance_components_maliau.csv
#|     path: data/derived/plant/output_data/validation/data_library
#|     description: |
#|       Cleaned and filtered carbon balance components for Maliau old-growth
#|       plots MLA-01 (Belian) and MLA-02 (Seraya), subset to variables
#|       relevant for Virtual Ecosystem plant output validation.
#|     variables:
#|       - name: ForestType
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Old-growth or Logged
#|         method: null
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SAFEPlotName
#|         type: character
#|         units: dimensionless
#|         description: |
#|           SAFE plot name, as in the SAFE Gazetteer
#|         method: null
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: PlotName
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Plot name (used in field work)
#|         method: null
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: ForestPlotsCode
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Plot code, as in the ForestPlots database (this should be used in publications, instead of plot name)
#|         method: null
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: WoodyNPP_Stem
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Woody stem productivity (subcomponent of woody net primary productivity)
#|         method: |
#|           Estimated from repeated tree censuses and allometric equations
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_WoodyNPP_Stem
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Standard error of woody stem productivity
#|         method: |
#|           Standard error  across the 25 subplots within each plot
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: WoodyNPP_CoarseRoot
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Coarse root productivity (subcomponent of woody net primary productivity)
#|         method: |
#|           Estimated from repeated tree censuses and allometric equations
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_WoodyNPP_CoarseRoot
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Standard error of coarse root productivity
#|         method: |
#|           Standard error  across the 25 subplots within each plot
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: WoodyNPP_BranchTurnover
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Branch turnover productivity (subcomponent of woody net primary productivity)
#|         method: |
#|           All branches collected from four 100 m x 1 m transects along the plot boundaries (LAM-06 and LAM-07 plots); All branches collected from permanent quadrats of 2 m x 2 n, n=25 per plot (other plots). Collection every three months.
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_WoodyNPP_BranchTurnover
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Standard error of branch turnover productivity
#|         method: |
#|           Standard error across the four branchfall replicates within each plot
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: WoodyNPP_Total
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Total woody net primary producivity
#|         method: |
#|           Total woody net primary productivity is calculated as the sum of woody stem productivity, coarse root productivity and branch turnover productivity
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_WoodyNPP_Total
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Standard error of total woody net primary producivity
#|         method: |
#|           Propagated of standard error of the individually measured components of woody NPP
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: CanopyNPP_Leaf
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Leaf productivity (subcomponent of canopy net primary productivity)
#|         method: |
#|           Littertraps (0.5 m x 0.5 m), n=25 per plot, collected every 14 days
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_CanopyNPP_Leaf
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Standard error of leaf productivity
#|         method: |
#|           Standard error  across the 25 littertraps within each plot
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: CanopyNPP_Twig
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Twig productivity (subcomponent of canopy net primary productivity)
#|         method: |
#|           Littertraps (0.5 m x 0.5 m), n=25 per plot, collected every 14 days
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_CanopyNPP_Twig
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Standard error of twig productivity
#|         method: |
#|           Standard error  across the 25 littertraps within each plot
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: CanopyNPP_Reproductive
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Reproductive productivity, i.e. fruit, seed and flowers (subcomponent of canopy net primary productivity)
#|         method: |
#|           Littertraps (0.5 m x 0.5 m), n=25 per plot, collected every 14 days
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_CanopyNPP_Reproductive
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Standard error of reproductive productivity, i.e. fruit, seed and flowers
#|         method: |
#|           Standard error  across the 25 littertraps within each plot
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: CanopyNPP_Miscellaneous
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Unidentified canopy debris (subcomponent of canopy net primary productivity)
#|         method: |
#|           Littertraps (0.5 m x 0.5 m), n=25 per plot, collected every 14 days
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_CanopyNPP_Miscellaneous
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Standard error of unidentified canopy debris
#|         method: |
#|           Standard error  across the 25 littertraps within each plot
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: CanopyNPP_Herbivory
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Leaf productivity lost to herbivory (subcomponent of canopy net primary productivity)
#|         method: |
#|           Herbivory estimates from scanned leaves from litterfall traps
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_CanopyNPP_Herbivory
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Standard error of leaf productivity lost to herbivory
#|         method: |
#|           Propagated standard error of leaf productivity and herbivory rate
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: CanopyNPP_Total
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Total canopy net primary producivty
#|         method: |
#|           Total canopy net primary producivty is sum of canopy NPP components, including leaf, twig, reproductive,  miscellaneous and herbivory
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_CanopyNPP_Total
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Standard error of total canopy net primary producivty
#|         method: |
#|           Propagated standard error of the individually measured components of canopy NPP
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: FineRootNPP
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Fine root productivity
#|         method: |
#|           Estimated using root ingrowth cores, n=9 in LAM-06 and LAM-07 plots, n=16 in other plots, collected every three months
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_FineRootNPP
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Standard error of fine root productivity
#|         method: |
#|           Standard error across ingrowth cores (n=9 in LAM-06 and LAM-07; n=16 in other plots) within each plot
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: TotalNPP_WithoutMycorrhiza
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Total net primary productivity without mycorrhiza
#|         method: |
#|           Total net primary productivity without including mycorrhiza is the sum of total woody NPP, total canopy NPP and fine root NPP
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_TotalNPP_WithoutMycorrhiza
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Standard error of total net primary productivity without mycorrhiza
#|         method: |
#|           Propagated of standard error of the individually measured components of woody, canopy and fine root NPP
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: TotalNPP_WithMycorrhiza
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Total net primary productivity including mycorrhiza
#|         method: |
#|           Total net primary productivity without including mycorrhiza is the sum of total woody NPP, total canopy NPP, fine root NPP and mycorrhizal respiration (assumed to be equal to NPP allocated to mycorrhiza)
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_TotalNPP_WithMycorrhiza
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Standard error of total net primary productivity including mycorrhiza
#|         method: |
#|           Propagated of standard error of the individually measured components of woody, canopy and fine root NPP, and mycorrhizal respiration (assumed to be equal to NPP allocated to mycorrhiza)
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: GPP_WithoutMycorrhiza
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Gross primary productivity without mycorrhiza
#|         method: |
#|           Gross primary productivity without including mycorrhiza is the sum of autotrophic respiration and total net primary productivity without mycorrhiza respiration
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_GPP_WithoutMycorrhiza
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Standard error of gross primary productivity without mycorrhiza
#|         method: |
#|           Propagated of standard error of NPP and autotrophic respiration
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: GPP_WithMycorrhiza
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Gross primary productivity  including mycorrhiza
#|         method: |
#|           Gross primary productivity  including mycorrhiza is the sum of autotrophic respiration, total net primary productivity and mycorrhiza respiration
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_GPP_WithMycorrhiza
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Standard error of gross primary productivity  including mycorrhiza
#|         method: |
#|           Propagated of standard error of NPP and autotrophic respiration
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: R_Stem
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Respiration from woody stems
#|         method: |
#|           Respiration from living stems was measured using static chamber technique from 40 - 50 trees per plot, evenly distributed around the plot. Estimates are scaled to the surface area of the 1-ha plot by estimating the total stem surface area using tree census data and allometric equations
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_R_Stem
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Standard error of respiration from woody stems
#|         method: |
#|           Propagated standard error of tree-level stem respiration (n=40 to 50 per plot) and stem area index estimate
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: R_Leaf
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Leaf Respiration
#|         method: |
#|           Measured during one campaign within each plot. If both shaded and fully lit branches were available, both were sampled. Leaf-level measurements were scaled to plot level. Mean dark respiration of sun and shade leaves were multiplied by their estimated fractions in each plot and then multiplied by the leaf area index of the plot. An inhibition correction factor of 0.67 for the daytime hours was used to account for the daytime light inhibition of leaf dark respiration
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_R_Leaf
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Standard error of leaf Respiration
#|         method: |
#|           Propagaged standard error of respiration of sun leaves (n= 9 to 52 trees per plot) and shade leaves (n= 9 to 23 trees per plot) and leaf area index estimates (n=9 in LAM-06 and LAM-07 plots, n=16 in other plots)
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: R_FineRoots
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Respiration from fine roots
#|         method: |
#|           Partioned respiration experiment, comparison of collars with and without roots, not corrected for root turnover (see Riutta et al. 2021 GCB for details)
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_R_FineRoots
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Standard error of respiration from fine roots
#|         method: |
#|           Propagated standard error of total soil respiration estimates (n=25 per plot) and proportion of root respiration (n=4 per plot)
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: R_CoarseRoots
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Respiration from coarse roots
#|         method: |
#|           Estimated by multiplying stem respiration by the average belowground to aboveground biomass ratio, 0.26 for logged plots and 0.24 for old-growth plots (Malhi et al. 2014 Plant Ecology and Diversity)
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_R_CoarseRoots
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Standard error of respiration from coarse roots
#|         method: |
#|           Propagated standard error of stem respiration and belowground to aboveground biomass ratio
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: R_auto
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Total autotrophic respiration
#|         method: |
#|           Autotrophic respiration is the sum off respiration from woody stems, leaves, fine roots and coarse roots
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_R_auto
#|         type: numeric
#|         units: MgCha-1year-1
#|         description: |
#|           Standard error of total autotrophic respiration
#|         method: |
#|           Propagated standard error of the individually measured components of autotrophic respiration
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: AbovegroundBiomassCarbonStock
#|         type: numeric
#|         units: MgCha-1
#|         description: |
#|           Plot above-ground biomass carbon stock
#|         method: |
#|           Estimated from repeated tree censuses and allometric equations
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_AbovegroundBiomassCarbonStock
#|         type: numeric
#|         units: MgCha-1
#|         description: |
#|           Standard error of plot above-ground biomass carbon stock
#|         method: |
#|           Standard error across the 25 subplots of each plot
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: CoarseRootBiomassCarbonStock
#|         type: numeric
#|         units: MgCha-1
#|         description: |
#|           Biomass carbon stock of coarse roots
#|         method: |
#|           Estimated from repeat census and allometric equation based on tree diameter
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|       - name: SE_CoarseRootBiomassCarbonStock
#|         type: numeric
#|         units: MgCha-1
#|         description: |
#|           Standard error of biomass carbon stock of coarse roots
#|         method: |
#|           Standard error across the 25 subplots of each plot
#|         references:
#|           - citation: "Riutta et al. (2021)"
#|             doi: "https://doi.org/10.5281/zenodo.7307449"
#|             url: "https://zenodo.org/records/7307449"
#|             origin: "Maliau Basin, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "old-growth"
#|             date: "2011-2018"
#|
#| package_dependencies:
#|   - readxl
#|
#| usage_notes: |
#|   Run this script to generate or update the plant validation dataset for
#|   Maliau carbon balance components. The generated CSV is used for
#|   comparing Virtual Ecosystem plant outputs against field observations.
#|
#|   Design decisions:
#|   - Retaining individual plots: Both MLA-01 (Belian) and MLA-02 (Seraya) are
#|     kept as separate observations so that plot-level variation and
#|     standard errors are preserved. Any averaging across plots or comparison
#|     with grid-cell spatial means should be performed downstream during the
#|     validation analysis step.
#|   - Unit documentation: Measurement units (e.g. Mg C ha^-1 year^-1 for fluxes
#|     and Mg C ha^-1 for stocks) are maintained in the metadata rather than as
#|     text rows in the CSV, keeping all tabular data strictly numeric for
#|     downstream computation.
#| ---

# Load required packages
library(readxl)

# Input file path
input_file <- "../../../../../data/primary/plant/carbon_balance_components/SAFE_CarbonBalanceComponents.xlsx"

# Load raw Excel data (skipping the first 5 metadata rows)
raw_data <- readxl::read_excel(
  path = input_file,
  sheet = "Data",
  skip = 5
)

# Filter for Maliau old-growth plots (MLA-01 and MLA-02)
maliau_plots <- c("MLA-01", "MLA-02")
maliau_data <- raw_data[raw_data$ForestPlotsCode %in% maliau_plots, ]

# Select relevant variables for Virtual Ecosystem plant output validation
# Ordered following original file structure with standard error (SE) paired after each variable
plant_variables <- c(
  "ForestType",
  "SAFEPlotName",
  "PlotName",
  "ForestPlotsCode",
  "WoodyNPP_Stem",
  "SE_WoodyNPP_Stem",
  "WoodyNPP_CoarseRoot",
  "SE_WoodyNPP_CoarseRoot",
  "WoodyNPP_BranchTurnover",
  "SE_WoodyNPP_BranchTurnover",
  "WoodyNPP_Total",
  "SE_WoodyNPP_Total",
  "CanopyNPP_Leaf",
  "SE_CanopyNPP_Leaf",
  "CanopyNPP_Twig",
  "SE_CanopyNPP_Twig",
  "CanopyNPP_Reproductive",
  "SE_CanopyNPP_Reproductive",
  "CanopyNPP_Miscellaneous",
  "SE_CanopyNPP_Miscellaneous",
  "CanopyNPP_Herbivory",
  "SE_CanopyNPP_Herbivory",
  "CanopyNPP_Total",
  "SE_CanopyNPP_Total",
  "FineRootNPP",
  "SE_FineRootNPP",
  "TotalNPP_WithoutMycorrhiza",
  "SE_TotalNPP_WithoutMycorrhiza",
  "TotalNPP_WithMycorrhiza",
  "SE_TotalNPP_WithMycorrhiza",
  "GPP_WithoutMycorrhiza",
  "SE_GPP_WithoutMycorrhiza",
  "GPP_WithMycorrhiza",
  "SE_GPP_WithMycorrhiza",
  "R_Stem",
  "SE_R_Stem",
  "R_Leaf",
  "SE_R_Leaf",
  "R_FineRoots",
  "SE_R_FineRoots",
  "R_CoarseRoots",
  "SE_R_CoarseRoots",
  "R_auto",
  "SE_R_auto",
  "AbovegroundBiomassCarbonStock",
  "SE_AbovegroundBiomassCarbonStock",
  "CoarseRootBiomassCarbonStock",
  "SE_CoarseRootBiomassCarbonStock"
)

cleaned_data <- maliau_data[, plant_variables]

# Output directory and file path
output_dir <- "../../../../../data/derived/plant/output_data/validation/data_library"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_file <- file.path(output_dir, "carbon_balance_components_maliau.csv")

# Write cleaned CSV file
write.csv(cleaned_data, output_file, row.names = FALSE)
