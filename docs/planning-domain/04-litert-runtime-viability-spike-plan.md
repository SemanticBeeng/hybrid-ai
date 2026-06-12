# 04 LiteRT Runtime Viability Spike Plan

## Purpose

This document isolates the real-runtime-first spike from the main delivery roadmap.

## Workstream Type

Alternative Linux-start implementation workstream.

## Status

Active preferred Linux implementation workstream.

## Requirements Served

- [[04-br-linux-sandbox-approximation-requirements]]
- [[05-br-conversation-oriented-inference-experience]]

## Design Decisions Relied On

- [[09-dd-model-bootstrap-and-runtime-pinning]]
- [[10-dd-backend-error-semantics]]
- [[13-dd-linux-backend-runtime-adapter]]
- [[14-dd-linux-backend-runtime-and-conversation-lifecycle]]

## Spike Goal

Prove that the chosen LiteRT runtime and Gemma model can initialize and answer one prompt through a minimal backend-to-Swift path.

The spike is still expected to preserve the one-runtime-many-conversations model rather than proving only a single stateless request path.

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

## Task Slices

1. Make model bootstrap and runtime pinning explicit enough to run a real LiteRT startup path.
2. Implement the smallest real LiteRT runtime class needed to prepare, create and track multiple conversations, and answer prompts through those conversation handles.
3. Expose the smallest transport surface needed for the Swift adapter to exercise prepare, create-conversation, send, and basic conversation identity behavior.
4. Implement the minimum Swift backend client and runtime wrapper needed to prove end-to-end reachability while preserving conversation identity and transcript isolation.
5. Stop once the runtime viability question is answered and refactor back toward the layered contract-first path.

## Exit Criteria

1. The chosen model can prepare successfully in the constrained Linux environment.
2. More than one backend conversation can exist without transcript or identity bleed.
3. The Swift adapter can reach a real assistant response through the backend while preserving conversation semantics.
4. The spike remains small enough that its transport and runtime logic can be folded back into the disciplined layered architecture.

## Companion Domain Documents

- [[04-br-linux-sandbox-approximation-requirements]]
- [[09-dd-model-bootstrap-and-runtime-pinning]]
- [[10-dd-backend-error-semantics]]
- [[13-dd-linux-backend-runtime-adapter]]
- [[14-dd-linux-backend-runtime-and-conversation-lifecycle]]

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]