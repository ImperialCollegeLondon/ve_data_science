#| ---
#| title: plant_pft_definitions_maliau_2
#|
#| description: |
#|     Builds the plant functional type definition table for the Maliau 2
#|     scenario by combining the T model parameters with stoichiometric and
#|     reproductive allocation values.
#|
#| virtual_ecosystem_module:
#|   - Plants
#|
#| author:
#|   - Arne Scheire
#|
#| status: final
#|
#| input_files:
#|   - name: stoichiometry_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       This CSV file contains PFT-level stoichiometric ratios and lignin
#|       fractions for plant biomass pools, including sapwood, foliage,
#|       senesced leaves, reproductive tissue, fruits, flowers, and fine roots.
#|       Where PFT-specific measurements are unavailable, literature-derived
#|       proxy values are used.
#|   - name: t_model_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       A CSV file listing T-model parameters by pft.
#|   - name: reproduction_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       This CSV file contains a summary of the ratios needed to calculate
#|       reproductive tissue allocation, and to separate propagules from
#|       non-propagules.
#|   - name: subcanopy_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       This CSV file contains the subcanopy parameters used as plant model
#|       constants in the plant input data library workflow.
#|
#| output_files:
#|   - name: plant_pft_definitions_maliau_2.csv
#|     path: data/derived/plant/input_data/scenarios/maliau_2
#|     description: |
#|       Plant functional type definition table for the Maliau 2 scenario.
#|       This scenario-specific table is assembled from the canonical Maliau
#|       library inputs in t_model_maliau.csv and stoichiometry_maliau.csv,
#|       with the reproductive allocation value extracted from
#|       reproduction_maliau.csv.
#|     variables:
#|       - name: pft_name
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Plant functional type name.
#|         references:
#|           - citation: "pfts_maliau.csv"
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: |
#|           Loaded from t_model_maliau.csv. Original assumption: PFT names are
#|           inherited from pfts_maliau.csv and identify the plant functional
#|           type associated with each output record.
#|       - name: h_max
#|         type: numeric
#|         units: m
#|         description: |
#|           Asymptotic maximum tree height.
#|         references:
#|           - citation: "Svátek et al. (2025)"
#|             doi: "https://doi.org/10.5281/zenodo.14882506"
#|             url: "https://zenodo.org/records/14882506"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: "Loaded from t_model_maliau.csv. Original assumption: Estimated by fitting an asymptotic height-diameter model to SAFE census trees within each PFT, using 2011 data across all plots."
#|       - name: a_hd
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Initial slope parameter of the height-diameter relationship.
#|         references:
#|           - citation: "Svátek et al. (2025)"
#|             doi: "https://doi.org/10.5281/zenodo.14882506"
#|             url: "https://zenodo.org/records/14882506"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: "Loaded from t_model_maliau.csv. Original assumption: Estimated by fitting an asymptotic height-diameter model to SAFE census trees within each PFT, using 2011 data across all plots."
#|       - name: ca_ratio
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Initial ratio of crown area to stem cross-sectional area.
#|         references:
#|           - citation: "Svátek et al. (2025)"
#|             doi: "https://doi.org/10.5281/zenodo.14882506"
#|             url: "https://zenodo.org/records/14882506"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: "Loaded from t_model_maliau.csv. Original assumption: Estimated by fitting crown projected area relationships for each PFT, using 2011 data across all plots."
#|       - name: rho_s
#|         type: numeric
#|         units: kg C m-3
#|         description: |
#|           Sapwood density expressed as carbon mass per unit volume.
#|         references:
#|           - citation: "Both et al. (2019)"
#|             doi: "https://doi.org/10.5281/zenodo.3247631"
#|             url: "https://zenodo.org/records/3247631"
#|             origin: "SAFE Project and Danum Valley Conservation Area, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2014-2018"
#|           - citation: "Inagawa et al. (2023)"
#|             doi: "https://doi.org/10.5281/zenodo.8158811"
#|             url: "https://zenodo.org/records/8158811"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "mixed dipterocarp lowland rainforest"
#|             site_condition: "logged"
#|             date: "2014-2015"
#|         assumptions: "Loaded from t_model_maliau.csv. Original assumption: Mean sapwood density without bark converted to carbon density using mean sapwood carbon content."
#|       - name: sla
#|         type: numeric
#|         units: mm2 mg-1 C
#|         description: |
#|           Specific leaf area expressed per unit carbon mass.
#|         references:
#|           - citation: "Both et al. (2019)"
#|             doi: "https://doi.org/10.5281/zenodo.3247631"
#|             url: "https://zenodo.org/records/3247631"
#|             origin: "SAFE Project and Danum Valley Conservation Area, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2014-2018"
#|         assumptions: "Loaded from t_model_maliau.csv. Original assumption: Specific leaf area is averaged by PFT from the functional-traits data and expressed per unit carbon mass."
#|       - name: lai
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Leaf area index.
#|         references:
#|           - citation: "Pfeifer et al. (2016)"
#|             doi: "https://doi.org/10.1016/j.rse.2016.01.014"
#|             url: "https://www.sciencedirect.com/science/article/pii/S003442571630013X?via%3Dihub"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland dipterocarp forest"
#|             site_condition: "primary and secondary"
#|             date: "2012-2013"
#|         assumptions: "Loaded from t_model_maliau.csv. Original assumption: A single primary-forest value is applied uniformly across PFTs."
#|       - name: par_ext
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Light extinction coefficient describing the attenuation of
#|           photosynthetically active radiation through the canopy.
#|         references:
#|           - citation: "White et al. (2000)"
#|             doi: "https://doi.org/10.1175/1087-3562(2000)004%3C0003:PASAOT%3E2.0.CO;2"
#|             url: "https://journals.ametsoc.org/view/journals/eint/4/3/1087-3562_2000_004_0003_pasaot_2.0.co_2.xml"
#|             origin: null
#|             biome: null
#|             vegetation_type: "rain forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Loaded from t_model_maliau.csv. Original assumption: The value reported for rain forest is applied uniformly across PFTs."
#|       - name: tau_f
#|         type: numeric
#|         units: years
#|         description: |
#|           Leaf turnover time.
#|         references:
#|           - citation: "Anderson et al. (1983)"
#|             doi: "https://doi.org/10.2307/2259731"
#|             url: "https://www.jstor.org/stable/2259731?origin=crossref"
#|             origin: "Gunung Mulu National Park, Sarawak, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: "primary"
#|             date: "1978"
#|         assumptions: "Loaded from t_model_maliau.csv. Original assumption: Derived as the inverse of reported annual leaf turnover and applied uniformly across pfts."
#|       - name: tau_rt
#|         type: numeric
#|         units: years
#|         description: |
#|           Turnover time of reproductive tissue.
#|         references:
#|           - citation: "Anderson et al. (1983)"
#|             doi: "https://doi.org/10.2307/2259731"
#|             url: "https://www.jstor.org/stable/2259731?origin=crossref"
#|             origin: "Gunung Mulu National Park, Sarawak, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: "primary"
#|             date: "1978"
#|         assumptions: |
#|           Loaded from t_model_maliau.csv. Original assumption: Derived as the
#|           inverse of the reported annual reproductive-organ turnover and
#|           applied uniformly across PFTs using the same source and approach as
#|           leaf turnover.
#|       - name: tau_b
#|         type: numeric
#|         units: years
#|         description: |
#|           Branch turnover time.
#|         references:
#|           - citation: "Anderson et al. (1983)"
#|             doi: "https://doi.org/10.2307/2259731"
#|             url: "https://www.jstor.org/stable/2259731?origin=crossref"
#|             origin: "Gunung Mulu National Park, Sarawak, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: "primary"
#|             date: "1978"
#|         assumptions: |
#|           Loaded from t_model_maliau.csv. Original assumption: Calculated from
#|           Anderson et al. small wood (<2 cm diameter) and large wood (2-10 cm
#|           diameter) input and standing crop values for dipterocarp forest. The
#|           combined turnover rate is total branch input divided by total branch
#|           standing crop, then inverted to turnover time and applied uniformly
#|           across PFTs.
#|       - name: tau_r
#|         type: numeric
#|         units: years
#|         description: |
#|           Fine root turnover time.
#|         references:
#|           - citation: "Huaraca Huasco et al. (2021)"
#|             doi: "https://doi.org/10.1111/gcb.15677"
#|             url: "https://onlinelibrary.wiley.com/doi/10.1111/gcb.15677"
#|             origin: "Maliau and Danum Valley Conservation Area, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "primary"
#|             date: "2021"
#|         assumptions: "Loaded from t_model_maliau.csv. Original assumption: Calculated as the mean root residence time across two Maliau plots and applied uniformly across pfts."
#|       - name: resp_r
#|         type: numeric
#|         units: year-1
#|         description: |
#|           Fine root specific maintenance respiration rate.
#|         references:
#|           - citation: "Yan and Zhao (2007)"
#|             doi: "http://dx.doi.org/10.1016/S1872-2032(07)60056-0"
#|             url: "https://www.sciencedirect.com/science/article/pii/S1872203207600560?via%3Dihub"
#|             origin: null
#|             biome: null
#|             vegetation_type: "rain forest tree"
#|             site_condition: null
#|             date: null
#|         assumptions: "Loaded from t_model_maliau.csv. Original assumption: A daily literature respiration value is multiplied by 365 to obtain an annual rate, which is applied uniformly across PFTs."
#|       - name: resp_f
#|         type: numeric
#|         units: year-1
#|         description: |
#|           Leaf specific maintenance respiration rate.
#|         references:
#|           - citation: "Yan and Zhao (2007)"
#|             doi: "http://dx.doi.org/10.1016/S1872-2032(07)60056-0"
#|             url: "https://www.sciencedirect.com/science/article/pii/S1872203207600560?via%3Dihub"
#|             origin: null
#|             biome: null
#|             vegetation_type: "rain forest tree"
#|             site_condition: null
#|             date: null
#|         assumptions: "Loaded from t_model_maliau.csv. Original assumption: A daily literature respiration value is multiplied by 365 to obtain an annual rate, which is applied uniformly across PFTs."
#|       - name: resp_s
#|         type: numeric
#|         units: year-1
#|         description: |
#|           Wood specific maintenance respiration rate.
#|         references:
#|           - citation: "Yan and Zhao (2007)"
#|             doi: "http://dx.doi.org/10.1016/S1872-2032(07)60056-0"
#|             url: "https://www.sciencedirect.com/science/article/pii/S1872203207600560?via%3Dihub"
#|             origin: null
#|             biome: null
#|             vegetation_type: "rain forest tree"
#|             site_condition: null
#|             date: null
#|         assumptions: "Loaded from t_model_maliau.csv. Original assumption: A daily literature respiration value is multiplied by 365 to obtain an annual rate, which is applied uniformly across PFTs."
#|       - name: resp_rt
#|         type: numeric
#|         units: year-1
#|         description: |
#|           Maintenance respiration rate for reproductive tissue.
#|         references:
#|           - citation: "Kinugasa et al. (2005)"
#|             doi: "https://doi.org/10.1093/aob/mci152"
#|             url: "https://academic.oup.com/aob/article-abstract/96/1/81/174607?redirectedFrom=fulltext"
#|             origin: "laboratory settings"
#|             biome: "temperate"
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Loaded from t_model_maliau.csv. Original assumption: Production of reproductive organs is assumed to be consistent throughout the year, and the maintenance respiration value is applied uniformly across PFTs."
#|       - name: yld
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Yield factor used in the T model.
#|         references:
#|           - citation: "Yan and Zhao (2007)"
#|             doi: "http://dx.doi.org/10.1016/S1872-2032(07)60056-0"
#|             url: "https://www.sciencedirect.com/science/article/pii/S1872203207600560?via%3Dihub"
#|             origin: null
#|             biome: null
#|             vegetation_type: "rain forest tree"
#|             site_condition: null
#|             date: null
#|         assumptions: "Loaded from t_model_maliau.csv. Original assumption: Calculated as 1 / (1 + r_g), using a growth respiration coefficient."
#|       - name: zeta
#|         type: numeric
#|         units: kg C m-2
#|         description: |
#|           Fine root carbon mass to foliage area ratio.
#|         references:
#|           - citation: "Niiyama et al. (2010)"
#|             doi: "http://dx.doi.org/10.1017/S0266467410000040"
#|             url: "https://www.cambridge.org/core/journals/journal-of-tropical-ecology/article/abs/estimation-of-root-biomass-based-on-excavation-of-individual-root-systems-in-a-primary-dipterocarp-forest-in-pasoh-forest-reserve-peninsular-malaysia/523F092746792B1ABF3B18DEE483895F"
#|             origin: "Pasoh Forest Reserve, Peninsular Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: "primary"
#|             date: "2004-2005"
#|           - citation: "Both et al. (2019)"
#|             doi: "https://doi.org/10.5281/zenodo.3247631"
#|             url: "https://zenodo.org/records/3247631"
#|             origin: "SAFE Project and Danum Valley Conservation Area, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2014-2018"
#|           - citation: "Imai et al. (2010)"
#|             doi: "https://doi.org/10.1017/S0266467410000350"
#|             url: "https://www.cambridge.org/core/journals/journal-of-tropical-ecology/article/abs/distribution-of-phosphorus-in-an-abovetobelowground-profile-in-a-bornean-tropical-rain-forest/FCCE8AA3D75C97EA444F509BF8F3FF51"
#|             origin: "Deramakot Forest Reserve, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "rain forest"
#|             site_condition: "pristine"
#|             date: "2010"
#|         assumptions: "Loaded from t_model_maliau.csv. Original assumption: Derived from Niiyama et al. (2010) fine-root and foliage masses, PFT-specific SLA from the functional-traits data, and a mean fine-root carbon content of 45.2% from Imai et al. (2010)."
#|       - name: m
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Scenario-specific plant model parameter m.
#|         references:
#|           - citation: null
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Assigned in this script as the Maliau 2 scenario value."
#|       - name: n
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Scenario-specific plant model parameter n.
#|         references:
#|           - citation: null
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Assigned in this script as the Maliau 2 scenario value."
#|       - name: f_g
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Scenario-specific plant model parameter f_g.
#|         references:
#|           - citation: null
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Assigned in this script as the Maliau 2 scenario value."
#|       - name: gpp_topslice
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Scenario-specific plant model parameter gpp_topslice.
#|         references:
#|           - citation: null
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Assigned in this script as the Maliau 2 scenario value."
#|       - name: p_foliage_for_reproductive_tissue
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Fraction of foliage carbon allocated to reproductive tissue.
#|         references:
#|           - citation: "Kitayama et al. (2015)"
#|             doi: "https://doi.org/10.1111/1365-2745.12379"
#|             url: "https://besjournals.onlinelibrary.wiley.com/doi/10.1111/1365-2745.12379"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Extracted from the reproduction_maliau.csv summary using the Kitayama dipterocarp non-mast value reported in the Aoyagi comparison."
#|       - name: c_mass_fruit_flesh
#|         type: numeric
#|         units: g C
#|         description: |
#|           Carbon mass per mature fruit flesh after subtracting seed carbon mass.
#|         references:
#|           - citation: "Ichie et al. (2005)"
#|             doi: "https://doi.org/10.1017/S0266467404002214"
#|             url: null
#|             origin: null
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Joined from stoichiometry_maliau.csv using the PFT name. Original assumption: Calculated from mature fruit dry mass and carbon percentage for Dipterocarpus tempehes, after subtracting the estimated carbon mass of one seed."
#|       - name: c_mass_per_fruit_seed
#|         type: numeric
#|         units: g C
#|         description: |
#|           Carbon mass per seed within a mature fruit.
#|         references:
#|           - citation: "Ichie et al. (2005)"
#|             doi: "https://doi.org/10.1017/S0266467404002214"
#|             url: null
#|             origin: null
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Nakagawa and Nakashizuka (2004)"
#|             doi: "https://doi.org/10.1079/SSR2004181"
#|             url: null
#|             origin: null
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Joined from stoichiometry_maliau.csv using the PFT name. Original assumption: Derived using seed dry mass from Nakagawa and Nakashizuka with fruit carbon concentration from Ichie as a proxy for seed carbon concentration, assuming one seed per fruit."
#|       - name: seeds_per_fruit
#|         type: numeric
#|         units: dimensionless
#|         description: |
#|           Number of seeds per mature fruit.
#|         references:
#|           - citation: "Nakagawa and Nakashizuka (2004)"
#|             doi: "https://doi.org/10.1079/SSR2004181"
#|             url: null
#|             origin: null
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Joined from stoichiometry_maliau.csv using the PFT name. Original assumption: Assumed to be one seed per fruit for dipterocarps."
#|       - name: deadwood_c_n_ratio
#|         type: numeric
#|         units: g C g^-1 N
#|         description: |
#|           Carbon-to-nitrogen ratio for sapwood / deadwood tissue.
#|         references:
#|           - citation: "Inagawa et al. (2023)"
#|             doi: "https://doi.org/10.5281/zenodo.8158811"
#|             url: "https://zenodo.org/records/8158811"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: "Joined from stoichiometry_maliau.csv using the PFT name. Original assumption: Calculated from sapwood nutrient concentrations and averaged across the limited species sample rather than by PFT."
#|       - name: foliage_c_n_ratio
#|         type: numeric
#|         units: g C g^-1 N
#|         description: |
#|           Carbon-to-nitrogen ratio for foliage.
#|         references:
#|           - citation: "Both et al. (2019)"
#|             doi: "https://doi.org/10.5281/zenodo.3247631"
#|             url: "https://zenodo.org/records/3247631"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: "Joined from stoichiometry_maliau.csv using the PFT name. Original assumption: Calculated from leaf trait measurements and aggregated to PFT using species-to-PFT matching, with genus-level matching where species-level matching is unavailable."
#|       - name: foliage_c_p_ratio
#|         type: numeric
#|         units: g C g^-1 P
#|         description: |
#|           Carbon-to-phosphorus ratio for foliage.
#|         references:
#|           - citation: "Both et al. (2019)"
#|             doi: "https://doi.org/10.5281/zenodo.3247631"
#|             url: "https://zenodo.org/records/3247631"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: "Joined from stoichiometry_maliau.csv using the PFT name. Original assumption: Calculated from leaf trait measurements and aggregated to PFT using species-to-PFT matching, with genus-level matching where species-level matching is unavailable."
#|       - name: root_turnover_c_n_ratio
#|         type: numeric
#|         units: g C g^-1 N
#|         description: |
#|           Carbon-to-nitrogen ratio for fine root turnover material.
#|         references:
#|           - citation: "Imai et al. (2010)"
#|             doi: "https://doi.org/10.1017/S0266467410000350"
#|             url: null
#|             origin: "Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "mixed dipterocarp lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Joined from stoichiometry_maliau.csv using the PFT name. Original assumption: Used directly from fine-root stoichiometry values rather than derived separately for turnover material."
#|       - name: root_turnover_c_p_ratio
#|         type: numeric
#|         units: g C g^-1 P
#|         description: |
#|           Carbon-to-phosphorus ratio for fine root turnover material.
#|         references:
#|           - citation: "Imai et al. (2010)"
#|             doi: "https://doi.org/10.1017/S0266467410000350"
#|             url: null
#|             origin: "Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "mixed dipterocarp lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Joined from stoichiometry_maliau.csv using the PFT name. Original assumption: Used directly from fine-root stoichiometry values rather than derived separately for turnover material."
#|       - name: leaf_turnover_c_n_ratio
#|         type: numeric
#|         units: g C g^-1 N
#|         description: |
#|           Carbon-to-nitrogen ratio for senesced leaf turnover material.
#|         references:
#|           - citation: "Han et al. (2013)"
#|             doi: "https://doi.org/10.1371/journal.pone.0083366"
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: "evergreen broadleaf forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Joined from stoichiometry_maliau.csv using the PFT name. Original assumption: Derived from foliage C:N using a fixed nitrogen resorption efficiency rather than direct senesced leaf measurements."
#|       - name: leaf_turnover_c_p_ratio
#|         type: numeric
#|         units: g C g^-1 P
#|         description: |
#|           Carbon-to-phosphorus ratio for senesced leaf turnover material.
#|         references:
#|           - citation: "Han et al. (2013)"
#|             doi: "https://doi.org/10.1371/journal.pone.0083366"
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: "evergreen broadleaf forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Joined from stoichiometry_maliau.csv using the PFT name. Original assumption: Derived from foliage C:P using a fixed phosphorus resorption efficiency rather than direct senesced leaf measurements."
#|       - name: plant_reproductive_tissue_turnover_c_n_ratio
#|         type: numeric
#|         units: g C g^-1 N
#|         description: |
#|           Carbon-to-nitrogen ratio for reproductive tissue turnover.
#|         references:
#|           - citation: "Kitayama et al. (2015)"
#|             doi: "https://doi.org/10.1111/1365-2745.12379"
#|             url: "https://besjournals.onlinelibrary.wiley.com/doi/10.1111/1365-2745.12379"
#|             origin: "Mount Kinabalu, Borneo"
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Joined from stoichiometry_maliau.csv using the PFT name. Original assumption: Based on combined reproductive-organ litter fractions from selected Kitayama sites, so flowers, fruits and seeds are not separated."
#|       - name: plant_reproductive_tissue_turnover_c_p_ratio
#|         type: numeric
#|         units: g C g^-1 P
#|         description: |
#|           Carbon-to-phosphorus ratio for reproductive tissue turnover.
#|         references:
#|           - citation: "Kitayama et al. (2015)"
#|             doi: "https://doi.org/10.1111/1365-2745.12379"
#|             url: "https://besjournals.onlinelibrary.wiley.com/doi/10.1111/1365-2745.12379"
#|             origin: "Mount Kinabalu, Borneo"
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Joined from stoichiometry_maliau.csv using the PFT name. Original assumption: Based on combined reproductive-organ litter fractions from selected Kitayama sites, so flowers, fruits and seeds are not separated."
#|       - name: deadwood_c_p_ratio
#|         type: numeric
#|         units: g C g^-1 P
#|         description: |
#|           Carbon-to-phosphorus ratio for deadwood tissue.
#|         references:
#|           - citation: null
#|             doi: "https://doi.org/10.5281/zenodo.8158811"
#|             url: "https://zenodo.org/records/8158811"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: "Joined from stoichiometry_maliau.csv using the PFT name. Original assumption: Calculated from sapwood nutrient concentrations and averaged across the limited species sample rather than by PFT."
#|     notes: |
#|       The remaining variables in this output are inherited from the canonical
#|       Maliau library definitions in t_model_maliau.csv and
#|       stoichiometry_maliau.csv; their full metadata are defined in those
#|       source scripts.
#|
#| package_dependencies:
#|   - tidyverse
#|
#| usage_notes: |
#|   This script creates the Maliau 2 PFT definition table by joining T model
#|   parameters with stoichiometric and reproductive allocation values.
#| ---

# Load packages

library(tidyverse)

# Load the input data files

stoichiometry_maliau <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/stoichiometry_maliau.csv",
  header = TRUE
)

t_model_maliau <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/t_model_maliau.csv",
  header = TRUE
)

reproduction_maliau <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/reproduction_maliau.csv",
  header = TRUE
)

subcanopy_maliau <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/subcanopy_maliau.csv",
  header = TRUE
)

##########

# Prepare plant_pft_definitions_maliau_2

# Start from the updated t_model_maliau data frame.
plant_pft_definitions_maliau_2 <- t_model_maliau

# Exclude variables that are not part of the final PFT definitions.
plant_pft_definitions_maliau_2 <- subset(
  plant_pft_definitions_maliau_2,
  select = -c(
    root_exudates,
    propagules_per_ha,
    per_stem_annual_mortality_probability,
    per_propagule_annual_recruitment_probability
  )
)

# Variables required:
# name OK
# a_hd OK
# ca_ratio OK
# h_max OK
# rho_s OK
# lai OK
# sla OK
# tau_f OK
# tau_rt OK
# tau_b OK
# tau_r OK
# par_ext OK
# yld OK
# zeta OK
# resp_r OK
# resp_rt OK
# resp_s OK
# resp_f OK

# m ADD default
# n ADD default
# f_g ADD default
# q_m ADD default
# z_max_prop ADD default
# gpp_topslice ADD default

# p_foliage_for_reproductive_tissue ADD from reproductive_tissue_allocation

# deadwood_c_n_ratio ADD from stoichiometry
# deadwood_c_p_ratio ADD from stoichiometry
# leaf_turnover_c_n_ratio ADD from stoichiometry
# leaf_turnover_c_p_ratio ADD from stoichiometry
# plant_reproductive_tissue_turnover_c_n_ratio ADD from stoichiometry
# plant_reproductive_tissue_turnover_c_p_ratio ADD from stoichiometry
# root_turnover_c_p_ratio ADD from stoichiometry
# root_turnover_c_n_ratio ADD from stoichiometry
# foliage_c_n_ratio ADD from stoichiometry
# foliage_c_p_ratio ADD from stoichiometry
# c_mass_fruit_flesh ADD from stoichiometry
# c_mass_per_fruit_seed ADD from stoichiometry
# seeds_per_fruit ADD from stoichiometry

# Add missing ones.
plant_pft_definitions_maliau_2$m <- 2
plant_pft_definitions_maliau_2$n <- 5
plant_pft_definitions_maliau_2$f_g <- 0.02
plant_pft_definitions_maliau_2$gpp_topslice <- 0.1

# p_foliage_for_reproductive_tissue
# Extract the value from the reproduction_maliau summary table matching the
# Kitayama dipterocarp, non-mast ratio used in the reproductive allocation.
plant_pft_definitions_maliau_2$p_foliage_for_reproductive_tissue <- as.numeric(
  reproduction_maliau$value[
    reproduction_maliau$variable == "reproductive_to_leaf_ratio_C" &
      reproduction_maliau$approach == "3" &
      reproduction_maliau$source == "aoyagi" &
      grepl("kitayama.*dipterocarp.*non-mast", reproduction_maliau$notes)
  ][1]
)

# deadwood_c_n_ratio
# deadwood_c_p_ratio
# leaf_turnover_c_n_ratio
# leaf_turnover_c_p_ratio
# plant_reproductive_tissue_turnover_c_n_ratio
# plant_reproductive_tissue_turnover_c_p_ratio
# root_turnover_c_n_ratio
# root_turnover_c_p_ratio
# foliage_c_n_ratio
# foliage_c_p_ratio
temp <- stoichiometry_maliau[, c(
  "pft_name",
  "deadwood_c_n_ratio",
  "deadwood_c_p_ratio",
  "leaf_turnover_c_n_ratio",
  "leaf_turnover_c_p_ratio",
  "plant_reproductive_tissue_turnover_c_n_ratio",
  "plant_reproductive_tissue_turnover_c_p_ratio",
  "root_turnover_c_n_ratio",
  "root_turnover_c_p_ratio",
  "foliage_c_n_ratio",
  "foliage_c_p_ratio",
  "c_mass_fruit_flesh",
  "c_mass_per_fruit_seed",
  "seeds_per_fruit"
)]

plant_pft_definitions_maliau_2 <-
  left_join(plant_pft_definitions_maliau_2, temp, by = "pft_name")

# Write out summary of variable data types and units

# Write CSV file.
write.csv(
  plant_pft_definitions_maliau_2,
  "../../../../data/derived/plant/input_data/scenarios/maliau_2/plant_pft_definitions_maliau_2.csv",
  row.names = FALSE
)

##########
