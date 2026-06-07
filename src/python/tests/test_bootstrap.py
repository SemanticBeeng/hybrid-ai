from pathlib import Path

from hybrid_ai.bootstrap import load_bootstrap_state


def test_load_bootstrap_state_discovers_pinned_model_file(tmp_path: Path) -> None:
    project_root = tmp_path
    model_root = project_root / "volumes/models/litert-lm"
    model_dir = model_root / "gemma4-e4b"
    model_dir.mkdir(parents=True)
    (project_root / "build/artifacts").mkdir(parents=True)

    (project_root / "build/artifacts/litert-lm.version").write_text("v0.13.1\n", encoding="utf-8")
    (model_root / "litert-lm.model").write_text("gemma4:e4b\n", encoding="utf-8")
    (model_root / "litert-lm.model-path").write_text(str(model_dir) + "\n", encoding="utf-8")
    model_file = model_dir / "gemma-4-E4B-it.litertlm"
    model_file.write_text("model", encoding="utf-8")

    state = load_bootstrap_state(project_root)

    assert not state.issues
    assert state.model_file == model_file.resolve()
    assert state.model_reference == "gemma4:e4b"


def test_load_bootstrap_state_reports_missing_model_file(tmp_path: Path) -> None:
    project_root = tmp_path
    model_root = project_root / "volumes/models/litert-lm"
    model_dir = model_root / "gemma4-e4b"
    model_dir.mkdir(parents=True)
    (project_root / "build/artifacts").mkdir(parents=True)

    (project_root / "build/artifacts/litert-lm.version").write_text("v0.13.1\n", encoding="utf-8")
    (model_root / "litert-lm.model").write_text("gemma4:e4b\n", encoding="utf-8")
    (model_root / "litert-lm.model-path").write_text(str(model_dir) + "\n", encoding="utf-8")

    state = load_bootstrap_state(project_root)

    assert state.model_file is None
    assert any("no .litertlm model file found" in issue for issue in state.issues)