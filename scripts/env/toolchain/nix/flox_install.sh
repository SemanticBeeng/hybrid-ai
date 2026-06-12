#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"
source "$project_root/scripts/env/toolchain/common.sh"
source "$project_root/scripts/env/toolchain/nix/nix_setup.sh"

TARGET_BIN_DIR="$NIX_ISOLATED_ROOT/bin"
FLOX_FLAKE_REF="${FLOX_FLAKE_REF:-github:flox/flox/v1.12.2}"
"$project_root/scripts/env/toolchain/nix/nix_mount_manage.sh" mount
ensure_nix_bind_mount

run_as_root mkdir -p "$TARGET_BIN_DIR"

if [[ ! -x "$NIX_WRAPPER_BIN" ]]; then
  if [[ ! -x "$DETERMINATE_NIX_BIN" ]]; then
    echo "ERROR: nix binary not found at $DETERMINATE_NIX_BIN" >&2
    echo "Install Determinate Nix first." >&2
    exit 1
  fi

  tmp_nix_wrapper="$(mktemp)"
  cat >"$tmp_nix_wrapper" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$DETERMINATE_NIX_BIN" "\$@"
EOF
  run_as_root install -m 0755 "$tmp_nix_wrapper" "$NIX_WRAPPER_BIN"
  rm -f "$tmp_nix_wrapper"
fi

if run_as_root test -x "$FLOX_PROFILE/bin/flox"; then
  echo "Flox already installed in profile $FLOX_PROFILE"
else
  echo "Installing flox via nix profile from: $FLOX_FLAKE_REF"
  run_as_root "$NIX_WRAPPER_BIN" profile install \
    --profile "$FLOX_PROFILE" \
    --accept-flake-config \
    "$FLOX_FLAKE_REF"
fi

tmp_flox_wrapper="$(mktemp)"
cat >"$tmp_flox_wrapper" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$FLOX_PROFILE/bin/flox" "\$@"
EOF
run_as_root install -m 0755 "$tmp_flox_wrapper" "$FLOX_WRAPPER_BIN"
rm -f "$tmp_flox_wrapper"

run_as_root "$FLOX_WRAPPER_BIN" --version

echo "Installed flox to: $FLOX_WRAPPER_BIN"
