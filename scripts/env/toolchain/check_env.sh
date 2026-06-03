#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/toolchain/common.sh"

echo "PROJECT_ROOT=$PROJECT_ROOT"
echo "NIX_ISOLATED_ROOT=$NIX_ISOLATED_ROOT"
echo "NIX_MOUNT_POINT=$NIX_MOUNT_POINT"
echo "NIX_CONF_DIR=$NIX_CONF_DIR"
echo "NIX_DAEMON_PROFILE_SCRIPT=$NIX_DAEMON_PROFILE_SCRIPT"
echo "NIX_DAEMON_SOCKET=$NIX_DAEMON_SOCKET"
echo "NIX_REMOTE=${NIX_REMOTE:-unset}"
echo "HOME=$HOME"
echo "XDG_CONFIG_HOME=$XDG_CONFIG_HOME"
echo "XDG_CACHE_HOME=$XDG_CACHE_HOME"
echo "XDG_DATA_HOME=$XDG_DATA_HOME"
echo "XDG_STATE_HOME=$XDG_STATE_HOME"
echo "PYTHON_DIR=$PYTHON_DIR"
echo "VIRTUAL_ENV=$VIRTUAL_ENV"
echo "PIP_CACHE_DIR=$PIP_CACHE_DIR"
echo "POETRY_CACHE_DIR=$POETRY_CACHE_DIR"
echo "UV_CACHE_DIR=$UV_CACHE_DIR"
echo "PYTHONPYCACHEPREFIX=$PYTHONPYCACHEPREFIX"
echo "SWIFT_BUILD_PATH=$SWIFT_BUILD_PATH"
echo "CACTUS_MODEL_PATH=$CACTUS_MODEL_PATH"
echo "LITERT_LM_MODELS=$LITERT_LM_MODELS"

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
