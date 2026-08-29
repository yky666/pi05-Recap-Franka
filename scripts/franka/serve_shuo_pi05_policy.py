#!/usr/bin/env python3
"""WebSocket inference service for Shuo's single-arm Franka pi0.5 checkpoint."""

from __future__ import annotations

import argparse
import base64
import logging
import os
import threading
import time
from pathlib import Path
from typing import Any

import cv2
import numpy as np
import torch
import websockets.exceptions
import websockets.sync.server
from omegaconf import OmegaConf

LOGGER = logging.getLogger("serve_shuo_pi05_policy")


def _import_msgpack_numpy():
    try:
        from openpi_client import msgpack_numpy
    except ImportError as exc:  # pragma: no cover
        raise ImportError(
            "openpi_client.msgpack_numpy is required by the pnp websocket client "
            "protocol. Install the OpenPI client package in this environment."
        ) from exc
    return msgpack_numpy


def _drop_proxy_env() -> None:
    for var in (
        "http_proxy",
        "https_proxy",
        "HTTP_PROXY",
        "HTTPS_PROXY",
        "all_proxy",
        "ALL_PROXY",
    ):
        os.environ.pop(var, None)
    os.environ.setdefault("NO_PROXY", "localhost,127.0.0.1")


def _decode_image(raw: Any) -> np.ndarray:
    """Decode numpy/base64/jpeg payloads into uint8 HWC RGB."""
    if isinstance(raw, str):
        raw = base64.b64decode(raw)
    if isinstance(raw, np.ndarray):
        img = raw
        if img.ndim == 3 and img.shape[0] == 3:
            img = np.transpose(img, (1, 2, 0))
        if np.issubdtype(img.dtype, np.floating):
            img = (255 * img).clip(0, 255).astype(np.uint8)
        return img.astype(np.uint8, copy=False)

    buf = np.frombuffer(raw, dtype=np.uint8)
    img = cv2.imdecode(buf, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("failed to decode image payload")
    return cv2.cvtColor(img, cv2.COLOR_BGR2RGB)


def _first_present(mapping: dict, keys: tuple[str, ...]):
    for key in keys:
        if key in mapping and mapping[key] is not None:
            return mapping[key]
    return None


def _extract_state(payload: dict) -> np.ndarray:
    state_block = payload.get("state", payload)
    raw_state = _first_present(
        state_block,
        (
            "observation/state",
            "follow1_pos",
            "eef_pos",
            "ee_pose",
            "proprio",
            "robot_state",
            "state",
        ),
    )
    if raw_state is None:
        raw_state = _first_present(
            payload,
            (
                "observation/state",
                "follow1_pos",
                "eef_pos",
                "ee_pose",
                "proprio",
                "robot_state",
                "state",
            ),
        )
    if raw_state is None:
        raise KeyError(
            "missing robot state; expected one of observation/state, "
            "state.follow1_pos, state, eef_pos, ee_pose, proprio, robot_state"
        )
    state = np.asarray(raw_state, dtype=np.float32).reshape(-1)
    if state.shape[0] < 7:
        raise ValueError(f"Franka pi05 shuo state must have at least 7 dims, got {state.shape}")
    return state[:7]


def _extract_prompt(payload: dict, default_prompt: str) -> str:
    state_block = payload.get("state", {})
    for source in (payload, state_block if isinstance(state_block, dict) else {}):
        value = _first_present(source, ("instruction", "prompt", "task", "task_description"))
        if value is None:
            continue
        if isinstance(value, np.ndarray):
            value = value.flat[0] if value.size else ""
        if isinstance(value, (list, tuple)):
            value = value[0] if value else ""
        prompt = str(value).strip()
        if prompt and prompt != "None":
            return prompt
    return default_prompt


def _extract_images(payload: dict) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    views = payload.get("views", payload)
    if not isinstance(views, dict):
        raise TypeError("payload.views must be a dict when provided")

    global_raw = _first_present(
        views,
        (
            "observation/global_image",
            "global_image",
            "camera_global",
            "camera_front",
            "front",
            "image",
            "main_image",
        ),
    )
    right_raw = _first_present(
        views,
        (
            "observation/right_image",
            "right_image",
            "camera_right",
            "right",
            "camera_left",
            "left",
        ),
    )
    wrist_raw = _first_present(
        views,
        (
            "observation/wrist_image",
            "wrist_image",
            "camera_wrist",
            "wrist",
            "hand_image",
            "camera_hand",
        ),
    )

    missing = [
        name
        for name, value in (
            ("global/front image", global_raw),
            ("right image", right_raw),
            ("wrist image", wrist_raw),
        )
        if value is None
    ]
    if missing:
        raise KeyError(f"missing image payloads: {', '.join(missing)}")

    return _decode_image(global_raw), _decode_image(right_raw), _decode_image(wrist_raw)


def _payload_to_env_obs(payload: dict, default_prompt: str) -> dict[str, Any]:
    state = _extract_state(payload)
    global_img, right_img, wrist_img = _extract_images(payload)
    prompt = _extract_prompt(payload, default_prompt)
    return {
        "states": state[None, :],
        "main_images": global_img[None, ...],
        "extra_view_images": np.stack([right_img, wrist_img], axis=0)[None, ...],
        "task_descriptions": [prompt],
    }


def _load_model(args: argparse.Namespace):
    from rlinf.models.embodiment.openpi_rlinf import get_model

    cfg = OmegaConf.load(args.model_config)
    cfg.model_path = args.model_path
    cfg.precision = args.precision
    cfg.num_steps = args.num_steps
    cfg.num_action_chunks = args.num_action_chunks
    cfg.action_dim = args.action_dim
    cfg.openpi.task = "eval"
    cfg.openpi.config_name = args.config_name
    cfg.openpi.assets_dir = args.assets_dir
    cfg.openpi.asset_id = args.asset_id
    cfg.openpi.num_images_in_input = 3
    cfg.openpi.action_horizon = args.num_action_chunks
    cfg.openpi.action_chunk = args.num_action_chunks
    cfg.openpi.action_env_dim = args.action_dim
    cfg.openpi_data.asset_id = args.asset_id
    cfg.openpi_data.norm_stats_path = args.norm_stats_path

    LOGGER.info("building model from %s", args.model_path)
    model = get_model(cfg)
    if args.ckpt_path:
        LOGGER.info("loading actor checkpoint from %s", args.ckpt_path)
        state_dict = torch.load(args.ckpt_path, map_location="cpu", weights_only=False)
        incompatible = model.load_state_dict(state_dict, strict=False)
        LOGGER.info(
            "checkpoint loaded: missing=%d unexpected=%d",
            len(incompatible.missing_keys),
            len(incompatible.unexpected_keys),
        )
    device = torch.device(args.device)
    model.to(device)
    model.eval()
    return model, cfg


def _predict(model, payload: dict, args: argparse.Namespace) -> tuple[dict, float]:
    env_obs = _payload_to_env_obs(payload, args.default_prompt)
    start = time.time()
    with torch.no_grad():
        actions, _ = model.predict_action_batch(env_obs, mode="eval")
    infer_ms = (time.time() - start) * 1000.0
    action_chunk = actions.detach().cpu().numpy()[0]
    if args.response_horizon > 0:
        action_chunk = action_chunk[: args.response_horizon]
    output = {
        "actions": action_chunk.tolist(),
        "follow1_pos": action_chunk.tolist(),
        "action": action_chunk[0].tolist(),
        "server_timing": {"infer_ms": infer_ms},
    }
    return output, infer_ms


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=33050)
    parser.add_argument(
        "--model-config",
        default="examples/embodiment/config/model/pi0_5_pytorch_franka_shuo_eval.yaml",
    )
    parser.add_argument("--config-name", default="pi05_franka_shuo")
    parser.add_argument("--model-path", required=True)
    parser.add_argument("--assets-dir", required=True)
    parser.add_argument("--norm-stats-path", required=True)
    parser.add_argument("--ckpt-path", required=True)
    parser.add_argument("--asset-id", default="franka_shuo_bowls_ring")
    parser.add_argument("--precision", default="bf16", choices=("fp32", "bf16", "fp16"))
    parser.add_argument("--device", default="cuda:0")
    parser.add_argument("--num-action-chunks", type=int, default=32)
    parser.add_argument("--action-dim", type=int, default=7)
    parser.add_argument("--num-steps", type=int, default=5)
    parser.add_argument("--response-horizon", type=int, default=32)
    parser.add_argument("--default-prompt", default="")
    parser.add_argument("--log-level", default="INFO")
    args = parser.parse_args()

    logging.basicConfig(
        level=getattr(logging, args.log_level.upper()),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        force=True,
    )
    _drop_proxy_env()
    msgpack_numpy = _import_msgpack_numpy()

    model, cfg = _load_model(args)
    lock = threading.Lock()
    metadata = {
        "model_type": "pi05_franka_shuo",
        "protocol": "openpi_msgpack_numpy_ws",
        "state_dim": args.action_dim,
        "action_dim": args.action_dim,
        "action_horizon": int(cfg.num_action_chunks),
        "num_steps": int(cfg.num_steps),
        "image_order": ["global_image", "right_image", "wrist_image"],
        "response_keys": ["actions", "follow1_pos", "action"],
    }

    def handler(ws):
        client = ws.remote_address
        LOGGER.info("client connected: %s", client)
        ws.send(msgpack_numpy.packb(metadata))
        try:
            while True:
                raw = ws.recv()
                if isinstance(raw, str):
                    continue
                payload = msgpack_numpy.unpackb(raw)
                prompt = _extract_prompt(payload, args.default_prompt)
                with lock:
                    result, infer_ms = _predict(model, payload, args)
                LOGGER.info(
                    "infer %.0fms prompt=%r actions=%s",
                    infer_ms,
                    prompt[:80],
                    np.asarray(result["actions"]).shape,
                )
                ws.send(msgpack_numpy.packb(result))
        except websockets.exceptions.ConnectionClosed:
            pass
        except Exception:
            LOGGER.exception("request failed")
            try:
                ws.send(msgpack_numpy.packb({"error": "server request failed"}))
            except Exception:
                pass
        finally:
            LOGGER.info("client disconnected: %s", client)

    LOGGER.info("SERVER READY: ws://%s:%d", args.host, args.port)
    LOGGER.info("config=%s ckpt=%s", args.config_name, args.ckpt_path)
    server = websockets.sync.server.serve(
        handler,
        args.host,
        args.port,
        max_size=None,
        ping_timeout=120,
        ping_interval=30,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        LOGGER.info("server stopped")


if __name__ == "__main__":
    main()
