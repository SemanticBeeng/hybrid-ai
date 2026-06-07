# 01 Sandboxed On-Device Inference Target

## Intent

This document captures the primary product requirement that the app ultimately ships as an iOS application integrated with an inference engine and LLM under Apple sandbox constraints.

## Core Requirements

1. The canonical deployment target is iOS on real device hardware.
2. The app and inference engine must run under the iOS application sandbox.
3. LLM assets, caches, and writable runtime state must obey sandbox-compatible storage rules.
4. Mac Catalyst is an approximation of iOS deployment, not a substitute for final iPhone validation.
5. Linux development must preserve a path back to sandbox-compatible Apple deployment rather than optimizing only for unconstrained desktop execution.

## Ubiquitous Language

- `canonical target`: the environment whose constraints are authoritative for product decisions
- `approximation environment`: a development or validation environment that intentionally simulates important target constraints without being identical
- `sandbox-compatible`: an implementation property meaning the design does not rely on unrestricted filesystem, process, or host-global state access
- `one runtime, many conversations`: the preferred inference ownership model across platforms

## Acceptance-Oriented Constraints

1. Resource ownership must stay explicit for models, caches, logs, and writable state.
2. The architecture must support direct Apple-native inference integration where the platform allows it.
3. Linux and Mac Catalyst validation should be interpreted as approximation evidence, not final product proof.

## Source Runbooks

- `docs/chat/litert_lm_gemma4_swift_runbook.md`