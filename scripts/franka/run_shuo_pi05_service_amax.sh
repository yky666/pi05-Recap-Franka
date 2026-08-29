#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_PATH="$(cd "${SCRIPT_DIR}/../.." && pwd)"

export PYTHONPATH="${REPO_PATH}:${PYTHONPATH:-}"
export HYDRA_FULL_ERROR=1

MODEL_PATH="${MODEL_PATH:-/home/amax/.cache/huggingface/hub/models--lerobot--pi05_base/snapshots/9e55186ad36e66b95cda57bc47818d9e6237ae30}"
ASSETS_DIR="${ASSETS_DIR:-${MODEL_PATH}}"
NORM_STATS_PATH="${NORM_STATS_PATH:-}"
CKPT_PATH="${CKPT_PATH:-${REPO_PATH}/checkpoints/sft_franka_shuo_pi05/checkpoints/global_step_15000/actor/model_state_dict/full_weights.pt}"
POLICY_PORT="${POLICY_PORT:-33050}"
TASK_PROMPT="${TASK_PROMPT:-stack_bowls_in_size_order_rc}"

if [[ ! -e "${MODEL_PATH}/model.safetensors" ]]; then
  echo "Missing base model: ${MODEL_PATH}/model.safetensors" >&2
  exit 1
fi

if [[ -z "${NORM_STATS_PATH}" || ! -f "${NORM_STATS_PATH}" ]]; then
  cat >&2 <<EOF
Missing NORM_STATS_PATH.

This checkpoint must use the norm stats from Shuo's training asset:
  franka_shuo_bowls_ring/norm_stats.json

Set it explicitly, for example:
  export NORM_STATS_PATH=/path/to/pi05_base_openpi_rlinf/assets/franka_shuo_bowls_ring/norm_stats.json
EOF
  exit 1
fi

if [[ ! -f "${CKPT_PATH}" ]]; then
  echo "Missing checkpoint: ${CKPT_PATH}" >&2
  echo "Download it with: bash scripts/franka/download_shuo_pi05_weights.sh" >&2
  exit 1
fi

exec python "${REPO_PATH}/scripts/franka/serve_shuo_pi05_policy.py" \
  --host 0.0.0.0 \
  --port "${POLICY_PORT}" \
  --model-path "${MODEL_PATH}" \
  --assets-dir "${ASSETS_DIR}" \
  --norm-stats-path "${NORM_STATS_PATH}" \
  --ckpt-path "${CKPT_PATH}" \
  --config-name pi05_franka_shuo \
  --num-action-chunks 32 \
  --num-steps 5 \
  --response-horizon 32 \
  --default-prompt "${TASK_PROMPT}"
