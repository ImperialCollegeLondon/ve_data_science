library(RNetCDF)
library(purrr)
library(futurize)
plan(multisession, workers = 6)

# Config
nco_path <- "C:/Users/User/miniconda3/Library/bin"
ncks <- file.path(nco_path, "ncks.exe")
ncrcat <- file.path(nco_path, "ncrcat.exe")

conda_exe <- "C:/Users/User/miniconda3/Scripts/conda.exe"
run_nco <- function(conda_exe, env = "base", ...) {
  system2(conda_exe, args = c("run", "-n", env, ...), stderr = TRUE)
}

# File list in numeric order
out_path <- "data/scenarios/sensitivity_soil_litter/out"
out_files <- list.files(out_path, "all_continuous_data.nc", recursive = TRUE)

# --- Step 1: promote cell_id to unlimited, write to tmp folder ---
tmp_dir <- "tmp_nc"
dir.create(tmp_dir)

walk(out_files, \(out_file) {
  tmp_file <- file.path(tmp_dir, paste0(sub("/.*", "", out_file), ".nc"))
  run_nco(
    conda_exe,
    env = "base",
    "ncks",
    "--no_tmp_fl",
    "--mk_rec_dmn",
    "cell_id",
    shQuote(file.path(out_path, out_file)),
    shQuote(tmp_file)
  )
}) |>
  futurize()

# --- Step 2: write file list and concatenate ---
flist <- "file_list.txt"
writeLines(list.files(tmp_dir, full.names = TRUE), "file_list.txt")

outfile <- file.path(out_path, "all_continuous_data_merged.nc")

cmd <- sprintf(
  paste(
    "cat %s | xargs",
    conda_exe,
    "run",
    "-n",
    "base",
    "ncra -Y ncrcat -O -4 -L 1 -o %s --no_tmp_fl"
  ),
  shQuote(flist),
  shQuote(outfile)
)

merging <-
  system2(
    "bash",
    c("-c", shQuote(cmd)),
    stderr = TRUE,
    stdout = TRUE
  )


err <- system2(
  conda_exe,
  args = c(
    "run",
    "-n",
    "base",
    "ncecat",
    "--fl_lst_in",
    shQuote(flist),
    "-o",
    shQuote(outfile)
  ),
  stderr = TRUE
)


# --- Step 3: overwrite cell_id with 1:4800 ---
nc <- open.nc(
  file.path(out_path, "all_continuous_data_merged.nc"),
  write = TRUE
)
var.put.nc(nc, "cell_id", paste0(sub("/.*", "", out_file)))
close.nc(nc)

# --- Cleanup ---
unlink(tmp_dir, recursive = TRUE)
file.remove("file_list.txt")
