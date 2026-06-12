# 03 DD Runtime Adapter Pattern

## Scope

This document isolates the runtime adapter pattern that keeps one shared Swift-facing contract across Apple-native and Linux backend execution modes.

## Design Statement

Use a shared Swift protocol surface as the stable seam, and implement platform-specific runtime adapters behind it.

## Target Adapter Set

1. `AppleLiteRTRuntime`
   - Apple-native design details are documented in [[11-dd-apple-native-runtime-adapter]]

2. `PythonBackendRuntime`
   - Linux backend design details are documented in [[13-dd-linux-backend-runtime-adapter]]

## Stable Shared Contract

The shared contract should remain minimal and conversation-oriented:

- runtime preparation
- conversation creation
- conversation listing
- conversation removal
- message send and optional stream on a conversation handle

## Design Consequences

1. The app model depends on the shared runtime contract, not on LiteRT or HTTP details.
2. Platform-specific packages remain replaceable as long as they satisfy the same shared semantics.
3. Linux can validate backend realism without contaminating Apple-native integration boundaries.

## Companion Design Documents

- [[11-dd-apple-native-runtime-adapter]]
- [[12-dd-apple-engine-and-conversation-lifecycle]]
- [[13-dd-linux-backend-runtime-adapter]]
- [[14-dd-linux-backend-runtime-and-conversation-lifecycle]]

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]