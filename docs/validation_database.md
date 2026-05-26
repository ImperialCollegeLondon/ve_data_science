# Building a database for (soil and litter) validation

!!! IMPORTANT

    This is a draft document. Most of the workflow below will only work for the
    soil and litter modules.

Here we use a config-driven pipeline to read, wrangle, unit-convert, and
combine multiple datasets into a single master file, hereafter referred to as
the "database". We are not aiming for a full database backend, instead we only
want to avoid having to write many custom codes that each only work for one
dataset. The idea to run a single script to build the database, while YAML
config metadata handles all dataset-specific idiosyncracies.

The folder structure looks like this:
```
data/derived/soil
└── validation
    ├── config
    │   ├── sources
    │   │   ├── 10-5281-ZENODO-1198460.yaml  # metadata about each dataset
    │   │   ├── 10-5281-ZENODO-1198471.yaml
    │   │   ├── ...
    │   ├── units_canonical.yaml   # canonical unit of VE data variables
    │   └── unit_conversions.csv   # unit conversion table
    └── database
        └── ...  # a master .csv, but I'm considering .parquet
tools/R
└── valdb.R
    ├── add_schema()                 # function to add dataset metadata
    ├── build_validation_database()  # main function to build database
    └── log_dataset()                # function to screen datasets and autofill metadata
```

I have built the pipeline in two parts:

1. data screening
2. data entering

Everything happens in `R` for now.

## Data screening workflow

The goal of this step is to log your decision whether to include or exclude a
dataset that you have come across (plus notes) into a interactive table that
guides data entering later.

1. Search for a dataset as per your routine (e.g., Google)
2. Obtain the DOI to the dataset
3. Log the dataset. The following code will bring up an interactive session:

   ```r
   box::use(tools/R/valdb[log_dataset])
   # box::help(log_dataset)
   log_dataset()
   ```

4. After filling up the questions, a YAML config or metadata file will be saved
   to `data/derived/soil/validation/config/sources` (currently this is
   hard-coded to the soil folder because I do not know if anyone would use it
   outside of soil). An example YAML config or metadata looks like this:
   ```yaml
   doi: 10.5281/ZENODO.2024580
   decision: included
   reason: ""
   notes: Contains soil nutrients, moisture, pH, bulk density etc.
   logged_at: "2026-05-21"
   metadata:
     title: Landuse change and species invasion
     author:
       Döbert, Timm and Webber, Bruce L. and Sugau, John B. and Dickinson,
       Katherine J. M. and Didham, Raphael K.
     year: "2019"
     journal: .na.character
     publisher: Zenodo
     url: https://zenodo.org/record/2024580
     keywords:
       plant diversity, above-ground biomass, plant functional traits, biological
       invasions, exotic plants, phylogenetic diversity, soil nutrients
   ```
5. Repeat the steps above until you've finished searching and screening for
   datasets.
6. Build a table to view the screened datasets and your decisions about them.
   I opted to write a Quarto report with additional notes, and then include an
   interactive table at the end of the html report. My report is saved in
   `analysis/soil/validation/safe_database_screen/dataset_screening.qmd`.

You have now completed the data screening phase and can proceed to entering data
that you've decided to include for validation.

## Data entering workflow

This stage begins by adding more information to the included dataset's YAML
config, and ends with building a single database for validation. The editing of
YAML configs is to tell the single R script how to harmonise each dataset.

1. Using the report's table as a tool, revisit the screened datasets to be
   included (e.g., visit its DOI link).
2. Download the dataset to `data/primary/soil/<author>_<year>`. Note that I am
   again using the soil folder as an example, and I have opted a `author_year`
   folder naming convention. If there are conflicts, then the next folder should
   be named `author_year_2` etc. We will work with CSV files. If the published
   dataset is in other formats (e.g., Excel or zip), then manually convert the
   desired data sheet into a CSV file. I opted not to accommodate for multiple
   data formats because the cost of manual conversion is relatively minor even
   in the long run.
3. Add the dataset's schema, which tells the build script how to harmonise this
   dataset:
   ```r
   box::use(tools/R/valdb[add_schema])
   add_schema("data/derived/soil/validation/config/sources/10-5281-ZENODO-3929632.yaml")
   ```
   This will append some template YAML sections to the dataset's config file,
   which you have created during the data screening stage. (Need to make the
   path setting more user friendly)
4. Manually add and edit the schema. An example schema looks like this:
   ```yaml
   source_id: dobert_2019
   data_file: data/primary/soil/dobert_2019/DoebertTF_SAFE_PlotData.csv
   skip_rows: 9
   variables:
     soilN:
       var_canonical: derived
       transform:
         "soil_cnp_pool_lmwc + soil_cnp_pool_maom + soil_cnp_pool_necromass +
         soil_cnp_pool_pom + soil_n_pool_ammonium + soil_n_pool_nitrate"
       unit: mg cm^-3
       unit_transform: kg N m^-3
       description: Total soil nitrogen content
     soilP:
       var_canonical: dissolved_phosphorus
       unit: ug cm^-3
       description: Plant available soil phosphorus content
   dedup_key:
     - plot.code
   ```
5. (More information on how to edit the schema)
6. Once you have added the schema for all datasets to be included, simply run
   the R script `tools/R/build_validation_database.R` once to build the
   validation database. For now, we will just `source()` the script.

## Regular housekeeping

- Update VE data variables table when there is a change upstream
  ```r
  box::use(tools/R/valdb[build_data_variables_table])
  build_data_variables_table()
  ```
