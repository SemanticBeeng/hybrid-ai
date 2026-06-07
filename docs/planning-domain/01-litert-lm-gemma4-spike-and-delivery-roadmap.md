# 01 LiteRT-LM Gemma4 Spike And Delivery Roadmap

## Purpose

This document is the overview for the LiteRT and Gemma delivery planning cluster.

## Planning Cluster

The planning cluster is now split into narrower workstreams:

1. layered backend-first delivery
2. real-runtime-first viability spike
3. Apple validation ladder

## Detailed Documents

- [[03-python-backend-layered-delivery-plan]]
- [[04-litert-runtime-viability-spike-plan]]
- [[05-apple-validation-ladder]]

## Stable Planning Position

1. Preserve the Swift runtime protocol as the contract target.
2. Preserve a path to sandbox-compatible Apple deployment.
3. Avoid coupling Linux development decisions too tightly to unconstrained desktop assumptions.

## Companion Domain Documents

- [[01-br-sandboxed-on-device-inference-target]]
- [[04-br-linux-sandbox-approximation-requirements]]
- [[01-bc-cross-platform-runtime-bounded-context]]
- [[09-dd-model-bootstrap-and-runtime-pinning]]

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]