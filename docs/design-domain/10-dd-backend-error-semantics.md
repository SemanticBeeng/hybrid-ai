# 10 DD Backend Error Semantics

## Scope

This document isolates the backend error model from the transport boundary that carries it.

## Design Statement

Backend failures should be represented as stable product-meaningful categories before they are translated into transport responses or Swift-side errors.

## Preferred Error Categories

1. `runtime_not_prepared`
   - the backend runtime has not been initialized and cannot yet serve requests

2. `conversation_not_found`
   - the requested conversation id does not exist in the active runtime state

3. `model_not_found`
   - the configured or requested model artifact is unavailable

4. `engine_init_failed`
   - runtime initialization failed while bringing up the inference engine

5. `inference_failed`
   - a request reached the inference path but generation failed

6. `invalid_request`
   - the request payload is syntactically or semantically invalid

## Transport Mapping Guidance

Recommended status code mapping:

1. `400` for invalid input
2. `404` for missing conversation state
3. `409` for runtime state conflicts
4. `500` for backend or inference failures
5. `503` for unavailable model or runtime state

## Translation Boundary

1. Python runtime code should raise typed failures or equivalent structured error states.
2. HTTP handlers should translate those failures into transport-visible envelopes.
3. The Swift backend adapter should translate those transport-visible envelopes into Swift-side domain errors.

## Design Constraints

1. Do not let ad hoc handler strings become the durable error contract.
2. Do not encode LiteRT-specific internal details into user-facing error categories.
3. Keep the category set small until real integration proves a need for more precision.

## Companion Design Documents

- [[04-dd-backend-transport-and-error-boundary]]
- [[07-dd-backend-conversation-contract]]

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]