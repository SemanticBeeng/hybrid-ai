#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python_env_dir="${HYBRID_AI_PYTHON_FLOX_ENV_DIR:-$project_root/env/python}"
python_manifest_path="$python_env_dir/manifest.toml"

hybrid_ai_python_gpu_run_phase() {
    local phase_name="$1"
    local success_json="$2"
    local failure_phase="${3:-$phase_name}"
    local status=0

    set +e
    python - "$phase_name" "$success_json" "$failure_phase" <<'PY'
from __future__ import annotations

import json
import sys


def fail(message: str, *, code: int = 1) -> None:
        print(json.dumps({"gpu_validation": "failed", "phase": failure_phase, "message": message}))
        raise SystemExit(code)


phase_name = sys.argv[1]
success_json = sys.argv[2]
failure_phase = sys.argv[3]

namespace = {
        "phase_name": phase_name,
        "success_json": success_json,
        "failure_phase": failure_phase,
        "fail": fail,
}

code = sys.stdin.read()
exec(compile(code, f"<gpu-phase:{phase_name}>", "exec"), namespace, namespace)
PY
    status=$?
    set -e

    if [[ $status -eq 139 ]]; then
        printf '%s\n' "{\"gpu_validation\":\"failed\",\"phase\":\"$failure_phase\",\"message\":\"Phase $phase_name crashed the Python process with SIGSEGV\"}"
        return 139
    fi

    if [[ $status -ne 0 ]]; then
        return "$status"
    fi

    printf '%s\n' "$success_json"
}

hybrid_ai_python_gpu_validate_inner() {
  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/python/python_env.sh"
  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/inference_env.sh"
  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/inference/linux_gpu_contract.sh"

  hybrid_ai_activate_python_env
  hybrid_ai_linux_gpu_contract_check
  hybrid_ai_linux_gpu_apply_bridge_env
  export HYBRID_AI_LITERT_BACKEND=gpu

  cd "$project_root/src/python"
  hybrid_ai_python_gpu_run_phase \
    runtime-library-resolution \
    '{"gpu_validation":"phase-ok","phase":"runtime-library-resolution"}' \
    runtime-library-resolution <<'PY'
import ctypes.util

libvulkan = ctypes.util.find_library("vulkan")
if not libvulkan:
    fail("ctypes could not resolve the Vulkan loader")
PY

  hybrid_ai_python_gpu_run_phase \
    python-import \
    '{"gpu_validation":"phase-ok","phase":"python-import"}' \
    python-import <<'PY'
try:
    import litert_lm
except Exception as exc:
    fail(f"failed to import litert_lm: {exc}")
PY

  hybrid_ai_python_gpu_run_phase \
    backend-selection \
    '{"gpu_validation":"phase-ok","phase":"backend-selection"}' \
    backend-selection <<'PY'
import litert_lm

backend_type = getattr(litert_lm, "Backend", None)
gpu_ctor = getattr(backend_type, "GPU", None) if backend_type is not None else None
if gpu_ctor is None:
    fail("litert_lm does not expose Backend.GPU")
PY

  hybrid_ai_python_gpu_run_phase \
    bootstrap-state \
    '{"gpu_validation":"phase-ok","phase":"bootstrap-state"}' \
    bootstrap-state <<'PY'
from hybrid_ai.bootstrap import load_bootstrap_state

state = load_bootstrap_state()
if state.issues:
    fail("; ".join(state.issues))
PY

  hybrid_ai_python_gpu_run_phase \
    engine-construction \
    '{"gpu_validation":"phase-ok","phase":"engine-construction"}' \
    engine-construction-crash <<'PY'
import litert_lm
from hybrid_ai.bootstrap import load_bootstrap_state

backend_type = getattr(litert_lm, "Backend", None)
gpu_ctor = getattr(backend_type, "GPU", None) if backend_type is not None else None
if gpu_ctor is None:
    fail("litert_lm does not expose Backend.GPU")

state = load_bootstrap_state()
if state.issues:
    fail("; ".join(state.issues))

try:
    engine_context = litert_lm.Engine(
        str(state.model_file),
        backend=gpu_ctor(),
        cache_dir=":nocache",
    )
except Exception as exc:
    fail(f"failed to construct LiteRT-LM GPU engine: {exc}")
PY

  hybrid_ai_python_gpu_run_phase \
    engine-enter \
    '{"gpu_validation":"phase-ok","phase":"engine-enter"}' \
    engine-enter-crash <<'PY'
import litert_lm
from hybrid_ai.bootstrap import load_bootstrap_state

backend_type = getattr(litert_lm, "Backend", None)
gpu_ctor = getattr(backend_type, "GPU", None) if backend_type is not None else None
if gpu_ctor is None:
    fail("litert_lm does not expose Backend.GPU")

state = load_bootstrap_state()
if state.issues:
    fail("; ".join(state.issues))

engine_context = None
try:
    engine_context = litert_lm.Engine(
        str(state.model_file),
        backend=gpu_ctor(),
        cache_dir=":nocache",
    )
    engine = engine_context.__enter__()
except Exception as exc:
    fail(f"failed to enter LiteRT-LM GPU engine context: {exc}")
finally:
    if engine_context is not None:
        exit_method = getattr(engine_context, "__exit__", None)
        if exit_method is not None:
            exit_method(None, None, None)
PY

  hybrid_ai_python_gpu_run_phase \
    conversation-create \
    '{"gpu_validation":"phase-ok","phase":"conversation-create"}' \
    conversation-create-crash <<'PY'
import litert_lm
from hybrid_ai.bootstrap import load_bootstrap_state

backend_type = getattr(litert_lm, "Backend", None)
gpu_ctor = getattr(backend_type, "GPU", None) if backend_type is not None else None
if gpu_ctor is None:
    fail("litert_lm does not expose Backend.GPU")

state = load_bootstrap_state()
if state.issues:
    fail("; ".join(state.issues))

attempts = (
    {"messages": [], "automatic_tool_calling": False, "sampler_config": None},
    {"messages": []},
    {},
)

engine_context = None
conversation_context = None
try:
    engine_context = litert_lm.Engine(
        str(state.model_file),
        backend=gpu_ctor(),
        cache_dir=":nocache",
    )
    engine = engine_context.__enter__()
    create_conversation = getattr(engine, "create_conversation", None)
    if create_conversation is None:
        fail("LiteRT-LM GPU engine does not expose create_conversation")

    last_error = None
    for kwargs in attempts:
        try:
            conversation_context = create_conversation(**kwargs)
            break
        except TypeError as exc:
            last_error = exc

    if conversation_context is None:
        fail(f"failed to create LiteRT-LM GPU conversation: {last_error}")

    if hasattr(conversation_context, "__enter__"):
        raw_conversation = conversation_context.__enter__()
    else:
        raw_conversation = conversation_context

    if raw_conversation is None:
        fail("LiteRT-LM returned an empty conversation object")
except Exception as exc:
    fail(f"failed to create LiteRT-LM GPU conversation: {exc}")
finally:
    if conversation_context is not None and hasattr(conversation_context, "__exit__"):
        conversation_context.__exit__(None, None, None)
    if engine_context is not None and hasattr(engine_context, "__exit__"):
        engine_context.__exit__(None, None, None)
PY

  hybrid_ai_python_gpu_run_phase \
    threaded-conversation-create \
    '{"gpu_validation":"phase-ok","phase":"threaded-conversation-create"}' \
    threaded-conversation-create-crash <<'PY'
import threading

import litert_lm
from hybrid_ai.bootstrap import load_bootstrap_state

backend_type = getattr(litert_lm, "Backend", None)
gpu_ctor = getattr(backend_type, "GPU", None) if backend_type is not None else None
if gpu_ctor is None:
    fail("litert_lm does not expose Backend.GPU")

state = load_bootstrap_state()
if state.issues:
    fail("; ".join(state.issues))

attempts = (
    {"messages": [], "automatic_tool_calling": False, "sampler_config": None},
    {"messages": []},
    {},
)

thread_error = []


def worker() -> None:
    engine_context = None
    conversation_context = None
    try:
        engine_context = litert_lm.Engine(
            str(state.model_file),
            backend=gpu_ctor(),
            cache_dir=":nocache",
        )
        engine = engine_context.__enter__()
        create_conversation = getattr(engine, "create_conversation", None)
        if create_conversation is None:
            raise RuntimeError("LiteRT-LM GPU engine does not expose create_conversation")

        last_error = None
        for kwargs in attempts:
            try:
                conversation_context = create_conversation(**kwargs)
                break
            except TypeError as exc:
                last_error = exc

        if conversation_context is None:
            raise RuntimeError(f"failed to create LiteRT-LM GPU conversation: {last_error}")

        if hasattr(conversation_context, "__enter__"):
            raw_conversation = conversation_context.__enter__()
        else:
            raw_conversation = conversation_context

        if raw_conversation is None:
            raise RuntimeError("LiteRT-LM returned an empty conversation object")
    except Exception as exc:
        thread_error.append(str(exc))
    finally:
        if conversation_context is not None and hasattr(conversation_context, "__exit__"):
            conversation_context.__exit__(None, None, None)
        if engine_context is not None and hasattr(engine_context, "__exit__"):
            engine_context.__exit__(None, None, None)


thread = threading.Thread(target=worker, name="hybrid-ai-gpu-validate")
thread.start()
thread.join()

if thread_error:
    fail(thread_error[0])
PY

  hybrid_ai_python_gpu_run_phase \
    backend-readiness \
    '{"gpu_validation":"phase-ok","phase":"backend-readiness"}' \
    backend-readiness <<'PY'
from hybrid_ai.backend import BackendService

service = BackendService()
try:
    payload = service.readiness_payload()
finally:
    service.shutdown()

if not payload.get("ready"):
    fail("; ".join(payload.get("issues", [])) or "backend readiness returned ready=false")
PY

  python - <<'PY'
from __future__ import annotations

import ctypes.util
import json
import os

from hybrid_ai.bootstrap import load_bootstrap_state

state = load_bootstrap_state()

print(
    json.dumps(
        {
            "gpu_validation": "ok",
            "backend": os.environ.get("HYBRID_AI_LITERT_BACKEND", "gpu"),
            "libvulkan": ctypes.util.find_library("vulkan"),
            "model_file": str(state.model_file),
            "vk_icd_filenames": os.environ.get("VK_ICD_FILENAMES"),
        }
    )
)
PY
}

if [[ "${FLOX_ENV:-}" == "$python_env_dir"/.flox/run/* ]]; then
  hybrid_ai_python_gpu_validate_inner
  exit 0
fi

exec env FLOX_ENV_DIR="$python_env_dir" FLOX_MANIFEST_PATH="$python_manifest_path" \
  "$project_root/scripts/env/toolchain/nix/flox_with.sh" \
  bash -lc 'project_root="$1"; shift; "$project_root/scripts/env/toolchain/python/python_gpu_validate.sh" "$@"' \
  bash "$project_root" "$@"