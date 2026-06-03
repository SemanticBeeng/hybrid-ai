#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/toolchain/common.sh"

use_nix_daemon
ensure_nix_bind_mount
require_nix_daemon_socket

FLOX_BIN=""
if command -v flox >/dev/null 2>&1; then
  FLOX_BIN="$(command -v flox)"
elif [[ -x "$FLOX_WRAPPER_BIN" ]]; then
  FLOX_BIN="$FLOX_WRAPPER_BIN"
fi

if [[ -z "$FLOX_BIN" ]]; then
  echo "ERROR: flox is required but not installed or not in PATH." >&2
  exit 1
fi

unset VIRTUAL_ENV
unset VIRTUAL_ENV_PROMPT

FLOX_ENV_DIR="$PROJECT_ROOT/env/hybrid-ai"
if [[ ! -f "$FLOX_ENV_DIR/manifest.toml" ]]; then
  echo "ERROR: expected Flox manifest at $FLOX_ENV_DIR/manifest.toml" >&2
  exit 1
fi

flox_cmd=("$FLOX_BIN" activate -d "$FLOX_ENV_DIR" --)
if [[ $# -eq 0 ]]; then
  flox_cmd+=(bash --noprofile --norc)
else
  flox_cmd+=("$@")
fi

cd "$PROJECT_ROOT"
exec "${flox_cmd[@]}"
