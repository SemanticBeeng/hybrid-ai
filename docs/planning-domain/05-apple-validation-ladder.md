# 05 Apple Validation Ladder

## Purpose

This document isolates the staged validation path from Linux approximation to Apple-hosted approximation to real iOS truth.

## Workstream Type

Companion validation workstream.

## Requirements Served

- [[01-br-sandboxed-on-device-inference-target]]
- [[03-br-apple-deployment-authority]]

## Design Decisions Relied On

- [[11-dd-apple-native-runtime-adapter]]
- [[12-dd-apple-engine-and-conversation-lifecycle]]

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

## Task Slices

1. Define what evidence is expected at the Linux approximation rung.
2. Define what evidence is expected at the Catalyst or Apple-hosted approximation rung.
3. Define the real-device checks for memory, startup, thermal behavior, and user experience.
4. Tag implementation claims and milestones with the highest rung they have actually passed.

## Exit Criteria

1. Apple-facing claims are explicitly tied to a validation rung.
2. No Linux or Catalyst success is misrepresented as final iOS truth.
3. Real-device validation remains scheduled rather than deferred indefinitely.

## Companion Domain Documents

- [[01-br-sandboxed-on-device-inference-target]]
- [[03-br-apple-deployment-authority]]
- [[11-dd-apple-native-runtime-adapter]]
- [[12-dd-apple-engine-and-conversation-lifecycle]]

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]