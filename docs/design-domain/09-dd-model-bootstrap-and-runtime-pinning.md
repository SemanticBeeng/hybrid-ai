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

## Current Repository Pin

The repository currently pins the Gemma bootstrap default as:

1. model reference: `gemma4:e4b`
2. model path: `volumes/models/litert-lm/gemma4-e4b`

The repository currently pins the LiteRT-LM runtime default as:

1. LiteRT-LM release tag: `v0.13.1`

Repository metadata for that pin is written to:

1. `volumes/models/litert-lm/litert-lm.model`
2. `volumes/models/litert-lm/litert-lm.model-path`
3. `volumes/models/litert-lm/litert-lm.model-file`
4. `build/artifacts/litert-lm.version`

## Repository Setup Surface

The application-level setup surface for LiteRT-LM and Gemma is:

1. `scripts/env/setup_litert_lm.sh`
	- installs the pinned LiteRT-LM Python binding
	- records the pinned runtime tag in `build/artifacts/litert-lm.version`

2. `scripts/env/setup_gemma4_e4b.sh`
	- records the pinned Gemma 4 E4B model reference and path
	- records the canonical pinned `.litertlm` file path
	- stores model metadata under `volumes/models/litert-lm`
	- copies or downloads the model into the pinned project-local model directory

3. `scripts/env/toolchain/inference_env.sh`
	- exports the pinned default model reference and pinned default model path
	- ensures those paths stay under repository-controlled roots

4. `scripts/env/run_inference_local.sh`
	- consumes the pinned model reference for local smoke execution

5. `scripts/env/run_inference_remote.sh`
	- consumes the same pinned model reference for remote transport-based smoke execution

## Application Setup Expectations

The application runtime contract should assume:

1. LiteRT-LM setup is pinned by default rather than dynamically resolved at runtime.
2. Gemma 4 E4B identity and location are pinned by default rather than hidden inside ad hoc CLI usage.
3. backend readiness checks should validate all three repository artifacts:
	- `build/artifacts/litert-lm.version`
	- `volumes/models/litert-lm/litert-lm.model`
	- `volumes/models/litert-lm/litert-lm.model-path`
4. backend readiness checks should also validate the canonical pinned model file metadata at `volumes/models/litert-lm/litert-lm.model-file` and confirm that the referenced `.litertlm` file exists.
5. model import or asset population remains separate from request handling and should target the pinned model path.

## Operational Setup Flow

For the application runtime, the expected order is:

1. run `scripts/env/setup_litert_lm.sh`
2. run `scripts/env/setup_gemma4_e4b.sh`
3. copy or download the Gemma 4 E4B `.litertlm` artifact into the pinned model path
4. run LiteRT-LM smoke checks using the pinned model reference
5. allow the backend readiness path to validate runtime and model availability before Swift connects

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