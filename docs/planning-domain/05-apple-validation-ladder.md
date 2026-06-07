# 05 Apple Validation Ladder

## Purpose

This document isolates the staged validation path from Linux approximation to Apple-hosted approximation to real iOS truth.

## Validation Order

1. Linux approximation
   - validate backend boundaries, shared Swift abstractions, and sandbox rehearsal discipline

2. Mac Catalyst or related Apple-hosted approximation
   - validate resource ownership, bundle handling, and Apple-side integration shape

3. Real iPhone or iPad deployment
   - validate memory, thermal, startup, and user-experience truth on the canonical target

## Planning Rule

Each higher stage can invalidate conclusions from the lower stage.

## Immediate Planning Consequences

1. Linux success should not end Apple validation planning.
2. Catalyst success should not end real-device validation planning.
3. Acceptance criteria should identify which ladder rung they actually cover.

## Companion Domain Documents

- [[01-br-sandboxed-on-device-inference-target]]
- [[03-br-apple-deployment-authority]]
- [[11-dd-apple-native-runtime-adapter]]
- [[12-dd-apple-engine-and-conversation-lifecycle]]

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]