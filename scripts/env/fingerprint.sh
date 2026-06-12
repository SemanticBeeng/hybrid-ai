#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"

echo "machine=$(uname -s)-$(uname -m)"
echo "date=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "flox=$([[ -n "${FLOX_BIN:-}" ]] && "$FLOX_BIN" --version || echo missing)"
echo "nix=$([[ -n "${NIX_BIN:-}" ]] && "$NIX_BIN" --version || echo missing)"
echo "python=$("$project_root/scripts/env/toolchain/nix/flox_with.sh" python --version 2>&1 || true)"
echo "swift=$("$project_root/scripts/env/toolchain/nix/flox_with.sh" swift --version 2>&1 | head -n 1 || true)"
