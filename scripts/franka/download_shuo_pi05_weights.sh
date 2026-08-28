#!/usr/bin/env bash
# Download the joint pi0.5 Franka SFT weights provided by JianZhangAI/Real-RL.
# The file is about 12.4 GiB and must stay out of git.

set -euo pipefail

REPO_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${1:-${REPO_PATH}/checkpoints/sft_franka_shuo_pi05/checkpoints/global_step_15000/actor/model_state_dict}"
URL="https://huggingface.co/JianZhangAI/Real-RL/resolve/main/franka/rlinf/sft_franka_shuo_pi05/checkpoints/global_step_15000/actor/model_state_dict/full_weights.pt"

mkdir -p "${OUT_DIR}"

echo "Downloading to ${OUT_DIR}/full_weights.pt"
curl -L -C - "${URL}" -o "${OUT_DIR}/full_weights.pt"

ls -lh "${OUT_DIR}/full_weights.pt"
