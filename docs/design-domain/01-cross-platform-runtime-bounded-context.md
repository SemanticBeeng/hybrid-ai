# 01 Cross-Platform Runtime Bounded Context

## Scope

This document tracks the current cross-platform runtime design language and the main design alternatives around app, runtime, and backend boundaries.

## Bounded Contexts

1. `App Context`
   - owns UI state, conversation selection, and user interaction flows
   - should depend only on shared Swift abstractions

2. `Shared Runtime Abstraction Context`
   - owns `InferenceRuntime`, `ConversationHandle`, `ConversationID`, and related protocol-facing types
   - should remain platform-neutral

3. `Apple Native Runtime Context`
   - owns direct LiteRT-LM Swift integration for iOS/macOS when used
   - models one engine with many conversations

4. `Linux Backend Runtime Context`
   - owns Python backend process integration and transport boundary
   - should preserve sandbox approximation and process separation

## Active Design Decisions Under Consideration

1. Shared Swift abstractions are the stable seam across platforms.
2. Apple platforms may use direct LiteRT-LM integration in-process.
3. Linux should prefer a backend/service boundary rather than PythonKit as the primary path.
4. One runtime with many conversations is the preferred model across platforms.

## Still-Open Or Intentionally Flexible Areas

1. Whether the Linux backend reaches parity first through a fake runtime or a real-runtime-first spike.
2. Whether the transport stabilizes first via fake runtime discipline or via a constrained real LiteRT spike.
3. How much of Catalyst behavior is sufficient before returning to real iPhone validation.

## Source Runbooks

- `docs/chat/litert_lm_gemma4_swift_runbook.md`