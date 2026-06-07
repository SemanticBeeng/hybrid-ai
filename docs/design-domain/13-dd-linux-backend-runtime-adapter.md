# 13 DD Linux Backend Runtime Adapter

## Scope

This document isolates the Linux backend runtime adapter design from the broader cross-platform adapter pattern.

## Design Statement

Linux inference integration should live behind a backend-facing adapter that satisfies the shared Swift runtime contract while preserving a real backend process boundary.

## Adapter Responsibility

`PythonBackendRuntime` should:

1. own one backend client relationship
2. prepare or validate backend reachability before use
3. create many backend-managed conversation handles
4. expose only shared `InferenceRuntime` semantics to the rest of the app

## Relationship To Shared Contract

The adapter exists to satisfy:

1. runtime preparation
2. conversation creation
3. conversation listing
4. conversation removal
5. blocking send and optional stream on conversation handles

## Design Boundaries

1. The app model should not construct HTTP requests directly.
2. The app model should not own backend transport, retry, or process lifecycle details.
3. Linux-specific transport models should remain isolated to backend-facing modules.

## Companion Runtime Types

The Linux backend adapter likely collaborates with:

1. `PythonBackendConversation`
2. `BackendClient`
3. transport DTOs and error translators

## Design Constraint

Do not let Linux backend integration collapse into in-process interpreter shortcuts when the goal is sandbox rehearsal and realistic backend validation.

## Companion Design Documents

- [[03-dd-runtime-adapter-pattern]]
- [[07-dd-backend-conversation-contract]]
- [[14-dd-linux-backend-runtime-and-conversation-lifecycle]]

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]