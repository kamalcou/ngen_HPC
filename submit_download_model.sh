#!/usr/bin/env bash
# Cloud-VM runner for the NGIAB download/preprocessing step (no SLURM/module system required).
# Runs NextGen_Run_all_test_updated.py --download for each gage.
#
# Requirements on the host: python venv at .venv with project deps installed,
# and `uv`/`uvx` on PATH (used internally by the --download step to run ngiab-prep).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Gages to download ───────────────────────────────────────────
# HYDROFABRIC_IDS=(
#     "gage-02465493"
#     "gage-02369800"
#     "gage-02371500"
#     "gage-02372250"
#     "gage-02374500"
#     "gage-02408540"
#     "gage-02422500"
#     "gage-02450250"
#     "gage-02464000"
#     "gage-02361000"
#     "gage-02469800"
#     "gage-03574500"
# )
HYDROFABRIC_IDS=(
    "gage-02464000"
    "gage-02361000"
    "gage-02469800"
    "gage-03574500"
)

START_DATE="2020-01-01"
END_DATE="2022-12-31"
MAX_PARALLEL="${MAX_PARALLEL:-4}"   # concurrent gage downloads; override with MAX_PARALLEL=N
export NGIAB_DATA_DIR="${NGIAB_DATA_DIR:-$HOME/ngiab_preprocess_output}"

mkdir -p logs

SYSTEM_PYTHON="python3"
if command -v python &>/dev/null; then
    SYSTEM_PYTHON="python"
fi

if [ ! -d .venv ]; then
    echo "Creating virtualenv at .venv"
    "$SYSTEM_PYTHON" -m venv .venv
fi
source .venv/bin/activate
pip install --quiet -r requirements.txt

# ── Run download/preprocessing for this gage ────────────────────
# precip-sources: aorc stage4 nldas2 imerg
# spatial-agg: distributed lumped
download_gage() {
    local hydrofabric_id="$1"
    local status=0
    echo "→ Downloading $hydrofabric_id"
    python NextGen_Run_all_test_updated.py \
        --hydrofabric-id "$hydrofabric_id" \
        --start-date     "$START_DATE" \
        --end-date       "$END_DATE" \
        --download \
        > "logs/download_${hydrofabric_id}.out" \
        2> "logs/download_${hydrofabric_id}.err" || status=$?
    echo "✓ Finished $hydrofabric_id (exit $status)"
    return "$status"
}

# Allow downloading a single gage ad hoc: ./submit_download_model.sh gage-02464000
if [ "$#" -gt 0 ]; then
    download_gage "$1"
    exit 0
fi

for hydrofabric_id in "${HYDROFABRIC_IDS[@]}"; do
    while (( $(jobs -rp | wc -l) >= MAX_PARALLEL )); do
        wait -n
    done
    download_gage "$hydrofabric_id" &
done

wait || echo "One or more gage downloads failed — check logs/download_<gage>.err"
echo "All gage downloads complete."
