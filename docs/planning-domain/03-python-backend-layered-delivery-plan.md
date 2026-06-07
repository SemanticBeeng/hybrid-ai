# 03 Python Backend Layered Delivery Plan

## Purpose

This document isolates the layered backend-first execution path from the broader LiteRT runbook.

## Sequence

1. Freeze the Python-side runtime contract.
2. Implement a fake runtime that matches the shared semantics.
3. Expose FastAPI endpoints over the fake runtime.
4. Add Python tests for lifecycle, send, and stream behavior.
5. Implement the Swift backend client and runtime adapter.
6. Run the shared Swift contract tests against the backend adapter.
7. Replace the fake runtime with the real LiteRT-backed runtime.

## Planning Rationale

1. The protocol and transport settle before model complexity enters.
2. Swift integration can begin before LiteRT viability is fully proven.
3. The runtime contract stays the acceptance gate instead of becoming documentation only.

## Dependencies

- shared Swift runtime contract
- Python runtime package separation
- FastAPI transport boundary

## Companion Domain Documents

- [[04-br-linux-sandbox-approximation-requirements]]
- [[05-br-conversation-oriented-inference-experience]]
- [[07-dd-backend-conversation-contract]]
- [[10-dd-backend-error-semantics]]
- [[13-dd-linux-backend-runtime-adapter]]
- [[14-dd-linux-backend-runtime-and-conversation-lifecycle]]

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]