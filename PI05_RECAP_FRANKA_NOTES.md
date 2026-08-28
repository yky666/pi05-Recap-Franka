# PI05 / RECAP / Franka Code Map

This repository is initialized from `https://github.com/RLinf/RLinf.git` for the Franka experiments that evaluate an OpenPI RECAP policy on real-world Franka tasks and compute success rate (SR).

## Current Model Naming Conclusion

Based on the RLinf source tree and the public RLinf/OpenPI documentation checked on 2026-08-27, the implementation is currently `pi05` / `pi0_5` / `pi0.5` RECAP.

Evidence:

- RLinf RECAP documentation says the RECAP pipeline improves a `pi0.5` policy and uses OpenPI `pi0.5` for CFG training.
- RLinf RECAP configs use `model_type: "pi05"` and `model/pi0_5`.
- RLinf Franka / real-world eval configs use `config_name` values such as `pi05_franka_pnp`, `pi05_franka_state`, and `pi05_dualfranka_tcp_rot6d`.
- Physical Intelligence `openpi` public documentation announces `pi05` as the upgraded version of `pi0`.
- A repository-wide search in the cloned RLinf source found the runnable Franka/OpenPI path under `pi05`, `pi0_5`, and `pi0.5` naming.

Working interpretation for this repo:

- Keep the GitHub repo name `pi05-Recap-Franka`.
- Treat the runnable code path as `pi05/pi0.5 + RECAP + Franka`.
- If the team provides a private checkpoint/config diff, document the checkpoint path and config diff here before running SR.

## External References

- RLinf upstream source: `https://github.com/RLinf/RLinf.git`
- Target repo: `https://github.com/yky666/pi05-Recap-Franka.git`
- RealWorld-RLinf reference repo: `https://github.com/1018weijia/RealWorld-RLinf.git`
- Checked RealWorld-RLinf commit: `9e799e25cbcfd70b3b5e03f79f3c1c0ffdad4bab`
- JianZhangAI Real-RL Franka SFT weights: `https://huggingface.co/JianZhangAI/Real-RL`
- RLinf RECAP docs: `https://rlinf.readthedocs.io/en/latest/rst_source/examples/embodied/recap.html`
- RLinf real-world Franka docs: `https://rlinf.readthedocs.io/en/latest/rst_source/examples/embodied/franka.html`
- OpenPI source/docs: `https://github.com/Physical-Intelligence/openpi`
- Feishu summary doc: `https://ecnirdhdkjpm.feishu.cn/wiki/KSMBwwSFaiJeP5kS51FcjYsFn8f`
- Feishu experiment table: `https://my.feishu.cn/wiki/KZt5wzJTZiq8QskT0qKcoKS5nwc?from=from_copylink`
- Teacher-provided RLT/OpenPI code: `https://github.com/jianzhang96/rlt-openpi`
- Teacher-provided RealWorld-RLinf toolkit path: `https://github.com/1018weijia/RealWorld-RLinf/tree/main/toolkits/`

Access status from this environment:

- The two Feishu pages require browser/login access, so their page content was not directly readable here.
- `jianzhang96/rlt-openpi` still returns `Repository not found` from this machine,
  likely because it is private or requires a different GitHub account.
- `RealWorld-RLinf` is now accessible from this machine. The checked Franka eval
  files match this repository's realworld eval templates; this repository keeps
  the extra `evaluations/realworld/franka_5tasks/` templates for our SR runs.
- `RealWorld-RLinf/toolkits/inference` contains Cobot/Dobot HTTP inference
  servers. It was not migrated into this Franka repo because the current Franka
  deployment path is RLinf Ray eval, not the Cobot/Dobot HTTP API.

## Main Code Paths

- Franka real-world environments and task wrappers:
  - `rlinf/envs/realworld/franka/`
  - `rlinf/envs/realworld/common/`
  - `rlinf/scheduler/hardware/robots/franka.py`
  - `rlinf/scheduler/hardware/robots/dual_franka.py`

- OpenPI / pi0.5 policy implementation:
  - `rlinf/models/embodiment/openpi/`
  - `rlinf/models/embodiment/openpi_rlinf/`
  - `examples/embodiment/config/model/pi0_5.yaml`
  - `examples/embodiment/config/model/pi0_5_rlinf.yaml`
  - `examples/sft/config/model/pi0_5*.yaml`

- RECAP data/value-model pipeline:
  - `rlinf/data/datasets/recap/`
  - `rlinf/models/embodiment/value_model/recap/`
  - `examples/offline_rl/config/recap_*.yaml`
  - `examples/offline_rl/advantage_labeling/recap/`
  - `tests/e2e_tests/offline_rl/recap_*.yaml`

- Franka / real-world experiment configs:
  - `examples/embodiment/config/realworld_eval_dual_franka.yaml`
  - `examples/embodiment/config/realworld_dual_franka_dagger_openpi.yaml`
  - `examples/embodiment/config/realworld_peginsertion_async_ppo_pi05.yaml`
  - `examples/embodiment/config/env/realworld_*franka*.yaml`
  - `evaluations/realworld/`

- Hardware check and teleoperation tools:
  - `toolkits/realworld_check/`
  - `toolkits/dual_franka/`

- Related documentation:
  - `docs/source-zh/rst_source/examples/embodied/recap.rst`
  - `docs/source-zh/rst_source/examples/embodied/franka*.rst`
  - `docs/source-en/rst_source/examples/embodied/recap.rst`
  - `docs/source-en/rst_source/examples/embodied/franka*.rst`

## Real-Robot SR Evaluation Plan

Goal: evaluate the RECAP-trained OpenPI policy on 5 Franka tasks and report SR.

Recommended metric:

- Primary: `env/success_once`, which RLinf docs describe as the unnormalized episodic success-rate signal.
- Report format per task: `successes / trials`, SR, checkpoint, task prompt, reset pose, camera setup, date, operator, and notes.

Five-task table template:

| Task ID | Task Name | Prompt / `task_description` | Config | Checkpoint | Trials | Successes | SR | Notes |
| --- | --- | --- | --- | --- | ---: | ---: | ---: | --- |
| T1 | TBD | TBD | `evaluations/realworld/realworld_pnp_eval_pi05_sft_RTC.yaml` or derived config | TBD | TBD | TBD | TBD | TBD |
| T2 | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| T3 | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| T4 | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| T5 | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

Before running:

- Fill robot IP, camera serials, gripper settings, checkpoint path, and task prompts in derived real-world eval configs.
- Confirm whether the robot is single-arm Franka or dual-arm Franka; the current RLinf tree includes both.
- Confirm the action interface used by the checkpoint: common options in this tree include `pi05_franka_pnp`, `pi05_franka_state`, and `pi05_dualfranka_tcp_rot6d`.
- Keep model weights, datasets, robot credentials, camera serials, and Feishu passwords out of git unless explicitly intended.

## Efficient-RLT / Human-Takeover Data Flow Notes

The provided diagram describes a managed rollout pipeline with human takeover and rollback labels:

- Segment 1: policy rollout from task start to a potential rollback state.
- Segment 2: predicted rollout excluding rollback, used around model evaluation and rollback decisions.
- Segment 3: human takeover from the potential rollback state to an endpoint.
- Segment 4: rollout segment after human takeover toward the rollback endpoint.
- Segment 5: validated rollout to the final success endpoint.

How this maps to the current repo:

- Use RLinf real-world Franka envs for robot rollout and episode control.
- Use keyboard / human control wrappers for success/failure labels and intervention/takeover control.
- Archive rollouts in LeRobot-style datasets so RECAP can compute returns, train the value model, compute advantages, and then run CFG policy training.
- Use RECAP as the offline stage after collecting SFT plus rollout/takeover data; use the real-world eval configs for final SR.

## Notes

- For SR evaluation on the 5 Franka tasks, start from the real-world eval configs above and fill in the task prompts, robot IPs, camera serials, gripper connections, reset poses, and checkpoint path.
- Keep model weights, datasets, and robot-specific credentials out of git unless explicitly intended.
