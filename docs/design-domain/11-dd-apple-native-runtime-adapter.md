# 11 DD Apple-Native Runtime Adapter

## Scope

This document isolates the Apple-native runtime adapter design from the broader cross-platform adapter pattern.

## Design Statement

Apple-native LiteRT integration should live behind a dedicated adapter that satisfies the shared Swift runtime contract without leaking LiteRT-specific engine details into the app model.

## Adapter Responsibility

`AppleLiteRTRuntime` should:

1. own exactly one LiteRT engine instance
2. initialize that engine once
3. create many Apple-native conversation wrappers from that engine
4. expose only shared `InferenceRuntime` semantics to the rest of the app

## Relationship To Shared Contract

The adapter exists to satisfy:

1. runtime preparation
2. conversation creation
3. conversation listing
4. conversation removal
5. blocking send and optional stream on conversation handles

## Design Boundaries

1. The app model should not construct `EngineConfig` directly.
2. The app model should not own `Engine` or `Conversation` lifecycle directly.
3. Apple-specific package imports should remain isolated to Apple-only targets or source membership.

## Companion Runtime Types

The Apple adapter likely collaborates with:

1. `AppleLiteRTConversation`
2. `AppleEngineProvider`
3. `BundleModelLocator`

## Design Constraint

Do not let Apple-native integration change the shared runtime semantics in ways the Linux backend path cannot still model.

## Companion Design Documents

- [[03-dd-runtime-adapter-pattern]]
- [[12-dd-apple-engine-and-conversation-lifecycle]]

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]