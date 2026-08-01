#!/usr/bin/env bash
# Cloud-VM runner for the NGIAB model step (no SLURM/module system required).
# Runs NextGen_Run_all_test_updated.py --run for each gage, using Docker
# (docker.io/awiciroh/ciroh-ngen-image) instead of Apptainer/Singularity.
#
# Runs are SEQUENTIAL by design: each gage's ngen run already spawns as many
# partitions/MPI ranks as there are cores (see num_cpus in
# NextGen_Run_all_test_updated.py), so running gages concurrently would
# oversubscribe the node.
#
# Requirements on the host: docker installed and running, docker pull access
# to docker.io/awiciroh/ciroh-ngen-image.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

mkdir -p logs

# ── Gages to run ────────────────────────────────────────────────
HYDROFABRIC_IDS=(
    "gage-02464000"
    "gage-02361000"
    "gage-02469800"
    "gage-03574500"
)

START_DATE="2020-01-01"
END_DATE="2022-12-31"
export NGIAB_DATA_DIR="${NGIAB_DATA_DIR:-$HOME/ngiab_preprocess_output}"

if ! command -v docker &>/dev/null; then
    echo "Error: docker is required but was not found on PATH." >&2
    exit 1
fi

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

run_gage() {
    local hydrofabric_id="$1"
    local log_file="logs/run_model_${hydrofabric_id}.log"
    echo "Running model [$hydrofabric_id] → $log_file"

    local start_ts end_ts elapsed elapsed_fmt status=0
    start_ts=$(date +%s)
    python NextGen_Run_all_test_updated.py \
        --hydrofabric-id "$hydrofabric_id" \
        --start-date     "$START_DATE" \
        --end-date       "$END_DATE" \
        --run \
        > "$log_file" 2>&1 || status=$?
    end_ts=$(date +%s)
    elapsed=$((end_ts - start_ts))
    printf -v elapsed_fmt '%02d:%02d:%02d' $((elapsed/3600)) $((elapsed%3600/60)) $((elapsed%60))

    if [ "$status" -ne 0 ]; then
        echo "FAILED: $hydrofabric_id after $elapsed_fmt (see $log_file)"
    else
        echo "DONE: $hydrofabric_id in $elapsed_fmt"
    fi
    echo "$hydrofabric_id  $elapsed_fmt  status=$status" >> logs/run_times.log
    return "$status"
}

# Allow running a single gage ad hoc: ./submit_run_model.sh gage-02464000
if [ "$#" -gt 0 ]; then
    run_gage "$1"
    exit $?
fi

overall_status=0
for hydrofabric_id in "${HYDROFABRIC_IDS[@]}"; do
    run_gage "$hydrofabric_id" || overall_status=1
done

exit $overall_status
