# 09 Current Chosen Workstreams

## Purpose

This note records which planning workstreams are currently chosen for execution and which alternatives remain available but not active.

## Current Execution Focus

The current planning focus is Linux-first implementation.

The preferred execution path is:

1. [[04-litert-runtime-viability-spike-plan]] as the active primary implementation workstream
2. [[06-shared-core-to-shell-delivery-sequence]] as the active supporting UI and shared-core workstream
3. [[05-apple-validation-ladder]] as the planned companion validation workstream

## Current Prioritization Decision

The repository is currently favoring the LiteRT runtime viability spike over the layered backend-first path.

Reason:

1. the dominant near-term uncertainty is whether the chosen LiteRT and Gemma path works under the constrained Linux environment at all
2. early proof of model startup, conversation creation, and backend reachability is more valuable right now than transport completeness
3. the spike can still preserve the path back to the more disciplined layered backend workstream if it is kept small and protocol-shaped

## Non-Negotiable Semantic Constraint

Even while favoring the spike, the implementation must preserve multiple session and conversation semantics.

That means the current chosen path should still demonstrate:

1. one prepared runtime with many conversations
2. explicit conversation identity
3. transcript isolation between conversations
4. a Swift-facing runtime adapter that does not collapse into stateless single-request behavior

## Workstream Status Summary

1. [[04-litert-runtime-viability-spike-plan]]
   - active primary Linux implementation workstream

2. [[06-shared-core-to-shell-delivery-sequence]]
   - active supporting workstream

3. [[05-apple-validation-ladder]]
   - planned companion validation workstream

4. [[03-python-backend-layered-delivery-plan]]
   - secondary follow-on workstream after the viability question is answered

5. [[07-platform-shell-decision-and-proof-workstream]]
   - deferred unless the current Linux UI proof path needs reevaluation

6. [[08-apple-native-direct-runtime-delivery-plan]]
   - deferred until Apple-hosted implementation becomes active

## Revisit Conditions

Revisit the current chosen workstreams if any of these become true:

1. the LiteRT spike fails to prove viable under Linux constraints
2. the spike starts distorting the backend contract or conversation semantics
3. Apple-hosted implementation becomes available sooner than expected
4. platform-shell uncertainty becomes the main delivery blocker instead of backend viability

## Companion Domain Documents

- [[05-br-conversation-oriented-inference-experience]]
- [[13-dd-linux-backend-runtime-adapter]]
- [[14-dd-linux-backend-runtime-and-conversation-lifecycle]]
- [[04-litert-runtime-viability-spike-plan]]
- [[06-shared-core-to-shell-delivery-sequence]]

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]
- [[swift_ui_cross_platform_roadmap]]