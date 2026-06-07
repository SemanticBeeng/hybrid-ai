# 04 BR Linux Sandbox Approximation Requirements

## Intent

This document captures the product-facing constraints Linux development must preserve when it is used as an approximation environment.

## Requirement Statements

1. Linux development must avoid depending on unrestricted host-global mutable state.
2. Writable runtime state must stay under approved project-owned roots.
3. Model caches, logs, and bootstrap artifacts must remain explicit and inspectable.
4. Linux integration should preserve process boundaries that matter for eventual sandboxed deployment.
5. Linux should be treated as an approximation of constrained deployment, not as permission to design around desktop abundance.

## Ubiquitous Language

- `project-owned root`: a repository-controlled writable location such as `build/` or `volumes/`
- `sandbox rehearsal`: development work that preserves the architectural consequences of sandboxing even when the host OS differs from the final target
- `desktop abundance`: assumptions based on unconstrained filesystem access, process freedom, or oversized memory budgets

## Acceptance Implications

1. Runtime bootstrapping should not leak into user-global cache and config locations by default.
2. Backend startup, cache population, and logs must be observable without relying on hidden host state.
3. Linux implementation choices should remain compatible with later Apple-side tightening.

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]