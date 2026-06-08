from __future__ import annotations

from collections.abc import Callable, Mapping
from dataclasses import dataclass
import os
from pathlib import Path
import threading
import uuid

from .bootstrap import BootstrapState, load_bootstrap_state


class BackendError(RuntimeError):
    status_code = 500


class ValidationError(BackendError):
    status_code = 400


class NotFoundError(BackendError):
    status_code = 404


class ReadinessError(BackendError):
    status_code = 503


class ConversationSession:
    def send_message(self, text: str) -> str:
        raise NotImplementedError

    def close(self) -> None:
        raise NotImplementedError


class EngineRuntime:
    model_file: Path

    def prepare(self) -> None:
        raise NotImplementedError

    def create_conversation(self, system_prompt: str | None) -> ConversationSession:
        raise NotImplementedError

    def close(self) -> None:
        raise NotImplementedError


class LiteRTConversationSession(ConversationSession):
    def __init__(self, raw_conversation: object, *, context_manager: object | None, system_prompt: str | None):
        self._raw_conversation = raw_conversation
        self._context_manager = context_manager
        self._system_prompt = system_prompt.strip() if system_prompt else None
        self._has_sent = False

    def send_message(self, text: str) -> str:
        prompt = text.strip()
        if not prompt:
            raise ValidationError("message text must not be empty")

        if self._system_prompt and not self._has_sent:
            prompt = f"System instruction:\n{self._system_prompt}\n\nUser message:\n{prompt}"

        sender = getattr(self._raw_conversation, "send_message", None) or getattr(self._raw_conversation, "send", None)
        if sender is None:
            raise ReadinessError("LiteRT conversation object does not expose a send method")

        response = sender(prompt)
        self._has_sent = True
        text_response = _extract_text(response)
        if not text_response:
            raise ReadinessError("LiteRT conversation returned an empty response")
        return text_response

    def close(self) -> None:
        if self._context_manager is None:
            return

        exit_method = getattr(self._context_manager, "__exit__", None)
        if exit_method is not None:
            exit_method(None, None, None)
        self._context_manager = None


class LiteRTEngineRuntime(EngineRuntime):
    def __init__(self, model_file: Path, *, backend_name: str = "cpu"):
        self.model_file = model_file
        self.backend_name = backend_name
        self._lock = threading.RLock()
        self._engine = None
        self._engine_context = None

    def prepare(self) -> None:
        with self._lock:
            if self._engine is not None:
                return

            try:
                import litert_lm
            except ImportError as exc:
                raise ReadinessError(
                    "litert_lm is not installed in the Python environment. Run scripts/env/setup_litert_lm.sh first."
                ) from exc

            try:
                engine_context = litert_lm.Engine(
                    str(self.model_file),
                    backend=_resolve_backend(litert_lm, self.backend_name),
                    cache_dir=":nocache",
                )
                engine = engine_context.__enter__()
            except Exception as exc:  # pragma: no cover - exercised only with real LiteRT-LM installed
                raise ReadinessError(f"failed to initialize LiteRT-LM engine: {exc}") from exc

            self._engine_context = engine_context
            self._engine = engine

    def create_conversation(self, system_prompt: str | None) -> ConversationSession:
        self.prepare()
        with self._lock:
            if self._engine is None:
                raise ReadinessError("LiteRT-LM engine is not prepared")

            conversation_context = self._create_raw_conversation()
            context_manager = conversation_context if hasattr(conversation_context, "__exit__") else None
            raw_conversation = conversation_context.__enter__() if hasattr(conversation_context, "__enter__") else conversation_context
            return LiteRTConversationSession(
                raw_conversation,
                context_manager=context_manager,
                system_prompt=system_prompt,
            )

    def close(self) -> None:
        with self._lock:
            if self._engine_context is not None:
                exit_method = getattr(self._engine_context, "__exit__", None)
                if exit_method is not None:
                    exit_method(None, None, None)
            self._engine = None
            self._engine_context = None

    def _create_raw_conversation(self):
        assert self._engine is not None
        create_conversation = getattr(self._engine, "create_conversation", None)
        if create_conversation is None:
            raise ReadinessError("LiteRT-LM engine does not expose create_conversation")

        attempts = (
            {"messages": [], "automatic_tool_calling": False, "sampler_config": None},
            {"messages": []},
            {},
        )
        last_error: Exception | None = None
        for kwargs in attempts:
            try:
                return create_conversation(**kwargs)
            except TypeError as exc:
                last_error = exc

        raise ReadinessError(f"failed to create LiteRT-LM conversation: {last_error}")


@dataclass(frozen=True)
class ConversationRecord:
    conversation_id: str
    system_prompt: str | None
    session: ConversationSession


class BackendService:
    def __init__(
        self,
        *,
        bootstrap_loader: Callable[[], BootstrapState] = load_bootstrap_state,
        runtime_factory: Callable[[BootstrapState], EngineRuntime] | None = None,
    ):
        self._bootstrap_loader = bootstrap_loader
        self._runtime_factory = runtime_factory or (
            lambda state: LiteRTEngineRuntime(
                _require_model_file(state),
                backend_name=os.environ.get("HYBRID_AI_LITERT_BACKEND", "cpu"),
            )
        )
        self._lock = threading.RLock()
        self._runtime: EngineRuntime | None = None
        self._runtime_model_file: Path | None = None
        self._conversations: dict[str, ConversationRecord] = {}

    def health_payload(self) -> dict[str, object]:
        state = self._bootstrap_loader()
        return {
            "service": "hybrid-ai-python-backend",
            "status": "ok",
            "ready": not state.issues,
            "backend": os.environ.get("HYBRID_AI_LITERT_BACKEND", "cpu"),
            "runtime_version": state.runtime_version,
            "model_reference": state.model_reference,
            "model_directory": str(state.model_directory),
            "model_file": str(state.model_file) if state.model_file else None,
            "issues": list(state.issues),
        }

    def readiness_payload(self) -> dict[str, object]:
        state = self._bootstrap_loader()
        issues = list(state.issues)
        if not issues:
            try:
                self._ensure_runtime(state).prepare()
            except BackendError as exc:
                issues.append(str(exc))

        return {
            "service": "hybrid-ai-python-backend",
            "ready": not issues,
            "backend": os.environ.get("HYBRID_AI_LITERT_BACKEND", "cpu"),
            "runtime_version_file": str(state.runtime_version_file),
            "model_reference_file": str(state.model_reference_file),
            "model_path_file": str(state.model_path_file),
            "runtime_version": state.runtime_version,
            "model_reference": state.model_reference,
            "model_directory": str(state.model_directory),
            "model_file": str(state.model_file) if state.model_file else None,
            "issues": issues,
        }

    def list_conversations(self) -> list[str]:
        with self._lock:
            return list(self._conversations.keys())

    def create_conversation(self, system_prompt: str | None) -> dict[str, object]:
        state = self._bootstrap_loader()
        if state.issues:
            raise ReadinessError("backend is not ready: " + "; ".join(state.issues))

        runtime = self._ensure_runtime(state)
        session = runtime.create_conversation(system_prompt)
        conversation_id = str(uuid.uuid4())
        record = ConversationRecord(conversation_id=conversation_id, system_prompt=system_prompt, session=session)

        with self._lock:
            self._conversations[conversation_id] = record

        return {
            "conversation_id": conversation_id,
            "system_prompt": system_prompt,
        }

    def delete_conversation(self, conversation_id: str) -> None:
        with self._lock:
            record = self._conversations.pop(conversation_id, None)

        if record is not None:
            record.session.close()

    def send_message(self, conversation_id: str, text: str) -> dict[str, object]:
        if not text.strip():
            raise ValidationError("message text must not be empty")

        with self._lock:
            record = self._conversations.get(conversation_id)

        if record is None:
            raise NotFoundError(f"conversation not found: {conversation_id}")

        reply = record.session.send_message(text)
        return {
            "conversation_id": conversation_id,
            "message": {
                "role": "assistant",
                "text": reply,
            },
        }

    def shutdown(self) -> None:
        with self._lock:
            records = list(self._conversations.values())
            self._conversations.clear()
            runtime = self._runtime
            self._runtime = None
            self._runtime_model_file = None

        for record in records:
            record.session.close()

        if runtime is not None:
            runtime.close()

    def _ensure_runtime(self, state: BootstrapState) -> EngineRuntime:
        model_file = _require_model_file(state)
        with self._lock:
            if self._runtime is not None and self._runtime_model_file == model_file:
                return self._runtime

            old_runtime = self._runtime
            records = list(self._conversations.values())
            self._conversations.clear()
            self._runtime = self._runtime_factory(state)
            self._runtime_model_file = model_file

        for record in records:
            record.session.close()
        if old_runtime is not None:
            old_runtime.close()

        return self._runtime


def _require_model_file(state: BootstrapState) -> Path:
    if state.model_file is None:
        raise ReadinessError("no pinned .litertlm model file is available")
    return state.model_file


def _resolve_backend(litert_lm: object, backend_name: str):
    backend_value = (backend_name or "cpu").strip().lower()
    backend_type = getattr(litert_lm, "Backend", None)
    if backend_type is None:
        raise ReadinessError("LiteRT-LM backend selection API is unavailable")

    mapping = {
        "cpu": getattr(backend_type, "CPU", None),
        "gpu": getattr(backend_type, "GPU", None),
        "npu": getattr(backend_type, "NPU", None),
    }
    backend_ctor = mapping.get(backend_value)
    if backend_ctor is None:
        supported = ", ".join(sorted(name for name, value in mapping.items() if value is not None))
        raise ReadinessError(f"unsupported LiteRT backend '{backend_name}', supported values: {supported}")

    return backend_ctor()


def _extract_text(response: object) -> str:
    if isinstance(response, str):
        return response.strip()

    if isinstance(response, Mapping):
        for key in ("text", "content", "message", "response"):
            value = response.get(key)
            if isinstance(value, str) and value.strip():
                return value.strip()
            if isinstance(value, Mapping):
                nested = _extract_text(value)
                if nested:
                    return nested

    text_attr = getattr(response, "text", None)
    if isinstance(text_attr, str) and text_attr.strip():
        return text_attr.strip()

    content_attr = getattr(response, "content", None)
    if isinstance(content_attr, str) and content_attr.strip():
        return content_attr.strip()

    candidates = getattr(response, "candidates", None)
    if isinstance(candidates, list):
        for candidate in candidates:
            candidate_text = _extract_text(candidate)
            if candidate_text:
                return candidate_text

    return str(response).strip()