#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/common.sh"

TARGET_BIN_DIR="$NIX_ISOLATED_ROOT/bin"
TARGET_FLOX_BIN="$TARGET_BIN_DIR/flox"
NIX_BIN="$NIX_ISOLATED_ROOT/bin/nix"
FLOX_FLAKE_REF="${FLOX_FLAKE_REF:-github:flox/flox/v1.12.2}"

case "$NIX_ISOLATED_ROOT" in
  /nix|/nix/*)
    echo "ERROR: refusing flox install with root /nix target: $NIX_ISOLATED_ROOT" >&2
    exit 1
    ;;
esac

mkdir -p "$TARGET_BIN_DIR"

if [[ ! -w "$TARGET_BIN_DIR" ]]; then
  echo "ERROR: no write permission to $TARGET_BIN_DIR" >&2
  exit 1
fi

if [[ ! -x "$NIX_BIN" ]]; then
  echo "ERROR: nix not found at $NIX_BIN" >&2
  echo "Run scripts/env/install_nix_determinate.sh first." >&2
  exit 1
fi

echo "Installing flox via nix profile from: $FLOX_FLAKE_REF"
"$NIX_BIN" profile install --accept-flake-config "$FLOX_FLAKE_REF"

cat >"$TARGET_FLOX_BIN" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$NIX_BIN" run --accept-flake-config "$FLOX_FLAKE_REF" -- "\$@"
EOF

chmod +x "$TARGET_FLOX_BIN"

"$TARGET_FLOX_BIN" --version

echo "Installed flox to: $TARGET_FLOX_BIN"
