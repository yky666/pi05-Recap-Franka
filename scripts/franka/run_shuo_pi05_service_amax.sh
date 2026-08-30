#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_PATH="$(cd "${SCRIPT_DIR}/../.." && pwd)"

FRANKA_SERVICE_VENV="${FRANKA_SERVICE_VENV:-/home/amax/venvs/pi05-franka-service}"
if [[ -f "${FRANKA_SERVICE_VENV}/bin/activate" ]]; then
  # Keep the launcher usable from a plain shell/base conda prompt on amax.
  # Override FRANKA_SERVICE_VENV to use another prepared environment.
  source "${FRANKA_SERVICE_VENV}/bin/activate"
fi

export PYTHONPATH="${REPO_PATH}:${PYTHONPATH:-}"
export HYDRA_FULL_ERROR=1

MODEL_PATH="${MODEL_PATH:-/home/amax/.cache/huggingface/hub/models--lerobot--pi05_base/snapshots/9e55186ad36e66b95cda57bc47818d9e6237ae30}"
ASSETS_DIR="${ASSETS_DIR:-${MODEL_PATH}}"
CKPT_PROFILE="${CKPT_PROFILE:-front2}"
CHECKPOINT_BASE="${CHECKPOINT_BASE:-/home/amax/checkpoints/pi05-Recap-Franka}"
case "${CKPT_PROFILE}" in
  front2)
    DEFAULT_CKPT_PATH="${CHECKPOINT_BASE}/sft_franka_shuo_pi05/checkpoints/global_step_15000/actor/model_state_dict/full_weights.pt"
    DEFAULT_ASSET_ID="franka_shuo_bowls_ring"
    ;;
  d2)
    DEFAULT_CKPT_PATH="${CHECKPOINT_BASE}/20260828-080659-franka_pi05_rlinf_d2/sft_franka_shuo_pi05/checkpoints/global_step_23000/actor/model_state_dict/full_weights.pt"
    DEFAULT_ASSET_ID="franka_shuo_fruits_charger_peg"
    ;;
  *)
    echo "Unknown CKPT_PROFILE=${CKPT_PROFILE}; expected front2 or d2" >&2
    exit 1
    ;;
esac
CKPT_PATH="${CKPT_PATH:-${DEFAULT_CKPT_PATH}}"
ASSET_ID="${ASSET_ID:-${DEFAULT_ASSET_ID}}"
DEFAULT_NORM_STATS_PATH="${CHECKPOINT_BASE}/assets/${ASSET_ID}/norm_stats.json"
if [[ ! -f "${DEFAULT_NORM_STATS_PATH}" ]]; then
  DEFAULT_NORM_STATS_PATH="${REPO_PATH}/scripts/franka/norm_stats/${ASSET_ID}/norm_stats.json"
fi
NORM_STATS_PATH="${NORM_STATS_PATH:-${DEFAULT_NORM_STATS_PATH}}"
POLICY_PORT="${POLICY_PORT:-33050}"
TASK_PROMPT="${TASK_PROMPT:-Stack the three bowls in size order: the purple bowl first, then the beige bowl.}"

if [[ ! -e "${MODEL_PATH}/model.safetensors" ]]; then
  echo "Missing base model: ${MODEL_PATH}/model.safetensors" >&2
  exit 1
fi

if [[ -z "${NORM_STATS_PATH}" || ! -f "${NORM_STATS_PATH}" ]]; then
  cat >&2 <<EOF
Missing NORM_STATS_PATH.

This checkpoint must use the norm stats from Shuo's training asset:
  ${ASSET_ID}/norm_stats.json

Set it explicitly, for example:
  export NORM_STATS_PATH=/path/to/pi05_base_openpi_rlinf/assets/${ASSET_ID}/norm_stats.json
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
  --asset-id "${ASSET_ID}" \
  --config-name pi05_franka_shuo \
  --num-action-chunks 32 \
  --num-steps 5 \
  --response-horizon 32 \
  --default-prompt "${TASK_PROMPT}"
