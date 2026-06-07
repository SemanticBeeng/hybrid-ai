# 01 LiteRT-LM Gemma4 Spike And Delivery Roadmap

## Purpose

This document captures the current execution-oriented roadmap for moving from the existing proof state toward a real LiteRT-LM and Gemma-based product path.

## Main Workstreams

### Workstream A: Layered Backend-First Delivery

1. Define the backend contract.
2. Build a fake Python runtime.
3. Expose FastAPI endpoints matching the Swift protocol.
4. Implement the Swift backend adapter.
5. Replace the fake runtime with the real LiteRT runtime.

### Workstream B: Real-Runtime-First Spike

1. Add LiteRT bootstrap and model wiring.
2. Implement a real Python LiteRT runtime.
3. Expose the smallest blocking HTTP surface.
4. Implement a minimal Swift backend adapter.
5. Re-enter the layered roadmap after the runtime viability questions are answered.

## Current Priorities

1. Preserve the Swift runtime protocol as the contract target.
2. Preserve a path to sandbox-compatible Apple deployment.
3. Avoid coupling Linux development decisions too tightly to unconstrained desktop assumptions.

## Planning Notes

1. Workstream B is a tactical shortcut, not the replacement for Workstream A.
2. The Swift runtime contract tests are the preferred acceptance gate for adapter behavior.
3. Streaming, persistence, and richer backend semantics are later concerns unless the spike proves they are required immediately.

## Source Runbooks

- `docs/chat/litert_lm_gemma4_swift_runbook.md`