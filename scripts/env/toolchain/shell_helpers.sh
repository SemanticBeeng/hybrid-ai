#!/usr/bin/env bash
# shell_helpers.sh — Common shell utility functions.
# Idempotent: safe to source multiple times.

[[ -n "${_SHELL_HELPERS_SOURCED:-}" ]] && return 0
_SHELL_HELPERS_SOURCED=1

have_command() {
  command -v "$1" >/dev/null 2>&1
}

run_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
    return
  fi

  if have_command sudo; then
    sudo -n "$@"
    return
  fi

  echo "ERROR: root privileges are required for: $*" >&2
  return 1
}
