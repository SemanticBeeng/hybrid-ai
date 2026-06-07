# 06 Shared Core To Shell Delivery Sequence

## Purpose

This document isolates the implementation sequence for the shared Swift core and platform shells.

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

## Planning Constraint

Do not let platform shell work absorb app logic that belongs in the shared core.

## Companion Domain Documents

- [[06-br-shared-swift-core-portability-requirements]]
- [[06-dd-platform-ui-shell-separation]]
- [[13-dd-linux-backend-runtime-adapter]]
- [[14-dd-linux-backend-runtime-and-conversation-lifecycle]]

## Source Runbooks

- [[swift_ui_cross_platform_roadmap]]