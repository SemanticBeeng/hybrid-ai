#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$project_root/scripts/env/toolchain/common.sh"

fail() {
  echo "ERROR: $1" >&2
  exit 1
}

must_exist=(
  "$project_root/build"
  "$project_root/volumes"
  "$project_root/deps"
  "$project_root/.flox/env/manifest.toml"
  "$project_root/.vscode/settings.json"
)

for p in "${must_exist[@]}"; do
  [[ -e "$p" ]] || fail "Missing required path: $p"
done

for p in "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"; do
  case "$p" in
    "$project_root"/*) ;;
    *) fail "Path is outside project root: $p" ;;
  esac
done

if [[ -x "$DETERMINATE_NIX_BIN" || -x "$NIX_WRAPPER_BIN" || -x "$FLOX_WRAPPER_BIN" ]]; then
  [[ -r "$NIX_DAEMON_PROFILE_SCRIPT" ]] || fail "Missing nix-daemon profile script: $NIX_DAEMON_PROFILE_SCRIPT"
  [[ -S "$NIX_DAEMON_SOCKET" ]] || fail "Missing nix-daemon socket: $NIX_DAEMON_SOCKET"
fi

for forbidden in "$project_root/src/python/__pycache__" "$project_root/src/swift/.build"; do
  [[ ! -e "$forbidden" ]] || fail "Forbidden byproduct detected: $forbidden"
done

echo "doctor: OK"
