#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

find "$PROJECT_ROOT/build/python/cache" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
find "$PROJECT_ROOT/build/swift" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
find "$PROJECT_ROOT/volumes/cache" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

mkdir -p \
  "$PROJECT_ROOT/build/python/cache/pip" \
  "$PROJECT_ROOT/build/python/cache/poetry" \
  "$PROJECT_ROOT/build/python/cache/uv" \
  "$PROJECT_ROOT/volumes/cache/huggingface" \
  "$PROJECT_ROOT/volumes/cache/transformers"

echo "Caches pruned."
