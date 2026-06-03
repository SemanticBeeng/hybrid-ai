#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/common.sh"

# Override if upstream organization/repo changes.
LITERT_LM_GH_REPO="${LITERT_LM_GH_REPO:-google-ai-edge/LiteRT-LM}"
LITERT_LM_TAG="${LITERT_LM_TAG:-}"

if [[ -z "$LITERT_LM_TAG" ]]; then
  LITERT_LM_TAG="$($PROJECT_ROOT/scripts/env/with_flox.sh curl -sS "https://api.github.com/repos/$LITERT_LM_GH_REPO/releases/latest" | $PROJECT_ROOT/scripts/env/with_flox.sh jq -r '.tag_name')"
fi

if [[ -z "$LITERT_LM_TAG" || "$LITERT_LM_TAG" == "null" ]]; then
  echo "ERROR: could not determine latest LiteRT-LM release tag from GitHub API." >&2
  exit 1
fi

mkdir -p "$PROJECT_ROOT/build/artifacts"
printf '%s\n' "$LITERT_LM_TAG" > "$PROJECT_ROOT/build/artifacts/litert-lm.version"

echo "Using LiteRT-LM release tag: $LITERT_LM_TAG"

echo "Installing Python binding into project Flox Python environment..."
"$PROJECT_ROOT/scripts/env/with_flox.sh" python -m pip install --upgrade \
  "git+https://github.com/$LITERT_LM_GH_REPO.git@$LITERT_LM_TAG"

echo "Swift binding setup guidance:"
echo "1) Add LiteRT-LM Swift package dependency to src/swift/Package.swift using exact tag $LITERT_LM_TAG"
echo "2) Run scripts/env/run_swift.sh package resolve"
echo "3) Run scripts/env/run_swift.sh build"
