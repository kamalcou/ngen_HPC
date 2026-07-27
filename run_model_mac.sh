#!/bin/bash
# macOS/Docker equivalent of submit_run_model.sh (no SLURM, no `module load`).
# Runs the ngen model + routing step for each gage locally via Docker, one at a time
# (Docker Desktop shares one CPU/RAM pool, so gages are run sequentially rather than
# as a parallel SLURM job array).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

mkdir -p logs

if ! command -v docker >/dev/null 2>&1; then
    echo "docker not found on PATH. Install Docker Desktop for Mac: https://www.docker.com/products/docker-desktop" >&2
    exit 1
fi

if ! docker image inspect awiciroh/ciroh-ngen-image:latest >/dev/null 2>&1; then
    echo "Pulling awiciroh/ciroh-ngen-image:latest..."
    docker pull awiciroh/ciroh-ngen-image:latest
fi

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

# ── Run model for each gage ───────────────────────────────────
for HYDROFABRIC_ID in "${HYDROFABRIC_IDS[@]}"; do
    echo "→ $HYDROFABRIC_ID"
    python NextGen_Run_all_test_updated.py \
        --hydrofabric-id "$HYDROFABRIC_ID" \
        --start-date     "2020-01-01" \
        --end-date       "2022-12-31" \
        --run \
        2>&1 | tee "logs/run_${HYDROFABRIC_ID}.log"
done
