#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1090
source "$PROJECT_ROOT/scripts/env/toolchain/common.sh"
# shellcheck disable=SC1090
source "$PROJECT_ROOT/scripts/env/toolchain/vscode_paths.sh"

use_nix_daemon
ensure_nix_bind_mount
require_nix_daemon_socket

FLOX_ENV_DIR="${FLOX_ENV_DIR:-$PROJECT_ROOT/env/hybrid-ai}"
FLOX_ENV_INIT_SCRIPT="${FLOX_ENV_INIT_SCRIPT:-$PROJECT_ROOT/scripts/env/toolchain/nix/flox_env_init.sh}"

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

hybrid_ai_require_flox_env "$FLOX_ENV_DIR"

FLOX_BIN="$(resolve_flox_bin || true)"
if [[ -z "$FLOX_BIN" ]]; then
  echo "ERROR: flox is required but was not found on PATH or at $FLOX_WRAPPER_BIN" >&2
  exit 1
fi

hybrid_ai_ensure_flox_env_ready "$FLOX_ENV_DIR" "$FLOX_ENV_INIT_SCRIPT"

hybrid_ai_ensure_vscode_dirs

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