from __future__ import annotations

import json

import numpy as np


def build_demo_payload() -> dict[str, object]:
    samples = np.array([1.0, 2.0, 3.0, 4.0], dtype=np.float64)
    weights = np.array([0.5, 1.5, -1.0, 2.0], dtype=np.float64)
    outer = np.outer(samples, weights)

    return {
        "vector": samples.tolist(),
        "weights": weights.tolist(),
        "dot": float(samples @ weights),
        "mean": float(samples.mean()),
        "outer_shape": list(outer.shape),
        "row_sums": outer.sum(axis=1).tolist(),
    }


def main() -> None:
    print(json.dumps(build_demo_payload(), indent=2, sort_keys=True))


if __name__ == "__main__":
    main()