# 07 DD Backend Conversation Contract

## Scope

This document isolates the minimal backend contract that mirrors the shared Swift runtime abstractions.

## Design Statement

The Linux backend should expose a conversation-oriented contract rather than a stateless text-generation surface.

## Minimal Contract Shape

### Runtime-Level Operations

1. `GET /ready`
2. `GET /health`
3. `GET /v1/conversations`
4. `POST /v1/conversations`
5. `DELETE /v1/conversations/{id}`

### Conversation-Level Operations

1. `POST /v1/conversations/{id}/messages`
2. streaming remains a Swift-runtime concern today and is currently implemented by additive client behavior over the blocking send path rather than a distinct backend stream endpoint

## Semantic Mapping

1. `prepare()` initializes or validates backend runtime state.
2. `createConversation(systemPrompt:)` creates one conversation id.
3. `listConversationIDs()` reports live ids.
4. `removeConversation(_:)` deletes one conversation.
5. `send(_:)` returns one assistant message.
6. `stream(_:)` preserves the same assistant text contract as blocking send.

## Payload Guidance

### Create Conversation Request

```json
{
  "system_prompt": "..."
}
```

### Create Conversation Response

```json
{
  "conversation_id": "..."
}
```

### Send Message Request

```json
{
  "text": "..."
}
```

### Assistant Message Response

```json
{
  "conversation_id": "...",
  "message": {
    "role": "assistant",
    "text": "..."
  }
}
```

Constraint on `message.text`:

1. the text returned to clients should be normalized plain assistant text
2. the transport contract must not expose stringified structured LiteRT payloads such as serialized `role` or `content` objects

## Design Constraints

1. Conversation ids should be backend-generated and opaque.
2. The contract should not leak LiteRT-specific engine internals.
3. Handlers should delegate runtime semantics to a runtime layer rather than owning them directly.

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]