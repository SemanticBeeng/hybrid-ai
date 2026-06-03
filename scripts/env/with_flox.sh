#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/common.sh"

if ! command -v flox >/dev/null 2>&1; then
  echo "ERROR: flox is required but not installed or not in PATH." >&2
  exit 1
fi

FLOX_ENV_DIR="$PROJECT_ROOT/env/hybrid-ai"
if [[ ! -f "$FLOX_ENV_DIR/manifest.toml" ]]; then
  echo "ERROR: expected Flox manifest at $FLOX_ENV_DIR/manifest.toml" >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  exec flox activate -d "$FLOX_ENV_DIR" -- bash --noprofile --norc
fi

exec flox activate -d "$FLOX_ENV_DIR" -- "$@"
