#!/usr/bin/env bash

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

if ! declare -F hybrid_ai_assert_under_project >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/project_paths.sh"
fi

export CACTUS_MODEL_PATH="$project_root/volumes/models/cactus"
export LITERT_LM_MODELS="$project_root/volumes/models/litert-lm"
export HF_HOME="$project_root/volumes/cache/huggingface"
export TRANSFORMERS_CACHE="$project_root/volumes/cache/transformers"

mkdir -p \
  "$CACTUS_MODEL_PATH" \
  "$LITERT_LM_MODELS" \
  "$HF_HOME" \
  "$TRANSFORMERS_CACHE" \
  "$project_root/volumes/logs" \
  "$project_root/build/artifacts" \
  "$project_root/deps/libs" \
  "$project_root/deps/models"

hybrid_ai_assert_under_project "$CACTUS_MODEL_PATH"
hybrid_ai_assert_under_project "$LITERT_LM_MODELS"
hybrid_ai_assert_under_project "$HF_HOME"
hybrid_ai_assert_under_project "$TRANSFORMERS_CACHE"
