library(ellmer)
library(glue)
library(toml)

# Input files
data_folder <- "data/derived/soil/llm"
constant_file <- "soil_constant_usage.toml"
constant_filepath <- file.path(data_folder, constant_file)

# Upload files
constant_file_upload <- google_upload(
  constant_filepath,
  mime_type = "text/plain"
)

# Read data that needs to be passed to the LLM from R
constant_usage <- read_toml(constant_filepath)
constant_list <- purrr::map_chr(constant_usage, "name") |> unname()

# Prompt
# To add later:
# - Encourage to think deeper
# - Examples and counter-examples
prompt <- glue(
  "
  You are an expert soil biogeochemist. Your task is to parameterise a 
  process-based ecosystem model. Search the internet for empirical or 
  modelled values for the following constants and suggest a plausible
  value with citation(s). **Do not simply repeat the preset values that
  are already in place.**

  # The model

  The process-based model is `virtual_ecosystem`, which aims to simulation 
  of all of the major processes involved in a real ecosystem including 
  plants, microclimate, hydrology, soil, animals and microbes.
  It is a Python program developed on https://github.com/ImperialCollegeLondon/virtual_ecosystem
  and documented on https://virtual-ecosystem.readthedocs.io/en/latest/
  
  # Constant parameters

  You will understand the constant parameters using the TOML document: {constant_file}.
  The entries' name structure is virtual_ecosystem.models.<module_name>.<py_script>.<constant_group>.<constant>
  
  For each constant entry, the metadata contain:
    - name: name of the constant.
    - description: the preset value, some with plausible bounds (le = less than 
      or equal; lt = less than; gt = greater than; ge = greater than or equal)
    - docstring: a short description, unit, and citation (if any) of the 
      constant
  Then, nested under `[[referenced_in]]`:
    - caller: the function in virtual_ecosystem that calls the constant.
    - docstring: docstring of the caller function.
  
  # Notes

  - A constant may be called by multiple functions.
  - Use the unit in the docstring to understand the dimension of each constant.
  - If you find multiple plausible values for a constant from the literature or
    datasets, return one row for each source.
  - If you cannot find a constant value from the literature or published
    datasets with confidence, then return NA in the columns other than `name`.
  "
)

# Define target output classes and types
type_output <- type_array(
  type_object(
    name = type_enum(
      constant_list,
      "Name of the constant.",
      required = TRUE
    ),
    value = type_number(
      "Suggested value of the constant.",
      required = FALSE
    ),
    unit = type_string(
      "Unit or dimension of the constant value.",
      required = FALSE
    ),
    citation = type_string(
      "The primary literature or dataset citation in bibtex format.",
      required = FALSE
    ),
    url = type_string(
      "URL to the literature or dataset source(s).",
      required = FALSE
    ),
    doi = type_string(
      "DOI to the literature or dataset source(s).",
      required = FALSE
    ),
    confidence = type_enum(
      c("low", "medium", "high"),
      "A confidence rating for the suggested value.",
      required = FALSE
    )
  )
)

# Prompt the LLM
chat <- chat_google_gemini(model = "gemini-3.5-flash")
tictoc::tic()
constant_search <- chat$chat_structured(
  constant_file_upload,
  prompt,
  type = type_output
)
tictoc::toc()
