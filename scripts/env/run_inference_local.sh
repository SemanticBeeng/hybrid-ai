#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROMPT="${1:-Hello from hybrid-ai}"
MODEL="${MODEL:-gemma4:e4b}"

if "$PROJECT_ROOT/scripts/env/with_flox.sh" bash -lc 'command -v litert-lm >/dev/null 2>&1'; then
	exec "$PROJECT_ROOT/scripts/env/with_flox.sh" litert-lm run --model "$MODEL" --prompt "$PROMPT"
fi

exec "$PROJECT_ROOT/scripts/env/with_flox.sh" python -m litert_lm --model "$MODEL" --prompt "$PROMPT"
