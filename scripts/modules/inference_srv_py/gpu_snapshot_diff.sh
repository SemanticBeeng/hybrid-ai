#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <left-json> <right-json>" >&2
  exit 2
fi

left_path="$1"
right_path="$2"

python - "$left_path" "$right_path" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path


def load(path: str):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def walk(prefix: str, left, right, output: list[str]) -> None:
    if type(left) is not type(right):
        output.append(f"{prefix}: type {type(left).__name__} != {type(right).__name__}")
        return

    if isinstance(left, dict):
        keys = sorted(set(left) | set(right))
        for key in keys:
            child_prefix = f"{prefix}.{key}" if prefix else key
            if key not in left:
                output.append(f"{child_prefix}: missing on left, right={right[key]!r}")
            elif key not in right:
                output.append(f"{child_prefix}: left={left[key]!r}, missing on right")
            else:
                walk(child_prefix, left[key], right[key], output)
        return

    if isinstance(left, list):
        if left != right:
            output.append(f"{prefix}: left={left!r} right={right!r}")
        return

    if left != right:
        output.append(f"{prefix}: left={left!r} right={right!r}")


left = load(sys.argv[1])
right = load(sys.argv[2])
differences: list[str] = []
walk("", left, right, differences)

if not differences:
    print("no differences")
    raise SystemExit(0)

for line in differences:
    print(line)
PY