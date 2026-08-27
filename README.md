# pi06-Recap-Franka

本仓库用于 **Franka 真机上测 OpenPI + RECAP 模型在 5 个任务上的成功率 SR**。

先把结论说清楚：目前从公开的 RLinf 源码、RLinf 官方 RECAP 文档和 OpenPI 文档看，代码里实际可运行的名字是 `pi05` / `pi0_5` / `pi0.5`，没有找到字面量 `pi06`、`pi0_6`、`pi0.6` 的模型或配置。因此本项目仓库名继续叫 `pi06-Recap-Franka`，但当前部署和测评流程先按 **pi0.5 + RECAP + Franka** 执行；如果师兄后续给了私有 `pi06` checkpoint 或 config diff，再把对应差异补进来。

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
- `PI06_RECAP_FRANKA_NOTES.md`：pi05/pi06 判断依据、代码地图、外部链接状态。
- `docs/UPSTREAM_RLINF_README.md`：原始 RLinf README 备份。
- `evaluations/realworld/realworld_pnp_eval_pi05_sft_RTC.yaml`：单臂 Franka + OpenPI pi0.5 + RTC 测评模板。
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
| 机器人 | 单臂 Franka 还是双臂 Franka |
| 5 个 task | 每个任务名称、自然语言 prompt、初始摆放、成功标准 |
| checkpoint | RECAP 后策略 checkpoint 路径 |
| 模型名 | 是公开 `pi05/pi0.5`，还是内部 `pi06` 变体 |
| action interface | `pi05_franka_pnp` / `pi05_franka_state` / `pi05_dualfranka_tcp_rot6d` |
| 摄像头 | camera serials、主视角 key |
| 夹爪 | Franka hand / Robotiq |
| 试验次数 | 每个 task 跑多少次，比如 10/20/30 |
| 记录方式 | 是否保存视频、是否导出 LeRobot rollout 数据 |

## 1. 克隆仓库

```bash
cd /mnt/data/yangky/test
git clone https://github.com/yky666/pi06-Recap-Franka.git
cd pi06-Recap-Franka
```

如果本地已经有仓库：

```bash
cd /mnt/data/yangky/test/pi06-Recap-Franka
git pull
```

## 2. 安装环境

RLinf 真机 Franka 通常分两类节点：

- GPU 节点：跑 actor / rollout / 模型推理。
- Franka 控制节点：连接 Franka、相机、夹爪，跑 env worker。

### 2.1 GPU 节点

Docker 方式：

```bash
cd /mnt/data/yangky/test/pi06-Recap-Franka

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
cd /mnt/data/yangky/test/pi06-Recap-Franka
bash requirements/install.sh embodied --model openpi --env franka
source .venv/bin/activate
pip install -e .
```

### 2.2 Franka 控制节点

控制节点需要和 Franka 固件匹配的 libfranka / ROS 环境。RLinf 文档中建议 Franka firmware `<5.9.0`，常用兼容版本是 `5.7.2`。

```bash
cd /path/to/pi06-Recap-Franka
bash requirements/install.sh embodied --env franka
source .venv/bin/activate
pip install -e .
```

如果实验室机器有固定 ROS/libfranka setup 脚本，先 source 它，再启动 Ray。

## 3. 准备模型和数据

最终测评至少需要：

- 策略 checkpoint：例如 `/mnt/data/checkpoints/pi05_recap_franka/global_step_XXXX`
- 与训练数据匹配的 OpenPI normalization stats
- 与 checkpoint 匹配的 OpenPI config name

当前仓库里常见 Franka 相关 config name：

- 单臂 PnP：`pi05_franka_pnp`
- 单臂 state：`pi05_franka_state`
- 双臂 TCP rot6d：`pi05_dualfranka_tcp_rot6d`

不要把模型权重、数据集、机器人 IP、相机 serial、飞书密码等提交到 git。

## 4. 配置 5 个任务的 eval YAML

仓库已经提供了 5 个单臂 Franka eval 模板：

```bash
evaluations/realworld/franka_5tasks/task01.yaml
evaluations/realworld/franka_5tasks/task02.yaml
evaluations/realworld/franka_5tasks/task03.yaml
evaluations/realworld/franka_5tasks/task04.yaml
evaluations/realworld/franka_5tasks/task05.yaml
```

这些模板来自 `evaluations/realworld/realworld_pnp_eval_pi05_sft_RTC.yaml`，默认是单臂 Franka + OpenPI pi0.5 + RTC。每个 `taskXX.yaml` 至少改这些字段：

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
      camera_serials: ["CAMERA_SERIAL1", "CAMERA_SERIAL2"]
      max_num_steps: 240

rollout:
  model:
    model_path: /path/to/pi05_or_pi06_recap_checkpoint
    openpi:
      config_name: "pi05_franka_pnp"

actor:
  model:
    model_path: /path/to/pi05_or_pi06_recap_checkpoint
    openpi:
      config_name: "pi05_franka_pnp"
```

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
  rollout.model.model_path=/path/to/checkpoint \
  actor.model.model_path=/path/to/checkpoint \
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
| task01 | TBD | 0 | 0 | 0.00 | TBD | `task01.yaml` | TBD |
| task02 | TBD | 0 | 0 | 0.00 | TBD | `task02.yaml` | TBD |
| task03 | TBD | 0 | 0 | 0.00 | TBD | `task03.yaml` | TBD |
| task04 | TBD | 0 | 0 | 0.00 | TBD | `task04.yaml` | TBD |
| task05 | TBD | 0 | 0 | 0.00 | TBD | `task05.yaml` | TBD |

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
- RLinf RECAP docs: `https://rlinf.readthedocs.io/en/latest/rst_source/examples/embodied/recap.html`
- RLinf Franka docs: `https://rlinf.readthedocs.io/en/latest/rst_source/examples/embodied/franka.html`
- OpenPI: `https://github.com/Physical-Intelligence/openpi`
