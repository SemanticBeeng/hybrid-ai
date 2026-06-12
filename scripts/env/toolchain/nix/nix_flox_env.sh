#!/usr/bin/env bash
# Flox environment defaults for project scripts.
# Assumes local_env.sh was sourced at shell startup.

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"

# Verify local_env.sh was sourced.
if [[ -z "${NIX_ISOLATED_ROOT:-}" ]]; then
  echo "ERROR: NIX_ISOLATED_ROOT not set. Source scripts/local_env.sh first." >&2
  exit 1
fi

case "$NIX_ISOLATED_ROOT" in
  /nix|/nix/*)
    echo "ERROR: NIX_ISOLATED_ROOT must be a physical backing path, not under /nix: $NIX_ISOLATED_ROOT" >&2
    exit 1
    ;;
esac

if [[ ":$PATH:" != *":$NIX_ISOLATED_ROOT/bin:"* ]]; then
  export PATH="$NIX_ISOLATED_ROOT/bin:$PATH"
fi

# Flox environment defaults.
: "${FLOX_ENV_DIR:=$project_root}"
export FLOX_ENV_DIR
export FLOX_ENV_NAME="${FLOX_ENV_NAME:-${FLOX_ENV_DIR%/}}"
export FLOX_ENV_NAME="${FLOX_ENV_NAME##*/}"
: "${FLOX_DISABLE_METRICS:=true}"
export FLOX_DISABLE_METRICS
