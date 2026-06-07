# 07 DD Backend Conversation Contract

## Scope

This document isolates the minimal backend contract that mirrors the shared Swift runtime abstractions.

## Design Statement

The Linux backend should expose a conversation-oriented contract rather than a stateless text-generation surface.

## Minimal Contract Shape

### Runtime-Level Operations

1. `POST /runtime/prepare`
2. `GET /runtime/conversations`
3. `POST /runtime/conversations`
4. `DELETE /runtime/conversations/{id}`

### Conversation-Level Operations

1. `POST /runtime/conversations/{id}/messages`
2. `POST /runtime/conversations/{id}/messages/stream`

## Semantic Mapping

1. `prepare()` initializes or validates backend runtime state.
2. `createConversation(systemPrompt:)` creates one conversation id.
3. `listConversationIDs()` reports live ids.
4. `removeConversation(_:)` deletes one conversation.
5. `send(_:)` returns one assistant message.
6. `stream(_:)` emits incremental assistant output.

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
  "id": "..."
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
  "role": "assistant",
  "text": "..."
}
```

## Design Constraints

1. Conversation ids should be backend-generated and opaque.
2. The contract should not leak LiteRT-specific engine internals.
3. Handlers should delegate runtime semantics to a runtime layer rather than owning them directly.

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]