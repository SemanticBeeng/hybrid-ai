# 01 LiteRT-LM Gemma4 Spike And Delivery Roadmap

## Purpose

This document is the overview for the LiteRT and Gemma delivery planning cluster.

## Planning Cluster

The planning cluster is now split into narrower workstreams:

1. layered backend-first delivery as the contract-first Linux workstream
2. real-runtime-first viability spike as the Linux shortcut workstream
3. Apple-native direct runtime delivery as the Apple implementation workstream
4. Apple validation ladder as the companion validation workstream

## Detailed Documents

- [[03-python-backend-layered-delivery-plan]]
- [[04-litert-runtime-viability-spike-plan]]
- [[08-apple-native-direct-runtime-delivery-plan]]
- [[05-apple-validation-ladder]]

## Workstream Relationships

1. [[03-python-backend-layered-delivery-plan]] and [[04-litert-runtime-viability-spike-plan]] are alternative Linux-start execution paths.
2. [[08-apple-native-direct-runtime-delivery-plan]] is the Apple implementation workstream when Apple-hosted development is available.
3. [[05-apple-validation-ladder]] is not an implementation alternative; it is the validation workstream that constrains all Apple-facing delivery claims.

## Stable Planning Position

1. Preserve the Swift runtime protocol as the contract target.
2. Preserve a path to sandbox-compatible Apple deployment.
3. Avoid coupling Linux development decisions too tightly to unconstrained desktop assumptions.
4. Choose one primary Linux-start workstream, then use Apple-native delivery and validation workstreams to confirm the path back to the canonical target.

## Companion Domain Documents

- [[01-br-sandboxed-on-device-inference-target]]
- [[04-br-linux-sandbox-approximation-requirements]]
- [[01-bc-cross-platform-runtime-bounded-context]]
- [[09-dd-model-bootstrap-and-runtime-pinning]]

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]