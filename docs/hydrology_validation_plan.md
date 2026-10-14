# Hydrology validation plan

 For each VE hydrology variable we find observations or published
values, convert them to the VE unit and the VE monthly time step, record how
close they are to the VE grid in space and time, for comparing them with the
model output for the same cells and months.

This plan gives an overview of that process for the hydrology module at Maliau:
the variables to validate and the data they need
([Section 3](#3-variables-and-data-needed)), the data in hand
([Section 4](#4-available-data)), how the data are processed
([Section 5](#5-processing-to-ve-units-and-monthly-values)) and the status of
each variable ([Section 6](#6-validation-tracker)).
<!-- markdownlint-disable MD013 -->

| File | What it holds |
| --- | --- |
| `data/primary/validation/maliau_variables_summary.xlsx` (globus) | VE variables with unit and validation priority (`output_variables`) and model constants (`model_constats`) |
| `data/primary/validation/dataset/`(globus) | The raw data from [SEARRP](https://zenodo.org/communities/searrp/about) and [SAFE](https://zenodo.org/communities/safe/about) Zenodo : `safe_hydro/` (stream gauges in `streamflow/`, Danum rainfall) and `safe_soil/` (soil moisture surveys) |
| `data/primary/validation/hydrology/hydrology_literature_values.csv` (globus) | Published values and ranges, one row per value, with citation, DOI and `status` |
| `data/primary/validation/hydrology/hydrology_sources.toml`(globus) | Where each dataset is, its columns, units, filters, coordinates and citation |
| `analysis/abiotic/validation/hydrology_validation_data.py`(github) | Python script that reads, cleans and converts the data, generates `hydrology_validation_data.xlsx` and writes the tracker in Section 6 |
| `data/derived/validation/hydrology/hydrology_validation_data.xlsx`(globus) | Processed data: monthly values, the long table `validation_long` and the `variable_registry` |

<!-- markdownlint-enable MD013 -->

## 1. Workflow

<!-- markdownlint-disable MD013 -->

```mermaid
flowchart LR
  A["Variables<br/>maliau_variables_summary.xlsx"] --> B["Data<br/>dataset folder, literature"]
  B --> C["Describe sources<br/>hydrology_sources.toml"]
  C --> D["Process<br/>hydrology_validation_data.py"]
  D --> E["validation_long<br/>workbook"]
```

<!-- markdownlint-enable MD013 -->

1. **Variables:** list the VE hydrology outputs and their priority
   ([Section 3](#3-variables-and-data-needed)).
2. **Data:** find observations and literature values and decide which to use
   ([Section 4](#4-available-data)); screening in the validation database.
3. **Describe sources:** record file, sheet, columns, units, filters and DOI in
   `hydrology_sources.toml`; the schema in the validation database.
4. **Process:** quality control, conversion to VE units and monthly values
   ([Section 5](#5-processing-to-ve-units-and-monthly-values)); building the
   validation database.

## 2. The VE scenario

<!-- markdownlint-disable MD013 -->

| Item | Value |
| --- | --- |
| Scenario | `maliau_2`, 10 x 10 cells of 100 m (1 km²), from `data/derived/site/maliau/maliau_grid_definition.toml` |
| Run period and time step | 2010-01 to 2020-12, monthly |
| Soil layers | top soil 0-0.25 m, sub soil 0.25-1.0 m |
| Forcing | ERA5-Land monthly, the same for every cell |

<!-- markdownlint-enable MD013 -->

Times are stored in UTC and months are local (Asia/Kuching, UTC+8).

## 3. Variables and data needed

Variables, units and priorities are from the `output_variables` sheet of
`maliau_variables_summary.xlsx`. *Direct* means compared with observations of
the same quantity, *derived* through a quantity in the second table, and
*literature* with published values only. *VE output* is how the model reports
the variable for each month (read from the hydrology model code): a sum of the
daily values, a mean of the daily values, or the state at the end of the month.

<!-- markdownlint-disable MD013 -->

| VE variable | VE unit | VE output | Priority | How validated | Data still needed |
| --- | --- | --- | --- | --- | --- |
| river_discharge_rate | m³ s⁻¹ | monthly mean, per cell, routed | Very High | direct, as specific discharge | A river gauge in or near Maliau; the upstream area of the grid's outlet cell |
| total_runoff | mm | monthly sum, per cell, routed | Very High | direct | As above |
| soil_moisture | mm | monthly mean, per soil layer | Very High | direct, as θ | A continuous logger record at Maliau; a profile below 12 cm |
| baseflow | mm | monthly sum, per cell, local | High | derived (baseflow) | A baseflow recession constant |
| subsurface_runoff_routed_plus_local | mm | monthly sum, per cell, routed | High | derived (baseflow) | As baseflow |
| surface_runoff | mm | monthly sum, per cell, local | High | literature | Overland flow from forest plots near Maliau |
| surface_runoff_routed_plus_local | mm | monthly sum, per cell, routed | High | derived (quickflow) | - |
| groundwater_storage | mm | end of month, per groundwater layer | High | derived (baseflow recession) | Groundwater level records |
| subsurface_flow | mm | monthly sum, per cell, local | Medium-High | derived (baseflow) | Drainage or lysimeter fluxes |
| vertical_flow | mm d⁻¹ | monthly mean, per soil layer | Medium-High | literature | Drainage or lysimeter fluxes |
| interception | mm | monthly sum, per canopy layer | Medium | literature | Throughfall and stemflow in old-growth forest |
| canopy_evaporation | mm | monthly sum, per canopy layer | Medium | derived (evapotranspiration) | As interception |
| precipitation_surface | mm | monthly sum, per cell | Medium | derived (rainfall − interception) | As interception |
| soil_evaporation | mm | monthly sum, per cell | Medium | derived (evapotranspiration) | A partition of evapotranspiration |
| matric_potential | kPa | monthly mean, per soil layer | Medium | literature | Values at Maliau; paired θ and potential |
| bypass_flow | mm | monthly sum, per cell | Medium | literature | Literature values |
| aerodynamic_resistance_soil | s m⁻¹ | monthly mean, per cell | Medium | literature | Literature values |
| subsurface_stormflow | mm | monthly sum, per cell, local | | derived (quickflow) | - |
| aerodynamic_resistance_canopy | s m⁻¹ | set at start | | literature | Literature values |
| stomatal_conductance | mol m⁻² s⁻¹ | set at start | | literature | Literature values |

<!-- markdownlint-enable MD013 -->

`condensation`, `density_air`, `latent_heat_vapourisation` and
`specific_heat_air` need no field data: they follow standard physical formulas
and are checked by unit tests.

*Derived variables* combine VE outputs so that they match what is measured.
They are candidates for `data/derived/validation/derived_variables.toml` (step 5
of the validation database). Σ upstream means the sum over the outlet cell and
all cells draining to it; VE routes water to the outlet within the same month,
with no delay.

<!-- markdownlint-disable MD013 -->

| Derived variable | Formula from VE outputs | Unit |
| --- | --- | --- |
| specific_discharge | river_discharge_rate / upstream area of the outlet cell | m³ s⁻¹ km⁻² |
| quickflow | surface_runoff_routed_plus_local + Σ upstream subsurface_stormflow, at the outlet cell | mm |
| baseflow (as separated from the gauge) | subsurface_runoff_routed_plus_local − Σ upstream subsurface_stormflow, at the outlet cell (that is, Σ upstream subsurface_flow + baseflow) | mm |
| baseflow_index | Σ baseflow (as separated from the gauge) / Σ total_runoff, at the outlet cell | fraction |
| runoff_ratio | Σ total_runoff / Σ precipitation | fraction |
| evapotranspiration | canopy_evaporation (summed over canopy layers) + soil_evaporation + transpiration (plants model) | mm |
| interception share, surface runoff share | Σ flux / Σ precipitation | fraction |
| θ (top layer) | soil_moisture (top layer) / 250 mm | m³ m⁻³ |

<!-- markdownlint-enable MD013 -->

*Inputs and constants* the same data can check: the precipitation forcing
(against the gauges), `saturated_hydraulic_conductivity`,
`soil_moisture_saturation`, `soil_moisture_residual` and the van Genuchten
parameters (values in the `model_constats` sheet). Two constants already
look out of range for Maliau:

- `saturated_hydraulic_conductivity` is 3.5 × 10⁻⁵ m s⁻¹ in VE, 5 to 57 times
  the values measured at Danum (6.1 × 10⁻⁷ to 7.1 × 10⁻⁶ m s⁻¹, in
  `hydrology_literature_values.csv`).
- `soil_moisture_residual` is 0.175, so VE soil cannot be drier than 17.5 %.
  A quarter of the soil respiration readings are below 18.2 %, so the driest
  observed months cannot be matched.

Snow variables and constants are left out: there is no snow at Maliau.

## 4. Available data

One row per dataset, as recorded in `hydrology_sources.toml`: each source there has a
screening record (`record_id`, `doi`, decision and reason) and its metadata, in the
format of the validation database. *Zenodo* is the dataset record; *DOI* is the paper or
other repository describing the same data. Values, sites and periods of each dataset are
in the workbook (`sources`, `stream_sites`, `soil_moisture_sites` sheets) and in the
tracker.

<!-- markdownlint-disable MD013 -->

| Dataset (file name) | Folder | Citation | Zenodo | DOI (paper or other repository) | VE variable | Screening |
| --- | --- | --- | --- | --- | --- | --- |
| `vjr_streamflow.csv`, `pf_streamflow.csv`, `*_event_basis_new.csv` | `safe_hydro/streamflow/VJR/` (SAFE), `safe_hydro/streamflow/PF/` (Danum) | Nainar et al. (2018, 2022) | none | [10.1016/j.jhydrol.2018.09.022](https://doi.org/10.1016/j.jhydrol.2018.09.022); [10.3390/w14223791](https://doi.org/10.3390/w14223791) | river_discharge_rate, total_runoff, baseflow, quickflow, precipitation | proceed |
| `SEARPP_compiled_climate_data_2025.xlsx` | `safe_hydro/` | O'Brien et al. (2026) | [10.5281/zenodo.18159592](https://doi.org/10.5281/zenodo.18159592) | none | precipitation (PF, Danum station) | proceed |
| `SAFE_SoilRespiration_Data_SAFEdatabase_update_2021-01-11.xlsx` | `safe_soil/` | Riutta et al. (2021) | [10.5281/zenodo.4542881](https://doi.org/10.5281/zenodo.4542881) | none | soil_moisture | proceed: old-growth plots |
| `Termite_monitoring_maliau.xlsx` | `safe_soil/` | Ashton et al. (2019) | [10.5281/zenodo.3265746](https://doi.org/10.5281/zenodo.3265746) | [10.5285/1e9993ae-add7-497a-b54b-745b0fc6a7ca](https://doi.org/10.5285/1e9993ae-add7-497a-b54b-745b0fc6a7ca) | soil_moisture | proceed: control plots |
| `Carbon_corrected_slopes.xlsx` | `safe_soil/` | Orme et al. (2019) | [10.5281/zenodo.3247592](https://doi.org/10.5281/zenodo.3247592) | none | soil_moisture | proceed |
| `BALI_Nottingham_Girdling_Data_2021_rev .xlsx` | `safe_soil/` | Nottingham et al. (2021) | [10.5281/zenodo.5519572](https://doi.org/10.5281/zenodo.5519572) | none | soil_moisture | exclude: logged forest with girdled trees; the only continuous soil moisture record found |
| `1_HJ_river_water_riparian.xlsx` | `safe_soil/` | Drewer et al. (2019a) | [10.5281/zenodo.3258079](https://doi.org/10.5281/zenodo.3258079) | none | soil_moisture | exclude: oil palm and riparian reserve, not old-growth forest |
| `3_GHG_jdrewer.xlsx` | `safe_soil/` | Drewer et al. (2019b) | [10.5281/zenodo.3258117](https://doi.org/10.5281/zenodo.3258117) | none | soil_moisture | exclude: logged forest and oil palm, not old-growth forest |
| `Lab_experiment_Melissa_corrected.xlsx` | `safe_soil/` | Drewer et al. (2020) | [10.5281/zenodo.3897394](https://doi.org/10.5281/zenodo.3897394) | none | soil moisture in incubations | exclude: laboratory experiment, not field soil moisture |
| `SAFE_Dataset.xlsx` | `safe_soil/` | Elias et al. (2020) | [10.5281/zenodo.3929632](https://doi.org/10.5281/zenodo.3929632) | none | gravimetric soil moisture | exclude: no sampling dates, and gravimetric, not volumetric |
| `hydrology_literature_values.csv` | `data/primary/validation/hydrology/` | per row | per row | per row | precipitation, interception, transpiration, evapotranspiration, surface_runoff, baseflow, saturated_hydraulic_conductivity, matric_potential | `extracted` rows |

<!-- markdownlint-enable MD013 -->

### 4.1 Stream gauges: VJR and PF

Two small forested catchments, VJR in the SAFE landscape and PF in Danum
Valley, are the only gauged streams in old-growth or primary forest (Nainar et
al. 2018, 2022). The other SAFE catchments (LF2, LF3, OP) are logged forest or
oil palm and are not used. Catchment areas and outlet coordinates are in
`hydrology_sources.toml`.

<!-- markdownlint-disable MD013 -->

| Item | VJR | PF |
| --- | --- | --- |
| Name and habitat | Virgin Jungle Reserve, old-growth forest | Primary forest, Danum Valley |
| Catchment area | 3.08 km² | 1.7 km² |
| Gauging station (lat, lon) | 4.646301, 117.542163 | 4.960274, 117.795029 |
| Distance to the `maliau_2` grid | 64.5 km | 94.4 km |
| Record | 2011-09 to 2013-01 | 2012-02 to 2013-08 |
| Files (`safe_hydro/streamflow/`) | `VJR/vjr_streamflow.csv`, `VJR/vjr_event_basis_new.csv` | `PF/pf_streamflow.csv`, `PF/pf_event_basis_new.csv` |
| Streamflow file | 5-minute specific discharge (m³ s⁻¹ km⁻²), rainfall (mm), water temperature (°C); date only, so record times are rebuilt from their position in the day | 5-minute specific discharge (m³ s⁻¹ km⁻²); Excel serial date-time; an Excel workbook saved with a .csv name; no rainfall or water temperature |
| Rainfall | Gauge rainfall in the streamflow file | Danum Valley weather station, daily (`safe_hydro/SEARPP_compiled_climate_data_2025.xlsx`) |
| Storm events | Start and end rows, rainfall, total, subsurface and storm flow, initial, end and peak discharge, time to peak (`*_event_basis_new.csv`) | Same; event rainfall is negative and set missing |
| Not used | `*_simple_cond.csv`, `*_5min.csv` | `*_simple_cond.csv`, `*_5min.csv` |

<!-- markdownlint-enable MD013 -->

The stored "discharge" is specific discharge (already divided by catchment
area). The event-file headers give Qinitial, Qend and Qpeak in mm per 5 min and
Ttpeak and Tstorm in 5-min steps, but the values are specific discharge and
minutes. Record means, monthly, daily and hourly values and the storm events are
in the `streams_*` and `storm_events` sheets of the workbook.

## 5. Processing to VE units and monthly values

The script `hydrology_validation_data.py` does every step below; each quality-control
step is logged in the workbook's `qc_log` sheet. Files are under the dataset folder
(`data/primary/validation/dataset/`) unless the path is given in full.

<!-- markdownlint-disable MD013 -->

| Data | Files processed | Steps to a monthly value | Conversion to the VE unit |
| --- | --- | --- | --- |
| Stream gauges (5 min) | `safe_hydro/streamflow/VJR/vjr_streamflow.csv`, `safe_hydro/streamflow/PF/pf_streamflow.csv`; storm events from `safe_hydro/streamflow/VJR/vjr_event_basis_new.csv`, `safe_hydro/streamflow/PF/pf_event_basis_new.csv` | Remove missing codes and negative values; average to hourly (at least 6 of 12 records); fill gaps up to 6 hours; split baseflow and quickflow (Lyne-Hollick filter); monthly total when at least 80 % of hours are present | Specific discharge q (m³ s⁻¹ km⁻²) × 3.6 = runoff in mm per hour; compare VE river_discharge_rate / upstream area with q |
| Rainfall (5 min at VJR, daily at Danum) | `safe_hydro/streamflow/VJR/vjr_streamflow.csv` (VJR gauge); `safe_hydro/SEARPP_compiled_climate_data_2025.xlsx` (Danum station, for PF) | Sum to monthly totals; gaps not filled; gauge failures removed | mm, no conversion |
| Soil moisture (probe surveys, 0-12 cm) | `safe_soil/SAFE_SoilRespiration_Data_SAFEdatabase_update_2021-01-11.xlsx`, `safe_soil/Termite_monitoring_maliau.xlsx`, `safe_soil/Carbon_corrected_slopes.xlsx` | Keep old-growth, untreated plots; remove values outside 0-100 %; mean of all readings of a plot in a month | θ = % / 100; VE value = θ × 250 mm (top layer) |
| Literature | `data/primary/validation/hydrology/hydrology_literature_values.csv` | Only `extracted` rows; a range becomes two rows | Annual values against the mean annual sum of monthly VE values; shares of rainfall against the same share from the VE |

<!-- markdownlint-enable MD013 -->

Checks against the raw files and the papers (2026-10-13): monthly runoff,
rainfall, soil moisture and the storm-event totals recalculated from the raw
files match the workbook. The record means agree with Nainar et al. (2018,
Fig. 4): runoff ratio 0.62 against 0.615 at VJR and 0.77 against 0.789 at PF;
rainfall 2920 and 3529 mm against 2904 and 3504 mm. The Lyne-Hollick baseflow
index (0.43 at both) matches the paper's Hewlett-Hibbert value at VJR (0.42)
but not at PF (0.68), so read baseflow with the method in mind. PF runoff is
high for the Danum station rainfall (some months with more runoff than rain;
P − Q about 800 mm per year), as in the source. The termite survey readings of
March 2016 (about 2 %) look too low for these soils.

Every row is then classed by its distance to the grid and its period:

<!-- markdownlint-disable MD013 -->

| Match | Classes |
| --- | --- |
| Spatial | inside grid (match); near grid, within 2 km (partial); regional, within 100 km (partial); outside region (no match) |
| Temporal | in run (match); in run but needs daily output, or partly in run (partial); outside run (no match) |

<!-- markdownlint-enable MD013 -->

The result is the `validation_long` sheet in
`data/derived/validation/hydrology/hydrology_validation_data.xlsx`: one row per
observation in the columns of the validation database (location, time window, original and
converted value), plus the value in VE terms (`ve_variable`, `ve_unit`,
`obs_in_ve_unit`, the observed value in the VE unit, not model output), where
to read the VE value (`ve_compare_at`: sink cell or grid mean) and the match
classes.

## 6. Validation tracker

<!-- tracker:start -->
<!-- Generated by hydrology_validation_data.py; do not edit this block. -->

Every VE value is predicted for 2010-01 to 2020-12 on the maliau_2 grid
(maliau_2: 10 x 10 cells of 100 m) at monthly time steps.
Data folders and files are under the dataset folder; the literature values
are in `hydrology_literature_values.csv`. Distances are from the sites to the
edge of the grid; the match classes are explained in
[Section 5](#5-processing-to-ve-units-and-monthly-values). Citations, every
site and the row counts are in the `variable_registry` sheet of the workbook.

<!-- markdownlint-disable MD013 -->

Status counts: no data yet 17, observed 6, observed + literature 4, literature 4, literature to extract 1.

| VE variable | VE unit | priority | data | sites (distance to grid) | spatial match | period | temporal match | status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| aerodynamic_resistance_canopy | s m⁻¹ | | | | | | | no data yet |
| aerodynamic_resistance_soil | s m⁻¹ | Medium | | | | | | no data yet |
| baseflow | mm | High | `safe_hydro/streamflow/PF/`, `safe_hydro/streamflow/VJR/`; `hydrology_literature_values.csv` | 2 sites, 64.5-94.4 km | regional | 2011-10 to 2013-08 | in run | observed + literature |
| bypass_flow | mm | Medium | | | | | | no data yet |
| canopy_evaporation | mm | Medium | | | | | | no data yet |
| condensation | mm | | | | | | | no data yet |
| density_air | kg m⁻³ | | | | | | | no data yet |
| groundwater_storage | mm | High | | | | | | no data yet |
| interception | mm | Medium | `hydrology_literature_values.csv` | | | | | literature |
| latent_heat_vapourisation | kJ kg⁻¹ | | | | | | | no data yet |
| matric_potential | kPa | Medium | `hydrology_literature_values.csv` (to extract) | | | | | literature to extract |
| precipitation_surface | mm | Medium | | | | | | no data yet |
| river_discharge_rate | m³ s⁻¹ | Very High | `safe_hydro/streamflow/PF/`, `safe_hydro/streamflow/VJR/` | 2 sites, 64.5-94.4 km | regional | 2011-10 to 2013-08 | in run | observed |
| soil_evaporation | mm | Medium | | | | | | no data yet |
| soil_moisture | mm | Very High | `safe_soil/Carbon_corrected_slopes.xlsx`; `safe_soil/SAFE_SoilRespiration_Data_SAFEdatabase_update_2021-01-11.xlsx`; `safe_soil/Termite_monitoring_maliau.xlsx` | 8 sites, 0.1-94.3 km | near grid, regional | 2012-01 to 2019-02 | in run | observed |
| specific_heat_air | J kg⁻¹ K⁻¹ | | | | | | | no data yet |
| stomatal_conductance | mol m⁻² s⁻¹ | | | | | | | no data yet |
| subsurface_flow | mm | Medium-High | | | | | | no data yet |
| subsurface_runoff_routed_plus_local | mm | High | | | | | | no data yet |
| subsurface_stormflow | mm | | | | | | | no data yet |
| surface_runoff | mm | High | `hydrology_literature_values.csv` | | | | | literature |
| surface_runoff_routed_plus_local | mm | High | | | | | | no data yet |
| total_runoff | mm | Very High | `safe_hydro/streamflow/PF/`, `safe_hydro/streamflow/VJR/` | 2 sites, 64.5-94.4 km | regional | 2011-10 to 2013-08 | in run | observed |
| vertical_flow | mm per time step (currently day) | Medium-High | | | | | | no data yet |
| precipitation | mm | | `safe_hydro/streamflow/PF/`, `safe_hydro/streamflow/VJR/`; `safe_hydro/SEARPP_compiled_climate_data_2025.xlsx`; `hydrology_literature_values.csv` | 2 sites, 64.5-94.4 km | regional | 2011-11 to 2013-08 | in run | observed + literature |
| quickflow | mm | | `safe_hydro/streamflow/PF/`, `safe_hydro/streamflow/VJR/` | 2 sites, 64.5-94.4 km | regional | 2011-10 to 2013-08 | in run | observed |
| baseflow_index | fraction | | `safe_hydro/streamflow/PF/`, `safe_hydro/streamflow/VJR/`; `hydrology_literature_values.csv` | 2 sites, 64.5-94.4 km | regional | 2011-10 to 2013-08 | in run | observed + literature |
| specific_discharge | m³ s⁻¹ km⁻² | | `safe_hydro/streamflow/PF/`, `safe_hydro/streamflow/VJR/` | 2 sites, 64.5-94.4 km | regional | 2011-10 to 2013-08 | in run | observed |
| runoff_ratio | fraction | | `safe_hydro/streamflow/PF/`, `safe_hydro/streamflow/VJR/` | 2 sites, 64.5-94.4 km | regional | 2011-11 to 2013-08 | in run | observed |
| transpiration | mm | | `hydrology_literature_values.csv` | | | | | literature |
| evapotranspiration | mm | | `safe_hydro/streamflow/PF/`, `safe_hydro/streamflow/VJR/`; `hydrology_literature_values.csv` | 2 sites, 64.5-94.4 km | regional | 2011-11 to 2013-08 | in run | observed + literature |
| saturated_hydraulic_conductivity | m s⁻¹ | | `hydrology_literature_values.csv` | | | | | literature |

<!-- markdownlint-enable MD013 -->

<!-- tracker:end -->

## 7. Next steps

1. Confirm the meaning of "% of pore space" in the soil respiration dataset
   and the probe depth of the termite survey.
2. Extract the Danum matric potential values (Newbery and Lingenfelder 2022).
3. Look for a continuous soil moisture record and a river gauge at Maliau.

Points to keep in mind when comparing: 2010-2013 is spin-up in current runs and
overlaps the stream records; the probes measure 0-12 cm, the upper half of the
VE top layer; the stream gauges are 64-94 km from the grid and drain larger
catchments, so compare monthly totals and specific discharge, not storm peaks.
VE splits the monthly rainfall at random over the days of the month (wet and
dry days drawn with a fixed seed), so daily and storm-scale values from VE do
not match real days; use monthly values only. Compare sums with sums (runoff,
rainfall, fluxes) and means with means (discharge rate, soil moisture).

## 8. References

The journal
articles were checked on the publisher and university repository pages.
Published values in `hydrology_literature_values.csv` carry their own citation
and DOI in each row.

Ashton, L., Griffiths, H., Parr, C., Evans, T., Eggleton, P., & Vairappan, C.
(2019). Termite abundance and ecosystem processes in Maliau Basin, 2015-2016
[HMTF] [Dataset]. Zenodo. <https://doi.org/10.5281/zenodo.3265746>

Drewer, J., Kuling, H. J., Sentian, J., & Skiba, U. (2019a). Soil greenhouse
gas fluxes along transects from oil palm to riparian forests in the SAFE
landscape [Dataset]. Zenodo. <https://doi.org/10.5281/zenodo.3258079>

Drewer, J., Leduning, M., Sentian, J., & Skiba, U. (2019b). Soil greenhouse gas
fluxes and associated parameters from forest and oil palm in the SAFE landscape
[Dataset]. Zenodo. <https://doi.org/10.5281/zenodo.3258117>

Drewer, J., Leduning, M., Zhao, J., Gubry-Rangin, C., & Skiba, U. (2020).
Linking potential greenhouse gas and nitric oxide fluxes to soil microbial
communities in incubation experiments with soil from the SAFE landscape
[Dataset]. Zenodo. <https://doi.org/10.5281/zenodo.3897394>

Elias, D., Robinson, S., Both, S., Goodall, T., Majalap-Lee, N., Ostle, N., &
McNamara, N. (2020). Soil and litter chemistry, soil microbial communities and
litter decomposition from tropical forest and oil palm [Dataset]. Zenodo.
<https://doi.org/10.5281/zenodo.3929632>

Nainar, A., Tanaka, N., Bidin, K., Annammala, K. V., Ewers, R. M., Reynolds,
G., & Walsh, R. P. D. (2018). Hydrological dynamics of tropical streams on a
gradient of land-use disturbance and recovery: A multi-catchment experiment.
*Journal of Hydrology*, 566, 581-594.
<https://doi.org/10.1016/j.jhydrol.2018.09.022>

Nainar, A., Walsh, R. P. D., Bidin, K., Tanaka, N., Annammala, K. V.,
Letchumanan, U., Ewers, R. M., & Reynolds, G. (2022). Baseflow persistence and
magnitude in oil palm, logged and primary tropical rainforest catchments in
Malaysian Borneo: Implications for water management under climate change.
*Water*, 14(22), 3791. <https://doi.org/10.3390/w14223791>

Nottingham, A., Cheeseman, A., Riutta, T., Doughty, C., Telford, E., Huasco,
W. H., Svátek, M., Kvasnica, J., Majalap, N., Malhi, Y., Meir, P., & Teh, Y. A.
(2021). Large contribution of recent photosynthate to soil respiration in
tropical dipterocarp forest revealed by girdling [Dataset]. Zenodo.
<https://doi.org/10.5281/zenodo.5519572>

O'Brien, M., Hanapi, J., Reynolds, G., & Walsh, R. (2026). Danum/Malua compiled
climate data 1985 to 2025 (Version 5.0) [Dataset]. Zenodo.
<https://doi.org/10.5281/zenodo.18159592>

Orme, C. D. L., Riutta, T., Fraser, A., Mackintosh, E., Vollans, M., Graves,
K., Roxby, G., Baynham, G., Noble, C., Adzhar, R., MacLean, C., Martin, S.,
McKinlay, A., Poznansky, F., Prairie, A., Brasington, E., & Wiederkehr, F.
(2019). Daily cycles in soil carbon flux [Dataset]. Zenodo.
<https://doi.org/10.5281/zenodo.3247592>

Riutta, T., Ewers, R. M., Malhi, Y., Majalap, N., & Khoon, K. L. (2021). Total
and partitioned soil respiration and below-ground carbon budget in SAFE
intensive carbon plots [Dataset]. Zenodo.
<https://doi.org/10.5281/zenodo.4542881>
