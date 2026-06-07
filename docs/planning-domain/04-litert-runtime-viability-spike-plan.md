# 04 LiteRT Runtime Viability Spike Plan

## Purpose

This document isolates the real-runtime-first spike from the main delivery roadmap.

## Spike Goal

Prove that the chosen LiteRT runtime and Gemma model can initialize and answer one prompt through a minimal backend-to-Swift path.

## Minimal Scope

### Python Side

1. Implement LiteRT bootstrap and model resolution.
2. Implement a real LiteRT runtime class.
3. Keep an in-memory conversation registry.
4. Expose blocking endpoints for prepare, conversation creation, and message send.

### Swift Side

1. Implement a minimal backend client.
2. Implement a minimal backend runtime adapter.
3. Exercise prepare, create-conversation, and send once.

## Stop Conditions

1. Runtime preparation succeeds.
2. One backend conversation can be created.
3. One prompt returns one assistant reply.
4. One Swift path reaches that reply.
5. The implementation remains simple enough to refactor back into the layered architecture.

## Guardrails

1. Keep LiteRT lifecycle behind a runtime class boundary.
2. Keep the HTTP surface aligned with the shared Swift abstraction.
3. Avoid treating the spike API as final architecture without review.

## Companion Domain Documents

- [[04-br-linux-sandbox-approximation-requirements]]
- [[09-dd-model-bootstrap-and-runtime-pinning]]
- [[10-dd-backend-error-semantics]]
- [[13-dd-linux-backend-runtime-adapter]]
- [[14-dd-linux-backend-runtime-and-conversation-lifecycle]]

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]