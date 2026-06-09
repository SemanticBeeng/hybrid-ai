# 04 DD Backend Transport And Error Boundary

## Scope

This document captures the current preferred transport boundary for the Linux backend path.

## Current Preferred Direction

Use `HTTP + JSON` for request-response behavior and add streaming through `SSE` or an equivalent inspectable text stream.

## Why This Boundary Is Preferred

1. It is easy to inspect with local tools.
2. It preserves a real process boundary.
3. It is compatible with the shared Swift runtime abstraction.
4. It avoids coupling Linux behavior to in-process interpreter shortcuts.

## Linux GPU Consequence

For the current LiteRT-LM Linux GPU path, the transport decision remains correct even though live GPU serving is not yet promoted.

That means:

1. HTTP remains the preferred process boundary for the Linux backend path
2. GPU capability probing can be promoted before long-lived GPU serving is promoted
3. transport design should not be changed just to compensate for unresolved Linux GPU runtime-bridge issues
4. unresolved Linux GPU runtime promotion remains a runtime-boundary concern, not a reason to collapse transport boundaries

## Rejected Or Deferred Defaults

1. `PythonKit` as the primary Linux integration path
   - weakens sandbox realism
   - collapses process boundaries

2. `gRPC` or custom protocols as the first transport
   - adds complexity before semantics are stable

3. transport-free direct handler-to-engine coupling
   - hardens the wrong seam

## Companion Design Document

Detailed backend error semantics now live in:

- [[10-dd-backend-error-semantics]]

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]