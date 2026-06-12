# 14 DD Linux Backend Runtime And Conversation Lifecycle

## Scope

This document isolates Linux backend runtime and conversation ownership beneath the shared runtime abstraction.

## Current Preferred Lifecycle Model

1. prepare or validate one backend runtime process or service relationship
2. create many backend-managed conversations beneath that prepared runtime
3. assign opaque backend-generated ids to conversations
4. send or stream messages against existing conversation ids
5. remove conversations without tearing down the whole backend runtime by default

## Ownership Boundaries

### Backend Runtime Ownership

- owns runtime preparation and model availability checks
- owns shared model and backend process state
- owns the registry of active backend conversations

### Backend Conversation Ownership

- owns per-conversation backend state
- accepts user messages in sequence
- returns assistant messages or streams through a wrapper aligned to the shared contract

### App Ownership

- triggers prepare, create, select, and delete actions
- owns transcript and selection state
- does not directly manipulate backend transport or process internals

## Design Consequences

1. Backend startup cost can be amortized across multiple conversations.
2. App-level transcript isolation maps cleanly to backend conversation state.
3. Linux lifecycle still fits the one-runtime-many-conversations model shared with Apple-native integration.

## Current Linux GPU Lifecycle Note

For the current LiteRT-LM Linux GPU path, the lifecycle model is promoted in two layers:

1. GPU preflight and managed-runtime validation are promoted as a capability boundary
2. long-lived server preparation and conversation-serving remain experimental until the live runtime bridge is promoted

The lifecycle model itself does not change, but the promotion boundary does:

1. one-runtime-many-conversations remains the intended steady-state model
2. the repo should not claim that this steady state is promoted for Linux GPU until live runtime preparation is stable without broad linker-path mutation

## Design Constraint

Do not regress to one-request-one-runtime or one-process-per-conversation as the Linux backend default.

## Companion Design Documents

- [[03-dd-runtime-adapter-pattern]]
- [[05-dd-runtime-lifecycle-and-conversation-ownership]]
- [[13-dd-linux-backend-runtime-adapter]]

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]