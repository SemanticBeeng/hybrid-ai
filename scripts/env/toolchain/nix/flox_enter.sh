#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
exec "$PROJECT_ROOT/scripts/env/toolchain/nix/flox_with.sh" bash --noprofile --norc
