#| ---
#| title: Extract amino sugar data from Li et al. (2023) Fig. 3
#|
#| description: |
#|     This R script uses a Gemini LLM to extract structured data from
#|     box-whisker diagrams in Fig. 3 of Li et al. (2023). The extracted
#|     amino sugar concentrations (GluN, GalN, MurN) in SOC, POC, and MAOC
#|     pools across four land-use types are saved as a CSV file.
#|
#| virtual_ecosystem_module: Soil
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: 1-s2.0-S0048969723018235-gr3_lrg.jpg
#|     path: data/primary/soil/necromass/
#|     description: |
#|         Figure 3 from Li et al. (2023) showing amino sugar accumulation
#|         in SOC, POC, and MAOC under different land-use types.
#|
#| output_files:
#|   - name: li_et_al_2023.csv
#|     path: data/derived/soil/necromass/
#|     description: |
#|         Extracted amino sugar data from panels a, b, and c of Fig. 3.
#|
#| package_dependencies:
#|     - ellmer
#|     - readr
#|
#| usage_notes: |
#|     Requires a Google Gemini API key configured for the ellmer package.
#| ---

library(ellmer)
library(readr)

# Initialise Gemini chat session
chat <- chat_google_gemini(model = "gemini-3.5-flash")

# Upload figure image to Gemini
li_et_al_2023_fig3 <- google_upload(
  "data/primary/soil/necromass/1-s2.0-S0048969723018235-gr3_lrg.jpg"
)

# Define extraction prompt
prompt <- "
You task is to extract structured data from a multi-paneled scientific diagram.

The figure caption is:
Fig. 3. Accumulation of amino sugars (i.e. amino glucosamine (GluN), amino galactosamine (GalN), and muramic acid (MurN)) in soil organic carbon (SOC), particulate organic carbon (POC), and mineral-associated organic carbon (MAOC) under land-use types. RF, primary forests; SF, secondary forests; OP, oil-palm plantations; RP, rubber plantations. Different lowercase letters indicate significant differences among land-use systems (P < 0.05). Vertical bars denote standard errors of mean values (n = 9).

Note that in panels d, e, and f, the proportions of GluN, GalN, and MurN should sum to 100%.
"

# Extract structured data via LLM
li_et_al_2023_data <- chat$chat_structured(
  li_et_al_2023_fig3,
  prompt,
  type = type_array(
    type_object(
      forest_type = type_string(
        "The X axes should be extracted into a column called `forest_type`. Possible levels are RF, SF, OP, or RP."
      ),
      animo_sugar_SOC = type_string(
        "animo_sugar_SOC is the Y axis values in panel a."
      ),
      animo_sugar_POC = type_string(
        "animo_sugar_POC is the Y axis values in panel b."
      ),
      animo_sugar_MAOC = type_string(
        "animo_sugar_MAOC is the Y axis values in panel c."
      ),
      GluN_SOC = type_string(
        "GluN_SOC is the Y axis percentage values in panels d. Refer to the legend to identify the relative percentage of GluN in SOC by bar colour."
      ),
      GalN_SOC = type_string(
        "GalN_SOC is the Y axis percentage values in panel d. Refer to the legend to identify the relative percentage of GalN in SOC by bar colour."
      ),
      MurN_SOC = type_string(
        "MurN_SOC is the Y axis percentage values in panel d. Refer to the legend to identify the relative percentage of MurN in SOC by bar colour."
      ),
      GluN_POC = type_string(
        "GluN_POC is the Y axis percentage values in panels e. Refer to the legend to identify the relative percentage of GluN in POC by bar colour."
      ),
      GalN_POC = type_string(
        "GalN_POC is the Y axis percentage values in panel e. Refer to the legend to identify the relative percentage of GalN in POC by bar colour."
      ),
      MurN_POC = type_string(
        "MurN_POC is the Y axis percentage values in panel e. Refer to the legend to identify the relative percentage of MurN in POC by bar colour."
      ),
      GluN_MAOC = type_string(
        "GluN_MAOC is the Y axis percentage values in panels f. Refer to the legend to identify the relative percentage of GluN in MAOC by bar colour."
      ),
      GalN_MAOC = type_string(
        "GalN_MAOC is the Y axis percentage values in panel f. Refer to the legend to identify the relative percentage of GalN in MAOC by bar colour."
      ),
      MurN_MAOC = type_string(
        "MurN_MAOC is the Y axis percentage values in panel f. Refer to the legend to identify the relative percentage of MurN in MAOC by bar colour."
      )
    )
  )
)

# Write extracted data to CSV
write_csv(
  li_et_al_2023_data,
  "data/derived/soil/necromass/li_et_al_2023.csv"
)
