#!/usr/bin/env bash

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

# shellcheck disable=SC1091
source "$project_root/scripts/env/toolchain/inference_env.sh"

hybrid_ai_export_litert_runtime_env() {
  export HYBRID_AI_INFERENCE_ENGINE="${HYBRID_AI_INFERENCE_ENGINE:-litert-lm}"
  export HYBRID_AI_LITERT_ARTIFACTS_DIR="${HYBRID_AI_LITERT_ARTIFACTS_DIR:-$project_root/build/artifacts/litert-lm}"

  mkdir -p "$HYBRID_AI_LITERT_ARTIFACTS_DIR"

  if declare -F hybrid_ai_assert_under_project >/dev/null 2>&1; then
    hybrid_ai_assert_under_project "$HYBRID_AI_LITERT_ARTIFACTS_DIR"
  fi
}

hybrid_ai_activate_litert_base_env() {
  hybrid_ai_export_litert_runtime_env
}

hybrid_ai_activate_litert_linux_gpu_env() {
  hybrid_ai_export_litert_runtime_env
  export HYBRID_AI_LITERT_BACKEND="${HYBRID_AI_LITERT_BACKEND:-gpu}"
}

hybrid_ai_activate_litert_ios_hosted_env() {
  hybrid_ai_export_litert_runtime_env
  export HYBRID_AI_APPLE_RUNTIME_HOST="${HYBRID_AI_APPLE_RUNTIME_HOST:-ios-hosted}"
  export HYBRID_AI_LITERT_APPLE_STAGING_DIR="${HYBRID_AI_LITERT_APPLE_STAGING_DIR:-$project_root/build/artifacts/litert-lm-ios}"

  mkdir -p "$HYBRID_AI_LITERT_APPLE_STAGING_DIR"

  if declare -F hybrid_ai_assert_under_project >/dev/null 2>&1; then
    hybrid_ai_assert_under_project "$HYBRID_AI_LITERT_APPLE_STAGING_DIR"
  fi
}