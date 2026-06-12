# 12 DD Apple Engine And Conversation Lifecycle

## Scope

This document isolates Apple-native engine and conversation ownership beneath the shared runtime abstraction.

## Current Preferred Lifecycle Model

1. resolve model and writable cache inputs
2. construct engine configuration
3. initialize one LiteRT engine instance off the main thread
4. create many LiteRT conversation instances from that engine
5. wrap each conversation in a shared-contract-compatible handle
6. remove conversations without reinitializing the engine by default

## Ownership Boundaries

### Engine Ownership

- owns expensive initialization
- owns model and cache configuration
- remains a shared runtime resource across many conversations

### Conversation Ownership

- owns per-conversation LiteRT state
- accepts user messages in sequence
- returns assistant messages or streams through a wrapper aligned to the shared contract

### App Ownership

- triggers prepare, create, select, and delete actions
- owns transcript and selection state
- does not directly manipulate engine internals

## Design Consequences

1. Engine preparation cost can be amortized across multiple conversations.
2. App-level transcript isolation maps cleanly to conversation-level LiteRT state.
3. Apple-native lifecycle still fits the one-runtime-many-conversations model shared with Linux.

## Design Constraint

Do not regress to engine-per-conversation or engine-per-request as the Apple-native default.

## Companion Design Documents

- [[03-dd-runtime-adapter-pattern]]
- [[05-dd-runtime-lifecycle-and-conversation-ownership]]
- [[11-dd-apple-native-runtime-adapter]]

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]