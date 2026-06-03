#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/common.sh"

fail() {
  echo "ERROR: $1" >&2
  exit 1
}

must_exist=(
  "$PROJECT_ROOT/build"
  "$PROJECT_ROOT/volumes"
  "$PROJECT_ROOT/deps"
  "$PROJECT_ROOT/env/hybrid-ai/manifest.toml"
  "$PROJECT_ROOT/.vscode/settings.json"
)

for p in "${must_exist[@]}"; do
  [[ -e "$p" ]] || fail "Missing required path: $p"
done

for p in "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"; do
  case "$p" in
    "$PROJECT_ROOT"/*) ;;
    *) fail "Path is outside project root: $p" ;;
  esac
done

for forbidden in "$PROJECT_ROOT/src/python/__pycache__" "$PROJECT_ROOT/src/swift/.build"; do
  [[ ! -e "$forbidden" ]] || fail "Forbidden byproduct detected: $forbidden"
done

echo "doctor: OK"
