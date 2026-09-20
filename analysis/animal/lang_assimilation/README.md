# Lang assimilation-efficiency extraction

The raw Lang et al. (2017) dataset is staged through Globus and is not stored
in this repository.

## Staging the input

Stage the approved raw CSV locally with this filename:

```text
Lang_et_al_2017_data.csv
```

The script assumes the staged CSV keeps the documented schema, including one
metadata row before the true header row, so it is read with `header=1`.

Do not store Globus credentials, access tokens, or other secrets in the
repository.

## Running the workflow

From the repository root:

```bash
uv sync

uv run python analysis/animal/lang_assimilation/extract_lang_assimilation_to_VE.py \
  --input /path/to/Lang_et_al_2017_data.csv \
  --output /path/to/Lang_et_al_2017_VE_mapped_observations.csv
```

If `--output` is omitted, the script writes
`Lang_et_al_2017_VE_mapped_observations.csv` in the current working directory.
The output directory is created automatically when needed.

## Reproducibility record

For each run, record:

- Globus collection name or identifier
- Globus logical source path
- transfer date
- input filename
- input SHA-256 checksum
- Git commit used for the extraction

The script prints the input SHA-256 checksum together with row-retention and
mapping summaries so the staged transfer can be audited later.
