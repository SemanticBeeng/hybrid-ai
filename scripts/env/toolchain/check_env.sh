#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$project_root/scripts/env/toolchain/common.sh"

printf "project_root=%s\n" "$project_root"
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
