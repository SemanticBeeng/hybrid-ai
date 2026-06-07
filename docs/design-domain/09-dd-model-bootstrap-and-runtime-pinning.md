# 09 DD Model Bootstrap And Runtime Pinning

## Scope

This document isolates the design concern around making LiteRT runtime and model bootstrap explicit, pinned, and reproducible.

## Design Statement

Model availability and runtime preparation should be first-class repository concerns rather than implicit side effects of ad hoc setup.

## Core Design Expectations

1. LiteRT runtime versioning should be pinned rather than always resolving the latest available release.
2. The selected Gemma model artifact should be named and managed explicitly.
3. Model import, cache population, and runtime preparation steps should be inspectable and repeatable.
4. Runtime bootstrapping should integrate with repository-owned writable roots and sandbox rehearsal discipline.

## Why This Matters

1. Reproducibility depends on runtime and model version stability.
2. Startup failures become diagnosable only when bootstrap behavior is explicit.
3. Linux approximation is weakened if model and cache behavior leak into hidden host-global state.

## Design Constraints

1. Avoid relying on dynamic latest-release resolution as the durable default.
2. Keep model bootstrap separate from request handling.
3. Capture startup cost, model load cost, and cache footprint as explicit operational concerns.

## Companion Planning Documents

- [[03-python-backend-layered-delivery-plan]]
- [[04-litert-runtime-viability-spike-plan]]

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]