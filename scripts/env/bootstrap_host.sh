#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NIX_ISOLATED_ROOT="${NIX_ISOLATED_ROOT:-/opt/bin/dev/nix}"

case "$NIX_ISOLATED_ROOT" in
  /nix|/nix/*)
    echo "ERROR: refusing root /nix target: $NIX_ISOLATED_ROOT" >&2
    echo "Use a non-root isolated target, for example: /opt/bin/dev/nix" >&2
    exit 1
    ;;
esac

mkdir -p "$PROJECT_ROOT/build" "$PROJECT_ROOT/volumes" "$PROJECT_ROOT/deps"

if [[ -w "$(dirname "$NIX_ISOLATED_ROOT")" ]] || [[ -d "$NIX_ISOLATED_ROOT" && -w "$NIX_ISOLATED_ROOT" ]]; then
  mkdir -p "$NIX_ISOLATED_ROOT/etc/nix" "$NIX_ISOLATED_ROOT/var/nix"
  NIX_CONF_TARGET="$NIX_ISOLATED_ROOT/etc/nix/nix.conf"
else
  echo "WARN: $NIX_ISOLATED_ROOT is not writable on this host. Using project-local fallback for nix.conf." >&2
  mkdir -p "$PROJECT_ROOT/nix"
  NIX_CONF_TARGET="$PROJECT_ROOT/nix/nix.conf"
fi

cat >"$NIX_CONF_TARGET" <<'EOF'
experimental-features = nix-command flakes
accept-flake-config = true
# Store/layer settings are host-specific and should be adjusted per machine policy.
# Keep this config explicit and under version control where feasible.
EOF

cat <<EOF
Bootstrap complete.
nix.conf path: $NIX_CONF_TARGET
Next: run scripts/env/install_toolchain.sh, then scripts/verify/doctor.sh
EOF
