# 06 Shared Core To Shell Delivery Sequence

## Purpose

This document isolates the implementation sequence for the shared Swift core and platform shells.

## Workstream Type

Primary UI implementation workstream.

## Status

Active supporting Linux-first UI workstream.

## Requirements Served

- [[02-br-cross-platform-swift-ui-delivery-target]]
- [[06-br-shared-swift-core-portability-requirements]]

## Design Decisions Relied On

- [[06-dd-platform-ui-shell-separation]]
- [[13-dd-linux-backend-runtime-adapter]]
- [[14-dd-linux-backend-runtime-and-conversation-lifecycle]]

## Delivery Sequence

1. Strengthen the shared Swift core.
   - keep app state, domain types, and service abstractions in the package

2. Prove the Linux shell against the shared core.
   - keep Linux UI work mobile-shaped and thin

3. Prepare the Apple shell path.
   - import the shared package from macOS and later iOS shells

4. Expand cross-platform app-model maturity.
   - preserve portability of conversation and runtime behavior across shells

## Near-Term Proofs

1. CLI smoke coverage for the shared core
2. Linux UI proof that exercises shared conversation state
3. Apple shell proof after the shared core proves stable reuse

## Task Slices

1. Keep strengthening the shared Swift package as the owner of state, runtime abstractions, and app logic.
2. Keep the Linux shell thin and mobile-shaped while it proves shared-core reuse.
3. Prepare Apple shells to import the same shared package once the shared core is stable.
4. Verify that conversation and runtime flows remain portable as UI capabilities expand.

## Exit Criteria

1. Shared app logic remains testable without any specific shell.
2. Linux and Apple shells can reuse the same core abstractions without duplicating business logic.
3. Platform shells stay thin enough that future UI choice changes do not require re-owning app state.
4. Multiple session and conversation flows remain owned by the shared core rather than by shell-local state.

## Planning Constraint

Do not let platform shell work absorb app logic that belongs in the shared core.

## Companion Domain Documents

- [[06-br-shared-swift-core-portability-requirements]]
- [[06-dd-platform-ui-shell-separation]]
- [[13-dd-linux-backend-runtime-adapter]]
- [[14-dd-linux-backend-runtime-and-conversation-lifecycle]]

## Source Runbooks

- [[swift_ui_cross_platform_roadmap]]