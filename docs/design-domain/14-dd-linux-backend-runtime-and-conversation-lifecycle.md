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

## Design Constraint

Do not regress to one-request-one-runtime or one-process-per-conversation as the Linux backend default.

## Companion Design Documents

- [[03-dd-runtime-adapter-pattern]]
- [[05-dd-runtime-lifecycle-and-conversation-ownership]]
- [[13-dd-linux-backend-runtime-adapter]]

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]