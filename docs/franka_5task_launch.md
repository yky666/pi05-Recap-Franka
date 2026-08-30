# Franka 5 Task Launch Commands

当前 C/S 部署：

- amax: pi0.5/OpenPI/RLinf policy service，监听 `192.168.10.114:33050`
- pnp: Franka 控制节点 + 异步推理 client
- 每个 task 测 30 次，SR = success_count / 30

## Prompt 要求

`TASK_PROMPT` / `TASK` 应精确匹配训练数据里的 task description。当前仓库的
`evaluations/realworld/franka_5tasks/task*.yaml` 中写死的 `task_description`
就是下面五个字符串。

不要把它改成自然语言 paraphrase，例如不要把
`stack_bowls_in_size_order_rc` 改成 `Stack bowls in size order`。如果训练数据的
`meta/tasks.jsonl` 使用的是自然语言文本，则应改成那个文件里的原文；在当前这套
Shuo pi0.5 Franka 权重里，按仓库 eval YAML 使用这些 task id 字符串。

amax 的 `TASK_PROMPT` 和 pnp 的 `config.sh` 里的 `TASK` 必须完全一致。

## Task/Weight 对应表

| Task | CKPT_PROFILE | Checkpoint | Norm stats |
| --- | --- | --- | --- |
| `stack_bowls_in_size_order_rc` | `front2` | `/home/amax/checkpoints/pi05-Recap-Franka/sft_franka_shuo_pi05/checkpoints/global_step_15000/actor/model_state_dict/full_weights.pt` | `/home/amax/checkpoints/pi05-Recap-Franka/assets/franka_shuo_bowls_ring/norm_stats.json` |
| `place_ring_on_rod_rc_0810` | `front2` | `/home/amax/checkpoints/pi05-Recap-Franka/sft_franka_shuo_pi05/checkpoints/global_step_15000/actor/model_state_dict/full_weights.pt` | `/home/amax/checkpoints/pi05-Recap-Franka/assets/franka_shuo_bowls_ring/norm_stats.json` |
| `place_fruits_on_plate_rc` | `d2` | `/home/amax/checkpoints/pi05-Recap-Franka/20260828-080659-franka_pi05_rlinf_d2/sft_franka_shuo_pi05/checkpoints/global_step_23000/actor/model_state_dict/full_weights.pt` | `/home/amax/checkpoints/pi05-Recap-Franka/assets/franka_shuo_fruits_charger_peg/norm_stats.json` |
| `plug_charger_into_socket_rc` | `d2` | `/home/amax/checkpoints/pi05-Recap-Franka/20260828-080659-franka_pi05_rlinf_d2/sft_franka_shuo_pi05/checkpoints/global_step_23000/actor/model_state_dict/full_weights.pt` | `/home/amax/checkpoints/pi05-Recap-Franka/assets/franka_shuo_fruits_charger_peg/norm_stats.json` |
| `insert_peg_into_hole_rc` | `d2` | `/home/amax/checkpoints/pi05-Recap-Franka/20260828-080659-franka_pi05_rlinf_d2/sft_franka_shuo_pi05/checkpoints/global_step_23000/actor/model_state_dict/full_weights.pt` | `/home/amax/checkpoints/pi05-Recap-Franka/assets/franka_shuo_fruits_charger_peg/norm_stats.json` |

## 通用切换流程

1. pnp 上停掉当前控制节点和推理节点：两个终端分别 `Ctrl+C`。
2. amax 上停掉当前 policy service。
3. amax 按目标 task 启动对应 `CKPT_PROFILE` 和 `TASK_PROMPT`。
4. pnp 的 `config.sh` 中把 `TASK` 改成完全相同的 task id。
5. pnp 启动 `bash start_control_async.sh` 和 `bash start_inference_async.sh`。

检查 amax service：

```bash
ss -ltnp | grep 33050
tmux capture-pane -t <session> -p | tail -n 80
```

检查 pnp ROS graph：

```bash
source /opt/ros/humble/setup.bash
ros2 node list
ros2 topic info /franka/infer_request -v
ros2 topic info /franka/action_command -v
ros2 topic info /franka/ee_states -v
```

正常应看到：

```text
/franka_control_node_async
/franka_inference_node_async

/franka/infer_request    Publisher count: 1, Subscription count: 1
/franka/action_command   Publisher count: 1, Subscription count: 1
/franka/ee_states        Publisher count: 1, Subscription count: 1
```

## 一键生成命令

在 amax 仓库中可以用脚本打印某个 task 的启动命令：

```bash
cd /data/yangky/test/pi05-Recap-Franka
bash scripts/franka/print_5task_launch_commands.sh stack_bowls_in_size_order_rc
```

## 1. stack_bowls_in_size_order_rc

amax:

```bash
tmux kill-session -t pi05_front2 2>/dev/null || true
tmux kill-session -t pi05_stack_bowls 2>/dev/null || true
tmux new-session -d -s pi05_stack_bowls \
  'cd /data/yangky/test/pi05-Recap-Franka && export CKPT_PROFILE=front2 TASK_PROMPT=stack_bowls_in_size_order_rc && bash scripts/franka/run_shuo_pi05_service_amax.sh'
tmux capture-pane -t pi05_stack_bowls -p | tail -n 80
```

pnp:

```bash
cd ~/桌面/franka_deploy_0128_ee/franka_deploy
perl -0pi -e 's/export TASK="[^"]+"/export TASK="stack_bowls_in_size_order_rc"/' config.sh
bash start_control_async.sh
bash start_inference_async.sh
```

## 2. place_ring_on_rod_rc_0810

amax:

```bash
tmux kill-session -t pi05_front2 2>/dev/null || true
tmux kill-session -t pi05_place_ring 2>/dev/null || true
tmux new-session -d -s pi05_place_ring \
  'cd /data/yangky/test/pi05-Recap-Franka && export CKPT_PROFILE=front2 TASK_PROMPT=place_ring_on_rod_rc_0810 && bash scripts/franka/run_shuo_pi05_service_amax.sh'
tmux capture-pane -t pi05_place_ring -p | tail -n 80
```

pnp:

```bash
cd ~/桌面/franka_deploy_0128_ee/franka_deploy
perl -0pi -e 's/export TASK="[^"]+"/export TASK="place_ring_on_rod_rc_0810"/' config.sh
bash start_control_async.sh
bash start_inference_async.sh
```

## 3. place_fruits_on_plate_rc

amax:

```bash
tmux kill-session -t pi05_front2 2>/dev/null || true
tmux kill-session -t pi05_place_fruits 2>/dev/null || true
tmux new-session -d -s pi05_place_fruits \
  'cd /data/yangky/test/pi05-Recap-Franka && export CKPT_PROFILE=d2 TASK_PROMPT=place_fruits_on_plate_rc && bash scripts/franka/run_shuo_pi05_service_amax.sh'
tmux capture-pane -t pi05_place_fruits -p | tail -n 80
```

pnp:

```bash
cd ~/桌面/franka_deploy_0128_ee/franka_deploy
perl -0pi -e 's/export TASK="[^"]+"/export TASK="place_fruits_on_plate_rc"/' config.sh
bash start_control_async.sh
bash start_inference_async.sh
```

## 4. plug_charger_into_socket_rc

amax:

```bash
tmux kill-session -t pi05_front2 2>/dev/null || true
tmux kill-session -t pi05_plug_charger 2>/dev/null || true
tmux new-session -d -s pi05_plug_charger \
  'cd /data/yangky/test/pi05-Recap-Franka && export CKPT_PROFILE=d2 TASK_PROMPT=plug_charger_into_socket_rc && bash scripts/franka/run_shuo_pi05_service_amax.sh'
tmux capture-pane -t pi05_plug_charger -p | tail -n 80
```

pnp:

```bash
cd ~/桌面/franka_deploy_0128_ee/franka_deploy
perl -0pi -e 's/export TASK="[^"]+"/export TASK="plug_charger_into_socket_rc"/' config.sh
bash start_control_async.sh
bash start_inference_async.sh
```

## 5. insert_peg_into_hole_rc

amax:

```bash
tmux kill-session -t pi05_front2 2>/dev/null || true
tmux kill-session -t pi05_insert_peg 2>/dev/null || true
tmux new-session -d -s pi05_insert_peg \
  'cd /data/yangky/test/pi05-Recap-Franka && export CKPT_PROFILE=d2 TASK_PROMPT=insert_peg_into_hole_rc && bash scripts/franka/run_shuo_pi05_service_amax.sh'
tmux capture-pane -t pi05_insert_peg -p | tail -n 80
```

pnp:

```bash
cd ~/桌面/franka_deploy_0128_ee/franka_deploy
perl -0pi -e 's/export TASK="[^"]+"/export TASK="insert_peg_into_hole_rc"/' config.sh
bash start_control_async.sh
bash start_inference_async.sh
```
