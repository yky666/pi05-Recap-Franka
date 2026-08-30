# pi05-Recap-Franka

本仓库用于 **单臂 Franka 真机上测 OpenPI + RECAP 模型在任务上的成功率 SR**。当前默认实验协议是每个 task 跑 30 次：

```text
SR = successes / 30
```

先把结论说清楚：师兄这次给的是自己训练的 **Franka pi0.5 联合 SFT checkpoint**，训练配置来自 `RealWorld-RLinf` 的 `franka` 分支：`examples/sft/config/franka_pi05_rlinf.yaml`，训练命令是：

```bash
bash examples/sft/run_vla_sft.sh franka_pi05_rlinf
```

因此当前部署和 SR 测评应优先对齐这套 `pi05_franka_shuo` 数据加载、相机输入和 normalization stats。公开代码里没有可直接运行的 `pi06` / `pi0.6` RECAP 源码；如果后续要补 `pi06 RECAP`，大概率需要拿到内部代码或按论文复现。

## 目标

在 5 个 Franka 真机任务上分别运行策略 rollout，统计每个任务的：

- 总测试次数 `trials`
- 成功次数 `successes`
- 成功率 `SR = successes / trials`
- 对应 checkpoint、配置、视频、日志和失败备注

RLinf 推荐关注的日志指标是：

- `env/success_once`：未归一化的 episodic success rate 信号
- `env/return`
- `env/episode_len`

## 关键文件

- `README.md`：本文件，具体部署和实验流程。
- `PI05_RECAP_FRANKA_NOTES.md`：pi05 代码地图、外部链接状态和实验注意事项。
- `docs/PI06_RECAP_MECHANISM_AND_PLAN.md`：可直接贴到飞书的 pi06/RECAP 机制、pi05 torch 区别和单臂 Franka 30 次 SR 计划。
- `docs/franka_cs_deployment.md`：amax 推理服务端 + pnp 机器人客户端的 C/S 部署步骤，可直接贴到飞书。
- `docs/franka_5task_launch.md`：五个 Franka task 的 amax/pnp 启动命令和切换流程。
- `docs/franka_recap_rollout_labeling.md`：pnp 端 rollout 保存路径、`is_success` 标注方式和 RECAP 数据准备。
- `docs/UPSTREAM_RLINF_README.md`：原始 RLinf README 备份。
- `scripts/franka/download_shuo_pi05_weights.sh`：下载师兄给的 Franka pi0.5 联合微调权重。
- `evaluations/realworld/realworld_pnp_eval_pi05_sft_RTC.yaml`：单臂 Franka + OpenPI pi0.5 + RTC 测评模板。
- `evaluations/realworld/franka_5tasks/task01.yaml`：`stack_bowls_in_size_order_rc` 测评模板。
- `evaluations/realworld/franka_5tasks/task02.yaml`：`place_ring_on_rod_rc_0810` 测评模板。
- `examples/embodiment/config/realworld_eval_dual_franka.yaml`：双臂 Franka 测评模板。
- `examples/offline_rl/config/recap_*.yaml`：RECAP 离线训练 4 个阶段配置。
- `toolkits/realworld_check/`：真机、相机、夹爪、GELLO/PICO 检查脚本。
- `rlinf/envs/realworld/franka/`：Franka 真机环境。
- `rlinf/models/embodiment/openpi/`：OpenPI 模型接入。
- `rlinf/models/embodiment/openpi_rlinf/`：RLinf 版 PyTorch OpenPI/pi0.5。
- `rlinf/data/datasets/recap/`：RECAP 数据处理。
- `rlinf/models/embodiment/value_model/recap/`：RECAP value model。

## 0. 实验前必须确认的信息

先和师兄或实验表格确认这些值，否则不要直接上真机：

| 项 | 需要确认的内容 |
| --- | --- |
| 机器人 | 当前按单臂 Franka |
| 5 个 task | 每个任务名称、自然语言 prompt、初始摆放、成功标准 |
| checkpoint | RECAP 后策略 checkpoint 路径 |
| 模型名 | 公开 `pi05/pi0.5`，或内部微调 checkpoint |
| action interface | 当前对齐 `pi05_franka_shuo`：7D Franka EE action，32 chunk |
| 摄像头 | 当前对齐 3 路图像：`global_image`、`right_image`、`wrist_image` |
| 夹爪 | Franka hand / Robotiq |
| 试验次数 | 每个 task 30 次 |
| 记录方式 | 是否保存视频、是否导出 LeRobot rollout 数据 |

## 1. 克隆仓库

```bash
cd /data/yangky/test
git clone https://github.com/yky666/pi05-Recap-Franka.git
cd pi05-Recap-Franka
```

如果本地已经有仓库：

```bash
cd /data/yangky/test/pi05-Recap-Franka
git pull
```

## 2. 安装环境

RLinf 真机 Franka 通常分两类节点：

- GPU 节点：跑 actor / rollout / 模型推理。
- Franka 控制节点：连接 Franka、相机、夹爪，跑 env worker。

### 2.1 GPU 节点

Docker 方式：

```bash
cd /data/yangky/test/pi05-Recap-Franka

docker run -it --rm --gpus all \
  --shm-size 20g \
  --network host \
  --name rlinf-franka-eval \
  -v "$(pwd)":/workspace/RLinf \
  rlinf/rlinf:agentic-rlinf0.4-franka

cd /workspace/RLinf
source switch_env openpi
```

本地 venv 方式：

```bash
cd /data/yangky/test/pi05-Recap-Franka
bash requirements/install.sh embodied --model openpi --env franka
source .venv/bin/activate
pip install -e .
```

### 2.2 Franka 控制节点

控制节点需要和 Franka 固件匹配的 libfranka / ROS 环境。RLinf 文档中建议 Franka firmware `<5.9.0`，常用兼容版本是 `5.7.2`。

```bash
cd /path/to/pi05-Recap-Franka
bash requirements/install.sh embodied --env franka
source .venv/bin/activate
pip install -e .
```

如果实验室机器有固定 ROS/libfranka setup 脚本，先 source 它，再启动 Ray。

## 3. 准备模型和数据

最终测评至少需要：

- 策略 checkpoint：例如师兄给的 `sft_franka_shuo_pi05/global_step_15000` 联合微调权重
- 与训练数据匹配的 OpenPI normalization stats
- 与 checkpoint 匹配的 OpenPI config name

当前仓库里常见 Franka 相关 config name：

- 师兄联合权重：`pi05_franka_shuo`
- 单臂 PnP：`pi05_franka_pnp`
- 单臂 state：`pi05_franka_state`
- 双臂 TCP rot6d：`pi05_dualfranka_tcp_rot6d`

不要把模型权重、数据集、机器人 IP、相机 serial、飞书密码等提交到 git。

### 3.1 下载师兄给的联合微调 / RLT 权重

师兄给了两套 Franka pi0.5 权重：

| 用途 | Hugging Face 路径 | checkpoint | asset id |
| --- | --- | --- | --- |
| bowls / ring 前两个任务 | `franka/rlinf/sft_franka_shuo_pi05` | `global_step_15000/actor/model_state_dict/full_weights.pt` | `franka_shuo_bowls_ring` |
| fruits / charger / peg 后续任务 | `franka/rlinf/20260828-080659-franka_pi05_rlinf_d2` | `global_step_23000/actor/model_state_dict/full_weights.pt` | `franka_shuo_fruits_charger_peg` |

每个 `full_weights.pt` 约 12.5 GiB。amax 的 `/data` 当前空间不够，默认下载到 `/home/amax/checkpoints/pi05-Recap-Franka`：

```bash
cd /data/yangky/test/pi05-Recap-Franka
bash scripts/franka/download_shuo_pi05_weights.sh
```

默认输出路径：

```text
/home/amax/checkpoints/pi05-Recap-Franka/sft_franka_shuo_pi05/checkpoints/global_step_15000/actor/model_state_dict/full_weights.pt
/home/amax/checkpoints/pi05-Recap-Franka/20260828-080659-franka_pi05_rlinf_d2/sft_franka_shuo_pi05/checkpoints/global_step_23000/actor/model_state_dict/full_weights.pt
```

如果要放到别的目录：

```bash
bash scripts/franka/download_shuo_pi05_weights.sh /home/amax/checkpoints/pi05-Recap-Franka
```

注意 Hugging Face 这两个目录只包含 `full_weights.pt` 和训练日志，没有单独上传 OpenPI assets / norm stats。根据训练日志，norm stats 已在 amax 上整理到：

```text
/home/amax/checkpoints/pi05-Recap-Franka/assets/franka_shuo_bowls_ring/norm_stats.json
/home/amax/checkpoints/pi05-Recap-Franka/assets/franka_shuo_fruits_charger_peg/norm_stats.json
```

仓库内也保留了一份同样的 stats 作为 fallback：

```text
scripts/franka/norm_stats/franka_shuo_bowls_ring/norm_stats.json
scripts/franka/norm_stats/franka_shuo_fruits_charger_peg/norm_stats.json
```

部署时：

- `runner.ckpt_path` 指向这个 `full_weights.pt`。
- `rollout.model.model_path` 和 `actor.model.model_path` 指向本地 `pi05_base_openpi_rlinf`。
- `rollout.model.openpi.config_name` 和 `actor.model.openpi.config_name` 使用 `pi05_franka_shuo`。
- `openpi_data.asset_id` 和 `openpi_data.norm_stats_path` 必须按上表和 task 组切换。

这里仍然需要 `pi05_base`，原因是 RLinf/OpenPI 的 PyTorch wrapper 会先用 base config 和 base 参数实例化模型结构，再加载师兄训练出来的 `full_weights.pt` 覆盖 actor 权重。推理输出 action 的不是官方裸 `pi05_base`，而是 `pi05_base + full_weights.pt + 对应 norm_stats` 组合后的你们自训策略。

师兄训练配置里的关键路径是：

```yaml
actor:
  model:
    model_path: /vast/users/xiaodan/zhangjian/RealRL/pi05_base_openpi_rlinf
    openpi:
      assets_dir: /vast/users/xiaodan/zhangjian/RealRL/pi05_base_openpi_rlinf/assets
      asset_id: franka_shuo_bowls_ring
    openpi_data:
      norm_stats_path: /vast/users/xiaodan/zhangjian/RealRL/pi05_base_openpi_rlinf/assets/franka_shuo_bowls_ring/norm_stats.json
```

部署机器上需要把这些路径替换成本地真实路径。不要只下载 `full_weights.pt` 就直接跑；如果 checkpoint、norm stats 或相机顺序不一致，SR 会失真。

### 3.2 已知任务和权重对应关系

根据 HF 训练日志，当前权重覆盖的数据目录如下：

| Task YAML | Task id | Prompt | 默认 checkpoint |
| --- | --- | --- | --- |
| `task01.yaml` | `stack_bowls_in_size_order_rc` | `Stack the three bowls in size order: the purple bowl first, then the beige bowl.` | `front2: sft_franka_shuo_pi05/global_step_15000` |
| `task02.yaml` | `place_ring_on_rod_rc_0810` | `Place the ring on the rod.` | `front2: sft_franka_shuo_pi05/global_step_15000` |
| `task03.yaml` | `place_fruits_on_plate_rc` | `Place all the fruits on the plate.` | `d2: 20260828-080659-franka_pi05_rlinf_d2/global_step_23000` |
| `task04.yaml` | `plug_charger_into_socket_rc` | `Plug the charger into the socket.` | `d2: 20260828-080659-franka_pi05_rlinf_d2/global_step_23000` |
| `task05.yaml` | `insert_peg_into_hole_rc` | `Insert the peg into the corresponding hole.` | `d2: 20260828-080659-franka_pi05_rlinf_d2/global_step_23000` |

训练日志里还包含 new-side 数据目录：`new_side/place_ring_on_rod_new_side_rc`、`new_side/plug_charger_into_socket_new_side_rc`、`new_side/insert_peg_into_hole_new_side_rc`。如果实验表格把 new-side 作为独立 task，需要先确认对应训练数据 `meta/tasks.jsonl` 里的自然语言 prompt，再把 pnp `TASK` 和 amax `TASK_PROMPT` 精确改成那个原文，并继续使用同一组 checkpoint / asset id。

`TASK_PROMPT` / `TASK` 不是“语义差不多就行”，应使用训练数据里的原始 task description，大小写和标点也保持一致。

## 4. 配置 5 个任务的 eval YAML

仓库已经提供了 5 个单臂 Franka eval 模板：

```bash
evaluations/realworld/franka_5tasks/task01.yaml
evaluations/realworld/franka_5tasks/task02.yaml
evaluations/realworld/franka_5tasks/task03.yaml
evaluations/realworld/franka_5tasks/task04.yaml
evaluations/realworld/franka_5tasks/task05.yaml
```

这些模板来自 `evaluations/realworld/realworld_pnp_eval_pi05_sft_RTC.yaml`，但 `task01.yaml` 和 `task02.yaml` 已经改成对齐师兄的 `pi05_franka_shuo`。每个 `taskXX.yaml` 至少改这些字段：

```yaml
cluster:
  node_groups:
    - label: "4090"
      node_ranks: 0
    - label: franka
      node_ranks: 1
      hardware:
        type: Franka
        configs:
          - robot_ip: ROBOT_IP
            node_rank: 1

runner:
  logger:
    log_path: "../results"
    experiment_name: "franka_taskXX_pi05_recap_eval"
  only_eval: True

env:
  eval:
    total_num_envs: 1
    max_episode_steps: 240
    max_steps_per_rollout_epoch: 240
    video_cfg:
      save_video: True
      video_base_dir: ${runner.logger.log_path}/video/eval
    data_collection:
      enabled: True
      save_dir: "/path/to/eval_rollouts/taskXX"
      export_format: "lerobot"
      only_success: False
    override_cfg:
      target_ee_pose: TARGET_EE_POSE
      camera_serials: ["GLOBAL_CAMERA_SERIAL", "RIGHT_CAMERA_SERIAL", "WRIST_CAMERA_SERIAL"]
      main_image_key: GLOBAL_CAMERA_KEY
      max_num_steps: 240

rollout:
  model:
    model_path: /path/to/pi05_base_openpi_rlinf
    openpi_data:
      asset_id: "franka_shuo_bowls_ring"
      norm_stats_path: /path/to/pi05_base_openpi_rlinf/assets/franka_shuo_bowls_ring/norm_stats.json
    openpi:
      config_name: "pi05_franka_shuo"
      num_images_in_input: 3

actor:
  model:
    model_path: /path/to/pi05_base_openpi_rlinf
    openpi_data:
      asset_id: "franka_shuo_bowls_ring"
      norm_stats_path: /path/to/pi05_base_openpi_rlinf/assets/franka_shuo_bowls_ring/norm_stats.json
    openpi:
      config_name: "pi05_franka_shuo"
      num_images_in_input: 3
```

对师兄给的 `full_weights.pt`，同时设置：

```yaml
runner:
  ckpt_path: checkpoints/sft_franka_shuo_pi05/checkpoints/global_step_15000/actor/model_state_dict/full_weights.pt
```

相机输入要和训练数据加载对齐。`franka_pi05_rlinf.yaml` 对应的数据字段是：

| 训练字段 | 推理侧要求 |
| --- | --- |
| `observation/global_image` | `env.eval.main_image_key` 对应的物理主视角 |
| `observation/right_image` | 额外相机第 1 路 |
| `observation/wrist_image` | 额外相机第 2 路 |
| `observation/state` | Franka 当前 7D EE / gripper state |
| `actions` | 7D Franka EE action |

当前仓库已加入 `pi05_franka_shuo` 的 data config 和 policy transform。真机 eval adapter 会提供 `observation/image` 和 `observation/extra_view_image`，`franka_ee_shuo_policy.py` 里做了兼容映射：主图 fallback 到 `global_image`，额外两路按顺序映射到 `right_image` 和 `wrist_image`。因此实际部署前必须确认 `camera_serials` 排序和 `main_image_key` 正确。

如果任务需要语言 prompt，且对应 env 支持 `task_description`，加到：

```yaml
env:
  eval:
    override_cfg:
      task_description: "pick up the object and place it into the container"
```

双臂 Franka 则从这个文件复制：

```bash
cp examples/embodiment/config/realworld_eval_dual_franka.yaml evaluations/realworld/franka_5tasks/task01.yaml
```

双臂需要额外填：

- `left_robot_ip`
- `right_robot_ip`
- `base_camera_serials`
- `left_camera_serials`
- `right_camera_serials`
- `left_gripper_connection`
- `right_gripper_connection`
- `actor.model.openpi.config_name: pi05_dualfranka_tcp_rot6d`

## 5. 真机硬件检查

这些命令在 Franka 控制节点跑。

### 5.1 检查 Franka controller

```bash
export FRANKA_ROBOT_IP=<robot_ip>
python -m toolkits.realworld_check.test_franka_controller --robot-ip "$FRANKA_ROBOT_IP"
```

如果使用 libfranka/franky backend，可检查：

```bash
python -m toolkits.realworld_check.test_franky_controller --robot-ip "$FRANKA_ROBOT_IP"
```

### 5.2 检查相机

```bash
python -m toolkits.realworld_check.test_franka_camera
```

也可以按实际设备检查：

```bash
python -m toolkits.realworld_check.test_zed_camera
python -m toolkits.realworld_check.test_lumos_camera
```

### 5.3 检查夹爪

Robotiq：

```bash
python -m toolkits.realworld_check.test_robotiq_gripper
```

Franka hand 相关代码在：

```text
rlinf/envs/realworld/common/gripper/franka_gripper.py
rlinf/envs/realworld/franka/end_effectors/franka_gripper.py
```

### 5.4 配置键盘成功/失败标注

如果使用键盘标注 success/failure：

```bash
ls -l /dev/input/by-id/*-event-kbd
sudo chmod 666 /dev/input/eventXX
export RLINF_KEYBOARD_DEVICE=/dev/input/eventXX
```

注意：`RLINF_KEYBOARD_DEVICE` 必须在 `ray start` 之前 export，因为 Ray 会继承启动时的环境变量。

## 6. 启动 Ray

### 6.1 GPU 节点

```bash
export RLINF_NODE_RANK=0
export RLINF_COMM_NET_DEVICES=<gpu_node_network_device>

ray stop -f
ray start --head --port=6379 --node-ip-address=<gpu_node_ip>
```

### 6.2 Franka 控制节点

```bash
export RLINF_NODE_RANK=1
export RLINF_COMM_NET_DEVICES=<robot_node_network_device>
export RLINF_KEYBOARD_DEVICE=/dev/input/eventXX

ray stop -f
ray start --address='<gpu_node_ip>:6379'
```

单机调试时可以把 YAML 里的 `cluster.num_nodes` 改成 `1`，并把 actor/env/rollout placement 都放到同一个 node group。

## 7. 跑单个 task 测评

如果采用 **amax 起推理 service，pnp 机器开 client** 的方式，不需要先启动 RLinf Ray eval；amax 只负责加载模型并通过 WebSocket 返回 action chunk。

### 7.1 amax 启动 pi05 Franka 推理服务

在 amax 上：

```bash
cd /data/yangky/test/pi05-Recap-Franka

export REPO_PATH="$(pwd)"
export PYTHONPATH="${REPO_PATH}:${PYTHONPATH:-}"
export HYDRA_FULL_ERROR=1

python scripts/franka/serve_shuo_pi05_policy.py \
  --host 0.0.0.0 \
  --port 33050 \
  --model-path /home/amax/.cache/huggingface/hub/models--lerobot--pi05_base/snapshots/9e55186ad36e66b95cda57bc47818d9e6237ae30 \
  --assets-dir /home/amax/.cache/huggingface/hub/models--lerobot--pi05_base/snapshots/9e55186ad36e66b95cda57bc47818d9e6237ae30 \
  --norm-stats-path /home/amax/checkpoints/pi05-Recap-Franka/assets/franka_shuo_bowls_ring/norm_stats.json \
  --ckpt-path /home/amax/checkpoints/pi05-Recap-Franka/sft_franka_shuo_pi05/checkpoints/global_step_15000/actor/model_state_dict/full_weights.pt \
  --asset-id franka_shuo_bowls_ring \
  --config-name pi05_franka_shuo \
  --num-action-chunks 32 \
  --num-steps 5 \
  --response-horizon 32 \
  --default-prompt "Stack the three bowls in size order: the purple bowl first, then the beige bowl."
```

amax 上已确认存在的 pi0.5 base model 路径是：

```text
/home/amax/.cache/huggingface/hub/models--lerobot--pi05_base/snapshots/9e55186ad36e66b95cda57bc47818d9e6237ae30
```

这个 snapshot 只有 `config.json` 和 `model.safetensors`，没有训练资产目录；Shuo 权重必须额外配套训练时的 norm stats。当前 amax 已从 HF 训练日志整理了两份 stats 到 `/home/amax/checkpoints/pi05-Recap-Franka/assets/`，不要拿旧 `stack_bowls_rc` / `pick_and_place_cup_rc` 的 stats 顶替。

推荐用 amax 专用启动脚本。这个脚本已经写入当前 amax 上实际存在的 pi0.5 base model 路径，并会按 `CKPT_PROFILE` 自动选择 checkpoint 和 norm stats：

```bash
cd /data/yangky/test/pi05-Recap-Franka

# 前两个任务：stack bowls / place ring
export CKPT_PROFILE=front2
export TASK_PROMPT="Stack the three bowls in size order: the purple bowl first, then the beige bowl."
bash scripts/franka/run_shuo_pi05_service_amax.sh

# 后续 fruits / charger / peg 任务
export CKPT_PROFILE=d2
export TASK_PROMPT="Place all the fruits on the plate."
bash scripts/franka/run_shuo_pi05_service_amax.sh
```

amax 上已准备好的推理环境是 `/home/amax/venvs/pi05-franka-service`，启动脚本会自动激活它。不要直接在 base 环境里跑 `python scripts/franka/serve_shuo_pi05_policy.py`，base 缺 `openpi_client/openpi/ray` 等依赖。

长时间跑实验建议用 tmux 保持服务：

```bash
tmux new-session -d -s pi05_front2 \
  'cd /data/yangky/test/pi05-Recap-Franka && export CKPT_PROFILE=front2 TASK_PROMPT="Stack the three bowls in size order: the purple bowl first, then the beige bowl." && bash scripts/franka/run_shuo_pi05_service_amax.sh'

tmux attach -t pi05_front2
```

服务启动成功后会打印：

```text
SERVER READY: ws://0.0.0.0:33050
```

如果看到 `OSError: [Errno 98] Address already in use`，说明 `33050` 上已经有一个服务在跑，不是权重或依赖失败。检查和重启：

```bash
ss -ltnp | grep 33050
tmux capture-pane -t pi05_front2 -p | tail -n 80
tmux kill-session -t pi05_front2
```

pnp client 连接地址填：

```text
ws://192.168.10.114:33050
```

pnp 机器上的 client 项目已核对：

```bash
ssh pnp@192.168.10.110
cd ~/桌面/franka_deploy_0128_ee/franka_deploy
```

注意：`启动命令.txt` / `start_all.sh` 可能仍是旧同步流程的参考命令。如果看到 `start_control.sh` 或 `start_inference.sh`，不要按它执行；当前 pi05 async 链路必须使用 `start_control_async.sh` + `start_inference_async.sh`。

实际配置文件是 `config.sh`，当前已改成：

```bash
export POLICY_SERVER_HOST="192.168.10.114"
export POLICY_SERVER_PORT="33050"
export TASK="Stack the three bowls in size order: the purple bowl first, then the beige bowl."
export MAX_ACTIONS_TO_PUBLISH="3"
export USE_LAST_ACTIONS="false"
export ASYNC_MAX_ACTIONS_TO_PUBLISH="32"
export ASYNC_USE_LAST_ACTIONS="false"
```

修改前备份在：

```text
~/桌面/franka_deploy_0128_ee/franka_deploy/config.sh.bak_20260829_pi05_shuo
```

当前 service 对齐的是 pnp 现有 OpenPI WebSocket client 协议，推荐先跑异步 client：

```bash
cd ~/桌面/franka_deploy_0128_ee/franka_deploy
export NO_PROXY=192.168.10.114,localhost,127.0.0.1
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
bash start_inference_async.sh
```

`start_inference.sh` 是同步版本，也能连同一个 service，但一次只发布较短 action chunk。`start_inference_async_rlt.sh` 和 `start_inference_rtc2.sh` 需要 RLT/RTC 专用服务端语义，当前这个 SFT 权重 service 不建议使用。

如果换到 ring 任务，把 prompt 改成：

```bash
--default-prompt "Place the ring on the rod."
```

服务端接收的 pnp payload 需要包含：

| 字段 | 说明 |
| --- | --- |
| `state.follow1_pos` 或 `state` | 单臂 Franka 7D state：`x,y,z,rx,ry,rz,gripper` |
| `views.global_image` 或 `views.camera_front` | 训练里的 `global_image` 主视角 |
| `views.right_image` 或 `views.camera_right` | 训练里的 `right_image` |
| `views.wrist_image` 或 `views.camera_wrist` | 训练里的 `wrist_image` |
| `prompt` / `instruction` / `task` | 可选；不传则使用 `--default-prompt` |

返回给 pnp client 的字段：

| 字段 | 说明 |
| --- | --- |
| `actions` | `[T, 7]` action chunk |
| `follow1_pos` | 同 `actions`，兼容老 pnp client |
| `action` | 第一个 7D action |
| `server_timing.infer_ms` | 单次推理耗时 |

注意：这条 service 路径和 `task01/task02` 的 YAML 一样走 `openpi_rlinf + pi05_franka_shuo + full_weights.pt`。它不是 OpenPI 官方 `model.safetensors` server；师兄给的 `full_weights.pt` 要按 RLinf wrapper 加载。

### 7.2 RLinf 一体式 eval

推荐直接指定自定义 config 目录：

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

也可以临时用命令行覆盖 checkpoint / robot ip：

```bash
python evaluations/eval_embodied_agent.py \
  --config-path evaluations/realworld/franka_5tasks \
  --config-name task01 \
  runner.logger.log_path="${REPO_PATH}/logs/franka_5tasks/task01/$(date +%Y%m%d-%H%M%S)" \
  runner.ckpt_path="${REPO_PATH}/checkpoints/sft_franka_shuo_pi05/checkpoints/global_step_15000/actor/model_state_dict/full_weights.pt" \
  rollout.model.model_path=/path/to/pi05_base_openpi_rlinf \
  rollout.model.openpi.assets_dir=/path/to/pi05_base_openpi_rlinf/assets \
  rollout.model.openpi_data.norm_stats_path=/path/to/pi05_base_openpi_rlinf/assets/franka_shuo_bowls_ring/norm_stats.json \
  actor.model.model_path=/path/to/pi05_base_openpi_rlinf \
  actor.model.openpi.assets_dir=/path/to/pi05_base_openpi_rlinf/assets \
  actor.model.openpi_data.norm_stats_path=/path/to/pi05_base_openpi_rlinf/assets/franka_shuo_bowls_ring/norm_stats.json \
  cluster.node_groups.1.hardware.configs.0.robot_ip=<robot_ip>
```

如果把 `task01.yaml` 放在 `evaluations/realworld/` 目录下，也可以用脚本：

```bash
bash evaluations/run_eval.sh realworld task01
```

## 8. 跑 5 个 task

真机不建议完全无人值守循环跑。推荐每个 task 单独执行，人工 reset 场景、确认安全、记录备注。

```bash
for task in task01 task02 task03 task04 task05; do
  python evaluations/eval_embodied_agent.py \
    --config-path evaluations/realworld/franka_5tasks \
    --config-name "${task}" \
    runner.logger.log_path="${REPO_PATH}/logs/franka_5tasks/${task}/$(date +%Y%m%d-%H%M%S)"
done
```

更稳妥的方式是逐条执行：

```bash
python evaluations/eval_embodied_agent.py --config-path evaluations/realworld/franka_5tasks --config-name task01
python evaluations/eval_embodied_agent.py --config-path evaluations/realworld/franka_5tasks --config-name task02
python evaluations/eval_embodied_agent.py --config-path evaluations/realworld/franka_5tasks --config-name task03
python evaluations/eval_embodied_agent.py --config-path evaluations/realworld/franka_5tasks --config-name task04
python evaluations/eval_embodied_agent.py --config-path evaluations/realworld/franka_5tasks --config-name task05
```

## 9. 统计 SR

先从日志中找 success 指标：

```bash
rg -n "env/success_once|success_once|success" logs/franka_5tasks
```

每个 task 填这个表：

| Task | Prompt | Trials | Successes | SR | Checkpoint | Config | Notes |
| --- | --- | ---: | ---: | ---: | --- | --- | --- |
| task01 | `Stack the three bowls in size order: the purple bowl first, then the beige bowl.` | 0 | 0 | 0.00 | `front2` | `task01.yaml` | TBD |
| task02 | `Place the ring on the rod.` | 0 | 0 | 0.00 | `front2` | `task02.yaml` | TBD |
| task03 | `Place all the fruits on the plate.` | 0 | 0 | 0.00 | `d2` | `task03.yaml` | TBD |
| task04 | `Plug the charger into the socket.` | 0 | 0 | 0.00 | `d2` | `task04.yaml` | TBD |
| task05 | `Insert the peg into the corresponding hole.` | 0 | 0 | 0.00 | `d2` | `task05.yaml` | TBD |

计算：

```text
SR = successes / trials
```

建议同时保存：

- 每次 rollout 的视频
- 每次 rollout 的 LeRobot 数据
- 成功/失败人工备注
- 失败原因分类：抓取失败、路径碰撞、视觉误识别、动作超界、超时、人工急停等

## 10. RECAP 离线训练流程

如果测评后收集到 rollout / human takeover / rollback 数据，需要再做一轮 RECAP 提升，流程是：

1. 计算 returns
2. 训练 value model
3. 计算 advantages
4. CFG 训练 policy
5. 拿新 checkpoint 回到第 7 步重新测 SR

相关配置：

- `examples/offline_rl/config/recap_compute_returns.yaml`
- `examples/offline_rl/config/recap_value_model_sft.yaml`
- `examples/offline_rl/config/recap_compute_advantages.yaml`
- `examples/offline_rl/config/recap_cfg_openpi_libero.yaml`

注意：公开配置主要是 LIBERO 示例，迁移到 Franka 数据时必须改：

- `data.train_data_paths`：指向 Franka LeRobot 数据集
- `data.tag`
- `advantage.returns_tag`
- `advantage.tag`
- `actor.model.model_path`
- `actor.model.openpi.config_name`
- SigLIP2 / Gemma3 / tokenizer 路径

示例命令：

```bash
# Step 1: compute returns
python examples/offline_rl/advantage_labeling/recap/process/compute_returns.py \
  --config-path examples/offline_rl/config \
  --config-name recap_compute_returns

# Step 2: value model SFT
bash examples/offline_rl/advantage_labeling/recap/run_value_sft.sh recap_value_model_sft

# Step 3: compute advantages
python examples/offline_rl/advantage_labeling/recap/process/compute_advantages.py \
  --config-path examples/offline_rl/config \
  --config-name recap_compute_advantages

# Step 4: CFG policy training
bash examples/embodiment/run_offline_rl.sh recap_cfg_openpi_libero
```

Step 4 产出的新 checkpoint 用回：

```yaml
rollout.model.model_path: /path/to/new_recap_checkpoint
actor.model.model_path: /path/to/new_recap_checkpoint
```

然后重新跑 5 个 task，比较 SR。

## 11. Efficient-RLT / Human Takeover 数据流

你给的图可以理解成一个带人工接管和回退标注的数据生成闭环：

1. 从任务起点开始 policy rollout。
2. 到潜在 rollback state 后，模型继续预测 rollout，同时判断是否需要 rollback。
3. 如果需要人工接管，记录 human takeover 段。
4. 保存 rollback path、validated rollout、success endpoint。
5. 所有片段导出为 LeRobot 格式。
6. 用 RECAP 对这些数据计算 returns / advantages。
7. CFG 训练得到新策略。
8. 在相同 5 个 task 上重新测 SR。

当前 RLinf 中可直接复用的模块：

- `env.*.data_collection.enabled`：保存 rollout/eval episode。
- `keyboard_reward_wrapper`：人工 success/failure 标注。
- `use_spacemouse` / `use_gello` / `use_pico`：人工控制或接管入口。
- `examples/embodiment/config/realworld_dual_franka_dagger_openpi.yaml`：在线人工干预/DAgger 数据采集参考。
- `examples/offline_rl/advantage_labeling/recap/`：RECAP returns/value/advantages 处理。

## 12. 每天实验 checklist

- 确认 robot workspace 清空、安全员在场。
- 确认 checkpoint 和 config name。
- 记录 git commit：

```bash
git rev-parse HEAD
```

- 检查 Franka controller。
- 检查相机。
- 检查夹爪。
- 检查键盘标注设备。
- 启动 Ray。
- 先跑 1 次低风险 dry run。
- 每个 task 按计划次数测评。
- 保存 logs、videos、LeRobot rollouts、SR 表格和失败备注。

## 参考链接

- RLinf upstream: `https://github.com/RLinf/RLinf`
- RealWorld-RLinf reference repo: `https://github.com/1018weijia/RealWorld-RLinf`
- JianZhangAI Real-RL Franka weights: `https://huggingface.co/JianZhangAI/Real-RL`
- RLinf RECAP docs: `https://rlinf.readthedocs.io/en/latest/rst_source/examples/embodied/recap.html`
- RLinf Franka docs: `https://rlinf.readthedocs.io/en/latest/rst_source/examples/embodied/franka.html`
- OpenPI: `https://github.com/Physical-Intelligence/openpi`
