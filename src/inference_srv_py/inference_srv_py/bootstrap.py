from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import os


@dataclass(frozen=True)
class BootstrapState:
    project_root: Path
    runtime_version_file: Path
    model_reference_file: Path
    model_path_file: Path
    model_file_metadata: Path
    runtime_version: str | None
    model_reference: str | None
    model_directory: Path
    model_file: Path | None
    issues: tuple[str, ...]


def _default_project_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _read_optional_text(path: Path) -> str | None:
    if not path.is_file():
        return None

    value = path.read_text(encoding="utf-8").strip()
    return value or None


def _discover_model_file(model_directory: Path, preferred: Path | None) -> Path | None:
    if preferred is not None and preferred.is_file():
        return preferred.resolve()

    candidates = sorted(model_directory.glob("*.litertlm"))
    if not candidates:
        return None

    return candidates[0].resolve()


def load_bootstrap_state(project_root: Path | None = None) -> BootstrapState:
    root = (project_root or _default_project_root()).resolve()
    runtime_version_file = root / "build/artifacts/litert-lm.version"
    model_root = root / "volumes/models/litert-lm"
    model_reference_file = model_root / "litert-lm.model"
    model_path_file = model_root / "litert-lm.model-path"
    model_file_metadata = model_root / "litert-lm.model-file"

    issues: list[str] = []

    runtime_version = _read_optional_text(runtime_version_file)
    if runtime_version is None:
        issues.append(f"missing runtime version metadata: {runtime_version_file}")

    model_reference = _read_optional_text(model_reference_file)
    if model_reference is None:
        issues.append(f"missing model reference metadata: {model_reference_file}")

    model_directory_raw = _read_optional_text(model_path_file)
    if model_directory_raw is None:
        issues.append(f"missing model path metadata: {model_path_file}")
        model_directory = Path(os.environ.get("HYBRID_AI_LITERT_MODEL_PATH", model_root / "gemma4-e4b"))
    else:
        model_directory = Path(model_directory_raw)

    if not model_directory.is_absolute():
        model_directory = (root / model_directory).resolve()
    else:
        model_directory = model_directory.resolve()

    try:
        model_directory.relative_to(root)
    except ValueError:
        issues.append(f"model directory is outside the project root: {model_directory}")

    if not model_directory.is_dir():
        issues.append(f"model directory does not exist: {model_directory}")

    preferred_model_file_raw = os.environ.get("HYBRID_AI_LITERT_MODEL_FILE") or _read_optional_text(model_file_metadata)
    preferred_model_file = Path(preferred_model_file_raw).resolve() if preferred_model_file_raw else None
    model_file = _discover_model_file(model_directory, preferred_model_file)
    if model_file is None:
        issues.append(f"no .litertlm model file found under {model_directory}")
    else:
        try:
            model_file.relative_to(root)
        except ValueError:
            issues.append(f"model file is outside the project root: {model_file}")

    return BootstrapState(
        project_root=root,
        runtime_version_file=runtime_version_file,
        model_reference_file=model_reference_file,
        model_path_file=model_path_file,
        model_file_metadata=model_file_metadata,
        runtime_version=runtime_version,
        model_reference=model_reference,
        model_directory=model_directory,
        model_file=model_file,
        issues=tuple(issues),
    )