#!/usr/bin/env bash
set -euo pipefail

HOST_USER="${SUDO_USER:-$(id -un)}"
HOST_HOME=""

if command -v getent >/dev/null 2>&1; then
  HOST_HOME="$(getent passwd "$HOST_USER" | cut -d: -f6)"
fi

if [[ -z "$HOST_HOME" ]]; then
  HOST_HOME="$(eval echo "~$HOST_USER")"
fi

if [[ -z "$HOST_HOME" || ! -d "$HOST_HOME" ]]; then
  echo "ERROR: could not resolve host home for user $HOST_USER" >&2
  exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/toolchain/common.sh"

use_nix_daemon
ensure_nix_bind_mount
require_nix_daemon_socket

FLOX_ENV_DIR="${FLOX_ENV_DIR:-$PROJECT_ROOT/env/hybrid-ai}"
FLOX_ENV_INIT_SCRIPT="${FLOX_ENV_INIT_SCRIPT:-$PROJECT_ROOT/scripts/env/toolchain/nix/flox_env_init.sh}"
VSCODE_PORTABLE_ROOT="${VSCODE_PORTABLE_ROOT:-$HOST_HOME/appdata/.vscode}"
VSCODE_USER_DATA_DIR="${VSCODE_USER_DATA_DIR:-$VSCODE_PORTABLE_ROOT/data}"
VSCODE_EXTENSIONS_DIR="${VSCODE_EXTENSIONS_DIR:-$VSCODE_USER_DATA_DIR/extensions}"
VSCODE_SETTINGS_PATH="${VSCODE_SETTINGS_PATH:-$VSCODE_USER_DATA_DIR/User/settings.json}"

usage() {
  cat <<'EOF'
Usage: scripts/env/start_vscode.sh [--print-env|--check] [--] [code args...]

Launch portable VS Code through the repository Flox environment so the editor,
extension host, Copilot, and language tools inherit the project Python and
Swift toolchain.

Environment overrides:
  VSCODE_BIN             Absolute path to the VS Code executable.
  VSCODE_PORTABLE_ROOT   Portable root, default: $HOST_HOME/appdata/.vscode
  VSCODE_USER_DATA_DIR   VS Code user-data dir, default: $VSCODE_PORTABLE_ROOT/data
  VSCODE_EXTENSIONS_DIR  VS Code extensions dir, default: $VSCODE_USER_DATA_DIR/extensions
  FLOX_ENV_DIR           Flox env dir, default: env/hybrid-ai

Modes:
  --print-env            Print the effective editor/toolchain environment.
  --check                Validate launch prerequisites without opening VS Code.
EOF
}

resolve_flox_bin() {
  if command -v flox >/dev/null 2>&1; then
    command -v flox
    return 0
  fi

  if [[ -x "$FLOX_WRAPPER_BIN" ]]; then
    printf '%s\n' "$FLOX_WRAPPER_BIN"
    return 0
  fi

  return 1
}

resolve_vscode_bin() {
  if [[ -n "${VSCODE_BIN:-}" ]]; then
    [[ -x "$VSCODE_BIN" ]] || {
      echo "ERROR: VSCODE_BIN is not executable: $VSCODE_BIN" >&2
      return 1
    }
    printf '%s\n' "$VSCODE_BIN"
    return 0
  fi

  local candidate
  for candidate in code code-insiders codium; do
    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done

  for candidate in \
    "$HOST_HOME/appdata/.vscode/bin/code" \
    "$HOST_HOME/appdata/.vscode/bin/code-insiders" \
    "$HOST_HOME/appdata/.vscode/code" \
    "$HOST_HOME/appdata/.vscode/code-insiders"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

ensure_flox_env_ready() {
  local activate_output=""
  local status=0

  set +e
  activate_output="$("$FLOX_BIN" activate -d "$FLOX_ENV_DIR" -- bash --noprofile --norc -lc 'exit 0' 2>&1)"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    return 0
  fi

  if [[ "$activate_output" == *"manifest and lockfile are out of sync"* ]]; then
    if [[ ! -x "$FLOX_ENV_INIT_SCRIPT" ]]; then
      echo "ERROR: Flox environment state is stale, and sync helper is not executable: $FLOX_ENV_INIT_SCRIPT" >&2
      printf '%s\n' "$activate_output" >&2
      return "$status"
    fi

    echo "INFO: Flox environment state is stale; syncing manifests before launching VS Code." >&2
    "$FLOX_ENV_INIT_SCRIPT" >/dev/null
    return 0
  fi

  printf '%s\n' "$activate_output" >&2
  return "$status"
}

if [[ ! -f "$FLOX_ENV_DIR/manifest.toml" ]]; then
  echo "ERROR: expected Flox manifest at $FLOX_ENV_DIR/manifest.toml" >&2
  exit 1
fi

FLOX_BIN="$(resolve_flox_bin || true)"
if [[ -z "$FLOX_BIN" ]]; then
  echo "ERROR: flox is required but was not found on PATH or at $FLOX_WRAPPER_BIN" >&2
  exit 1
fi

ensure_flox_env_ready

mkdir -p "$VSCODE_USER_DATA_DIR" "$VSCODE_EXTENSIONS_DIR"

mode="launch"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --print-env)
      mode="print-env"
      shift
      ;;
    --check)
      mode="check"
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

print_effective_env() {
  local resolved_vscode_bin="${1:-unresolved}"

  env \
    HOST_HOME="$HOST_HOME" \
    PROJECT_ROOT="$PROJECT_ROOT" \
    VSCODE_PORTABLE_ROOT="$VSCODE_PORTABLE_ROOT" \
    VSCODE_USER_DATA_DIR="$VSCODE_USER_DATA_DIR" \
    VSCODE_EXTENSIONS_DIR="$VSCODE_EXTENSIONS_DIR" \
    VSCODE_SETTINGS_PATH="$VSCODE_SETTINGS_PATH" \
    RESOLVED_VSCODE_BIN="$resolved_vscode_bin" \
    "$FLOX_BIN" activate -d "$FLOX_ENV_DIR" -- bash --noprofile --norc -lc '
      set -euo pipefail
      source "$PROJECT_ROOT/scripts/env/toolchain/python/python_env.sh"
      source "$PROJECT_ROOT/scripts/env/toolchain/swift/swift_env.sh"
      hybrid_ai_activate_python_env
      hybrid_ai_activate_swift_env

      printf "project_root=%s\n" "$PROJECT_ROOT"
      printf "host_home=%s\n" "$HOST_HOME"
      printf "editor_home=%s\n" "$HOME"
      printf "xdg_config_home=%s\n" "$XDG_CONFIG_HOME"
      printf "xdg_cache_home=%s\n" "$XDG_CACHE_HOME"
      printf "xdg_data_home=%s\n" "$XDG_DATA_HOME"
      printf "xdg_state_home=%s\n" "$XDG_STATE_HOME"
      printf "vscode_bin=%s\n" "$RESOLVED_VSCODE_BIN"
      printf "vscode_user_data_dir=%s\n" "$VSCODE_USER_DATA_DIR"
      printf "vscode_extensions_dir=%s\n" "$VSCODE_EXTENSIONS_DIR"
      printf "vscode_settings_path=%s\n" "$VSCODE_SETTINGS_PATH"
      printf "python_bin=%s\n" "$(command -v python)"
      python -c "import sys; print(f\"python_executable={sys.executable}\")"
      python --version
      printf "swiftly_root=%s\n" "${SWIFTLY_ROOT:-unset}"
      printf "swiftly_home_dir=%s\n" "${SWIFTLY_HOME_DIR:-unset}"
      printf "swiftly_bin_dir=%s\n" "${SWIFTLY_BIN_DIR:-unset}"
      printf "swift_bin=%s\n" "$(command -v swift)"
      swift --version | head -n 1
      swift package --version
      printf "clang_bin=%s\n" "$(command -v clang || true)"
      clang --version | head -n 1
      printf "sourcekit_lsp_bin=%s\n" "$(command -v sourcekit-lsp || true)"
      printf "lldb_bin=%s\n" "$(command -v lldb || true)"
    '
}

case "$mode" in
  print-env)
    print_effective_env "$(resolve_vscode_bin || true)"
    exit 0
    ;;
  check)
    resolved_vscode_bin="$(resolve_vscode_bin || true)"
    print_effective_env "$resolved_vscode_bin"
    if [[ -z "$resolved_vscode_bin" ]]; then
      echo "ERROR: no VS Code executable found. Set VSCODE_BIN to the portable editor binary." >&2
      exit 1
    fi
    if [[ ! -f "$VSCODE_SETTINGS_PATH" ]]; then
      echo "WARNING: portable settings file not found at $VSCODE_SETTINGS_PATH" >&2
    fi
    echo "VS Code launch prerequisites look valid."
    exit 0
    ;;
esac

resolved_vscode_bin="$(resolve_vscode_bin || true)"
if [[ -z "$resolved_vscode_bin" ]]; then
  echo "ERROR: no VS Code executable found. Set VSCODE_BIN to the portable editor binary." >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  set -- "$PROJECT_ROOT"
fi

exec env \
  PROJECT_ROOT="$PROJECT_ROOT" \
  VSCODE_PORTABLE_ROOT="$VSCODE_PORTABLE_ROOT" \
  VSCODE_USER_DATA_DIR="$VSCODE_USER_DATA_DIR" \
  VSCODE_EXTENSIONS_DIR="$VSCODE_EXTENSIONS_DIR" \
  VSCODE_SETTINGS_PATH="$VSCODE_SETTINGS_PATH" \
  "$FLOX_BIN" activate -d "$FLOX_ENV_DIR" -- \
  bash --noprofile --norc -lc '
    set -euo pipefail
    source "$PROJECT_ROOT/scripts/env/toolchain/python/python_env.sh"
    source "$PROJECT_ROOT/scripts/env/toolchain/swift/swift_env.sh"
    hybrid_ai_activate_python_env
    hybrid_ai_activate_swift_env
    exec "$@"
  ' bash \
  "$resolved_vscode_bin" \
  --user-data-dir "$VSCODE_USER_DATA_DIR" \
  --extensions-dir "$VSCODE_EXTENSIONS_DIR" \
  "$@"