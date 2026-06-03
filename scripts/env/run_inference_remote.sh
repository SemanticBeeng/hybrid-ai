#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/common.sh"

: "${REMOTE_INFERENCE_URL:?Set REMOTE_INFERENCE_URL in your project-local secret loader.}"
: "${REMOTE_INFERENCE_TOKEN:?Set REMOTE_INFERENCE_TOKEN in your project-local secret loader.}"
PROMPT="${1:-Hello from hybrid-ai remote inference}"
MODEL="${MODEL:-gemma4:e4b}"

# Uses curl intentionally to keep provider integration generic.
exec "$PROJECT_ROOT/scripts/env/with_flox.sh" curl -sS \
  -H "Authorization: Bearer $REMOTE_INFERENCE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"$MODEL\",\"prompt\":\"$PROMPT\"}" \
  "$REMOTE_INFERENCE_URL"
