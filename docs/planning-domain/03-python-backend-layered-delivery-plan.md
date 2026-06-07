# 03 Python Backend Layered Delivery Plan

## Purpose

This document isolates the layered backend-first execution path from the broader LiteRT runbook.

## Workstream Type

Primary alternative Linux-start implementation workstream.

## Requirements Served

- [[04-br-linux-sandbox-approximation-requirements]]
- [[05-br-conversation-oriented-inference-experience]]
- [[06-br-shared-swift-core-portability-requirements]]

## Design Decisions Relied On

- [[07-dd-backend-conversation-contract]]
- [[10-dd-backend-error-semantics]]
- [[13-dd-linux-backend-runtime-adapter]]
- [[14-dd-linux-backend-runtime-and-conversation-lifecycle]]

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

## Task Slices

1. Define Python runtime protocols, models, and error types.
2. Implement a fake runtime and in-memory conversation store.
3. Expose FastAPI endpoints that mirror the shared Swift contract.
4. Add Python unit and API tests around lifecycle, send, stream, and error mapping.
5. Implement the Swift backend client and runtime adapter against the fake service.
6. Re-run the shared Swift contract tests against the backend-backed runtime.
7. Swap the fake runtime for the real LiteRT-backed runtime once the contract is stable.

## Exit Criteria

1. The Linux backend satisfies the shared runtime contract through the Swift adapter.
2. Contract, transport, and error behavior remain stable as the real LiteRT runtime replaces the fake one.
3. The workstream leaves the Apple deployment path intact rather than optimizing only for Linux convenience.

## Dependencies

- shared Swift runtime contract
- Python runtime package separation
- FastAPI transport boundary

## Companion Domain Documents

- [[04-br-linux-sandbox-approximation-requirements]]
- [[05-br-conversation-oriented-inference-experience]]
- [[06-br-shared-swift-core-portability-requirements]]
- [[07-dd-backend-conversation-contract]]
- [[10-dd-backend-error-semantics]]
- [[13-dd-linux-backend-runtime-adapter]]
- [[14-dd-linux-backend-runtime-and-conversation-lifecycle]]

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]