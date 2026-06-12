#!/usr/bin/env bash
# local_env.sh — Single source of truth for project root and Nix/Flox binary paths.
#
# MUST be sourced once at shell startup (e.g., in .bashrc or flox hook) before
# running any project scripts. Scripts assume these variables are already set.
#
# Exports:
#   PROJECT_ROOT      - Absolute path to the project root directory
#   NIX_ISOLATED_ROOT - Physical backing path for /nix mount (default: /opt/bin/dev/nix)
#   NIX_BIN           - Resolved path to nix binary
#   FLOX_BIN          - Resolved path to flox binary

# Project root — customize this path for your environment.
# Always set, even on re-source, since scripts depend on it.
: "${PROJECT_ROOT:=/home/nkse/projects/hybrid-ai}"
export PROJECT_ROOT

# Physical backing path for the Nix store bind mount.
: "${NIX_ISOLATED_ROOT:=/opt/bin/dev/nix}"
export NIX_ISOLATED_ROOT

# Idempotent: skip expensive binary resolution if already sourced.
[[ -n "${_LOCAL_ENV_SOURCED:-}" ]] && return 0
_LOCAL_ENV_SOURCED=1

# Resolve nix binary: prefer PATH, fall back to isolated root.
if command -v nix >/dev/null 2>&1; then
  NIX_BIN="$(command -v nix)"
elif [[ -x "$NIX_ISOLATED_ROOT/bin/nix" ]]; then
  NIX_BIN="$NIX_ISOLATED_ROOT/bin/nix"
else
  NIX_BIN=""
fi
export NIX_BIN

# Resolve flox binary: prefer PATH, fall back to isolated root.
if command -v flox >/dev/null 2>&1; then
  FLOX_BIN="$(command -v flox)"
elif [[ -x "$NIX_ISOLATED_ROOT/bin/flox" ]]; then
  FLOX_BIN="$NIX_ISOLATED_ROOT/bin/flox"
else
  FLOX_BIN=""
fi
export FLOX_BIN
