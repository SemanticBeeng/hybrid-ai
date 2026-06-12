#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"
PROMPT="${1:-Hello from hybrid-ai}"
MODEL="${MODEL:-${HYBRID_AI_LITERT_MODEL:-gemma4:e4b}}"
MODEL_FILE="${HYBRID_AI_LITERT_MODEL_FILE:-$project_root/volumes/models/litert-lm/gemma4-e4b/gemma-4-E4B-it.litertlm}"

if [[ -f "$MODEL_FILE" ]]; then
	MODEL="$MODEL_FILE"
fi

if "$project_root/scripts/env/toolchain/nix/flox_with.sh" bash -lc 'command -v litert-lm >/dev/null 2>&1'; then
	exec "$project_root/scripts/env/toolchain/nix/flox_with.sh" litert-lm run "$MODEL" --prompt "$PROMPT"
fi

exec "$project_root/scripts/env/toolchain/nix/flox_with.sh" python -m litert_lm "$MODEL" --prompt "$PROMPT"
