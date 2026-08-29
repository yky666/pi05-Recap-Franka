#!/usr/bin/env bash
# Download the pi0.5 Franka weights provided by JianZhangAI/Real-RL.
# Each full_weights.pt is about 12.5 GiB and must stay out of git.

set -euo pipefail

REPO_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE_DIR="${1:-/home/amax/checkpoints/pi05-Recap-Franka}"

FRONT2_DIR="${BASE_DIR}/sft_franka_shuo_pi05/checkpoints/global_step_15000/actor/model_state_dict"
D2_DIR="${BASE_DIR}/20260828-080659-franka_pi05_rlinf_d2/sft_franka_shuo_pi05/checkpoints/global_step_23000/actor/model_state_dict"

FRONT2_URL="https://huggingface.co/JianZhangAI/Real-RL/resolve/main/franka/rlinf/sft_franka_shuo_pi05/checkpoints/global_step_15000/actor/model_state_dict/full_weights.pt"
D2_URL="https://huggingface.co/JianZhangAI/Real-RL/resolve/main/franka/rlinf/20260828-080659-franka_pi05_rlinf_d2/sft_franka_shuo_pi05/checkpoints/global_step_23000/actor/model_state_dict/full_weights.pt"

download_one() {
  local url="$1"
  local out_dir="$2"
  mkdir -p "${out_dir}"
  echo "Downloading to ${out_dir}/full_weights.pt"
  if command -v aria2c >/dev/null 2>&1; then
    aria2c -c -x16 -s16 -k1M --file-allocation=none --retry-wait=5 --max-tries=0 \
      -d "${out_dir}" -o full_weights.pt "${url}"
  else
    curl -L -C - "${url}" -o "${out_dir}/full_weights.pt"
  fi
  ls -lh "${out_dir}/full_weights.pt"
}

download_one "${FRONT2_URL}" "${FRONT2_DIR}"
download_one "${D2_URL}" "${D2_DIR}"

echo
echo "front2 checkpoint: ${FRONT2_DIR}/full_weights.pt"
echo "d2 checkpoint:     ${D2_DIR}/full_weights.pt"
