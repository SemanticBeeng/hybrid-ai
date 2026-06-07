from pathlib import Path

from hybrid_ai.backend import BackendService, ConversationSession, EngineRuntime, NotFoundError, ReadinessError
from hybrid_ai.bootstrap import BootstrapState


class FakeConversation(ConversationSession):
    def __init__(self, system_prompt: str | None):
        self.system_prompt = system_prompt
        self.closed = False

    def send_message(self, text: str) -> str:
        prefix = f"[{self.system_prompt}] " if self.system_prompt else ""
        return prefix + text.upper()

    def close(self) -> None:
        self.closed = True


class FakeRuntime(EngineRuntime):
    def __init__(self, model_file: Path):
        self.model_file = model_file
        self.prepared = False

    def prepare(self) -> None:
        self.prepared = True

    def create_conversation(self, system_prompt: str | None) -> ConversationSession:
        self.prepare()
        return FakeConversation(system_prompt)

    def close(self) -> None:
        self.prepared = False


def make_ready_state(tmp_path: Path) -> BootstrapState:
    model_file = tmp_path / "volumes/models/litert-lm/gemma4-e4b/gemma-4-E4B-it.litertlm"
    model_file.parent.mkdir(parents=True)
    model_file.write_text("model", encoding="utf-8")

    return BootstrapState(
        project_root=tmp_path,
        runtime_version_file=tmp_path / "build/artifacts/litert-lm.version",
        model_reference_file=tmp_path / "volumes/models/litert-lm/litert-lm.model",
        model_path_file=tmp_path / "volumes/models/litert-lm/litert-lm.model-path",
        model_file_metadata=tmp_path / "volumes/models/litert-lm/litert-lm.model-file",
        runtime_version="v0.13.1",
        model_reference="gemma4:e4b",
        model_directory=model_file.parent,
        model_file=model_file,
        issues=(),
    )


def test_backend_service_supports_create_send_delete(tmp_path: Path) -> None:
    state = make_ready_state(tmp_path)
    service = BackendService(
        bootstrap_loader=lambda: state,
        runtime_factory=lambda ready_state: FakeRuntime(ready_state.model_file),
    )

    created = service.create_conversation("system prompt")
    conversation_id = created["conversation_id"]
    assert isinstance(conversation_id, str)
    assert service.list_conversations() == [conversation_id]

    reply = service.send_message(conversation_id, "hello")
    assert reply["message"]["role"] == "assistant"
    assert reply["message"]["text"] == "[system prompt] HELLO"

    service.delete_conversation(conversation_id)
    assert service.list_conversations() == []


def test_backend_service_reports_readiness_failure(tmp_path: Path) -> None:
    state = BootstrapState(
        project_root=tmp_path,
        runtime_version_file=tmp_path / "build/artifacts/litert-lm.version",
        model_reference_file=tmp_path / "volumes/models/litert-lm/litert-lm.model",
        model_path_file=tmp_path / "volumes/models/litert-lm/litert-lm.model-path",
        model_file_metadata=tmp_path / "volumes/models/litert-lm/litert-lm.model-file",
        runtime_version=None,
        model_reference="gemma4:e4b",
        model_directory=tmp_path / "volumes/models/litert-lm/gemma4-e4b",
        model_file=None,
        issues=("missing runtime version metadata",),
    )
    service = BackendService(bootstrap_loader=lambda: state)

    payload = service.readiness_payload()
    assert payload["ready"] is False
    assert payload["issues"] == ["missing runtime version metadata"]

    try:
        service.create_conversation(None)
    except ReadinessError:
        pass
    else:
        raise AssertionError("expected readiness error")


def test_backend_service_raises_not_found_for_unknown_conversation(tmp_path: Path) -> None:
    state = make_ready_state(tmp_path)
    service = BackendService(
        bootstrap_loader=lambda: state,
        runtime_factory=lambda ready_state: FakeRuntime(ready_state.model_file),
    )

    try:
        service.send_message("missing", "hello")
    except NotFoundError:
        pass
    else:
        raise AssertionError("expected not found error")