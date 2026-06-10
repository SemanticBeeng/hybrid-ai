#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$project_root/scripts/env/toolchain/common.sh"

# Override if upstream organization/repo changes.
LITERT_LM_GH_REPO="${LITERT_LM_GH_REPO:-google-ai-edge/LiteRT-LM}"
LITERT_LM_TAG="${LITERT_LM_TAG:-v0.13.1}"
LITERT_LM_PYPI_PACKAGE="${LITERT_LM_PYPI_PACKAGE:-litert-lm}"
LITERT_LM_PYPI_VERSION="${LITERT_LM_PYPI_VERSION:-${LITERT_LM_TAG#v}}"

if [[ -z "$LITERT_LM_TAG" || "$LITERT_LM_TAG" == "null" ]]; then
  echo "ERROR: LiteRT-LM release tag is empty." >&2
  exit 1
fi

if [[ -z "$LITERT_LM_PYPI_VERSION" || "$LITERT_LM_PYPI_VERSION" == "null" ]]; then
  echo "ERROR: LiteRT-LM PyPI version is empty." >&2
  exit 1
fi

mkdir -p "$project_root/build/artifacts"
printf '%s\n' "$LITERT_LM_TAG" > "$project_root/build/artifacts/litert-lm.version"

echo "Using LiteRT-LM release tag: $LITERT_LM_TAG"
echo "Using LiteRT-LM PyPI package: $LITERT_LM_PYPI_PACKAGE==$LITERT_LM_PYPI_VERSION"

echo "Validating Poetry-managed LiteRT-LM dependency in project Flox Python environment..."
"$project_root/scripts/modules/inference_srv_py/run.sh" - <<'PY'
from importlib import metadata

package_name = "litert-lm"
module_name = "litert_lm"
expected_version = "0.13.1"

installed_version = metadata.version(package_name)
if installed_version != expected_version:
  raise SystemExit(
    f"ERROR: expected {package_name}=={expected_version}, found {installed_version}. "
    "Run poetry lock/sync through the managed Python environment first."
  )

module = __import__(module_name)
print(f"Verified {package_name}=={installed_version}")
print(f"Module path: {module.__file__}")
PY

echo "Swift binding setup guidance:"
echo "1) Add LiteRT-LM Swift package dependency to src/swift/Package.swift using exact tag $LITERT_LM_TAG"
echo "2) Run scripts/modules/swift/run.sh package resolve"
echo "3) Run scripts/modules/swift/run.sh build"
