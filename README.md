# ngen_testbed

Scripts for running the [NOAA NextGen (NGEN)](https://github.com/NOAA-OWP/ngen) water model
end-to-end for a set of USGS gages: preprocess forcing/hydrofabric data with
[NGIAB](https://github.com/CIROH-UA/NGIAB-CloudInfra) (`ngiab-prep`), run the model in a
container (Docker or Singularity/Apptainer), and evaluate the simulated output against
observations with [TEEHR](https://github.com/RTIInternational/teehr).

## Contents

| File | Purpose |
|---|---|
| `NextGen_Run_all_test_updated.py` | Pipeline driver: `--download` (ngiab-prep), `--run` (ngen + routing via Docker), `--evaluate` (TEEHR). Written for the Jetstream2 cloud VM environment. |
| `NextGen_Download_all_test_updated.py` | Same pipeline driver, with auto-detection of the container runtime (Docker on macOS/workstations, Singularity/Apptainer on HPC). |
| `ngiab_utils.py` | Helpers for reading NGIAB/ngen simulation outputs (NetCDF or CSV troute output) and hydrofabric metadata (gages, crosswalks, simulation time range). |
| `submit_download_model.sh` | Batch driver that runs the `--download` step for a list of gages (parallelized, `MAX_PARALLEL` gages at once). |
| `submit_run_model.sh` | Batch driver that runs the `--run` step for a list of gages sequentially (each run already uses all available cores). |
| `requirements.txt` | Python dependencies. |

## Requirements

- Python 3.10+
- [`uv`](https://github.com/astral-sh/uv) on `PATH` (used by the download step to run `ngiab-prep` via `uvx`)
- A container runtime: Docker, or Singularity/Apptainer on HPC
- Access to the `awiciroh/ciroh-ngen-image` container image (or a local `ngen_noaa_latest.sif`)

Install Python dependencies:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Usage

### Single gage

```bash
python NextGen_Run_all_test_updated.py \
    --hydrofabric-id gage-02464000 \
    --start-date 2020-01-01 \
    --end-date 2022-12-31 \
    --all            # or any combination of --download --run --evaluate
```

Key options:

- `--hydrofabric-id` — gage/hydrofabric identifier, e.g. `gage-10109001` (required)
- `--start-date`, `--end-date` — simulation period (`YYYY-MM-DD`)
- `--download` / `--run` / `--evaluate` / `--all` — which pipeline steps to execute
- `--data-root` — root directory for per-gage data (default: `$NGIAB_DATA_ROOT` or `~/ngiab_preprocess_output`); `NextGen_Run_all_test_updated.py` instead uses `$NGIAB_DATA_DIR` (default `/home/mhchowdhury/ngiab_preprocess_output`)
- `--container-runtime` — `auto` (default), `docker`, or `singularity` (only in `NextGen_Download_all_test_updated.py`)
- `--image-name` — override the container image reference

### Batch (multiple gages)

Edit the `HYDROFABRIC_IDS` array and `START_DATE`/`END_DATE` at the top of each script, then:

```bash
./submit_download_model.sh          # preprocess all configured gages
./submit_run_model.sh               # run the model for all configured gages

# or target a single gage ad hoc:
./submit_download_model.sh gage-02464000
./submit_run_model.sh gage-02464000
```

Both scripts create/activate a `.venv` and install `requirements.txt` automatically, and
write logs to `logs/`.

## Data layout

Each gage's data lives under `<data-root>/<hydrofabric_id>/`, e.g.:

```
<hydrofabric_id>/
├── config/
│   ├── realization.json
│   └── <hydrofabric_id>_subset.gpkg
├── forcings/
│   └── forcings.nc
├── outputs/
│   ├── ngen/
│   └── troute/
├── results/<tag>/         # outputs moved here after a --run completes
└── teehr/                 # TEEHR cache/scratch directory
```
