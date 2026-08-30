# Franka RECAP Rollout 保存与 is_success 标注

本文档记录当前 amax + pnp C/S 部署下，如何在测 SFT baseline SR 的同时保存 rollout，并给每个 episode 打 `is_success` 标签，供后续 RECAP 使用。

官方 RECAP 文档说明：RECAP 使用 LeRobot 格式数据集，数据分为 SFT 成功轨迹和 rollout 轨迹；rollout 数据包含成功和失败。四步流程是 `compute_returns -> value model SFT -> compute_advantages -> CFG training`。官方文档链接：

```text
https://rlinf.readthedocs.io/zh-cn/latest/rst_source/examples/embodied/recap.html
```

## 1. 当前 pnp 端实际保存位置

pnp 机器：

```text
pnp@192.168.10.110
```

部署目录：

```text
/home/pnp/桌面/franka_deploy_0128_ee/franka_deploy
```

当前异步 client 启动脚本：

```bash
cd /home/pnp/桌面/franka_deploy_0128_ee/franka_deploy
bash start_control_async.sh
bash start_inference_async.sh
```

`start_inference_async.sh` 会运行：

```bash
python3 franka_inference_node_async.py ...
```

该节点每启动一次，会创建一个 session 目录：

```text
/home/pnp/桌面/franka_deploy_0128_ee/franka_deploy/logs/session_async_YYYYMMDD_HHMMSS/
```

实测目录形态如下：

```text
logs/session_async_20260830_162433/
  actions.json
  frame_states.json
  images/
    chunk_000_cam_high.jpg
    chunk_000_cam_wrist.jpg
    chunk_000_cam_side.jpg
    ...
  videos/
    cam_high.mp4
    cam_wrist.mp4
    cam_side.mp4
```

其中：

| 文件 | 内容 |
| --- | --- |
| `actions.json` | task、session、mode、每次模型输出的 action chunk、发送给模型的 state、推理耗时 |
| `frame_states.json` | 视频帧对应的 EE state |
| `images/` | 每个 inference chunk 对应的三视角观测 JPEG |
| `videos/` | 三视角完整视频 |

注意：这套 pnp 原始 session 不是标准 LeRobot 数据集；它是后续转换 LeRobot 的原始 rollout 包。RECAP 的 `compute_returns.py` 最终需要 LeRobot parquet 中有 `episode_index`、`frame_index`、`task` 或 `task_index`、以及 rollout 必需的 `is_success`。

## 2. 测 SFT baseline 时必须保存的数据

每个 task 跑 30 次。最清楚的做法是每次 trial 都重启一次 `start_inference_async.sh`，这样一个 session 目录就是一个 episode。

每次 trial 结束后记录：

| 字段 | 示例 |
| --- | --- |
| `task_id` | `stack_bowls_in_size_order_rc` |
| `prompt` | `Stack the three bowls in size order: the purple bowl first, then the beige bowl.` |
| `checkpoint_profile` | `front2` 或 `d2` |
| `trial` | `1` 到 `30` |
| `is_success` | 成功为 `1`，失败为 `0` |
| `notes` | 失败原因、人工暂停、安全停止、物体初始摆放异常等 |
| `session_dir` | `logs/session_async_YYYYMMDD_HHMMSS` |

RECAP 后续最关键的是 `is_success`。如果只记录 SR 表格，不保存 session 数据，后续无法从真实 rollout 中计算 return / advantage。

## 3. 标注单个 episode

先把本仓库脚本拷到 pnp：

```bash
scp scripts/franka/label_pnp_session.py pnp@192.168.10.110:/home/pnp/桌面/franka_deploy_0128_ee/franka_deploy/
```

在 pnp 上查看最新 session：

```bash
cd /home/pnp/桌面/franka_deploy_0128_ee/franka_deploy
ls -dt logs/session_async_* | head
```

给成功 episode 打标签：

```bash
python3 label_pnp_session.py logs/session_async_20260830_162433 \
  --success 1 \
  --trial 1 \
  --task-id stack_bowls_in_size_order_rc \
  --prompt "Stack the three bowls in size order: the purple bowl first, then the beige bowl." \
  --checkpoint-profile front2 \
  --notes "success"
```

给失败 episode 打标签：

```bash
python3 label_pnp_session.py logs/session_async_20260830_162433 \
  --success 0 \
  --trial 2 \
  --task-id stack_bowls_in_size_order_rc \
  --prompt "Stack the three bowls in size order: the purple bowl first, then the beige bowl." \
  --checkpoint-profile front2 \
  --notes "failed: bowl slipped before stacking"
```

脚本会写三个位置：

```text
logs/session_async_*/actions.json
logs/session_async_*/episode_label.json
logs/recap_episode_labels.csv
```

检查：

```bash
python3 - <<'PY'
import json
from pathlib import Path
p = Path("logs/session_async_20260830_162433/actions.json")
d = json.loads(p.read_text())
print(d["is_success"])
print(d["recap_label"])
PY

tail -n 5 logs/recap_episode_labels.csv
```

## 4. 五个任务的标注命令模板

### task01 bowls

```bash
python3 label_pnp_session.py logs/session_async_YYYYMMDD_HHMMSS \
  --success 1 \
  --trial 1 \
  --task-id stack_bowls_in_size_order_rc \
  --prompt "Stack the three bowls in size order: the purple bowl first, then the beige bowl." \
  --checkpoint-profile front2 \
  --notes ""
```

### task02 ring

```bash
python3 label_pnp_session.py logs/session_async_YYYYMMDD_HHMMSS \
  --success 1 \
  --trial 1 \
  --task-id place_ring_on_rod_rc_0810 \
  --prompt "Place the ring on the rod." \
  --checkpoint-profile front2 \
  --notes ""
```

### task03 fruits

```bash
python3 label_pnp_session.py logs/session_async_YYYYMMDD_HHMMSS \
  --success 1 \
  --trial 1 \
  --task-id place_fruits_on_plate_rc \
  --prompt "Place all the fruits on the plate." \
  --checkpoint-profile d2 \
  --notes ""
```

### task04 charger

```bash
python3 label_pnp_session.py logs/session_async_YYYYMMDD_HHMMSS \
  --success 1 \
  --trial 1 \
  --task-id plug_charger_into_socket_rc \
  --prompt "Plug the charger into the socket." \
  --checkpoint-profile d2 \
  --notes ""
```

### task05 peg

```bash
python3 label_pnp_session.py logs/session_async_YYYYMMDD_HHMMSS \
  --success 1 \
  --trial 1 \
  --task-id insert_peg_into_hole_rc \
  --prompt "Insert the peg into the corresponding hole." \
  --checkpoint-profile d2 \
  --notes ""
```

失败时只需要把 `--success 1` 改成 `--success 0`，并在 `--notes` 写失败原因。

## 5. 后续转换为 RECAP 数据

当前 pnp session 是原始 rollout 包。进入 RECAP 前，需要把它转换成 LeRobot 数据集，至少保证 parquet/meta 中有：

```text
episode_index
frame_index
task_index
task
is_success
observation images
observation state
actions
```

RECAP 的 `compute_returns.py` 对 rollout 数据集的处理逻辑是：

```text
type=sft      -> 默认整条 episode 成功
type=rollout  -> 必须读取 is_success 区分成功/失败
```

因此转换时应把 `episode_label.json` 或 `logs/recap_episode_labels.csv` 中的 `is_success` 写入每个 episode 的最后一帧，最稳妥是写入该 episode 的每一帧。

后续 RECAP 配置应使用类似：

```yaml
data:
  train_data_paths:
    - dataset_path: /path/to/franka_sft_success_dataset
      type: sft
      weight: 1.0
      robot_type: franka
      model_type: pi05
    - dataset_path: /path/to/franka_rollout_lerobot_dataset
      type: rollout
      weight: 1.0
      robot_type: franka
      model_type: pi05
  tag: franka_fail300_v1
```

然后按官方四步：

```bash
bash examples/offline_rl/advantage_labeling/recap/process/run_compute_returns.sh recap_compute_returns
bash examples/offline_rl/advantage_labeling/recap/run_value_sft.sh recap_value_model_sft
bash examples/offline_rl/advantage_labeling/recap/process/run_compute_advantages.sh recap_compute_advantages
bash examples/offline_rl/policy_optimization/cfg_rl/run_cfg_rl.sh cfg_rl_openpi
```

产出新的 CFG/RECAP policy checkpoint 后，再回到 amax + pnp 部署流程，每个 task 重新跑 30 次 SR。

## 6. 当前注意事项

1. pnp 当前 `config.sh` 中仍可能残留旧的 task id，例如 `export TASK="stack_bowls_in_size_order_rc"`。真正跑模型时应该用训练原文 prompt，而不是 task id。
2. 每次 trial 最好独立启动一次 inference node，保证一个 `session_async_*` 对应一个 episode。
3. 失败 episode 不要删除；RECAP 需要失败数据来学习 value / advantage。
4. 如果发生安全急停、Reflex、相机异常、网络断连，也保留 session，并在 `--notes` 中标清楚。
5. 当前脚本只是给原始 session 打标；标准 LeRobot 转换脚本还需要根据最终训练数据格式单独补齐。
