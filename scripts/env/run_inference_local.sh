#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROMPT="${1:-Hello from hybrid-ai}"
MODEL="${MODEL:-gemma4:e4b}"

if "$project_root/scripts/env/toolchain/nix/flox_with.sh" bash -lc 'command -v litert-lm >/dev/null 2>&1'; then
	exec "$project_root/scripts/env/toolchain/nix/flox_with.sh" litert-lm run --model "$MODEL" --prompt "$PROMPT"
fi

exec "$project_root/scripts/env/toolchain/nix/flox_with.sh" python -m litert_lm --model "$MODEL" --prompt "$PROMPT"
