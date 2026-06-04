#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

exec "$PROJECT_ROOT/scripts/env/with_flox.sh" bash -lc '
	PROJECT_ROOT="$1"
	shift

	# shellcheck disable=SC1090
	source "$PROJECT_ROOT/scripts/env/toolchain/python_env.sh"
	hybrid_ai_activate_python_env

	printf "PROJECT_ROOT=%s\n" "$PROJECT_ROOT"
	printf "FLOX_ENV=%s\n" "${FLOX_ENV:-unset}"
	printf "FLOX_ENV_CACHE=%s\n" "${FLOX_ENV_CACHE:-unset}"
	printf "NIX_ISOLATED_ROOT=%s\n" "$NIX_ISOLATED_ROOT"
	printf "NIX_MOUNT_POINT=%s\n" "$NIX_MOUNT_POINT"
	printf "NIX_CONF_DIR=%s\n" "$NIX_CONF_DIR"
	printf "NIX_DAEMON_PROFILE_SCRIPT=%s\n" "$NIX_DAEMON_PROFILE_SCRIPT"
	printf "NIX_DAEMON_SOCKET=%s\n" "$NIX_DAEMON_SOCKET"
	printf "NIX_REMOTE=%s\n" "${NIX_REMOTE:-unset}"
	printf "HOME=%s\n" "$HOME"
	printf "XDG_CONFIG_HOME=%s\n" "$XDG_CONFIG_HOME"
	printf "XDG_CACHE_HOME=%s\n" "$XDG_CACHE_HOME"
	printf "XDG_DATA_HOME=%s\n" "$XDG_DATA_HOME"
	printf "XDG_STATE_HOME=%s\n" "$XDG_STATE_HOME"
	printf "PYTHON_DIR=%s\n" "$PYTHON_DIR"
	printf "HYBRID_AI_PYTHON_VENV=%s\n" "$HYBRID_AI_PYTHON_VENV"
	printf "VIRTUAL_ENV=%s\n" "${VIRTUAL_ENV:-unset}"
	printf "POETRY_VIRTUALENVS_CREATE=%s\n" "${POETRY_VIRTUALENVS_CREATE:-unset}"
	printf "PIP_CACHE_DIR=%s\n" "$PIP_CACHE_DIR"
	printf "POETRY_CACHE_DIR=%s\n" "$POETRY_CACHE_DIR"
	printf "UV_CACHE_DIR=%s\n" "$UV_CACHE_DIR"
	printf "PYTHONPYCACHEPREFIX=%s\n" "$PYTHONPYCACHEPREFIX"
	printf "LD_LIBRARY_PATH=%s\n" "${LD_LIBRARY_PATH:-unset}"
	printf "SWIFT_BUILD_PATH=%s\n" "$SWIFT_BUILD_PATH"
	printf "CACTUS_MODEL_PATH=%s\n" "$CACTUS_MODEL_PATH"
	printf "LITERT_LM_MODELS=%s\n" "$LITERT_LM_MODELS"

	if [[ -r "$NIX_DAEMON_PROFILE_SCRIPT" ]]; then
		echo "daemon_profile_script=readable"
	else
		echo "daemon_profile_script=missing_or_unreadable"
	fi

	if [[ -S "$NIX_DAEMON_SOCKET" ]]; then
		echo "daemon_socket=present"
	else
		echo "daemon_socket=missing"
	fi
' bash "$PROJECT_ROOT"
