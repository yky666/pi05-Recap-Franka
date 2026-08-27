# PI06 / RECAP / Franka Code Map

This repository is initialized from `https://github.com/RLinf/RLinf.git` for the Franka experiments that evaluate an OpenPI RECAP policy on real-world Franka tasks and compute success rate (SR).

## Current Model Naming Conclusion

Based on the RLinf source tree and the public RLinf/OpenPI documentation checked on 2026-08-27, the implementation is currently `pi05` / `pi0_5` / `pi0.5` RECAP, not a literal `pi06` RECAP implementation.

Evidence:

- RLinf RECAP documentation says the RECAP pipeline improves a `pi0.5` policy and uses OpenPI `pi0.5` for CFG training.
- RLinf RECAP configs use `model_type: "pi05"` and `model/pi0_5`.
- RLinf Franka / real-world eval configs use `config_name` values such as `pi05_franka_pnp`, `pi05_franka_state`, and `pi05_dualfranka_tcp_rot6d`.
- Physical Intelligence `openpi` public documentation announces `pi05` as the upgraded version of `pi0`; no public `pi06` model/config name was found in the checked repos/docs.
- A repository-wide search in the cloned RLinf source found no `pi06`, `pi0_6`, or `pi0.6` config/model entry.

Working interpretation for this repo:

- Keep the GitHub repo name `pi06-Recap-Franka` because that is the project label from the group.
- Treat the runnable code path as `pi05/pi0.5 + RECAP + Franka` unless a separate private `pi06` checkpoint/config is later provided.
- If the team uses `pi06` as an internal nickname for a pi0.5-derived RECAP checkpoint, document the checkpoint path and config diff here before running SR.

## External References

- RLinf upstream source: `https://github.com/RLinf/RLinf.git`
- Target repo: `https://github.com/yky666/pi06-Recap-Franka.git`
- RLinf RECAP docs: `https://rlinf.readthedocs.io/en/latest/rst_source/examples/embodied/recap.html`
- RLinf real-world Franka docs: `https://rlinf.readthedocs.io/en/latest/rst_source/examples/embodied/franka.html`
- OpenPI source/docs: `https://github.com/Physical-Intelligence/openpi`
- Feishu summary doc: `https://ecnirdhdkjpm.feishu.cn/wiki/KSMBwwSFaiJeP5kS51FcjYsFn8f`
- Feishu experiment table: `https://my.feishu.cn/wiki/KZt5wzJTZiq8QskT0qKcoKS5nwc?from=from_copylink`
- Teacher-provided RLT/OpenPI code: `https://github.com/jianzhang96/rlt-openpi`
- Teacher-provided RealWorld-RLinf toolkit path: `https://github.com/1018weijia/RealWorld-RLinf/tree/main/toolkits/`

Access status from this environment:

- The two Feishu pages require browser/login access, so their page content was not directly readable here.
- The two teacher-provided GitHub repositories returned `Repository not found`, likely because they are private or require GitHub credentials with access.

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
