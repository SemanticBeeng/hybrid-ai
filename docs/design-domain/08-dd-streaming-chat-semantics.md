# 08 DD Streaming Chat Semantics

## Scope

This document isolates the streaming behavior expected from the backend and the shared Swift integration layer.

## Current Preferred Direction

Use server-sent events or an equally inspectable streamed text boundary for incremental assistant output.

## Semantic Model

1. A streaming request belongs to one existing conversation.
2. The backend emits incremental assistant output rather than independent unrelated messages.
3. The stream ends with an explicit completion condition or error.
4. Cancellation and retry should be modeled as runtime behavior, not UI accidents.

## Preferred Event Vocabulary

1. `chunk`
   - carries incremental assistant text
2. `done`
   - marks normal stream completion
3. `error`
   - marks failed stream completion

## Design Consequences

1. Swift app-model code must accumulate chunks into the selected conversation transcript.
2. Streaming should be additive to the blocking send path, not a replacement for basic contract clarity.
3. Error and cancellation behavior should remain testable independently from UI rendering.
4. The assembled streamed text should satisfy the same normalized plain-text contract as blocking `send(_:)` responses.

## Design Constraints

1. Do not add tool-calling, multimodal payloads, or rich event taxonomies before basic streaming semantics are stable.
2. Streaming should preserve the same conversation identity model as blocking send.
3. Streaming should remain inspectable with local developer tools.

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]