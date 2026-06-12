#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"
host="${HYBRID_AI_HOST:-127.0.0.1}"
port="${HYBRID_AI_PORT:-18090}"
server_url="http://${host}:${port}"
server_log="/tmp/hybrid-ai-gpu-smoke-server-${port}.log"
startup_timeout_seconds="${HYBRID_AI_GPU_SMOKE_STARTUP_TIMEOUT_SECONDS:-30}"
poll_interval_seconds="${HYBRID_AI_GPU_SMOKE_POLL_INTERVAL_SECONDS:-1}"
system_prompt="${HYBRID_AI_GPU_SMOKE_SYSTEM_PROMPT:-Reply briefly.}"
message_text="${HYBRID_AI_GPU_SMOKE_MESSAGE:-Say hello in five words or fewer.}"
server_pid=""

cleanup() {
  if [[ -n "$server_pid" ]] && kill -0 "$server_pid" >/dev/null 2>&1; then
    kill -- "-$server_pid" >/dev/null 2>&1 || kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" >/dev/null 2>&1 || true
  fi
}

port_is_busy() {
  ss -ltn "sport = :$port" | awk 'NR > 1 { exit 0 } END { exit 1 }'
}

trap cleanup EXIT

cd "$project_root"

if port_is_busy; then
  echo "ERROR: smoke port ${port} is already in use; set HYBRID_AI_PORT to a free port" >&2
  exit 1
fi

echo "==> host GPU check"
nvidia-smi --query-gpu=index,name,driver_version,memory.total --format=csv,noheader

echo "==> managed GPU validation"
./scripts/modules/inference_srv_py/gpu_validate.sh

echo "==> starting GPU server on ${server_url}"
setsid env HYBRID_AI_HOST="$host" \
HYBRID_AI_PORT="$port" \
./scripts/modules/inference_srv_py/server_gpu_run.sh >"$server_log" 2>&1 &
server_pid="$!"

echo "==> waiting for /ready"
ready_payload=""
for ((attempt=0; attempt<startup_timeout_seconds; attempt+=poll_interval_seconds)); do
  ready_payload="$(curl -fsS "${server_url}/ready" 2>/dev/null || true)"
  if [[ -n "$ready_payload" ]] && printf '%s' "$ready_payload" | jq -e '.ready == true' >/dev/null 2>&1; then
    break
  fi
  sleep "$poll_interval_seconds"
done

if [[ -z "$ready_payload" ]] || ! printf '%s' "$ready_payload" | jq -e '.ready == true' >/dev/null 2>&1; then
  echo "ERROR: GPU smoke server did not become ready" >&2
  echo "Last /ready payload:" >&2
  if [[ -n "$ready_payload" ]]; then
    printf '%s\n' "$ready_payload" >&2
  else
    echo "<empty>" >&2
  fi
  echo "Server log:" >&2
  cat "$server_log" >&2 || true
  exit 1
fi

echo "==> /ready"
printf '%s\n' "$ready_payload"

echo "==> /health"
curl -fsS "${server_url}/health"
echo

echo "==> create conversation"
conversation_payload="$(curl -fsS -X POST "${server_url}/v1/conversations" -H 'Content-Type: application/json' -d "$(jq -nc --arg system_prompt "$system_prompt" '{system_prompt: $system_prompt}')")"
printf '%s\n' "$conversation_payload"
conversation_id="$(printf '%s' "$conversation_payload" | jq -r '.conversation_id')"

if [[ -z "$conversation_id" || "$conversation_id" == "null" ]]; then
  echo "ERROR: conversation creation did not return a conversation_id" >&2
  exit 1
fi

echo "==> send message"
message_payload="$(curl -fsS -X POST "${server_url}/v1/conversations/${conversation_id}/messages" -H 'Content-Type: application/json' -d "$(jq -nc --arg text "$message_text" '{text: $text}')")"
printf '%s\n' "$message_payload"

assistant_text="$(printf '%s' "$message_payload" | jq -r '.message.text')"
if [[ -z "$assistant_text" || "$assistant_text" == "null" ]]; then
  echo "ERROR: message response did not contain assistant text" >&2
  exit 1
fi

if [[ "$assistant_text" == "{"* || "$assistant_text" == "["* ]]; then
  echo "ERROR: message response was not normalized to plain assistant text" >&2
  printf 'assistant_text=%s\n' "$assistant_text" >&2
  exit 1
fi

echo "==> GPU smoke succeeded"