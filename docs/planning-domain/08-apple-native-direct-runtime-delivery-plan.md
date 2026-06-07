# 08 Apple-Native Direct Runtime Delivery Plan

## Purpose

This document isolates the Apple-native direct LiteRT runtime workstream from the Linux-start backend workstreams.

## Workstream Type

Alternative Apple implementation workstream.

## Requirements Served

- [[01-br-sandboxed-on-device-inference-target]]
- [[03-br-apple-deployment-authority]]
- [[05-br-conversation-oriented-inference-experience]]
- [[06-br-shared-swift-core-portability-requirements]]

## Design Decisions Relied On

- [[03-dd-runtime-adapter-pattern]]
- [[11-dd-apple-native-runtime-adapter]]
- [[12-dd-apple-engine-and-conversation-lifecycle]]

## Workstream Goal

Deliver an Apple-native LiteRT integration path that satisfies the shared Swift runtime contract and can be validated through the Apple deployment ladder.

## Task Slices

1. Add or prepare the Apple-hosted project structure needed to import LiteRT-LM Swift.
2. Implement model and cache location support such as bundle model resolution and writable cache handling.
3. Implement `AppleLiteRTRuntime` and its conversation wrapper types behind the shared runtime contract.
4. Bind the Apple shell to the shared app model rather than to LiteRT engine details directly.
5. Validate the Apple-native path first in an Apple-hosted approximation and then on real device hardware.

## Exit Criteria

1. Apple-native runtime behavior satisfies the same one-runtime-many-conversations semantics used elsewhere in the repo.
2. The Apple shell can reach the runtime through shared abstractions rather than custom app-owned engine logic.
3. Apple validation proceeds beyond desktop approximation to the real device ladder.

## Companion Domain Documents

- [[01-br-sandboxed-on-device-inference-target]]
- [[03-br-apple-deployment-authority]]
- [[05-br-conversation-oriented-inference-experience]]
- [[03-dd-runtime-adapter-pattern]]
- [[11-dd-apple-native-runtime-adapter]]
- [[12-dd-apple-engine-and-conversation-lifecycle]]
- [[05-apple-validation-ladder]]

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]