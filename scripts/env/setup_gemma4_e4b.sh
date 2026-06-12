#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"

# shellcheck disable=SC1090
source "$project_root/scripts/env/toolchain/project_paths.sh"

MODEL_ROOT="$project_root/volumes/models/litert-lm"
MODEL_REF="${HYBRID_AI_LITERT_MODEL:-gemma4:e4b}"
MODEL_DIR="${HYBRID_AI_LITERT_MODEL_PATH:-$project_root/volumes/models/litert-lm/gemma4-e4b}"
MODEL_REF_FILE="$MODEL_ROOT/litert-lm.model"
MODEL_PATH_FILE="$MODEL_ROOT/litert-lm.model-path"
MODEL_FILE_METADATA="$MODEL_ROOT/litert-lm.model-file"
MODEL_FILENAME="${HYBRID_AI_LITERT_MODEL_FILENAME:-gemma-4-E4B-it.litertlm}"
MODEL_FILE="$MODEL_DIR/$MODEL_FILENAME"
MODEL_SOURCE="${HYBRID_AI_LITERT_MODEL_SOURCE:-}"
MODEL_URL="${HYBRID_AI_LITERT_MODEL_URL:-}"

mkdir -p "$MODEL_ROOT" "$MODEL_DIR"
hybrid_ai_assert_under_project "$MODEL_ROOT"
hybrid_ai_assert_under_project "$MODEL_DIR"

printf '%s\n' "$MODEL_REF" > "$MODEL_REF_FILE"
printf '%s\n' "$MODEL_DIR" > "$MODEL_PATH_FILE"
printf '%s\n' "$MODEL_FILE" > "$MODEL_FILE_METADATA"

if [[ -n "$MODEL_SOURCE" ]]; then
	hybrid_ai_assert_under_project "$MODEL_SOURCE"
	if [[ ! -f "$MODEL_SOURCE" ]]; then
		echo "ERROR: model source file not found: $MODEL_SOURCE" >&2
		exit 1
	fi
	cp -f "$MODEL_SOURCE" "$MODEL_FILE"
	bootstrap_action="copied local model source"
elif [[ -n "$MODEL_URL" ]]; then
	if ! command -v curl >/dev/null 2>&1; then
		echo "ERROR: curl is required for HYBRID_AI_LITERT_MODEL_URL downloads." >&2
		exit 1
	fi
	curl -fL "$MODEL_URL" -o "$MODEL_FILE"
	bootstrap_action="downloaded model from URL"
elif [[ -f "$MODEL_FILE" ]]; then
	bootstrap_action="reused existing pinned model file"
else
	echo "ERROR: no Gemma 4 E4B model file is available." >&2
	echo "Set HYBRID_AI_LITERT_MODEL_SOURCE to a project-local .litertlm file or HYBRID_AI_LITERT_MODEL_URL to a direct download URL." >&2
	exit 1
fi

echo "Pinned LiteRT-LM model reference: $MODEL_REF"
echo "Pinned LiteRT-LM model path: $MODEL_DIR"
echo "Pinned LiteRT-LM model file: $MODEL_FILE"
echo "Bootstrap action: $bootstrap_action"
echo ""
echo "Next steps:"
echo "1) Use HYBRID_AI_LITERT_MODEL=$MODEL_REF for metadata and logical model identity"
echo "2) Use the pinned model file at $MODEL_FILE for LiteRT-LM runtime and backend inference"
echo "3) Keep backend readiness checks tied to $MODEL_REF_FILE, $MODEL_PATH_FILE, build/artifacts/litert-lm.version, and the presence of $MODEL_FILE"