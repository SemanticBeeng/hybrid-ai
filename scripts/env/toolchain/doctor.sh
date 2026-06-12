#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"
source "$project_root/scripts/env/toolchain/common.sh"
source "$project_root/scripts/env/toolchain/nix/nix_setup.sh"

fail() {
  echo "ERROR: $1" >&2
  exit 1
}

must_exist=(
  "$project_root/build"
  "$project_root/volumes"
  "$project_root/deps"
  "$project_root/.flox/env/manifest.toml"
  "$project_root/.vscode/settings.json"
)

for p in "${must_exist[@]}"; do
  [[ -e "$p" ]] || fail "Missing required path: $p"
done

for p in "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"; do
  case "$p" in
    "$project_root"/*) ;;
    *) fail "Path is outside project root: $p" ;;
  esac
done

if [[ -x "$DETERMINATE_NIX_BIN" || -x "$NIX_WRAPPER_BIN" || -x "$FLOX_WRAPPER_BIN" ]]; then
  ensure_nix_bind_mount || fail "/nix mount is not active"
  [[ -r "$NIX_DAEMON_PROFILE_SCRIPT" ]] || fail "Missing nix-daemon profile script: $NIX_DAEMON_PROFILE_SCRIPT"
  require_nix_daemon_socket || fail "Nix daemon socket check failed"
fi

for forbidden in "$project_root/src/inference_srv_py/__pycache__" "$project_root/src/swift/.build"; do
  [[ ! -e "$forbidden" ]] || fail "Forbidden byproduct detected: $forbidden"
done

# Flox environment sync check (ensures manifest and lockfile are in sync).
# This is done once in doctor.sh rather than on every flox_with.sh / start_vscode.sh call.
_require_flox_bin() {
  if [[ -n "${FLOX_BIN:-}" ]]; then
    printf '%s\n' "$FLOX_BIN"
  else
    echo "ERROR: flox is required but not installed or not in PATH." >&2
    return 1
  fi
}

_require_flox_env() {
  local env_dir="$1"
  if [[ ! -f "$env_dir/manifest.toml" && ! -f "$env_dir/.flox/env/manifest.toml" ]]; then
    echo "ERROR: expected Flox manifest at $env_dir/.flox/env/manifest.toml or $env_dir/manifest.toml" >&2
    return 1
  fi
}

_ensure_flox_env_ready() {
  local env_dir="${1:-$FLOX_ENV_DIR}"
  local init_script="$project_root/scripts/env/toolchain/nix/flox_env_init.sh"
  local flox_bin=""
  local activate_output=""
  local status=0

  _require_flox_env "$env_dir" || return
  flox_bin="$(_require_flox_bin)" || return

  set +e
  activate_output="$("$flox_bin" activate -d "$env_dir" -- bash --noprofile --norc -lc 'exit 0' 2>&1)"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    return 0
  fi

  if [[ "$activate_output" == *"manifest and lockfile are out of sync"* ]]; then
    if [[ ! -x "$init_script" ]]; then
      echo "ERROR: Flox environment state is stale, and sync helper is not executable: $init_script" >&2
      printf '%s\n' "$activate_output" >&2
      return "$status"
    fi

    echo "INFO: Flox environment state is stale; syncing manifests." >&2
    FLOX_ENV_DIR="$env_dir" "$init_script" >/dev/null
    return 0
  fi

  printf '%s\n' "$activate_output" >&2
  return "$status"
}

if [[ -n "${FLOX_BIN:-}" ]]; then
  _ensure_flox_env_ready "$project_root" || fail "Flox root environment sync failed"
fi

echo "doctor: OK"
