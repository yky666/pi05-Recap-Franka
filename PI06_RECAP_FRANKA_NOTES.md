# PI06 / RECAP / Franka Code Map

This repository is initialized from `https://github.com/RLinf/RLinf.git` for the Franka experiments that evaluate the pi0.5/pi06-style OpenPI RECAP policy on real-world Franka tasks and compute success rate (SR).

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

## Notes

- The upstream code currently names the OpenPI model configs as `pi0_5` / `pi05`; no literal `pi06` config name was found in the cloned RLinf source.
- For SR evaluation on the 5 Franka tasks, start from the real-world eval configs above and fill in the task prompts, robot IPs, camera serials, gripper connections, reset poses, and checkpoint path.
- Keep model weights, datasets, and robot-specific credentials out of git unless explicitly intended.
