# Franka 5-Task Eval Templates

This directory contains five real-world Franka evaluation templates derived from `evaluations/realworld/realworld_pnp_eval_pi05_sft_RTC.yaml`.

Before running, edit each `taskXX.yaml`.

Required fields:

- `cluster.node_groups.1.hardware.configs.0.robot_ip`
- `env.eval.override_cfg.target_ee_pose`
- `env.eval.override_cfg.camera_serials`
- `env.eval.data_collection.save_dir`
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
  runner.logger.log_path="${REPO_PATH}/logs/franka_5tasks/task01/$(date +%Y%m%d-%H%M%S)"
```

Use `env/success_once` and manual success counts to compute SR:

```text
SR = successes / trials
```
