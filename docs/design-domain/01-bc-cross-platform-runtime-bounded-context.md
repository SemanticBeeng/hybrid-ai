# 01 BC Cross-Platform Runtime Bounded Context

## Scope

This document is the overview for the runtime design cluster.

## Cluster Summary

The runtime cluster is now split into narrower design documents for:

1. the adapter pattern
2. backend transport and error boundaries
3. runtime lifecycle and conversation ownership
4. backend contract shape and streaming semantics
5. model bootstrap and runtime pinning concerns

## Detailed Documents

- [[03-dd-runtime-adapter-pattern]]
- [[04-dd-backend-transport-and-error-boundary]]
- [[05-dd-runtime-lifecycle-and-conversation-ownership]]
- [[07-dd-backend-conversation-contract]]
- [[08-dd-streaming-chat-semantics]]
- [[09-dd-model-bootstrap-and-runtime-pinning]]
- [[10-dd-backend-error-semantics]]
- [[11-dd-apple-native-runtime-adapter]]
- [[12-dd-apple-engine-and-conversation-lifecycle]]
- [[13-dd-linux-backend-runtime-adapter]]
- [[14-dd-linux-backend-runtime-and-conversation-lifecycle]]

## Stable Cluster-Level Position

1. Shared Swift abstractions remain the stable seam across Apple-native and backend-backed runtime paths.
2. Linux still prefers a backend/service boundary over in-process interpreter shortcuts.

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]