# pi06 / RECAP 机制、代码现状与 Franka SR 实验计划

## 1. 当前实验设定

我们这轮实验按 **单臂 Franka** 做部署评测。

已知任务：

| Task | Prompt / task id | 模型权重 | 评测次数 | 指标 |
| --- | --- | --- | ---: | --- |
| task01 | `stack_bowls_in_size_order_rc` | `sft_franka_shuo_pi05/global_step_15000/full_weights.pt` | 30 | SR |
| task02 | `place_ring_on_rod_rc_0810` | `sft_franka_shuo_pi05/global_step_15000/full_weights.pt` | 30 | SR |

SR 计算：

```text
SR = successes / 30
```

每个 task 要记录 30 次 rollout 的成功/失败、视频、日志、失败原因和人工备注。建议同时记录：

| 字段 | 说明 |
| --- | --- |
| `task` | task01 / task02 / task03... |
| `trial` | 1-30 |
| `checkpoint` | 当前部署 checkpoint |
| `prompt` | 训练/推理使用的 task description |
| `success` | 1 成功，0 失败 |
| `steps` | episode 步数 |
| `timeout` | 是否超时 |
| `intervention` | 是否人工介入 |
| `safety_stop` | 是否安全停止 |
| `video_path` | 对应视频路径 |
| `notes` | 失败原因或异常说明 |

## 2. RECAP 是什么

RECAP 全称是 **RL with Experience and Corrections via Advantage-conditioned Policies**。

核心目标：让 VLA 不只从成功示教学习，还能从真机部署中的成功、失败、人工纠正和自主经验中继续变强。

它解决的问题是：普通 SFT 只看“正确示范”，机器人一旦执行时偏离示教分布，就容易进入没见过的状态并连续犯错。RECAP 的思路是把 rollout 过程中的状态和结果也纳入训练，通过 value / advantage 告诉模型哪些状态-动作更接近成功，哪些更差。

## 3. pi06 RECAP 的高层机制

根据 Physical Intelligence 的 `π*0.6` 论文/博客，完整 RECAP 大致是一个可迭代闭环：

```text
1. 初始 VLA / SFT policy
   ↓
2. 真机部署，收集自主 rollout
   ↓
3. 记录 episode outcome reward：成功 / 失败 / 超时等
   ↓
4. 可选：人工接管或纠正，收集 correction trajectory
   ↓
5. 用 collected data 训练 / 更新 value function
   ↓
6. 计算每个 timestep 或 chunk 的 advantage
   ↓
7. 用 advantage-conditioned policy extraction 更新 VLA
   ↓
8. 得到更强 policy，再回到真机继续收集和训练
```

更具体地说，RECAP 包含三个关键思想：

### 3.1 Experience：自主经验

机器人用当前 policy 上真机执行任务，产生 rollout。rollout 里既有成功，也有失败，还会包含 SFT 示教里没有的偏离状态。

这些数据很重要，因为它们反映了模型真实部署时会犯什么错，而不是只反映人类示教的理想轨迹。

### 3.2 Corrections：人工纠正 / 接管

当机器人卡住、走偏或快失败时，人可以接管，把任务从错误状态带回可恢复轨迹，或直接完成任务。

这样能补齐“失败附近如何恢复”的数据。对真机任务来说，这比重新采集大量完整成功示教更高效。

### 3.3 Advantage-conditioned Policies：优势条件策略

RECAP 不只是简单地把成功数据当正样本、失败数据当负样本。它会训练 value function 来估计某个 observation / trajectory segment 对最终任务成功的价值，然后计算 advantage。

一个简化形式：

```text
A_t = return_from_t - V(o_t)
```

RLinf 文档里的 N-step 形式更接近：

```text
A_t = normalize(r_{t:t+N}) + gamma^N * V(o_{t+N}) - V(o_t)
```

然后根据 advantage 把样本分成 positive / negative：

- positive：比 value 预期更好，更值得模仿或增强。
- negative：比 value 预期更差，应弱化或作为 unconditional 分支。

策略训练时把 advantage 标签写进条件输入，类似 classifier-free guidance：

```text
prompt: "place ring on rod"
condition: "Advantage: positive"
```

推理时可以提高 positive condition 的引导强度，使模型更偏向高 advantage 行为。

## 4. RLinf 里已经实现的 RECAP 是什么

我们参考的 RLinf 公开代码里，RECAP 是一个 **面向 pi0.5 的离线 advantage-based policy optimization pipeline**。

RLinf 的 RECAP pipeline 是 4 步：

```text
Step 1: compute returns
Step 2: value model SFT
Step 3: compute advantages
Step 4: CFG training
```

对应代码：

| 阶段 | 代码 / 配置 |
| --- | --- |
| Compute returns | `examples/offline_rl/config/recap_compute_returns.yaml` |
| Value model SFT | `examples/offline_rl/config/recap_value_model_sft.yaml` |
| Compute advantages | `examples/offline_rl/config/recap_compute_advantages.yaml` |
| CFG policy training | `examples/offline_rl/config/recap_cfg_openpi_libero.yaml` |
| 数据集处理 | `rlinf/data/datasets/recap/` |
| value model | `rlinf/models/embodiment/value_model/recap/` |
| CFG action model | `rlinf/models/embodiment/openpi_cfg/` |

这套公开实现明确围绕 `pi05` / `pi0.5`：

- RLinf RECAP 文档写的是 improve a `π0.5` policy。
- 配置里使用 `model_type: "pi05"`。
- Franka 相关 OpenPI config 是 `pi05_franka_pnp`、`pi05_franka_state`、`pi05_dualfranka_tcp_rot6d`。
- 本仓库全局搜索没有发现可运行的 `pi06` / `pi0_6` / `pi0.6` 模型配置。

## 5. pi06 RECAP 和 RLinf 重构 pi05 torch 的区别

这里要分清三个概念：

### 5.1 pi0.5 / pi05

`pi0.5` 是 Physical Intelligence 在 OpenPI 公开体系里的升级版 VLA。OpenPI 公开仓库在 2025-09 之后提供 PyTorch 支持，并公开了 pi0.5 的训练/推理支持。

我们当前代码里可直接跑的 Franka 路径就是：

```text
OpenPI pi0.5 / pi05
  + RLinf realworld Franka env
  + RLinf eval runner
  + full_weights.pt 微调权重
```

### 5.2 RLinf 重构的 pi05 torch

RLinf 里有两套相关实现：

| 实现 | 路径 | 作用 |
| --- | --- | --- |
| `openpi` | `rlinf/models/embodiment/openpi/` | 接入 OpenPI 风格模型，用于 RLinf 训练/评测 |
| `openpi_rlinf` | `rlinf/models/embodiment/openpi_rlinf/` | RLinf 版 PyTorch pi0.5 重构实现，方便 FSDP、RLT、RL pipeline 集成 |

也就是说，RLinf 重构 pi05 torch 主要是工程实现层面的事情：把 pi0.5 模型放进 RLinf 的分布式训练、rollout、checkpoint、数据转换框架里。

它不是 `pi06`，也不等价于 PI 官方 `π*0.6`。

### 5.3 pi06 / π*0.6 RECAP

PI 官方论文/博客里的 `π*0.6` 是用完整 RECAP 方法训练后的模型系列。它包含：

- `π0.6` base VLA
- 真机 rollout 数据
- 人工 correction / intervention 数据
- value function 训练
- advantage-conditioned policy extraction
- 可能还有 PI 内部系统、数据、模型细节和工程技巧

公开 OpenPI 仓库目前没有完整 `π0.6 + RECAP` 训练源码。OpenPI issue 里也有人问过 RECAP 训练何时支持，问题中明确指出当前 OpenPI 代码主要是 supervised learning，缺少 value training、advantage computation、advantage-conditioned policy architecture、online RL loop、human correction integration 等组件。

因此，从当前公开资料看：

```text
补 pi06 RECAP != 直接打开某个公开源码开关
补 pi06 RECAP ≈ 基于论文和可参考代码复现 / 近似实现
```

更准确地说，我们能做的是：

1. 用公开 RLinf 的 pi0.5 RECAP pipeline 作为 baseline。
2. 用师兄给的 `RealWorld-RLinf` 和 `sft_franka_shuo_pi05` 权重先完成单臂 Franka 部署与 SR 测评。
3. 如果一定要“pi06 RECAP”，需要确认师兄是否有内部源码、checkpoint 或 config diff。
4. 如果没有内部源码，就需要按 PI 论文复现关键模块，而不是简单迁移 RLinf 的 pi05 torch。

## 6. 对我们当前任务的判断

当前最稳的执行路径：

```text
先不要假设已有 pi06 recap 公开实现。

短期目标：
  单臂 Franka
  task01 / task02
  每个 task 30 次
  用 sft_franka_shuo_pi05 full_weights.pt 部署
  统计 SR

中期目标：
  如果收集到 rollout / failure / intervention 数据
  用 RLinf pi0.5 RECAP pipeline 做离线提升
  再测 task01/task02 的 SR 对比

长期目标：
  若师兄要求补 pi06 recap
  需要拿到 pi06 base/checkpoint/config 或按论文复现
```

## 7. 单臂 Franka 30 次 SR 实验流程

### 7.1 下载权重

```bash
cd /data/yangky/test/pi05-Recap-Franka
bash scripts/franka/download_shuo_pi05_weights.sh
```

默认得到：

```text
checkpoints/sft_franka_shuo_pi05/checkpoints/global_step_15000/actor/model_state_dict/full_weights.pt
```

### 7.2 配置 pi0.5 Franka base/assets

师兄给的 Hugging Face 路径只包含 `full_weights.pt`，没有 normalization assets。

所以部署时：

```yaml
runner:
  ckpt_path: checkpoints/sft_franka_shuo_pi05/checkpoints/global_step_15000/actor/model_state_dict/full_weights.pt

rollout:
  model:
    model_path: /path/to/pi05_franka_pnp_base_or_assets_checkpoint

actor:
  model:
    model_path: /path/to/pi05_franka_pnp_base_or_assets_checkpoint
```

`model_path` 需要能提供 `pi05_franka_pnp` 对应的 assets / norm stats。

### 7.3 配置单臂 Franka

当前模板：

```text
evaluations/realworld/franka_5tasks/task01.yaml
evaluations/realworld/franka_5tasks/task02.yaml
```

必须按实验台实际情况修改：

```yaml
cluster:
  num_nodes: 2
  node_groups:
    - label: "4090"
      node_ranks: 0
    - label: franka
      node_ranks: 1
      hardware:
        type: Franka
        configs:
          - robot_ip: <robot_ip>
            node_rank: 1

env:
  eval:
    override_cfg:
      target_ee_pose: <target_ee_pose>
      camera_serials: ["<camera_serial_1>", "<camera_serial_2>"]
```

### 7.4 启动 Ray

GPU/head 节点：

```bash
export RLINF_NODE_RANK=0
export RLINF_COMM_NET_DEVICES=<gpu_node_network_device>

ray stop -f
ray start --head --port=6379 --node-ip-address=<gpu_node_ip>
```

Franka 控制节点：

```bash
export RLINF_NODE_RANK=1
export RLINF_COMM_NET_DEVICES=<robot_node_network_device>

ray stop -f
ray start --address='<gpu_node_ip>:6379'
```

### 7.5 每个 task 跑 30 次

建议逐个 task 跑，真机不要完全无人值守。

task01：

```bash
export REPO_PATH=/data/yangky/test/pi05-Recap-Franka
export EMBODIED_PATH="${REPO_PATH}/examples/embodiment"
export PYTHONPATH="${REPO_PATH}:${PYTHONPATH:-}"
export HYDRA_FULL_ERROR=1

python evaluations/eval_embodied_agent.py \
  --config-path evaluations/realworld/franka_5tasks \
  --config-name task01 \
  algorithm.eval_rollout_epoch=30 \
  env.eval.max_steps_per_rollout_epoch=240 \
  env.eval.max_episode_steps=240 \
  runner.logger.log_path="${REPO_PATH}/logs/franka_5tasks/task01/$(date +%Y%m%d-%H%M%S)"
```

task02：

```bash
python evaluations/eval_embodied_agent.py \
  --config-path evaluations/realworld/franka_5tasks \
  --config-name task02 \
  algorithm.eval_rollout_epoch=30 \
  env.eval.max_steps_per_rollout_epoch=240 \
  env.eval.max_episode_steps=240 \
  runner.logger.log_path="${REPO_PATH}/logs/franka_5tasks/task02/$(date +%Y%m%d-%H%M%S)"
```

如果代码实际按 `env.eval.rollout_epoch` 控制 episode 数，则同时覆盖：

```bash
env.eval.rollout_epoch=30
```

### 7.6 统计 SR

从日志中找成功指标：

```bash
rg -n "env/success_once|success_once|success" logs/franka_5tasks
```

人工表格统计：

| Task | Trials | Successes | SR |
| --- | ---: | ---: | ---: |
| stack_bowls_in_size_order_rc | 30 | TBD | `successes / 30` |
| place_ring_on_rod_rc_0810 | 30 | TBD | `successes / 30` |

## 8. 结论

当前可以确定：

1. 我们现在是 **单臂 Franka**，每个 task 测 **30 次 SR**。
2. 师兄给的权重是 `pi05` Franka SFT 联合权重，不是公开 `pi06 recap` 源码。
3. RLinf 公开代码里有 `pi0.5 RECAP` pipeline，可以作为可运行 baseline。
4. PI 官方 `π*0.6 + RECAP` 机制公开在论文/博客里，但完整训练源码和 `π0.6` base/checkpoint 在 OpenPI/RLinf 里没有直接公开。
5. 所以“补 pi06 recap”大概率意味着：
   - 要么师兄另有内部源码/权重/config，需要同步过来；
   - 要么我们要按论文和 RLinf pi0.5 RECAP 代码做复现或近似实现。

## 9. 参考链接

- PI `π*0.6` paper: <https://arxiv.org/abs/2511.14759>
- PI `π*0.6` blog: <https://www.pi.website/blog/pistar06>
- OpenPI repo: <https://github.com/Physical-Intelligence/openpi>
- OpenPI issue about RECAP support: <https://github.com/Physical-Intelligence/openpi/issues/857>
- RLinf RECAP docs: <https://rlinf.readthedocs.io/en/latest/rst_source/examples/embodied/recap.html>
- RLinf repo: <https://github.com/RLinf/RLinf>
- RealWorld-RLinf reference: <https://github.com/1018weijia/RealWorld-RLinf>
- JianZhangAI Real-RL weights: <https://huggingface.co/JianZhangAI/Real-RL>
