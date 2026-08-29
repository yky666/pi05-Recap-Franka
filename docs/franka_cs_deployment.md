# Franka pi0.5 RECAP C/S 部署步骤

本文档对应当前部署方式：amax 作为推理服务端加载 pi0.5 Franka 权重，pnp 机器作为机器人客户端采集相机 / 机器人状态并通过 WebSocket 请求 action。

## 1. 机器和端口

| 角色 | 机器 | 地址 | 说明 |
| --- | --- | --- | --- |
| 推理服务端 | amax | `192.168.10.114` | 加载 `pi05_base + full_weights.pt + norm_stats` |
| 机器人客户端 | pnp | `192.168.10.110` | 运行 `franka_deploy_0128_ee/franka_deploy` |
| WebSocket 端口 | amax | `33050` | pnp client 连接 `ws://192.168.10.114:33050` |

## 2. 权重和资产路径

amax 上 pi0.5 base model 路径：

```bash
/home/amax/.cache/huggingface/hub/models--lerobot--pi05_base/snapshots/9e55186ad36e66b95cda57bc47818d9e6237ae30
```

这个 base 不是最终策略。服务启动时会先用它实例化 OpenPI/RLinf 的 pi0.5 模型结构，然后加载师兄训练得到的 `full_weights.pt` 覆盖 actor 权重。

| Profile | 任务 | checkpoint | norm stats |
| --- | --- | --- | --- |
| `front2` | `stack_bowls_in_size_order_rc`, `place_ring_on_rod_rc_0810` | `/home/amax/checkpoints/pi05-Recap-Franka/sft_franka_shuo_pi05/checkpoints/global_step_15000/actor/model_state_dict/full_weights.pt` | `/home/amax/checkpoints/pi05-Recap-Franka/assets/franka_shuo_bowls_ring/norm_stats.json` |
| `d2` | `place_fruits_on_plate_rc`, `plug_charger_into_socket_rc`, `insert_peg_into_hole_rc` | `/home/amax/checkpoints/pi05-Recap-Franka/20260828-080659-franka_pi05_rlinf_d2/sft_franka_shuo_pi05/checkpoints/global_step_23000/actor/model_state_dict/full_weights.pt` | `/home/amax/checkpoints/pi05-Recap-Franka/assets/franka_shuo_fruits_charger_peg/norm_stats.json` |

HF 训练日志里还包含 new-side 数据目录：

```text
new_side/place_ring_on_rod_new_side_rc
new_side/plug_charger_into_socket_new_side_rc
new_side/insert_peg_into_hole_new_side_rc
```

如果实验表格把 new-side 当独立任务，服务端 `TASK_PROMPT` 和 pnp 端 `TASK` 要改成对应的 `*_new_side_rc`。

## 3. amax 下载权重

进入仓库：

```bash
cd /data/yangky/test/pi05-Recap-Franka
```

下载两套权重，脚本默认用 `aria2c` 多连接断点续传：

```bash
bash scripts/franka/download_shuo_pi05_weights.sh
```

后台下载方式：

```bash
cd /data/yangky/test/pi05-Recap-Franka
setsid bash -lc 'bash scripts/franka/download_shuo_pi05_weights.sh >> /home/amax/checkpoints/pi05-Recap-Franka/download.log 2>&1' >/dev/null 2>&1 &
echo $! > /home/amax/checkpoints/pi05-Recap-Franka/download.pid
```

查看下载进度：

```bash
ps -ef | grep -E 'aria2c|download_shuo' | grep -v grep
tail -n 60 /home/amax/checkpoints/pi05-Recap-Franka/download.log
find /home/amax/checkpoints/pi05-Recap-Franka -path '*full_weights.pt' -o -name '*.aria2' | sort | xargs -r ls -lh
```

完整下载后，目标文件旁边不应再有 `.aria2` 文件，且两个 `full_weights.pt` 大小应接近 `13,413,974,342 bytes`。

## 4. amax 启动推理服务

amax 上已准备好的推理 venv：

```bash
/home/amax/venvs/pi05-franka-service
```

`scripts/franka/run_shuo_pi05_service_amax.sh` 会自动激活这个 venv。不要直接用 base 里的 `python scripts/franka/serve_shuo_pi05_policy.py`，base 环境缺 `openpi_client/openpi/ray` 等 OpenPI 推理依赖。

前两个任务：

```bash
cd /data/yangky/test/pi05-Recap-Franka
export CKPT_PROFILE=front2
export TASK_PROMPT=stack_bowls_in_size_order_rc
bash scripts/franka/run_shuo_pi05_service_amax.sh
```

长时间跑实验建议用 tmux：

```bash
tmux new-session -d -s pi05_front2 \
  'cd /data/yangky/test/pi05-Recap-Franka && export CKPT_PROFILE=front2 TASK_PROMPT=stack_bowls_in_size_order_rc && bash scripts/franka/run_shuo_pi05_service_amax.sh'

tmux attach -t pi05_front2
```

切到 ring：

```bash
export CKPT_PROFILE=front2
export TASK_PROMPT=place_ring_on_rod_rc_0810
bash scripts/franka/run_shuo_pi05_service_amax.sh
```

后三个 d2 任务：

```bash
export CKPT_PROFILE=d2
export TASK_PROMPT=place_fruits_on_plate_rc
bash scripts/franka/run_shuo_pi05_service_amax.sh
```

其它 d2 任务只改 `TASK_PROMPT`：

```bash
export TASK_PROMPT=plug_charger_into_socket_rc
export TASK_PROMPT=insert_peg_into_hole_rc
```

服务成功启动时会打印：

```text
SERVER READY: ws://0.0.0.0:33050
```

## 5. pnp 配置客户端

登录 pnp：

```bash
ssh pnp@192.168.10.110
```

进入 client 项目：

```bash
cd ~/桌面/franka_deploy_0128_ee/franka_deploy
```

检查 `config.sh`：

```bash
grep -nE 'POLICY_SERVER_HOST|POLICY_SERVER_PORT|export TASK=|MAX_ACTIONS_TO_PUBLISH|USE_LAST_ACTIONS|ASYNC_MAX_ACTIONS_TO_PUBLISH|ASYNC_USE_LAST_ACTIONS' config.sh
```

推荐配置：

```bash
export POLICY_SERVER_HOST="192.168.10.114"
export POLICY_SERVER_PORT="33050"
export TASK="stack_bowls_in_size_order_rc"
export MAX_ACTIONS_TO_PUBLISH="3"
export USE_LAST_ACTIONS="false"
export ASYNC_MAX_ACTIONS_TO_PUBLISH="32"
export ASYNC_USE_LAST_ACTIONS="false"
```

切任务时同步修改 pnp 的 `TASK` 和 amax 的 `TASK_PROMPT`：

```bash
export TASK="place_ring_on_rod_rc_0810"
export TASK="place_fruits_on_plate_rc"
export TASK="plug_charger_into_socket_rc"
export TASK="insert_peg_into_hole_rc"
```

pnp 当前配置备份：

```text
~/桌面/franka_deploy_0128_ee/franka_deploy/config.sh.bak_20260829_pi05_shuo
```

## 6. pnp 启动 client

推荐先用异步 client：

```bash
cd ~/桌面/franka_deploy_0128_ee/franka_deploy
bash start_inference_async.sh
```

同步版本也能连接同一个服务，但 action 发布较短：

```bash
bash start_inference.sh
```

当前不要使用：

```bash
start_inference_async_rlt.sh
start_inference_rtc2.sh
```

这两个脚本需要 RLT/RTC 专用服务端语义，当前 WebSocket SFT/RL 权重服务没有实现对应控制协议。

## 7. 单个任务测 SR

每个 task 做 30 次：

1. 在 amax 上选择正确 `CKPT_PROFILE` 和 `TASK_PROMPT`，启动 service。
2. 在 pnp 的 `config.sh` 中把 `TASK` 改成同一个 task id。
3. pnp 启动 `bash start_inference_async.sh`。
4. 每次 episode 结束记录 success / failure。
5. SR 计算：`SR = success_count / 30`。

建议记录表头：

| Task | CKPT_PROFILE | Trial | Success | Failure reason | Note |
| --- | --- | --- | --- | --- | --- |
| `stack_bowls_in_size_order_rc` | `front2` | 1-30 | 0/1 | 失败原因 | 环境/相机/异常 |
| `place_ring_on_rod_rc_0810` | `front2` | 1-30 | 0/1 | 失败原因 | 环境/相机/异常 |
| `place_fruits_on_plate_rc` | `d2` | 1-30 | 0/1 | 失败原因 | 环境/相机/异常 |
| `plug_charger_into_socket_rc` | `d2` | 1-30 | 0/1 | 失败原因 | 环境/相机/异常 |
| `insert_peg_into_hole_rc` | `d2` | 1-30 | 0/1 | 失败原因 | 环境/相机/异常 |

## 8. 常见问题

### pnp 连不上服务

在 pnp 上检查：

```bash
ping 192.168.10.114
nc -vz 192.168.10.114 33050
```

如果 pnp shell 里配置过代理，先绕过 amax 内网地址：

```bash
export NO_PROXY=192.168.10.114,localhost,127.0.0.1
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
```

在 amax 上检查：

```bash
ss -lntp | grep 33050
```

### service 报缺 checkpoint

先确认 `.aria2` 是否还存在：

```bash
find /home/amax/checkpoints/pi05-Recap-Franka -path '*full_weights.pt' -o -name '*.aria2' | sort | xargs -r ls -lh
```

存在 `.aria2` 说明还没下完，继续跑：

```bash
cd /data/yangky/test/pi05-Recap-Franka
bash scripts/franka/download_shuo_pi05_weights.sh
```

### task 表现异常

优先检查三件事：

1. amax 的 `TASK_PROMPT` 和 pnp 的 `TASK` 是否完全一致。
2. `CKPT_PROFILE` 是否和 task 组匹配：前两个用 `front2`，后面 fruits/charger/peg 用 `d2`。
3. pnp 相机 key 是否仍是 service 兼容的 `observation/global_image`、`observation/right_image`、`observation/wrist_image`。
