#!/bin/bash
set -euo pipefail

TASK="${1:-}"

case "${TASK}" in
  stack_bowls_in_size_order_rc)
    CKPT_PROFILE="front2"
    TMUX_SESSION="pi05_stack_bowls"
    ;;
  place_ring_on_rod_rc_0810)
    CKPT_PROFILE="front2"
    TMUX_SESSION="pi05_place_ring"
    ;;
  place_fruits_on_plate_rc)
    CKPT_PROFILE="d2"
    TMUX_SESSION="pi05_place_fruits"
    ;;
  plug_charger_into_socket_rc)
    CKPT_PROFILE="d2"
    TMUX_SESSION="pi05_plug_charger"
    ;;
  insert_peg_into_hole_rc)
    CKPT_PROFILE="d2"
    TMUX_SESSION="pi05_insert_peg"
    ;;
  *)
    cat >&2 <<'EOF'
Usage:
  bash scripts/franka/print_5task_launch_commands.sh <task_id>

Supported task_id:
  stack_bowls_in_size_order_rc
  place_ring_on_rod_rc_0810
  place_fruits_on_plate_rc
  plug_charger_into_socket_rc
  insert_peg_into_hole_rc
EOF
    exit 1
    ;;
esac

cat <<EOF
# Task: ${TASK}
# CKPT_PROFILE: ${CKPT_PROFILE}
# tmux session: ${TMUX_SESSION}

# 1) amax: stop the current policy service if it is using the same port.
tmux kill-session -t pi05_front2 2>/dev/null || true
tmux kill-session -t ${TMUX_SESSION} 2>/dev/null || true

# 2) amax: start the policy service.
tmux new-session -d -s ${TMUX_SESSION} \\
  'cd /data/yangky/test/pi05-Recap-Franka && export CKPT_PROFILE=${CKPT_PROFILE} TASK_PROMPT=${TASK} && bash scripts/franka/run_shuo_pi05_service_amax.sh'

tmux capture-pane -t ${TMUX_SESSION} -p | tail -n 80

# 3) pnp: set the exact same task id in config.sh.
cd ~/桌面/franka_deploy_0128_ee/franka_deploy
perl -0pi -e 's/export TASK="[^"]+"/export TASK="${TASK}"/' config.sh
grep -nE 'POLICY_SERVER_HOST|POLICY_SERVER_PORT|export TASK=|ASYNC_MAX_ACTIONS|ASYNC_USE_LAST' config.sh

# 4) pnp: restart async control and async inference in two terminals.
bash start_control_async.sh
bash start_inference_async.sh
EOF
