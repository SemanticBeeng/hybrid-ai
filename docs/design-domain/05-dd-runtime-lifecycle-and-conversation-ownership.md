# 05 DD Runtime Lifecycle And Conversation Ownership

## Scope

This document separates the cross-platform runtime lifecycle model from the transport and UI decisions around it.

## Current Preferred Lifecycle Model

1. Prepare one runtime or engine instance.
2. Create many conversations beneath that prepared runtime.
3. Keep conversation ids opaque and transport-safe.
4. Remove conversations without tearing down the whole runtime by default.

## Ownership Boundaries

### Runtime Ownership

- owns expensive engine initialization
- owns shared model/bootstrap state
- owns the registry of active conversations

Apple-native engine and conversation lifecycle details are documented in:

- [[12-dd-apple-engine-and-conversation-lifecycle]]

Linux backend runtime and conversation lifecycle details are documented in:

- [[14-dd-linux-backend-runtime-and-conversation-lifecycle]]

### Conversation Ownership

- owns per-conversation state
- accepts user input in sequence
- returns assistant messages or streams

### App Ownership

- owns selection state, transcript display, and user actions
- does not own LiteRT or backend lifecycle directly

## Design Constraint

Do not regress to one-model-load-per-request or one-process-per-conversation as the default architecture.

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]