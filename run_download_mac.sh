#!/bin/bash
# macOS/Docker equivalent of submit_download_model.sh (no SLURM, no `module load`).
# Runs the download/preprocessing step for each gage locally, one at a time.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

mkdir -p logs

# ── Hydrofabric IDs ───────────────────────────────────────────
HYDROFABRIC_IDS=(
    "gage-02464000"
    "gage-02361000"
    "gage-02469800"
    "gage-03574500"
)

[ -d .venv ] || uv venv
source .venv/bin/activate
uv pip install -r requirements.txt

# ── Run download step for each gage ───────────────────────────
for HYDROFABRIC_ID in "${HYDROFABRIC_IDS[@]}"; do
    echo "→ $HYDROFABRIC_ID"
    python NextGen_Download_all_test_updated.py \
        --hydrofabric-id "$HYDROFABRIC_ID" \
        --start-date     "2020-01-01" \
        --end-date       "2022-12-31" \
        --download \
        2>&1 | tee "logs/download_${HYDROFABRIC_ID}.log"
done
