#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
export -n PROJECT_ROOT 2>/dev/null || true

if ! declare -F hybrid_ai_assert_under_project >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$PROJECT_ROOT/scripts/env/toolchain/project_paths.sh"
fi

export CACTUS_MODEL_PATH="$PROJECT_ROOT/volumes/models/cactus"
export LITERT_LM_MODELS="$PROJECT_ROOT/volumes/models/litert-lm"
export HF_HOME="$PROJECT_ROOT/volumes/cache/huggingface"
export TRANSFORMERS_CACHE="$PROJECT_ROOT/volumes/cache/transformers"

mkdir -p \
  "$CACTUS_MODEL_PATH" \
  "$LITERT_LM_MODELS" \
  "$HF_HOME" \
  "$TRANSFORMERS_CACHE" \
  "$PROJECT_ROOT/volumes/logs" \
  "$PROJECT_ROOT/build/artifacts" \
  "$PROJECT_ROOT/deps/libs" \
  "$PROJECT_ROOT/deps/models"

hybrid_ai_assert_under_project "$CACTUS_MODEL_PATH"
hybrid_ai_assert_under_project "$LITERT_LM_MODELS"
hybrid_ai_assert_under_project "$HF_HOME"
hybrid_ai_assert_under_project "$TRANSFORMERS_CACHE"
