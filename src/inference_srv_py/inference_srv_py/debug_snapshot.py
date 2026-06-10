from __future__ import annotations

from collections.abc import Mapping
import ctypes.util
import json
import os
from pathlib import Path
import platform
import sys
import threading

from .bootstrap import load_bootstrap_state


def _snapshot_dir() -> Path | None:
    raw = os.environ.get("HYBRID_AI_GPU_DEBUG_SNAPSHOT_DIR")
    if not raw:
        return None
    return Path(raw)


def _sanitize_label(label: str) -> str:
    cleaned = [character.lower() if character.isalnum() else "-" for character in label.strip()]
    normalized = "".join(cleaned).strip("-")
    return normalized or "snapshot"


def _env_subset() -> dict[str, str | None]:
    keys = (
        "FLOX_ENV",
        "FLOX_ENV_CACHE",
        "GLIBC_TUNABLES",
        "HYBRID_AI_LITERT_BACKEND",
        "HYBRID_AI_LITERT_MODEL",
        "HYBRID_AI_LITERT_MODEL_PATH",
        "HYBRID_AI_LITERT_MODEL_FILE",
        "HYBRID_AI_GPU_DEVICE_NODES",
        "HYBRID_AI_GPU_ICD_FILES",
        "HYBRID_AI_GPU_VENDOR_LIBRARIES",
        "VK_ICD_FILENAMES",
        "LD_AUDIT",
        "LD_FLOXLIB_FILES_PATH",
        "LD_LIBRARY_PATH",
        "PATH",
        "SANDBOX_LD_AUDIT",
    )
    return {key: os.environ.get(key) for key in keys}


def write_runtime_snapshot(label: str, extra: Mapping[str, object] | None = None) -> Path | None:
    destination_dir = _snapshot_dir()
    if destination_dir is None:
        return None

    destination_dir.mkdir(parents=True, exist_ok=True)
    state = load_bootstrap_state()

    litert_module = sys.modules.get("litert_lm")
    litert_path = getattr(litert_module, "__file__", None) if litert_module is not None else None

    payload: dict[str, object] = {
        "label": label,
        "pid": os.getpid(),
        "thread": threading.current_thread().name,
        "cwd": os.getcwd(),
        "platform": platform.platform(),
        "python_executable": os.environ.get("PYTHONEXECUTABLE") or os.sys.executable,
        "python_prefix": os.sys.prefix,
        "python_version": os.sys.version,
        "libvulkan": ctypes.util.find_library("vulkan"),
        "litert_lm_loaded": litert_module is not None,
        "litert_lm_file": litert_path,
        "env": _env_subset(),
        "bootstrap": {
            "runtime_version": state.runtime_version,
            "model_reference": state.model_reference,
            "model_directory": str(state.model_directory),
            "model_file": str(state.model_file) if state.model_file else None,
            "issues": list(state.issues),
        },
    }
    if extra:
        payload["extra"] = dict(extra)

    output_path = destination_dir / f"py-{_sanitize_label(label)}.json"
    output_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return output_path