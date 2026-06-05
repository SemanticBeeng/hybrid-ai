#!/usr/bin/env bash

if [[ -z "${PROJECT_ROOT:-}" ]]; then
  PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fi

export HOST_USER="${HOST_USER:-${SUDO_USER:-$(id -un)}}"

hybrid_ai_resolve_host_home() {
  local host_home=""

  if command -v getent >/dev/null 2>&1; then
    host_home="$(getent passwd "$HOST_USER" | cut -d: -f6)"
  fi

  if [[ -z "$host_home" ]]; then
    host_home="$(eval echo "~$HOST_USER")"
  fi

  if [[ -z "$host_home" || ! -d "$host_home" ]]; then
    echo "ERROR: could not resolve host home for user $HOST_USER" >&2
    return 1
  fi

  printf '%s\n' "$host_home"
}

export HOST_HOME="${HOST_HOME:-$(hybrid_ai_resolve_host_home)}"
export VSCODE_PORTABLE_ROOT="${VSCODE_PORTABLE_ROOT:-$HOST_HOME/appdata/.vscode}"
export VSCODE_USER_DATA_DIR="${VSCODE_USER_DATA_DIR:-$VSCODE_PORTABLE_ROOT/data}"
export VSCODE_EXTENSIONS_DIR="${VSCODE_EXTENSIONS_DIR:-$VSCODE_USER_DATA_DIR/extensions}"
export VSCODE_SETTINGS_PATH="${VSCODE_SETTINGS_PATH:-$VSCODE_USER_DATA_DIR/User/settings.json}"

hybrid_ai_ensure_vscode_dirs() {
  mkdir -p "$VSCODE_USER_DATA_DIR" "$VSCODE_EXTENSIONS_DIR"
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
    "$VSCODE_PORTABLE_ROOT/bin/code" \
    "$VSCODE_PORTABLE_ROOT/bin/code-insiders" \
    "$VSCODE_PORTABLE_ROOT/code" \
    "$VSCODE_PORTABLE_ROOT/code-insiders"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}
