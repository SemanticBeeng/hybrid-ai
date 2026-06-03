#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ $# -eq 0 ]]; then
  set -- build
fi

exec "$PROJECT_ROOT/scripts/env/with_flox.sh" swift "$@" --build-path "$PROJECT_ROOT/build/swift"
