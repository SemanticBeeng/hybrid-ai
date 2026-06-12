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

## Current Linux GPU Promotion Boundary

For the current LiteRT-LM Linux GPU path, the promoted repository boundary is:

1. host-contract preflight
2. managed-runtime validation
3. explicit experimental live serving beyond that point only

This means:

1. the Linux adapter design can rely on a promoted validation contract for GPU capability checks
2. the Linux adapter design must not assume that long-lived GPU serving is already a promoted runtime guarantee
3. the repo should not hide unresolved live-serving bridge problems behind application-level fallbacks or broad host linker mutation

## Linux GPU Bridge Constraint

The current bridge model for Linux GPU must remain narrow.

Accepted current bridge inputs:

1. device visibility
2. Vulkan ICD discovery
3. explicit validation inside the managed Python environment

Rejected current bridge behavior:

1. broad `LD_LIBRARY_PATH` mutation to normalize host vendor library trees
2. application-level workarounds that try to promote live serving before the runtime boundary is actually stable

## Companion Runtime Types

The Linux backend adapter likely collaborates with:

1. `PythonBackendConversation`
2. `BackendClient`
3. transport DTOs and error translators

## Design Constraint

Do not let Linux backend integration collapse into in-process interpreter shortcuts when the goal is sandbox rehearsal and realistic backend validation.

Do not treat Linux GPU live serving as promoted until it can be supported without broad host dynamic-linker mutation.

## Companion Design Documents

- [[03-dd-runtime-adapter-pattern]]
- [[07-dd-backend-conversation-contract]]
- [[14-dd-linux-backend-runtime-and-conversation-lifecycle]]

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]