"""GPU validation phases for the LiteRT-LM inference server.

Each phase function returns a result dict on success or raises PhaseError on failure.
Phases are designed to be run sequentially — later phases depend on earlier ones passing.
"""

from __future__ import annotations

import ctypes
import ctypes.util
import json
import os
import shutil
import subprocess
import sys
import threading
from dataclasses import dataclass
from pathlib import Path


class PhaseError(RuntimeError):
    """A validation phase failed."""

    def __init__(self, phase: str, message: str) -> None:
        super().__init__(message)
        self.phase = phase
        self.message = message

    def to_json(self) -> str:
        return json.dumps({"gpu_validation": "failed", "phase": self.phase, "message": self.message})


@dataclass(frozen=True)
class PhaseResult:
    phase: str

    def to_json(self) -> str:
        return json.dumps({"gpu_validation": "phase-ok", "phase": self.phase})


def _fail(phase: str, message: str) -> None:
    raise PhaseError(phase, message)


# --- Phase implementations ---


def phase_runtime_library_resolution() -> PhaseResult:
    """Verify ctypes can resolve the Vulkan loader."""
    libvulkan = ctypes.util.find_library("vulkan")
    if not libvulkan:
        _fail("runtime-library-resolution", "ctypes could not resolve the Vulkan loader")
    return PhaseResult("runtime-library-resolution")


def phase_managed_vulkan_tooling() -> PhaseResult:
    """Verify vulkaninfo resolves within the managed runtime."""
    vulkaninfo = shutil.which("vulkaninfo")
    if not vulkaninfo:
        _fail("managed-vulkan-tooling", "managed runtime could not resolve vulkaninfo")

    flox_env = os.environ.get("FLOX_ENV")
    if flox_env and not vulkaninfo.startswith(f"{flox_env}/"):
        _fail("managed-vulkan-tooling", f"vulkaninfo resolved outside FLOX_ENV: {vulkaninfo}")
    return PhaseResult("managed-vulkan-tooling")


def phase_icd_vendor_library_loadability() -> PhaseResult:
    """Verify GPU vendor libraries can be loaded via ctypes."""
    vendor_libraries = [
        item for item in os.environ.get("HYBRID_AI_GPU_VENDOR_LIBRARIES", "").split(":") if item
    ]
    if not vendor_libraries:
        _fail("icd-vendor-library-loadability", "no resolved GPU vendor libraries were exported")

    for library_path in vendor_libraries:
        try:
            ctypes.CDLL(library_path)
        except OSError as exc:
            _fail(
                "icd-vendor-library-loadability",
                f"managed runtime could not load GPU vendor library {library_path}: {exc}",
            )
    return PhaseResult("icd-vendor-library-loadability")


def phase_python_import() -> PhaseResult:
    """Verify litert_lm can be imported."""
    try:
        import litert_lm  # noqa: F401
    except Exception as exc:
        _fail("python-import", f"failed to import litert_lm: {exc}")
    return PhaseResult("python-import")


def phase_backend_selection() -> PhaseResult:
    """Verify litert_lm exposes Backend.GPU."""
    import litert_lm

    backend_type = getattr(litert_lm, "Backend", None)
    gpu_ctor = getattr(backend_type, "GPU", None) if backend_type is not None else None
    if gpu_ctor is None:
        _fail("backend-selection", "litert_lm does not expose Backend.GPU")
    return PhaseResult("backend-selection")


def phase_bootstrap_state() -> PhaseResult:
    """Verify bootstrap state has no issues."""
    from .bootstrap import load_bootstrap_state

    state = load_bootstrap_state()
    if state.issues:
        _fail("bootstrap-state", "; ".join(state.issues))
    return PhaseResult("bootstrap-state")


def _get_gpu_engine_components():
    """Shared helper: resolve Backend.GPU and bootstrap state."""
    import litert_lm

    from .bootstrap import load_bootstrap_state

    backend_type = getattr(litert_lm, "Backend", None)
    gpu_ctor = getattr(backend_type, "GPU", None) if backend_type is not None else None
    if gpu_ctor is None:
        _fail("engine-construction", "litert_lm does not expose Backend.GPU")

    state = load_bootstrap_state()
    if state.issues:
        _fail("engine-construction", "; ".join(state.issues))

    return litert_lm, gpu_ctor, state


def phase_engine_construction() -> PhaseResult:
    """Verify GPU engine can be constructed."""
    litert_lm, gpu_ctor, state = _get_gpu_engine_components()

    try:
        litert_lm.Engine(
            str(state.model_file),
            backend=gpu_ctor(),
            cache_dir=":nocache",
        )
    except Exception as exc:
        _fail("engine-construction", f"failed to construct LiteRT-LM GPU engine: {exc}")
    return PhaseResult("engine-construction")


def phase_engine_enter() -> PhaseResult:
    """Verify GPU engine context can be entered."""
    litert_lm, gpu_ctor, state = _get_gpu_engine_components()

    engine_context = None
    try:
        engine_context = litert_lm.Engine(
            str(state.model_file),
            backend=gpu_ctor(),
            cache_dir=":nocache",
        )
        engine_context.__enter__()
    except Exception as exc:
        _fail("engine-enter", f"failed to enter LiteRT-LM GPU engine context: {exc}")
    finally:
        if engine_context is not None:
            exit_method = getattr(engine_context, "__exit__", None)
            if exit_method is not None:
                exit_method(None, None, None)
    return PhaseResult("engine-enter")


def _create_conversation_on_engine(engine):
    """Try to create a conversation with various kwarg combinations."""
    create_conversation = getattr(engine, "create_conversation", None)
    if create_conversation is None:
        return None, "LiteRT-LM GPU engine does not expose create_conversation"

    attempts = (
        {"messages": [], "automatic_tool_calling": False, "sampler_config": None},
        {"messages": []},
        {},
    )

    last_error = None
    for kwargs in attempts:
        try:
            return create_conversation(**kwargs), None
        except TypeError as exc:
            last_error = exc

    return None, f"failed to create LiteRT-LM GPU conversation: {last_error}"


def phase_conversation_create() -> PhaseResult:
    """Verify a GPU conversation can be created."""
    litert_lm, gpu_ctor, state = _get_gpu_engine_components()

    engine_context = None
    conversation_context = None
    try:
        engine_context = litert_lm.Engine(
            str(state.model_file),
            backend=gpu_ctor(),
            cache_dir=":nocache",
        )
        engine = engine_context.__enter__()

        conversation_context, error = _create_conversation_on_engine(engine)
        if error and conversation_context is None:
            _fail("conversation-create", error)

        if hasattr(conversation_context, "__enter__"):
            raw_conversation = conversation_context.__enter__()
        else:
            raw_conversation = conversation_context

        if raw_conversation is None:
            _fail("conversation-create", "LiteRT-LM returned an empty conversation object")
    except PhaseError:
        raise
    except Exception as exc:
        _fail("conversation-create", f"failed to create LiteRT-LM GPU conversation: {exc}")
    finally:
        if conversation_context is not None and hasattr(conversation_context, "__exit__"):
            conversation_context.__exit__(None, None, None)
        if engine_context is not None and hasattr(engine_context, "__exit__"):
            engine_context.__exit__(None, None, None)
    return PhaseResult("conversation-create")


def phase_threaded_conversation_create() -> PhaseResult:
    """Verify conversation creation works from a non-main thread."""
    litert_lm, gpu_ctor, state = _get_gpu_engine_components()

    thread_error: list[str] = []

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

            conversation_context, error = _create_conversation_on_engine(engine)
            if error and conversation_context is None:
                thread_error.append(error)
                return

            if hasattr(conversation_context, "__enter__"):
                raw_conversation = conversation_context.__enter__()
            else:
                raw_conversation = conversation_context

            if raw_conversation is None:
                thread_error.append("LiteRT-LM returned an empty conversation object")
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
        _fail("threaded-conversation-create", thread_error[0])
    return PhaseResult("threaded-conversation-create")


def phase_vulkan_adapter_enumeration() -> PhaseResult:
    """Run vulkaninfo --summary (only when HYBRID_AI_GPU_STRICT_VULKANINFO=1)."""
    completed = subprocess.run(
        ["vulkaninfo", "--summary"],
        capture_output=True,
        text=True,
        env=os.environ.copy(),
    )
    if completed.returncode != 0:
        output = (completed.stderr or completed.stdout or "").strip()
        _fail("vulkan-adapter-enumeration", f"vulkaninfo --summary failed: {output}")
    return PhaseResult("vulkan-adapter-enumeration")


def phase_backend_readiness() -> PhaseResult:
    """Verify BackendService reports ready."""
    from .backend import BackendService

    service = BackendService()
    try:
        payload = service.readiness_payload()
    finally:
        service.shutdown()

    if not payload.get("ready"):
        _fail(
            "backend-readiness",
            "; ".join(payload.get("issues", [])) or "backend readiness returned ready=false",
        )
    return PhaseResult("backend-readiness")


def phase_threaded_backend_readiness() -> PhaseResult:
    """Verify BackendService readiness from a non-main thread."""
    from .backend import BackendService

    thread_error: list[str] = []

    def worker() -> None:
        service = BackendService()
        try:
            payload = service.readiness_payload()
        except Exception as exc:
            thread_error.append(str(exc))
            return
        finally:
            service.shutdown()

        if not payload.get("ready"):
            thread_error.append(
                "; ".join(payload.get("issues", [])) or "backend readiness returned ready=false"
            )

    thread = threading.Thread(target=worker, name="hybrid-ai-backend-readiness")
    thread.start()
    thread.join()

    if thread_error:
        _fail("threaded-backend-readiness", thread_error[0])
    return PhaseResult("threaded-backend-readiness")


# --- Orchestration ---

ALL_PHASES = [
    phase_runtime_library_resolution,
    phase_managed_vulkan_tooling,
    phase_icd_vendor_library_loadability,
    phase_python_import,
    phase_backend_selection,
    phase_bootstrap_state,
    phase_engine_construction,
    phase_engine_enter,
    phase_conversation_create,
    phase_threaded_conversation_create,
    # phase_vulkan_adapter_enumeration is conditional (HYBRID_AI_GPU_STRICT_VULKANINFO)
    phase_backend_readiness,
    phase_threaded_backend_readiness,
]


def run_all_phases(*, strict_vulkaninfo: bool = False) -> str:
    """Run all validation phases sequentially. Returns final JSON summary on success."""
    for phase_fn in ALL_PHASES:
        result = phase_fn()
        print(result.to_json(), flush=True)

    if strict_vulkaninfo:
        result = phase_vulkan_adapter_enumeration()
        print(result.to_json(), flush=True)

    # Final summary
    from .bootstrap import load_bootstrap_state

    state = load_bootstrap_state()
    summary = json.dumps({
        "gpu_validation": "ok",
        "backend": os.environ.get("HYBRID_AI_LITERT_BACKEND", "gpu"),
        "libvulkan": ctypes.util.find_library("vulkan"),
        "model_file": str(state.model_file),
        "vk_icd_filenames": os.environ.get("VK_ICD_FILENAMES"),
    })
    print(summary, flush=True)
    return summary


def main() -> None:
    """CLI entry point for gpu_validation."""
    strict = os.environ.get("HYBRID_AI_GPU_STRICT_VULKANINFO", "0") == "1"
    snapshot_dir = os.environ.get("HYBRID_AI_GPU_DEBUG_SNAPSHOT_DIR")

    if snapshot_dir:
        from .debug_snapshot import write_runtime_snapshot

        Path(snapshot_dir).mkdir(parents=True, exist_ok=True)
        write_runtime_snapshot("validate")

    try:
        run_all_phases(strict_vulkaninfo=strict)
    except PhaseError as exc:
        print(exc.to_json(), flush=True)
        raise SystemExit(1) from None


if __name__ == "__main__":
    main()
