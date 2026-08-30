# Franka 5-Task Eval Templates

This directory contains five real-world Franka evaluation templates derived from `evaluations/realworld/realworld_pnp_eval_pi05_sft_RTC.yaml`.

The five templates are pre-filled for the current Franka task prompts and the
two provided Shuo pi0.5 checkpoints:

| Config | Task id | Prompt | Checkpoint |
| --- | --- | --- | --- |
| `task01.yaml` | `stack_bowls_in_size_order_rc` | `Stack the three bowls in size order: the purple bowl first, then the beige bowl.` | `checkpoints/sft_franka_shuo_pi05/checkpoints/global_step_15000/actor/model_state_dict/full_weights.pt` |
| `task02.yaml` | `place_ring_on_rod_rc_0810` | `Place the ring on the rod.` | `checkpoints/sft_franka_shuo_pi05/checkpoints/global_step_15000/actor/model_state_dict/full_weights.pt` |
| `task03.yaml` | `place_fruits_on_plate_rc` | `Place all the fruits on the plate.` | `checkpoints/20260828-080659-franka_pi05_rlinf_d2/sft_franka_shuo_pi05/checkpoints/global_step_23000/actor/model_state_dict/full_weights.pt` |
| `task04.yaml` | `plug_charger_into_socket_rc` | `Plug the charger into the socket.` | `checkpoints/20260828-080659-franka_pi05_rlinf_d2/sft_franka_shuo_pi05/checkpoints/global_step_23000/actor/model_state_dict/full_weights.pt` |
| `task05.yaml` | `insert_peg_into_hole_rc` | `Insert the peg into the corresponding hole.` | `checkpoints/20260828-080659-franka_pi05_rlinf_d2/sft_franka_shuo_pi05/checkpoints/global_step_23000/actor/model_state_dict/full_weights.pt` |

Download the checkpoint from repo root:

```bash
bash scripts/franka/download_shuo_pi05_weights.sh
```

The downloaded `full_weights.pt` is loaded through `runner.ckpt_path`. Keep
`rollout.model.model_path` and `actor.model.model_path` pointed at a local
pi0.5 Franka base/assets checkpoint, not at the raw `.pt` file.

Before running, edit each `taskXX.yaml`.

Required fields:

- `cluster.node_groups.1.hardware.configs.0.robot_ip`
- `env.eval.override_cfg.target_ee_pose`
- `env.eval.override_cfg.camera_serials`
- `env.eval.data_collection.save_dir`
- `runner.ckpt_path`
- `rollout.model.model_path`
- `actor.model.model_path`
- `rollout.model.openpi.config_name`
- `actor.model.openpi.config_name`

Optional task-specific fields:

- `env.eval.override_cfg.task_description`
- `env.eval.main_image_key`
- `env.eval.max_episode_steps`
- `env.eval.max_steps_per_rollout_epoch`
- `runner.rtc.enabled`
- `runner.rtc.min_exec_horizon`

Run example:

```bash
export REPO_PATH="$(pwd)"
export EMBODIED_PATH="${REPO_PATH}/examples/embodiment"
export PYTHONPATH="${REPO_PATH}:${PYTHONPATH:-}"
export HYDRA_FULL_ERROR=1

python evaluations/eval_embodied_agent.py \
  --config-path evaluations/realworld/franka_5tasks \
  --config-name task01 \
  runner.logger.log_path="${REPO_PATH}/logs/franka_5tasks/task01/$(date +%Y%m%d-%H%M%S)" \
  runner.ckpt_path="${REPO_PATH}/checkpoints/sft_franka_shuo_pi05/checkpoints/global_step_15000/actor/model_state_dict/full_weights.pt" \
  rollout.model.model_path=/path/to/pi05_franka_pnp_base_or_assets_checkpoint \
  actor.model.model_path=/path/to/pi05_franka_pnp_base_or_assets_checkpoint
```

Use `env/success_once` and manual success counts to compute SR:

```text
SR = successes / trials
```
