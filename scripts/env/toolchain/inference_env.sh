#!/usr/bin/env bash

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

if ! declare -F hybrid_ai_assert_under_project >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/project_paths.sh"
fi

export CACTUS_MODEL_PATH="$project_root/volumes/models/cactus"
export LITERT_LM_MODELS="$project_root/volumes/models/litert-lm"
export HYBRID_AI_LITERT_MODEL="${HYBRID_AI_LITERT_MODEL:-gemma4:e4b}"
export HYBRID_AI_LITERT_MODEL_PATH="${HYBRID_AI_LITERT_MODEL_PATH:-$LITERT_LM_MODELS/gemma4-e4b}"
export HYBRID_AI_LITERT_MODEL_FILENAME="${HYBRID_AI_LITERT_MODEL_FILENAME:-gemma-4-E4B-it.litertlm}"
export HYBRID_AI_LITERT_MODEL_FILE="${HYBRID_AI_LITERT_MODEL_FILE:-$HYBRID_AI_LITERT_MODEL_PATH/$HYBRID_AI_LITERT_MODEL_FILENAME}"
export HF_HOME="$project_root/volumes/cache/huggingface"
export TRANSFORMERS_CACHE="$project_root/volumes/cache/transformers"

mkdir -p \
  "$CACTUS_MODEL_PATH" \
  "$LITERT_LM_MODELS" \
  "$HYBRID_AI_LITERT_MODEL_PATH" \
  "$(dirname "$HYBRID_AI_LITERT_MODEL_FILE")" \
  "$HF_HOME" \
  "$TRANSFORMERS_CACHE" \
  "$project_root/volumes/logs" \
  "$project_root/build/artifacts" \
  "$project_root/deps/libs" \
  "$project_root/deps/models"

hybrid_ai_assert_under_project "$CACTUS_MODEL_PATH"
hybrid_ai_assert_under_project "$LITERT_LM_MODELS"
hybrid_ai_assert_under_project "$HYBRID_AI_LITERT_MODEL_PATH"
hybrid_ai_assert_under_project "$HYBRID_AI_LITERT_MODEL_FILE"
hybrid_ai_assert_under_project "$HF_HOME"
hybrid_ai_assert_under_project "$TRANSFORMERS_CACHE"
