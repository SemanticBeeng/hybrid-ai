# 07 Platform Shell Decision And Proof Workstream

## Purpose

This document isolates the workstream for evaluating and proving the platform-shell direction before the repository hardens around one UI proof path.

## Workstream Type

Alternative UI evaluation workstream.

## Requirements Served

- [[02-br-cross-platform-swift-ui-delivery-target]]
- [[06-br-shared-swift-core-portability-requirements]]

## Design Decisions Relied On

- [[02-dd-platform-specific-ui-shells-decision-space]]
- [[06-dd-platform-ui-shell-separation]]

## Candidate Proof Paths

1. Linux-first shell proof
2. Apple-first shell proof
3. shared-abstraction-first proof before either shell deepens

## Task Slices

1. Define evaluation criteria for shell proofs, including native fit, thin-shell discipline, and portability of shared app logic.
2. Select one initial proof path or explicitly run two proofs in parallel.
3. Build the smallest shell proof needed to exercise shared state and conversation interactions.
4. Compare the proof outcome against the evaluation criteria and decide whether to continue, pivot, or narrow scope.

## Exit Criteria

1. The repository has an explicit shell-proof decision rather than an implicit drift into one toolkit.
2. The selected shell direction still preserves reuse of the shared Swift core.
3. Rejected shell paths remain documented as evaluated alternatives rather than disappearing from the planning record.

## Companion Domain Documents

- [[02-br-cross-platform-swift-ui-delivery-target]]
- [[06-br-shared-swift-core-portability-requirements]]
- [[02-dd-platform-specific-ui-shells-decision-space]]
- [[06-dd-platform-ui-shell-separation]]

## Source Runbooks

- [[swift_ui_cross_platform_roadmap]]