#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "machine=$(uname -s)-$(uname -m)"
echo "date=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "flox=$(command -v flox >/dev/null 2>&1 && flox --version || echo missing)"
echo "nix=$(command -v nix >/dev/null 2>&1 && nix --version || echo missing)"
echo "python=$("$PROJECT_ROOT/scripts/env/with_flox.sh" python --version 2>&1 || true)"
echo "swift=$("$PROJECT_ROOT/scripts/env/with_flox.sh" swift --version 2>&1 | head -n 1 || true)"
