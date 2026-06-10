# hybrid-ai: Linux GPU Runtime Portability Runbook

Date: 2026-06-08
Status: Active decision runbook
Scope: Define and maintain the solution space for running the LiteRT-LM Python inference server through Flox/Nix while preserving portability across Linux hosts, macOS development environments, and Apple packaging paths.

## 1. Problem Statement

The current Linux CPU path works in the repository-managed Flox Python environment.
The current Linux GPU path does not.

Observed state:
- the Python server runs correctly with `HYBRID_AI_LITERT_BACKEND=cpu`
- the Python server selects the LiteRT-LM `GPU` backend when `HYBRID_AI_LITERT_BACKEND=gpu`
- LiteRT-LM then initializes a WebGPU-backed GPU path on Linux
- host Vulkan diagnostics can enumerate the NVIDIA GPU in a clean host environment
- the Flox/Nix-launched Python server cannot safely consume the host NVIDIA Vulkan/GLX userspace stack yet

This is not just a one-host troubleshooting issue. It affects the repository strategy for:
- Linux GPU development
- reproducible dependency control under Flox/Nix
- multi-host portability
- macOS development workflows
- iOS packaging and deployment preparation

## 2. Requirements Context

This runbook should be interpreted together with:
- `docs/chat/devenv_portable_workflow.md`
- `docs/design-domain/13-dd-linux-backend-runtime-adapter.md`
- `docs/usecases/05-inference-server-workflow.md`

The controlling requirements are:
- repository-managed dependency and runtime boundaries
- minimal reliance on implicit host shell state
- support for Linux VMs, macOS hosts, and GPU providers
- preserve an architecture that still maps cleanly onto Apple-native packaging and iOS deployment

Domain traceability used below:
- business requirements:
   - `[[01-br-sandboxed-on-device-inference-target]]`
   - `[[03-br-apple-deployment-authority]]`
   - `[[04-br-linux-sandbox-approximation-requirements]]`
   - `[[06-br-shared-swift-core-portability-requirements]]`
- design decisions:
   - `[[03-dd-runtime-adapter-pattern]]`
   - `[[04-dd-backend-transport-and-error-boundary]]`
   - `[[09-dd-model-bootstrap-and-runtime-pinning]]`
   - `[[13-dd-linux-backend-runtime-adapter]]`

## 3. Proposed Solution Set

The following solution set is the starting point for the project. These options are intentionally preserved here as the baseline decision space.

### 3.1 Pure Nix userland plus host driver passthrough bridge

Model:
- keep Python, LiteRT-LM, wrapper scripts, model paths, and server process in Flox/Nix
- explicitly bridge only the host GPU driver layer into that runtime
- do not rely on arbitrary host shell state like current `LD_PRELOAD`, `PATH`, or random library search behavior

Typical Linux pattern:
- `nixGL`-style launchers
- or a custom wrapper that injects only the required driver libraries, ICD JSONs, and GPU device nodes into the Nix runtime

What this would look like in this repo:
- add a dedicated GPU launcher for the inference server
- the launcher normalizes environment:
  - unsets hostile host variables like `LD_PRELOAD`
  - sets explicit Vulkan ICD paths if needed
  - adds only the required host driver libs
- the launcher is the only supported path for `HYBRID_AI_LITERT_BACKEND=gpu`

What it would take to implement:

1. Add a dedicated Linux GPU server wrapper
    - create a wrapper such as `scripts/env/toolchain/python/python_server_gpu_run.sh`
    - keep `scripts/env/toolchain/python/python_env.sh` as the generic Python activation path
    - avoid polluting the default Python environment activation with Linux GPU host-library assumptions

2. Make the GPU wrapper explicitly construct the runtime boundary
    - source the existing Flox and Python environment helpers first
    - source `scripts/env/toolchain/inference_env.sh`
    - force `HYBRID_AI_LITERT_BACKEND=gpu`
    - unset host variables known to destabilize the runtime, especially `LD_PRELOAD`
    - optionally sanitize or rebuild `LD_LIBRARY_PATH` instead of inheriting it blindly

3. Discover and validate the host GPU contract before starting Python
    - detect required device nodes such as `/dev/dri/renderD128`
    - detect the Vulkan ICD JSONs actually intended for this host
    - detect the vendor userspace libraries required by those ICD JSONs
    - fail fast with a clear error if the contract is incomplete rather than letting LiteRT-LM fail later with opaque backend errors

4. Inject only the minimum required host GPU surface into the Flox-managed process
    - pass through the selected Vulkan ICD path using explicit environment variables rather than ambient discovery where possible
    - add only the required host driver library directories needed by the chosen ICD
    - do not prepend large host library trees broadly if a narrower path or wrapper can be used
    - preserve project-owned model, cache, and log paths from `scripts/env/toolchain/inference_env.sh`

Host package hygiene note:
- host-installed CUDA toolkits and host-installed `vulkan-tools` are not automatically helpful to this strategy
- they can contaminate the intended Flox-managed user-space boundary by introducing incompatible binaries, libraries, or loader expectations into diagnostics and runtime behavior
- if the host CUDA toolkit or host `vulkan-tools` are causing ABI conflicts, GLIBC mismatches, or misleading diagnostics, they may need to be:
   - excluded from the bridged environment
   - isolated behind explicit absolute-path invocation for host-only diagnostics
   - or uninstalled entirely if they keep defeating the repo-controlled runtime contract
- the goal of `3.1` is not to depend on whatever host CUDA or Vulkan user-space packages happen to be present; it is to make the host contribution as narrow and deliberate as possible

5. Add a bridge verification mode separate from normal server startup
    - add a check command that proves the bridged runtime can see:
       - the intended Vulkan loader
       - at least one usable adapter
       - the required vendor userspace libraries
    - make this a deterministic preflight instead of discovering problems only after the server starts

6. Keep the repository contract explicit
    - document which parts are repository-controlled:
       - Python runtime
       - LiteRT-LM version
       - model path and cache roots
       - wrapper logic
    - document which parts remain host-provided:
       - kernel driver
       - `/dev/dri` visibility
       - Vulkan ICD and vendor userspace compatibility

7. Add vendor-aware handling only where necessary
    - start with the currently observed NVIDIA path
    - keep the wrapper structured so AMD or Intel handling could be added later without rewriting the whole launch flow
    - do not pretend one set of host library rules is portable across all Linux GPU stacks

8. Add proof points to the workflow docs
    - the inference-server workflow should gain a Linux GPU preflight and launch path
    - expected failures should distinguish:
       - missing host contract
       - incompatible host-driver userspace
       - LiteRT-LM backend initialization failure after a valid bridge

Repository-oriented implementation sketch:
- add one wrapper for GPU launch
- add one helper for host GPU contract discovery and validation
- add one preflight command for bridge verification
- keep generic Python activation unchanged except where a narrow extension hook is needed

Concretely in this repo, that likely means:
- `scripts/env/toolchain/python/python_env.sh`
   - remains the generic Flox Python activation layer
- `scripts/env/toolchain/inference_env.sh`
   - continues to own model and cache path defaults
- new helper under `scripts/env/toolchain/inference/` or `scripts/env/toolchain/python/`
   - discovers ICD JSONs, vendor libs, and device-node visibility
- new launch wrapper under `scripts/env/toolchain/python/`
   - assembles the bridged environment and invokes the existing server entrypoint

Risks and engineering cost:
- moderate to high implementation effort because the hard part is not scripting, it is defining a stable ABI boundary between Nix userland and host proprietary GPU userspace
- high ongoing maintenance cost if multiple Linux GPU vendors or driver families must be supported
- acceptable only if this remains an explicit Linux-only bridge rather than an accidental requirement for all environments

Knowledge to reuse from Flox CUDA and model-serving references:

### 3.1.a What Flox’s CUDA material confirms

The Flox CUDA material reinforces several points that are directly relevant to this option:

1. Repository-controlled user space is realistic
   - Flox now distributes prebuilt CUDA user-space packages from its catalog and binary cache
   - this means a Linux GPU strategy can keep substantial parts of the runtime in Flox/Nix instead of treating CUDA-adjacent userspace as entirely unmanaged host state

2. Host drivers remain a separate contract on Linux
   - the Flox CUDA catalog content does not eliminate the need for the host NVIDIA driver stack on Linux
   - this exactly matches the premise of `3.1`: user-space can be repo-controlled while the kernel driver boundary remains host-provided

3. Environment composition is the preferred way to get predictability
   - Flox distinguishes layering from composition
   - layering is useful for temporary runtime additions, but composition surfaces conflicts at environment creation time and gives more predictable runtime behavior
   - for this repo, the bridge path should prefer composition for stable runtime pieces and reserve layering for optional debugging extras

4. Cross-platform manifests should use system constraints rather than one giant shared runtime assumption
   - Flox’s cross-platform CUDA examples use per-system package selection to switch between Linux CUDA and macOS Metal/MPS-compatible alternatives
   - that supports the repo’s broader portability stance: one repo, stable contracts, platform-specific runtimes

5. Minimal dependency closure matters
   - Flox’s CUDA guidance repeatedly recommends installing only the specific CUDA packages needed rather than a bloated monolithic toolkit
   - for this repo, that means the bridge strategy should import only the minimum Linux GPU runtime dependencies and not normalize broad host library trees

6. Preflight-driven serving is a validated pattern
   - Flox’s hardened serving environments for vLLM, Triton, and llama.cpp all use explicit preflight, model validation, startup orchestration, and controlled environment-variable overrides
   - that is directly reusable for this repo’s LiteRT-LM backend launch flow

### 3.1.b Concrete implications for this repo

The Flox material suggests the following concrete adjustments to the bridge design:

1. Prefer a composed GPU environment over ad hoc wrapper-only mutation
   - instead of keeping all GPU logic in one shell wrapper, create a dedicated Linux GPU environment module that includes the repo-controlled user-space pieces needed for GPU runtime support
   - then use the wrapper only for the final host-driver bridge and preflight logic

2. Separate base runtime from optional debug tooling
   - keep the core inference runtime minimal
   - if GPU debugging becomes necessary, layer or compose a separate diagnostics environment instead of inflating the base runtime path

3. Treat driver passthrough as the narrowest possible boundary
   - pass through only the host driver-facing pieces that genuinely must stay outside Flox
   - document that boundary explicitly, as Flox’s CUDA material does for Linux driver requirements

4. Build a hardened service pipeline, not just a launch command
   - Flox’s serving runtimes consistently separate:
     - preflight
     - model resolution or validation
     - serving
   - this repo should do the same for LiteRT-LM GPU backend startup instead of treating server launch as a single opaque shell command

5. Use declarative conflict management rather than shell-time improvisation
   - Flox’s CUDA guidance emphasizes manifest-level package priorities, package groups, and composition
   - if the repo adds Linux GPU-specific Flox packages, resolution should happen declaratively in manifests whenever possible, not as a shell-time accident

6. Keep the environment as the unit of promotion
   - Flox’s serving and CUDA Kickstart materials strongly emphasize promoting the environment, not rebuilding bespoke runtime state on every host
   - for this repo, the GPU bridge path should be versioned as an environment plus wrapper contract, not as tribal shell knowledge

### 3.1.c Proposed reuse pattern for hybrid-ai

Based on the Flox references, `3.1` should be interpreted as a three-layer design:

1. Composed repo-controlled GPU user-space layer
   - Flox-managed Python
   - LiteRT-LM and related Python packages
   - any repo-controlled GPU-capable user-space packages that are relevant and supported
   - model, cache, and log path policy

2. Hardened service orchestration layer
   - preflight step
   - runtime validation step
   - server launch step
   - structured exit behavior and actionable error reporting

3. Narrow host-driver bridge layer
   - device-node visibility
   - selected host driver libraries or ICD paths
   - explicit environment-variable passthrough
   - no broad inheritance of arbitrary host shell state

This is materially better than a single wrapper script that mutates `LD_LIBRARY_PATH` and hopes for the best.

### 3.1.d What to investigate next from these references

The Flox references suggest several concrete follow-up investigations for this repo:

1. Whether a dedicated Linux GPU environment should include prebuilt Flox CUDA user-space packages for validation utilities, even if LiteRT-LM itself remains the inference engine
2. Whether `python313Packages.ai-edge-litert` is relevant for LiteRT-related validation or compatibility experiments in a separate environment track
3. Whether the repo should mirror Flox’s service-pipeline shape with three explicit commands:
   - `hybrid-ai-gpu-preflight`
   - `hybrid-ai-gpu-validate`
   - `hybrid-ai-gpu-serve`
4. Whether the repo should define a small Linux GPU diagnostics environment that can be layered on top of the base GPU runtime for debugging only
5. Whether later Linux deployment paths should reuse the hardened patterns seen in Flox’s vLLM and Triton runtimes even if the immediate local-development path stays wrapper-based

### 3.1.d.1 Evaluation of `python313Packages.ai-edge-litert`

Current evaluation:
- useful for adjacent experimentation
- not a drop-in reuse candidate for the current Python backend

Why it is not a drop-in fit:

1. The current repo uses `litert-lm`, not base LiteRT
   - the current Python backend imports `litert_lm` and uses its high-level `Engine` and conversation APIs
   - the current model contract is built around `.litertlm` model bundles and LiteRT-LM-specific runtime behavior
   - `ai-edge-litert` is the base LiteRT runtime package, described as targeting mobile and embedded on-device inference, not the LiteRT-LM chat-serving layer the repo currently uses

2. The current backend contract is conversation-oriented
   - this repo’s Python server and Swift transport are built around one runtime creating many conversations, with send and optional stream semantics
   - reusing `ai-edge-litert` directly would likely require designing a lower-level model execution adapter, not simply swapping packages

3. The current Python environment does not match the published Flox package naming
   - the repo’s Python module currently targets `>=3.11,<3.13`
   - the cited Flox package is `python313Packages.ai-edge-litert`
   - that means it does not align cleanly with the current Poetry-managed Python 3.11 path without either:
     - introducing a dedicated Python 3.13 environment
     - or splitting validation experiments from the main backend runtime

4. It does not solve the current LiteRT-LM Linux GPU question by itself
   - even if base LiteRT is available from Flox, that does not automatically provide the same API surface, model format handling, or service behavior currently implemented with LiteRT-LM
   - using it would be an architectural exploration, not a low-risk packaging tweak

What it may still be good for:

1. Separate validation track
   - use it in a dedicated experiment environment to understand the lower-level LiteRT runtime behavior on Linux and Apple-adjacent targets

2. Compatibility probing
   - compare what base LiteRT can initialize or execute under a fully Flox-managed runtime versus what LiteRT-LM currently does

3. Future Apple-oriented investigation
   - because LiteRT is framed around mobile and embedded devices, it may be more relevant to future Apple-native or embedded validation work than to the current Linux backend service path

4. Diagnostic isolation
   - if the goal is to answer whether the lower-level LiteRT runtime can be made cleaner under Flox than LiteRT-LM on Linux, `ai-edge-litert` may be useful as a separate probe

Recommended reuse stance:
- do not add `python313Packages.ai-edge-litert` to the current main inference environment as part of the primary server path
- do consider a separate experiment environment if the team wants to answer one of these questions:
  - can base LiteRT initialize cleanly under a pure Flox-managed Linux runtime?
  - does base LiteRT expose a more tractable GPU path than LiteRT-LM on Linux?
  - is there a future adapter path worth building directly on LiteRT instead of LiteRT-LM?

Practical implication for this repo:
- keep `env/inference` minimal
- if this package is evaluated, do it in a dedicated environment such as `env/litert-probe` or `env/inference-gpu-linux`
- treat that work as architectural investigation, not as an in-place dependency substitution

Reference takeaways worth preserving in this runbook:
- Flox can own and version much more of the GPU user space than a naive Linux setup typically does
- Linux still needs an explicit host-driver contract
- composition is safer than ad hoc layering for stable runtime stacks
- preflight and staged service orchestration are not optional if the goal is reproducible GPU serving
- cross-platform portability should come from constrained manifests and stable contracts, not from pretending Linux CUDA and Apple GPU runtimes are the same thing

### 3.1.e Proposed solution for hybrid-ai

Based on the repo’s current state and the Flox references above, the recommended implementation of `3.1` is:

1. Create a dedicated composed Linux GPU environment
    - add a new environment such as `env/inference-gpu-linux`
    - this environment should include:
       - the existing Python environment via composition
       - the existing inference path policy via composition
       - only the minimum additional repo-controlled GPU user-space packages needed for Linux GPU runtime support and diagnostics
    - this environment must remain Linux-only via system constraints

2. Keep host-installed CUDA user space out of the supported runtime path
    - do not depend on a host CUDA toolkit for normal operation
    - if host CUDA packages are present, the wrapper should avoid inheriting their binaries and library paths implicitly
    - if they continue to contaminate linkage or diagnostics, prefer uninstalling them over trying to support an ambiguous mixed mode

Clarification:
- uninstalling the host CUDA toolkit is compatible with this strategy and is preferred if the toolkit is only adding impurity
- uninstalling host `vulkan-tools` is also compatible; those tools are diagnostics, not a required part of the supported runtime
- neither of those changes eliminates the need for the host GPU driver stack itself

3. Treat host Vulkan and driver state as an explicit contract, not a convenience
    - the host must provide:
       - kernel driver compatibility
       - device-node visibility
       - working Vulkan ICD registration for the intended GPU vendor
    - the repo should provide:
       - a deterministic preflight that checks these conditions before server launch
       - clear failure messages that distinguish host-contract failure from LiteRT-LM runtime failure

4. Implement a three-stage service path
    - `hybrid-ai-gpu-preflight`
       - checks device nodes, ICD files, vendor libraries, and bridge assumptions
    - `hybrid-ai-gpu-validate`
       - runs a narrow validation command inside the bridged environment to confirm that the Flox-managed process can resolve the intended GPU stack
    - `hybrid-ai-gpu-serve`
       - launches the Python server only after preflight and validation pass

5. Put the bridge logic in one narrow launcher
    - the launcher should:
       - source the composed Linux GPU environment
       - sanitize inherited host environment variables
       - inject only the selected ICD and the minimal host driver-facing library surface
       - preserve repo-owned paths for models, caches, logs, and artifacts
    - the launcher must not become a second package manager or an unbounded `LD_LIBRARY_PATH` accumulator

6. Keep diagnostics separate from the normal runtime
    - if richer tools are needed, add a small layered diagnostics environment rather than bloating the serving path
    - this is where host-only tools like absolute-path `vulkaninfo` can still be used for comparison without becoming part of the supported runtime contract

7. Promote the environment plus wrapper together
    - the supported unit is:
       - the composed Flox environment definition
       - the bridge preflight and validation helpers
       - the GPU launch wrapper
    - this package of behavior should be versioned and documented together

In short, the concrete solution is:
- compose a Linux-only GPU environment for repo-controlled user space
- bridge only the narrow host driver boundary at launch time
- gate server startup with explicit preflight and validation
- reject mixed-mode reliance on arbitrary host CUDA or Vulkan user-space packages

This is the recommended `3.1` shape because it preserves the repo’s controlled-runtime goals without pretending the Linux host driver layer can be fully absorbed into Flox.

### 3.1.f Re-evaluation with host CUDA toolkit and vulkan-tools removed

Assumption for this re-evaluation:
- host CUDA toolkit is uninstalled
- host `vulkan-tools` is uninstalled
- only the official GPU driver stack remains on the host

Under that assumption, the key question becomes:
- is there still a bridge, and if so, to what?

Answer:
- yes, but not to the host CUDA toolkit
- the bridge is only to the host GPU driver boundary:
   - kernel driver modules
   - device nodes
   - vendor driver userspace that is part of the driver installation
   - Vulkan ICD registration and vendor libraries required by the active driver

What disappears from the bridge:
- host CUDA compiler toolchain
- host CUDA runtime toolkit packages
- host `vulkaninfo` and related user-installed Vulkan diagnostics

What remains non-negotiable on non-NixOS Linux:
- the official driver stack, because Flox’s CUDA materials explicitly separate user-space package management from the host driver requirement on Linux

### 3.1.g Is there an out-of-the-box solution in the cited Flox resources?

For this repository’s current LiteRT-LM Linux GPU problem, the answer is:
- not fully

What the Flox resources do provide out of the box:
- reusable patterns for:
   - composing Linux GPU environments declaratively
   - using Flox-managed CUDA user-space packages instead of host CUDA toolkit installs
   - running hardened service pipelines with preflight, validation, and serve stages
   - promoting environment definitions across development, CI, and production
- ready-made runtimes for other inference stacks such as:
   - vLLM
   - Triton
   - llama.cpp
   - Ollama
   - LM Studio

What they do not provide out of the box for this exact case:
- a drop-in Flox runtime specifically for LiteRT-LM on Linux using the current Vulkan or WebGPU-backed GPU path
- a prebuilt Flox solution that removes the need to interact with the host driver boundary on non-NixOS Linux

So the correct re-evaluation is:
- there is no fully out-of-the-box replacement for the `3.1` bridge strategy if the target remains the current LiteRT-LM Linux GPU path
- there are out-of-the-box reusable building blocks for the repo-controlled user-space layer and the hardened service-orchestration layer
- the remaining custom work is to define the narrow driver-facing contract for LiteRT-LM on this host class

### 3.1.h Practical consequence for hybrid-ai

If the project keeps LiteRT-LM as the Linux inference engine, then the recommended `3.1` solution is:
- do not rely on host CUDA toolkit
- do not rely on host `vulkan-tools`
- do use the existing Python server Flox environment as the repo-controlled user-space boundary
- do add a narrow launch-time driver bridge only for the official driver boundary that remains after uninstalling host toolkits

If the project instead wants a more out-of-the-box Linux GPU path, then the Flox resources point toward a different conclusion:
- switch the Linux GPU-serving path to a runtime for which Flox already provides a hardened environment, such as vLLM, Triton, or llama.cpp
- keep LiteRT-LM as an Apple-native path or as a different validation track

That would reduce custom bridge work, but it would also change the Linux inference engine and therefore the product architecture.

### 3.1.i Recommendation after re-evaluation

For the current repo and current evidence, the best interpretation is:
- `3.1` remains viable, but only as a narrow driver-bridge strategy
- it should no longer be described as bridging to host CUDA user space
- it is bridging only to the residual host driver boundary that Flox does not eliminate on non-NixOS Linux
- if eliminating that remaining custom bridge work is more important than keeping LiteRT-LM as the Linux engine, the project should prefer `3.3` or `3.5` with a Flox-supported serving runtime instead

Current environment note:
- the existing [env/inference/manifest.toml](env/inference/manifest.toml) is intentionally minimal and does not yet represent a Linux GPU runtime environment
- the re-evaluated `3.1` path should extend [env/python/manifest.toml](env/python/manifest.toml) because that is already the Python server runtime boundary
- [env/inference/manifest.toml](env/inference/manifest.toml) should remain a minimal inference-policy module unless the repo later removes it entirely

### 3.1.j Implementation roadmap

The implementation roadmap for `3.1` should be executed in phases so the repo gains explicit runtime control without mixing refactors, diagnostics, and serving changes in one step.

#### Phase 0: Keep the current server surface stable

Goal:
- preserve the current Python server surface while making Linux GPU the intended runtime path through the existing Python environment

Actions:
- leave [env/inference/manifest.toml](env/inference/manifest.toml) minimal
- use [env/python/manifest.toml](env/python/manifest.toml) as the single Python server environment boundary
- add Linux GPU support to [env/python/manifest.toml](env/python/manifest.toml) and [scripts/env/toolchain/python/python_env.sh](/home/nkse/projects/hybrid-ai/scripts/env/toolchain/python/python_env.sh) only where that support is part of the normal server runtime contract

Exit criteria:
- the existing Python server entrypoint remains the only backend application surface

#### Phase 1: Extend the existing Python server environment for Linux GPU

Goal:
- make Linux GPU support part of the existing Python server runtime boundary instead of introducing a second server environment

Files to update:
- [env/python/manifest.toml](env/python/manifest.toml)

Files to reference or include:
- [env/base/](env/base)
- [env/inference/manifest.toml](env/inference/manifest.toml)

Recommended shape:
- Linux-only via system constraints
- keep `env/python` as the package owner for the Python backend runtime
- add only the minimum extra GPU-relevant user-space packages needed for Linux runtime support
- keep debugging-only tools out of the normal server environment unless they are required for launch-time validation

Do not do in this phase:
- do not add host driver assumptions into the manifest
- do not assume host CUDA toolkit exists
- do not put broad host library paths into Flox hooks

Exit criteria:
- the existing Python server environment can host the intended Linux GPU runtime without introducing a parallel environment boundary

#### Phase 2: Add explicit Linux GPU contract discovery

Goal:
- determine whether the host satisfies the residual non-Flox Linux driver contract before Python is launched

Files to add:
- `scripts/env/toolchain/inference/linux_gpu_contract.sh`

Responsibilities:
- detect required device nodes
- detect intended Vulkan ICD JSON locations
- detect whether the ICD JSON references vendor libraries that actually resolve on the host
- emit clear machine-readable failures for:
   - missing device visibility
   - missing ICD registration
   - missing vendor library resolution

Do not do in this phase:
- do not launch Python
- do not attempt to repair the host automatically

Exit criteria:
- the repo can answer "is the host driver contract present?" without starting LiteRT-LM

#### Phase 3: Add bridged runtime validation

Goal:
- prove that a Flox-managed Python process can see the required GPU-facing runtime surface after controlled environment assembly

Files to add:
- `scripts/env/toolchain/python/python_gpu_validate.sh`

Responsibilities:
- activate the existing Python server environment
- source the existing inference path policy from [scripts/env/toolchain/inference_env.sh](/home/nkse/projects/hybrid-ai/scripts/env/toolchain/inference_env.sh)
- sanitize inherited environment variables
- apply only the narrow driver-facing bridge inputs
- run a minimal validation command that checks runtime visibility from inside the Flox-managed Python process

Validation should answer:
- can the runtime resolve the selected GPU-facing libraries?
- can the runtime reach at least one usable adapter path?
- does the bridged process fail before LiteRT-LM initialization or during LiteRT-LM initialization?

Implementation note after initial probing:
- the validated bridge should not mutate `LD_LIBRARY_PATH` as part of the normal path
- early experiments that injected host vendor library directories into `LD_LIBRARY_PATH` caused Python process instability and violated the intended flow boundary
- until a narrower sanctioned bridge is identified, the promoted implementation boundary should stop at `validate`, not `serve`

Exit criteria:
- the repo can answer "can the managed runtime see the bridged GPU stack?" separately from "can LiteRT-LM serve requests?"

#### Phase 4: Add the dedicated GPU server launcher

Goal:
- create one supported path for starting the Linux GPU-backed inference server

Files to add:
- `scripts/env/toolchain/python/python_server_gpu_run.sh`

Responsibilities:
- activate the existing Python server environment
- run host-contract discovery
- run bridged runtime validation
- force `HYBRID_AI_LITERT_BACKEND=gpu`
- launch the existing Python backend entrypoint only after the earlier gates pass and the live serve stage has been explicitly promoted

Non-goals:
- this script should not become a generic shell environment manager
- it should not guess at multiple incompatible host runtime layouts in an unbounded way

Exit criteria:
- there is exactly one documented Linux GPU launch path for LiteRT-LM in this repo, and it is not promoted beyond validation until a non-`LD_LIBRARY_PATH` bridge is proven

#### Phase 5: Add optional diagnostics as a separate layer

Goal:
- keep day-to-day runtime small while still allowing deeper debugging when needed

Files to add only if needed:
- `env/python-gpu-debug/manifest.toml`
- or a remote/layered diagnostics env reference if that becomes preferable

Examples of what belongs here:
- richer Vulkan diagnostics
- debugging-only utilities
- instrumentation tools that are not required by normal server startup

Exit criteria:
- diagnostics are available without inflating the supported serving path

#### Phase 6: Document and validate the workflow

Goal:
- make the Linux GPU path auditable and reproducible by developers and CI-like validation

Files to update:
- [docs/usecases/05-inference-server-workflow.md](docs/usecases/05-inference-server-workflow.md)
- [docs/chat/linux_gpu_runtime_portability_runbook.md](docs/chat/linux_gpu_runtime_portability_runbook.md)

Workflow additions to document:
- how the existing Python server environment is extended for Linux GPU
- how to run preflight separately
- how to run validation separately
- how to start the GPU-backed server
- how to interpret the distinct failure classes

Exit criteria:
- the Linux GPU path is documented as a staged workflow, not a one-shot shell incantation

#### Phase 7: Promotion criteria

The `3.1` path should be considered implemented only when all of the following are true:

1. The CPU path still works unchanged
2. The host contract check is deterministic and explicit
3. Bridged runtime validation is separate from server startup
4. The GPU server launcher is the only supported Linux GPU start path
5. Failure classes are documented and actionable
6. The environment and wrapper contract can be versioned together
7. Live serving does not depend on broad `LD_LIBRARY_PATH` mutation

### 3.1.k Current promotion boundary after implementation probing

The initial implementation probing changes the recommended promotion boundary for
this repo.

Current state:
- `preflight` is implemented and promoted
- `validate` is implemented and promoted
- `serve` is implemented only as an experimental launcher boundary

Reason:
- the current LiteRT-LM Linux GPU path can be validated inside the managed
   Python environment with host-contract discovery plus `VK_ICD_FILENAMES`
- attempts to promote live serving by mutating `LD_LIBRARY_PATH` to include host
   vendor library directories caused Python process instability and violated the
   intended narrow-bridge model from the cited flow resources
- therefore the current implementation should not treat live GPU serving as a
   promoted path until a narrower sanctioned serve bridge is identified

Practical consequence:
- the repo should treat `python_gpu_validate.sh` as the promoted GPU gate
- `python_server_gpu_run.sh` should remain explicitly experimental beyond that
   gate
- documentation should not describe Linux GPU serving as fully implemented in
   the same sense as the CPU server workflow

What this does not mean:
- it does not invalidate `3.1`
- it means `3.1` is currently promoted only through validation, not through
   long-lived server serving

### 3.1.l Re-evaluation after prompt challenging the host pollution diagnosis

User prompt to preserve:

> "Not so sure about this because this host has cuda & vulkan tools installed and it seems the flox env is polluted by references to those binaries either directly or indirectly."

Requested follow-up from the same prompt:
- explore that challenge before proceeding
- consider reusing one of the strongest Flox references from the `agentic-lmstudio` or `agentic-ollama` materials to prove that local GPU can be used by Gemma 4 on this host
- use that hands-on exercise to improve troubleshooting of the Python inference-server crash

What was tested:

1. Inspect the actual repo-managed runtime surface
   - reviewed [env/python/manifest.toml](env/python/manifest.toml), [env/inference/manifest.toml](env/inference/manifest.toml), [scripts/env/toolchain/python/python_env.sh](/home/nkse/projects/hybrid-ai/scripts/env/toolchain/python/python_env.sh), [scripts/env/toolchain/inference_env.sh](/home/nkse/projects/hybrid-ai/scripts/env/toolchain/inference_env.sh), [scripts/env/toolchain/python/python_gpu_validate.sh](/home/nkse/projects/hybrid-ai/scripts/env/toolchain/python/python_gpu_validate.sh), and [scripts/env/toolchain/python/python_server_gpu_run.sh](/home/nkse/projects/hybrid-ai/scripts/env/toolchain/python/python_server_gpu_run.sh)
   - confirmed that the repo deliberately exposes a controlled GPU-related surface:
      - `env/python` installs `vulkan-loader`
      - `python_env.sh` prepends the Flox runtime lib directory to `LD_LIBRARY_PATH`
      - plain Flox activation still preserves host `PATH` entries such as `/usr/bin`

2. Compare normal validation with a nearly clean shell
   - ran `python_gpu_validate.sh` normally
   - reran it from a near-empty `env -i` shell with only essential variables restored
   - both runs passed through `threaded-backend-readiness`

3. Inspect LiteRT-LM linkage directly
   - `liblitert-lm.so` links to `libvulkan.so.1`
   - it does not directly link to `libcuda.so.1` or other CUDA toolkit libraries
   - `RUNPATH` is `$ORIGIN`

4. Test which libraries the managed Python runtime can actually load
   - inside the Flox-managed Python runtime:
      - `ctypes.CDLL("libvulkan.so.1")` works
      - `ctypes.CDLL("libcuda.so.1")` works
      - `ctypes.CDLL("libGLX_nvidia.so.0")` fails with `cannot open shared object file`
   - the same NVIDIA GLX library does exist on the host and is visible to `ldconfig`
   - loading the library by absolute path works:
      - `ctypes.CDLL("/lib/x86_64-linux-gnu/libGLX_nvidia.so.0")`

5. Reproduce the live server failure again
   - launched the experimental server on an alternate port
   - `/ready` returned HTTP 503 with:
      - `failed to initialize LiteRT-LM engine`
   - `/health` still reported service status `ok`
   - server logs again showed the Vulkan and WebGPU path failing during live engine creation

6. Compare host GPU diagnostics directly
   - `vulkaninfo --summary` on this host currently fails to detect a valid GPU
   - `nvidia-smi -L` currently fails to enumerate a usable device handle

7. Test a narrower bridge hypothesis without changing repo code
   - created a temporary ICD JSON with an absolute `library_path` pointing at `/lib/x86_64-linux-gnu/libGLX_nvidia.so.0`
   - used that file through `VK_ICD_FILENAMES`
   - result: the soname lookup problem was bypassed, but Vulkan still could not enumerate a valid adapter inside the Flox process

8. Test the old broad-host-library idea one more time as a safety check
   - temporarily prepending `/lib/x86_64-linux-gnu` to `LD_LIBRARY_PATH` caused crashes and ABI breakage again
   - this reconfirmed that broad host-library bridging is not a safe promoted solution

Revised findings after these probes:

1. The current problem is not best explained as generic Flox shell pollution
   - inherited shell state does exist
   - but the promoted validator still passes from a nearly clean shell
   - that weakens the theory that ambient host shell references are the main cause

2. The managed runtime has a narrower loader-boundary problem
   - the Flox-managed Python runtime can load `libvulkan.so.1` and `libcuda.so.1`
   - it cannot load the NVIDIA ICD vendor library by soname from the host ICD JSON
   - this matches the live-server log line:
      - `libGLX_nvidia.so.0: cannot open shared object file`

3. The immediate live failure is consistent with Vulkan ICD or adapter initialization failure in-process
   - the server log shows:
      - `vkCreateInstance failed with VK_ERROR_INCOMPATIBLE_DRIVER`
      - `Found 0 adapters`
      - `Failed to initialize WebGPU environment: No adapters found`
   - the failure still occurs inside live `prepare()` or engine creation, not during the earlier validation ladder

4. There is also an underlying host GPU visibility problem on this machine right now
   - host `vulkaninfo` does not enumerate a valid GPU
   - host `nvidia-smi` cannot enumerate a usable device cleanly
   - even after bypassing the ICD vendor-library soname issue with an absolute-path ICD JSON, Vulkan still fails to enumerate a valid adapter

5. The old `LD_LIBRARY_PATH` workaround remains rejected
   - direct experimentation again showed process instability and ABI mismatch when broad host library directories were injected into the managed runtime

Current interpretation after this re-evaluation:
- the earlier statement that this is not mainly a CUDA dev-tool packaging problem still stands
- but it should be refined
- the meaningful host interaction is not generic binary pollution from host CUDA or Vulkan tools on `PATH`
- the meaningful host interaction is:
   - host Vulkan ICD metadata
   - host NVIDIA vendor-library lookup from a Flox or Nix-managed process
   - actual host GPU adapter enumeration

Practical consequence for the repo:
- the validator should eventually gain a stricter probe than `find_library()` alone
- future validation should explicitly test:
   - whether the managed process can load the ICD vendor library named by the selected ICD
   - whether a minimal adapter-enumeration path succeeds before LiteRT-LM tries to serve
- any future bridge experiment should prefer a narrow sanctioned mechanism, such as explicit ICD rewriting or equivalent targeted handling, rather than broad `LD_LIBRARY_PATH` mutation

Result of the requested Flox reference exercise:
- attempted to use the remote `flox/agentic-ollama` environment as the strongest near-term reference stack for proving local GPU-backed Gemma serving on this host
- the environment resolved far enough to begin downloading `ollama-cuda`
- activation then failed because the package was not signed by a trusted key in the current Flox policy context
- therefore the reference exercise did not produce a Gemma 4 proof on this machine yet
- however, the lower-level host probes already suggest that even a trusted activation would still be blocked by the current host GPU enumeration failures unless the host driver state is corrected first

### 3.1.m Narrow isolation hardening implemented after the re-evaluation

Implemented changes:

1. Managed Vulkan tooling was added to the Python server environment
   - [env/python/manifest.toml](env/python/manifest.toml) now includes `vulkan-tools` in addition to `vulkan-loader`
   - this gives the GPU validation path a Flox-managed `vulkaninfo` instead of relying on a host-installed diagnostic binary

2. The GPU path now scrubs ambient CUDA and Vulkan environment variables before activation
   - [scripts/env/toolchain/inference/linux_gpu_contract.sh](/home/nkse/projects/hybrid-ai/scripts/env/toolchain/inference/linux_gpu_contract.sh) now unsets ambient GPU-related variables such as:
      - `LD_PRELOAD`
      - `CUDA_*`
      - `VK_*`
      - `NVIDIA_*`
   - this is intentionally narrow to the GPU validation and GPU server-launch path; it does not change the default CPU workflow

3. The GPU path now rebuilds a narrower runtime `PATH`
   - after Python activation, the GPU scripts rebuild `PATH` to prefer:
      - the managed Python venv
      - `FLOX_ENV/bin`
      - `FLOX_ENV/sbin`
      - `/usr/bin`
      - `/bin`
   - this reduces accidental dependence on user-level host tool paths while still allowing the residual host driver boundary to be reached through the standard system runtime

4. The promoted validator gained stricter isolation-oriented checks
   - [scripts/env/toolchain/python/python_gpu_validate.sh](/home/nkse/projects/hybrid-ai/scripts/env/toolchain/python/python_gpu_validate.sh) now includes:
      - `managed-vulkan-tooling`
         - verifies that `vulkaninfo` resolves from inside `FLOX_ENV`
      - `icd-vendor-library-loadability`
         - verifies that the resolved GPU vendor library paths exported by the contract helper can be loaded by the managed Python runtime
   - an optional stricter probe is also available:
      - `HYBRID_AI_GPU_STRICT_VULKANINFO=1`
      - this adds a managed `vulkaninfo --summary` adapter-enumeration phase to the validator

Observed outcome after these changes:
- the promoted validator still succeeds under the narrowed GPU runtime path
- the stricter managed `vulkaninfo` phase also succeeds when enabled
- at that stage the live server still failed on `/ready` with LiteRT-LM engine creation failure

Interpretation:
- these changes improved runtime isolation and made the validator more trustworthy as a managed-environment check
- they did not eliminate the separate live-serving failure boundary
- therefore the repo remains in the same promotion state:
   - validation is promoted
   - live GPU serving remains experimental

### 3.1.n Experimental narrow serve bridge found after live request-thread probing

Additional investigation after `3.1.m`:
- added an env-gated request-thread probe in [src/python/hybrid_ai/backend.py](/home/nkse/projects/hybrid-ai/src/python/hybrid_ai/backend.py) so the live `prepare()` path could capture what the actual HTTP request thread sees immediately before LiteRT-LM engine creation
- this probe records:
   - whether the resolved NVIDIA vendor library can be loaded by absolute path
   - `nvidia-smi` output from the request thread
   - `vulkaninfo --summary` output from the request thread

Observed breakthrough:
- the broad live probe unexpectedly changed the live outcome:
   - `/ready` returned `ready: true`
   - `backend-prepare-success` was captured from `Thread-1 (process_request_thread)`
- the probe output showed that the request thread could load the resolved NVIDIA vendor library by absolute path and that `nvidia-smi` returned normal device metadata
- removing the probe again caused live `/ready` to fall back to engine creation failure

Isolation of the winning behavior:
- a narrower prewarm path was added
- this path loads the resolved vendor library paths from `HYBRID_AI_GPU_VENDOR_LIBRARIES` by absolute path in `LiteRTEngineRuntime.prepare()` before LiteRT-LM engine creation
- once this prewarm was present in the live GPU path:
   - `/ready` returned `ready: true`
   - `/health` returned `ready: true`
   - creating a conversation and sending a real message through `/v1/conversations/.../messages` succeeded

Important nuance:
- the successful request-thread probe also showed that `vulkaninfo --summary` launched from inside Python subprocess execution can still fail with a glibc-related mismatch even while LiteRT-LM engine creation succeeds
- therefore the most meaningful serve-path indicator here is not subprocess `vulkaninfo`, but whether the NVIDIA vendor library can be loaded by absolute path inside the managed process before engine creation

Current interpretation after this experiment:
- a narrow serve bridge likely exists for this host class
- that bridge is not broad `LD_LIBRARY_PATH` mutation
- the currently successful narrow mechanism is:
   - keep the isolated managed runtime path from `3.1.m`
   - resolve the vendor library path during host-contract discovery
   - prewarm the vendor library by absolute path before LiteRT-LM engine creation in the live server path

Current repo status after this result:
- validation remains promoted
- live GPU serving is no longer blocked in the same way on this host when the experimental vendor-library prewarm flag is enabled
- however, the serve bridge is still experimental until the project decides whether this prewarm should be:
   - promoted as the supported narrow Linux serve bridge
   - constrained to NVIDIA-only handling
   - or replaced with a still cleaner sanctioned mechanism

Operator flags still relevant to this runbook:
- `HYBRID_AI_GPU_LIVE_PROBE=1`
   - enables the richer request-thread diagnostic probe used to isolate the winning behavior

### 3.1.o Verified end-to-end smoke and promotion decision

Verified result captured after implementing the repo-local smoke workflow:
- the repo-level shell entrypoint [scripts/env/run_inference_local_gpu_smoke.sh](scripts/env/run_inference_local_gpu_smoke.sh) now wraps [scripts/env/toolchain/python/python_gpu_smoke.sh](scripts/env/toolchain/python/python_gpu_smoke.sh)
- the shell smoke workflow was executed end to end on this host on a fresh port after hardening cleanup and port checks
- the smoke workflow completed successfully through all stages:
   - host `nvidia-smi` check
   - managed GPU validation
   - GPU server startup
   - `/ready`
   - `/health`
   - conversation creation
   - one message round-trip
- the verified ready payload reported:
   - `ready: true`
   - `backend: gpu`
- the verified health payload reported:
   - `status: ok`
   - `ready: true`
- the verified round-trip returned assistant content through the live HTTP API
- after backend normalization and stale-listener cleanup hardening, the verified message payload returned normalized plain assistant text:
   - `Hello there, how are you?`

Follow-up issue found during that smoke:
- the first successful end-to-end smoke exposed that the backend was returning a stringified structured LiteRT response object instead of normalized plain assistant text
- this was fixed at the backend extraction boundary in [src/python/hybrid_ai/backend.py](/home/nkse/projects/hybrid-ai/src/python/hybrid_ai/backend.py) by normalizing:
   - structured content-part lists
   - stringified structured payloads that serialize as Python literals
- the smoke wrapper was also hardened so repeated local runs do not silently reuse stale listeners:
   - it now checks whether the requested port is already in use
   - it logs per-port under `/tmp/hybrid-ai-gpu-smoke-server-<port>.log`
   - it tears down the background server process group rather than only one PID

Promotion decision:
- promote the narrow absolute-path vendor-library prewarm as the supported Linux GPU serve bridge for the current repository target

Scope of that promotion:
- Linux
- NVIDIA driver stack
- Vulkan ICD-based discovery
- repo-managed Python runtime in `env/python`

Why this is now the right promotion point:
- the serve bridge is now exercised by a deterministic repo-local shell smoke path rather than only ad hoc terminal probes
- the bridge no longer depends on broad `LD_LIBRARY_PATH` mutation
- the bridge is narrow, inspectable, and derived from the same host-contract data already exported by `linux_gpu_contract.sh`
- the end-to-end API path now returns normalized plain assistant text instead of implementation-shaped response objects

What remains constrained even after promotion:
- this is still a host-driver boundary, not a fully host-independent GPU stack
- this promotion should be treated as NVIDIA-specific unless and until another vendor path is implemented and verified
- if a future LiteRT-LM release removes the need for absolute-path prewarm, the bridge should be simplified again rather than preserved out of inertia

Practical repo consequence:
- Linux GPU `serve` is now promoted for the supported host class above
- the vendor-library prewarm should no longer be described as experimental in the main workflow docs
- the shell smoke entrypoint should remain part of the supported verification ladder because it proves the live server contract, not just the validation ladder

### 3.1.p Live serve failure after promotion: missing X11/XCB transitive runtime dependencies

Follow-up troubleshooting on the same host found one more real serve-path gap even after the narrow vendor-library prewarm was promoted.

Observed symptom:
- `python_gpu_validate.sh` still passed
- the live GPU server process could still fail `/ready` with:
   - `Found 0 adapters`
   - `Failed to initialize WebGPU environment: No adapters found`

Key diagnostic step:
- enabled live request-thread snapshots with:
   - `HYBRID_AI_GPU_DEBUG_SNAPSHOT_DIR=<dir>`
   - optionally `HYBRID_AI_GPU_LIVE_PROBE=1`
- inspected:
   - `py-backend-prepare-entry.json`
   - `py-backend-prepare-engine-error.json`
   - `serve-launch.json`

Root cause shown directly by the snapshots:
- the live server process was correctly activated inside `env/python`
- `VK_ICD_FILENAMES` and `HYBRID_AI_GPU_VENDOR_LIBRARIES` were present
- but the prewarm and probe both failed to load the NVIDIA vendor library because of missing transitive X11 runtime libraries

Initial concrete failure captured in the snapshot:
- `libGLX_nvidia.so.0` failed to load with:
   - `libX11.so.6: cannot open shared object file: No such file or directory`

After adding `libX11`, the next concrete missing dependency was:
- `libXext.so.6`

Host `ldd` on `/usr/lib/x86_64-linux-gnu/libGLX_nvidia.so.0` showed the relevant transitive runtime set included:
- `libX11.so.6`
- `libXext.so.6`
- `libxcb.so.1`
- `libXau.so.6`
- `libXdmcp.so.6`

Implemented repo fix:
- extended [env/python/manifest.toml](env/python/manifest.toml) to include the X11/XCB runtime libraries needed by the NVIDIA GLX vendor library:
   - `xorg.libX11`
   - `xorg.libXext`
   - `xorg.libxcb`
   - `xorg.libXau`
   - `xorg.libXdmcp`

Interpretation:
- this was not a Flox activation failure
- it was not a reason to uninstall host CUDA or host Vulkan tooling
- it was a missing transitive userspace runtime dependency inside the managed Python environment used by the long-lived live server process

Verification sequence that proved the fix:

1. Re-sync `env/python`
   - `FLOX_ENV_DIR=$PWD/env/python FLOX_MANIFEST_PATH=$PWD/env/python/manifest.toml ./scripts/env/toolchain/nix/flox_env_init.sh`

2. Verify the managed runtime can load the direct X11 dependency
   - use `ctypes.CDLL("libX11.so.6")`

3. Verify the managed runtime can load the actual NVIDIA vendor library by absolute path
   - use `ctypes.CDLL("/usr/lib/x86_64-linux-gnu/libGLX_nvidia.so.0")`

4. Restart the GPU server on a fresh port

5. Recheck `/ready` and `/health`

6. Re-run the repo smoke workflow or Swift live integration tests against that fresh port

Practical lesson:
- when `python_gpu_validate.sh` passes but live `/ready` still fails, inspect the live snapshot files before assuming the bridge model is wrong
- the live serve path can still surface missing transitive dependencies of the resolved vendor library even when the earlier validation ladder succeeds
- the correct repair is to add the missing userspace runtime libraries to `env/python`, not to broaden `LD_LIBRARY_PATH`

#### Proposed work order in this repo

1. Update [env/python/manifest.toml](env/python/manifest.toml)
2. Add `scripts/env/toolchain/inference/linux_gpu_contract.sh`
3. Add `scripts/env/toolchain/python/python_gpu_validate.sh`
4. Add `scripts/env/toolchain/python/python_server_gpu_run.sh`
5. Update [docs/usecases/05-inference-server-workflow.md](docs/usecases/05-inference-server-workflow.md)

#### Explicit non-goals for the roadmap

This roadmap does not attempt to:
- replace `litert-lm` with another inference engine
- turn [env/inference/manifest.toml](env/inference/manifest.toml) into the Python server runtime boundary
- make Linux GPU behavior the canonical product proof instead of Apple-native validation
- support arbitrary host CUDA toolkit installations as part of the normal runtime path

Sources consulted:
- https://flox.dev/blog/the-flox-catalog-now-contains-nvidia-cuda/
- https://flox.dev/blog/get-nvidia-cuda-stacks-that-travel-across-your-sdlc-with-flox/
- https://flox.dev/blog/run-gpu-accelerated-frontier-coding-models-locally-on-your-laptop/
- https://flox.dev/blog/a-turnkey-toolkit-for-agentic-development-with-flox/
- https://flox.dev/blog/deploying-hardened-flox-nvidia-cuda-stacks-in-minutes-not-hours/
- https://flox.dev/cuda-kickstart/
- https://hub.flox.dev/packages/base/python313Packages.ai-edge-litert
- https://flox.dev/blog/gpu-optimized-pytorch-builds-made-easy-with-flox-and-nix/
- https://flox.dev/blog/production-model-serving-using-nvidia-triton-vllm-llamacpp-with-flox/

Applicable business requirements:
- `[[04-br-linux-sandbox-approximation-requirements]]`
- `[[01-br-sandboxed-on-device-inference-target]]`

Applicable design decisions:
- `[[13-dd-linux-backend-runtime-adapter]]`
- `[[09-dd-model-bootstrap-and-runtime-pinning]]`

Pros:
- strongest alignment with controlled dependency boundaries required by `[[04-br-linux-sandbox-approximation-requirements]]`
- keeps the Python server itself under Flox/Nix, which fits `[[13-dd-linux-backend-runtime-adapter]]` by preserving the backend process boundary instead of collapsing into in-process shortcuts
- explicit and scriptable, which matches the inspectable bootstrap expectation in `[[09-dd-model-bootstrap-and-runtime-pinning]]`
- works with the portability goals better than ad hoc host hacks because it keeps Linux approximation disciplined under `[[01-br-sandboxed-on-device-inference-target]]`

Cons:
- Linux proprietary GPU support still depends on the host driver stack, so it only partially satisfies the repository-control goal in `[[04-br-linux-sandbox-approximation-requirements]]`
- `nixGL`-style solutions are Linux-specific, which limits direct reuse under the cross-environment expectations implied by `[[01-br-sandboxed-on-device-inference-target]]`
- likely requires per-vendor and per-driver handling, which complicates keeping runtime preparation uniformly explicit under `[[09-dd-model-bootstrap-and-runtime-pinning]]`
- does not generalize to macOS or iOS as the same runtime path, which is acceptable but reinforces the authority boundary in `[[03-br-apple-deployment-authority]]`

Best fit when:
- Linux GPU development should remain primarily Nix/Flox managed
- a thin explicit host-driver bridge is acceptable as the only host-specific piece

### 3.2 Split controlled runtime from controlled driver interface

Model:
- define two dependency classes:
  - repository-controlled dependencies
  - host-provided GPU driver contract
- treat the host driver layer as an explicit external interface, not an accidental dependency

In practice:
- Flox manages:
  - Python
  - LiteRT-LM
  - wrappers
  - models
  - API contract
  - test tools
- host must provide:
  - Vulkan ICD
  - vendor GPU userspace
  - `/dev/dri` access
- repo supplies a verification command proving the host contract is satisfied

Applicable business requirements:
- `[[04-br-linux-sandbox-approximation-requirements]]`
- `[[03-br-apple-deployment-authority]]`

Applicable design decisions:
- `[[13-dd-linux-backend-runtime-adapter]]`
- `[[09-dd-model-bootstrap-and-runtime-pinning]]`

Pros:
- very explicit, which directly supports the observability and owned-runtime expectations in `[[04-br-linux-sandbox-approximation-requirements]]`
- portable as policy across many Linux hosts even when exact driver implementations differ, which helps Linux remain an approximation environment rather than a one-machine special case under `[[01-br-sandboxed-on-device-inference-target]]`
- realistic for GPU work, because total elimination of host driver dependence is often not achievable, and `[[03-br-apple-deployment-authority]]` already says Linux feasibility does not redefine the product truth

Cons:
- still not fully self-contained, so it stops short of the strongest interpretation of repo-owned runtime boundaries in `[[04-br-linux-sandbox-approximation-requirements]]`
- controls everything except the final hardware-driver boundary, which means runtime preparation under `[[09-dd-model-bootstrap-and-runtime-pinning]]` remains partly contractual rather than fully repo-supplied

Best fit when:
- reproducibility matters, but GPU drivers are accepted as part of the platform rather than part of the repo

### 3.3 Containerized GPU backend with Nix/Flox build inputs

Model:
- use Nix/Flox to build and define the Python server environment
- package it into a GPU-capable container runtime boundary
- rely on NVIDIA Container Toolkit or equivalent host GPU passthrough
- deploy the inference backend that way on Linux GPU machines

This gives:
- controlled userspace in the image
- explicit host GPU handoff through container runtime tooling
- easier portability across GPU Linux hosts and GPU providers

Applicable business requirements:
- `[[04-br-linux-sandbox-approximation-requirements]]`
- `[[01-br-sandboxed-on-device-inference-target]]`
- `[[03-br-apple-deployment-authority]]`

Applicable design decisions:
- `[[13-dd-linux-backend-runtime-adapter]]`
- `[[04-dd-backend-transport-and-error-boundary]]`
- `[[09-dd-model-bootstrap-and-runtime-pinning]]`

Pros:
- strong reproducibility story because the image can carry the pinned runtime and model bootstrap expectations from `[[09-dd-model-bootstrap-and-runtime-pinning]]`
- explicit deployment artifact, which fits the inspectable-runtime discipline required by `[[04-br-linux-sandbox-approximation-requirements]]`
- well-aligned with multi-host deployment, matching the Linux VM and GPU-provider direction in `docs/chat/devenv_portable_workflow.md` while keeping Linux as an approximation under `[[01-br-sandboxed-on-device-inference-target]]`
- often easier than mixing proprietary GPU drivers directly into Nix userland, while still preserving the backend boundary favored by `[[13-dd-linux-backend-runtime-adapter]]`

Cons:
- adds container runtime complexity on top of the existing backend transport boundary in `[[04-dd-backend-transport-and-error-boundary]]`
- still host-dependent for GPU driver and kernel interface, so it does not eliminate the host contract problem called out by `[[04-br-linux-sandbox-approximation-requirements]]`
- less convenient for purely local non-container development unless both modes are supported, which can weaken the simple local rehearsal path expected by the Linux approximation requirement set

Best fit when:
- deployment portability matters more than pure local shell purity
- Linux GPU hosts and GPU providers are part of the operating model

### 3.4 Dedicated Linux GPU runtime env, separate from general dev env

Model:
- keep today’s `env/python` as the general, portable, CPU-safe environment
- add a separate `env/inference-gpu-linux` or similar
- that env exists only for Linux GPU backend execution
- it can carry different runtime assumptions, bridge logic, and diagnostics

Applicable business requirements:
- `[[04-br-linux-sandbox-approximation-requirements]]`
- `[[03-br-apple-deployment-authority]]`

Applicable design decisions:
- `[[09-dd-model-bootstrap-and-runtime-pinning]]`
- `[[13-dd-linux-backend-runtime-adapter]]`

Pros:
- clean separation of concerns, which helps preserve Linux-specific behavior inside the backend-facing lane described by `[[13-dd-linux-backend-runtime-adapter]]`
- avoids contaminating normal Python development or macOS workflows, which respects the authority split in `[[03-br-apple-deployment-authority]]`
- makes the GPU path explicit instead of magical, which is consistent with the explicit runtime-preparation direction in `[[09-dd-model-bootstrap-and-runtime-pinning]]`

Cons:
- more environments to maintain, which increases operational surface area around the pinned runtime policy in `[[09-dd-model-bootstrap-and-runtime-pinning]]`
- still needs one of the bridging strategies above, so by itself it does not satisfy the Linux runtime-boundary discipline required by `[[04-br-linux-sandbox-approximation-requirements]]`

Best fit when:
- repo structure should clearly separate Linux GPU quirks from normal development workflows

### 3.5 Remote GPU backend as the canonical GPU path

Model:
- local Flox/Nix env remains CPU-safe and fully controlled
- GPU inference runs on a dedicated Linux GPU node or provider
- Swift app and local development tools talk to the backend over HTTP
- the backend image or VM is the controlled deployment artifact

This aligns with the current architecture because the repo already has:
- a Python backend process boundary
- a Swift transport adapter
- live integration tests against the running backend

Applicable business requirements:
- `[[01-br-sandboxed-on-device-inference-target]]`
- `[[03-br-apple-deployment-authority]]`
- `[[06-br-shared-swift-core-portability-requirements]]`

Applicable design decisions:
- `[[03-dd-runtime-adapter-pattern]]`
- `[[04-dd-backend-transport-and-error-boundary]]`
- `[[13-dd-linux-backend-runtime-adapter]]`

Pros:
- strongest cross-host portability because the shared Swift-facing contract in `[[03-dd-runtime-adapter-pattern]]` stays stable while GPU execution moves behind the backend boundary
- avoids solving proprietary NVIDIA userspace mixing on every developer workstation, which reduces Linux-host leakage against `[[04-br-linux-sandbox-approximation-requirements]]`
- naturally compatible with macOS and iOS development because `[[03-br-apple-deployment-authority]]` keeps Apple deployment truth separate from Linux execution details
- matches realistic deployment better by leaning into the real HTTP process boundary preferred in `[[04-dd-backend-transport-and-error-boundary]]`

Cons:
- local GPU rehearsal is less direct, so Linux loses some immediacy as a fast approximation environment under `[[04-br-linux-sandbox-approximation-requirements]]`
- requires remote environment provisioning, auth, and networking discipline, which adds operational work outside the core adapter design captured by `[[13-dd-linux-backend-runtime-adapter]]`

Best fit when:
- the backend process boundary is already part of the architecture
- one consistent GPU story is needed across Linux, macOS, CI, and remote GPU providers

### 3.6 Vendor the open-source GPU userspace where possible

Model:
- package Mesa and Vulkan userspace in Nix where possible
- avoid host proprietary GL and Vulkan userspace as much as possible

This can work better for:
- Intel
- AMD Mesa-based stacks

It is much harder for:
- NVIDIA proprietary userspace

Applicable business requirements:
- `[[04-br-linux-sandbox-approximation-requirements]]`
- `[[01-br-sandboxed-on-device-inference-target]]`

Applicable design decisions:
- `[[09-dd-model-bootstrap-and-runtime-pinning]]`

Pros:
- closest to fully repo-controlled GPU userspace, which is the strongest match for the owned-runtime expectations in `[[04-br-linux-sandbox-approximation-requirements]]`
- good for open driver stacks because it keeps more of runtime preparation inside the explicit pinning and setup discipline of `[[09-dd-model-bootstrap-and-runtime-pinning]]`

Cons:
- weak fit for proprietary NVIDIA environments, which is a practical problem for current Linux GPU rehearsal even if the policy direction is clean
- not one universal answer across all hosts, so it weakens the approximation portability expected by `[[01-br-sandboxed-on-device-inference-target]]`

Best fit when:
- the Linux GPU fleet is standardized on Mesa-friendly hardware and drivers

### 3.7 Do not make Linux GPU backend the canonical portability proof

Given the broader requirements:
- Linux development
- macOS development
- iOS packaging and deployment

the canonical abstraction should be:
- API contract
- model path contract
- runtime contract
- packaging policy

not:
- one exact GPU execution backend across all platforms

That means:
- Linux GPU backend is one adapter path
- macOS and iOS will use different native execution paths
- the shared proof should be contract-level, not driver-level

This is consistent with:
- the backend adapter design
- the live Swift integration tests
- the backend process boundary already implemented in the repo

Applicable business requirements:
- `[[01-br-sandboxed-on-device-inference-target]]`
- `[[03-br-apple-deployment-authority]]`
- `[[06-br-shared-swift-core-portability-requirements]]`

Applicable design decisions:
- `[[03-dd-runtime-adapter-pattern]]`
- `[[04-dd-backend-transport-and-error-boundary]]`
- `[[13-dd-linux-backend-runtime-adapter]]`

Pros:
- keeps the portability proof anchored to the real product target defined by `[[03-br-apple-deployment-authority]]` instead of overfitting Linux desktop GPU specifics
- reinforces the shared-core portability goal in `[[06-br-shared-swift-core-portability-requirements]]` because shells and runtimes can differ while semantics stay stable
- matches `[[03-dd-runtime-adapter-pattern]]` by treating Linux GPU as one adapter path rather than the only proof of correctness

Cons:
- can feel less satisfying for local Linux GPU optimization work because hardware-specific tuning is intentionally demoted below contract-level proof
- requires discipline to keep contract tests and backend validation strong enough that de-emphasizing Linux GPU parity does not turn into hand-waving around runtime behavior

## 4. Recommended Direction

Reject this recommendation:
- do not make `CPU-in-Flox` the baseline portable local path for architecture or product-direction decisions

Reason:
- it is useful for setup, diagnostics, and narrow smoke validation
- it is not the right anchor for reasoning about the deployment constraints that actually matter
- the authoritative sequence must start from iOS sandbox effects, then Apple-hosted approximation, and only then Linux approximation strategies

The recommended direction is therefore:

1. Treat iOS sandbox effects as the primary decision source
2. Use Mac Catalyst on macOS as the closest development approximation of those effects
3. Evaluate Linux options by how well they preserve those same effects
4. Keep the shared Swift runtime contract stable across all of the above

### 4.1 Packaging Direction For The LiteRT-LM Linux GPU Runtime

The current repository state proves that LiteRT-LM GPU serving can run on the
supported Linux NVIDIA plus Vulkan host class through a narrow host-driver
bridge and a Flox-managed Python runtime.

The current `env/python/manifest.toml` should not be treated as the desired
long-term packaging boundary.

Why it currently looks granular:
- the manifest currently installs the Vulkan loader, Vulkan diagnostics tooling,
   and the X11 or XCB userspace libraries that the resolved NVIDIA vendor
   library requires at runtime
- this is not arbitrary library collection; it is the explicitly discovered
   native closure required for the current LiteRT-LM Linux GPU path
- however, it still expresses transitive runtime details at the application
   environment layer rather than through a named runtime capability

Recommended target shape:
- move toward a dedicated LiteRT-LM Linux GPU runtime environment or package
- keep the application-facing `env/python` manifest small and product-oriented
- treat the Linux GPU runtime as a named and versioned capability rather than a
   growing list of native libraries

That target runtime should own:
- the pinned Python runtime used by the server
- the pinned LiteRT-LM package set
- the Vulkan loader and any diagnostics tools that are part of supported
   validation
- the required Linux userspace graphics-library closure for the supported host
   class
- the wrapper commands for preflight, validate, and serve
- the documented host contract for what remains outside Flox:
   - NVIDIA driver stack
   - device-node visibility
   - Vulkan ICD registration

Preferred near-term structure:

1. A composed LiteRT-LM runtime base
    - Python
    - Poetry or uv as needed
    - LiteRT-LM and related Python dependencies

2. A Linux GPU support layer
    - Vulkan loader and diagnostics tooling
    - the required Linux userspace graphics-library closure
    - vendor-library discovery and validation helpers

3. A server product layer
    - preflight command
    - managed-runtime validation command
    - server launch command
    - logging, snapshots, and readiness policy

Implications for this repo:
- the current explicit native-library installs are acceptable as an interim
   implementation because they make the runtime boundary inspectable and
   reproducible
- they should eventually move under a dedicated runtime environment or package
   so that `env/python` depends on a higher-level runtime capability instead of
   curating transitive Linux GPU libraries directly
- the wrapper scripts already point in that direction because they separate:
   - host-contract discovery
   - managed-runtime validation
   - server launch

In short:
- the current manifest is explicit but still low-level
- the desired end state is equally explicit, but at the level of a named
   LiteRT-LM Linux GPU runtime contract rather than individual Vulkan or X11
   libraries

### 4.2 Reusable Flox Runtime Patterns From Existing GPU Environments

The existing Flox GPU-serving environments are still useful to this repo even
though they are mostly NVIDIA and Linux oriented and do not package LiteRT-LM
itself.

The most reusable parts are higher-level runtime patterns, not their exact
engine binaries or exact native-library sets.

Reusable patterns already proven in Flox environments:

1. Runtime package plus wrapper-command split
    - `llamacpp` uses `flox/llamacpp-flox-runtime`
    - `vllm` uses `flox/vllm-flox-runtime`
    - `sglang` uses `flox/sglang-flox-runtime`
    - the key reuse idea is to publish stable commands such as:
       - `preflight`
       - `resolve-model`
       - `serve`
    - this is directly applicable to LiteRT-LM and is better than leaving all
       runtime behavior embedded in the application environment manifest

2. Service pipeline as the unit of promotion
    - `llamacpp`, `vllm`, `sglang`, and `nvidia-triton` all promote a service
       command chain instead of a raw binary invocation
    - this aligns with the current repo direction of separating:
       - host-contract discovery
       - managed-runtime validation
       - server launch

3. Model resolution as a distinct concern
    - `llamacpp`, `vllm`, and `nvidia-triton` all distinguish runtime setup from
       model provisioning
    - supported source patterns include:
       - Flox-packaged models from the Nix store
       - local project models
       - Hugging Face cache or Hugging Face download
       - object-store sources such as R2
    - this is directly reusable for LiteRT-LM even if the actual model file type
       differs from GGUF or Hugging Face directories

4. Host-driver bridge encapsulation
    - `lmstudio` and `ollama-cuda` show a higher-level boundary than direct
       application-manifest references to native libraries
    - the key idea is that the package or runtime wrapper owns the host-driver
       bridge instead of the application env curating low-level link inputs
    - for LiteRT-LM, this is the main reusable idea behind eventually replacing
       direct `vulkan-loader` and `xorg.*` entries in `env/python/manifest.toml`

5. Activation-time defaults and cache ownership
    - the existing runtimes consistently use:
       - activation-time environment-variable defaults
       - `$FLOX_ENV_CACHE` for generated state, logs, and staged assets
       - explicit service commands under `[services]`
    - this is reusable as-is for LiteRT-LM Linux and for an Apple-hosted
       development environment

6. Platform-specific runtime packaging under one logical product
    - `lmstudio` already demonstrates a single logical runtime with different
       Linux and Apple implementation details
    - that pattern is directly relevant to a future split between:
       - `litert-lm-linux-gpu-runtime`
       - `litert-lm-ios-hosted-runtime`
    - the logical contract can stay stable while the packaged runtime differs by
       platform

What is not directly reusable:
- the exact CUDA package selections from `llama.cpp`, `vLLM`, `SGLang`, and
   `Triton`
- the exact Linux driver probes they use, because LiteRT-LM on Linux currently
   depends on the Vulkan-backed path rather than a CUDA-native engine path
- the exact model packaging layout used by GGUF- and Hugging Face-based engines

Therefore the best reuse target is:
- reuse the runtime packaging pattern
- reuse the service-pipeline pattern
- reuse the model-resolution pattern
- do not copy their exact native dependency closure or assume that CUDA-native
   runtime logic automatically solves LiteRT-LM's Vulkan-backed Linux path

### 4.3 Engine Comparison Matrix For Future Repo Extension

The table below compares the engines and runtimes most relevant to a future
multi-engine `hybrid-ai` layout.

| Engine or Runtime | Existing Flox runtime evidence | Best reusable parts for this repo | Main mismatch with current LiteRT-LM path | Fit for future `hybrid-ai` |
| --- | --- | --- | --- | --- |
| LiteRT-LM | No existing Flox runtime found in checked repos | N/A, this repo would author the runtime | Linux GPU path is Vulkan-backed and app-specific today | Required, custom runtime |
| llama.cpp | Strong: `flox-cuda/llama-cpp` plus `flox/llamacpp-flox-runtime` | Clean `preflight -> resolve-model -> serve` pipeline, model provisioning, service promotion | GGUF and CUDA offload are a different runtime model | High |
| vLLM | Strong: `flox-cuda/python3Packages.vllm` plus `flox/vllm-flox-runtime` | Python-engine packaging, model resolution, service scripts, OpenAI-compatible serving | CUDA-native and Hugging Face oriented, not Vulkan-backed | High |
| SGLang | Strong: `flox/sglang-python312-cuda12_8-*` plus `flox/sglang-flox-runtime` | Explicit runtime package ownership, multi-GPU server shape, packaged models | CUDA-native package family, not aligned with LiteRT-LM API surface | Medium to high |
| NVIDIA Triton | Strong: `flox/triton-server` plus backend packages and service pipeline | Multi-backend serving plane, preflight, model repository assembly, backend separation | Much heavier operational model than current repo needs | Medium |
| Ollama | Strong: `ollama`, `ollama-cuda`, multiple env examples | Product-grade local runtime packaging, service composition, operational maturity | Internal engine abstraction hides too much for LiteRT-LM-style runtime authoring | Medium |
| LM Studio | Strong: packaged runtime in `flox/floxenvs` and `agentic-development-with-flox` | Cross-platform runtime packaging, host-driver mediation, local API shape, composition | Product package rather than engine-authoring template; unfree upstream | Medium |
| oMLX | Strong on Apple only: `flox/omlx` | Apple-hosted inference env shape, service and composition pattern | Apple-only and MLX-specific, not LiteRT-LM | Medium for iOS-hosted design inspiration |
| MLC-LM | No existing Flox runtime found in checked repos | None found in checked repos | Would likely require custom packaging similar to LiteRT-LM | Possible custom future runtime |
| cactus engine | No existing Flox runtime found in checked repos | None found in checked repos | Unknown packaging surface in Flox ecosystem | Possible custom future runtime |

Recommended interpretation:
- the repo should treat `llama.cpp` and `vLLM` as the strongest reusable design
   references for a future custom LiteRT-LM runtime
- `SGLang` is also relevant where explicit packaged CUDA server runtimes are
   useful design input
- `LM Studio` is the best reference for cross-platform local-runtime packaging
   where Linux and Apple use different runtime internals under one product name
- `oMLX` is useful as an Apple-hosted packaging reference, not as a LiteRT-LM
   substitute

### 4.4 Proposed Multi-Engine And iOS-Oriented Flox Layout

The repo requirement is broader than Linux NVIDIA GPU serving.
The app must also preserve a path to iOS deployment, which implies an Apple-side
LiteRT-LM runtime contract in addition to the Linux GPU runtime.

Important constraint:
- a Flox environment cannot be the on-device iOS runtime itself
- the iOS runtime that ships to the device remains the app bundle and its
   Apple-managed packaging path
- what Flox can provide is the hosted build, validation, packaging, fixture,
   and approximation environment used to prepare and verify that iOS runtime

That means the future repo layout should distinguish:

1. Hosted runtime environments
    - reusable development and validation environments running on Linux or macOS

2. Product packaging targets
    - the actual deployed Swift or Apple runtime packaged into the app

Recommended future environment layout:

1. `env/inference-litert-base`
    - shared LiteRT-LM contract surface
    - shared model, cache, and log policy
    - shared wrapper naming and helper functions
    - no Linux GPU-specific or Apple-specific native closure

2. `env/inference-litert-linux-gpu`
    - Linux x86_64 only
    - owns the supported Linux NVIDIA plus Vulkan runtime closure
    - owns:
       - preflight
       - validate
       - serve
       - model resolution for `.litertlm` assets
    - eventually replaces direct native-library curation in `env/python`

3. `env/inference-litert-ios-hosted`
    - macOS Apple Silicon only
    - does not pretend to run iOS inside Flox
    - owns the hosted environment needed to:
       - validate LiteRT-LM Apple backend assumptions
       - stage pinned model assets and metadata for app packaging
       - run Swift-side contract tests against the Apple-native runtime adapter
       - prepare bundle-friendly asset layout for iOS or Mac Catalyst workflows
    - should be interpreted as the hosted companion to the on-device iOS runtime,
       not a substitute for it

4. `env/inference-llamacpp`
    - future optional engine env
    - wraps an OpenAI-compatible local server contract

5. `env/inference-vllm`
    - future optional engine env
    - wraps the OpenAI-compatible high-throughput server contract

6. `env/inference-sglang`
    - future optional engine env
    - wraps the structured-generation server contract

7. `env/inference-router`
    - optional later composition env
    - owns engine selection and shared client-facing configuration
    - could expose a stable backend contract to Swift and Python callers while
       selecting a concrete runtime underneath

8. `env/app-dev`
    - application-facing env that composes:
       - shared toolchain envs
       - one selected inference env
       - test and smoke utilities

Resulting product-facing contract:
- the app and tests target one shared backend contract
- each engine env owns its own runtime closure and service semantics
- LiteRT-LM remains first-class on both:
   - Linux via `env/inference-litert-linux-gpu`
   - Apple-hosted development and iOS packaging via
      `env/inference-litert-ios-hosted`

### 4.5 Immediate Design Guidance For LiteRT-LM

Based on the existing Flox runtime ecosystem, the next evolution of the current
LiteRT-LM env should be:

1. Do not keep growing `env/python/manifest.toml` as the permanent owner of raw
    Linux GPU link inputs

2. Move toward a dedicated LiteRT-LM Linux runtime package or composed env that
    owns:
    - native closure
    - validation commands
    - serve command
    - host-contract documentation

3. Define a separate Apple-hosted LiteRT-LM env for the iOS path so the repo
    keeps the Apple deployment authority explicit instead of treating Linux GPU
    as the only runtime that matters

4. Reuse existing Flox runtime ideas at the service and packaging layer,
    especially from:
    - `llamacpp`
    - `vllm`
    - `lmstudio`

5. Avoid direct reuse of CUDA-native dependency decisions where LiteRT-LM's
    Linux path is still Vulkan-backed and Apple deployment remains a separate
    product requirement

## 5. Apple Backend Surface

LiteRT-LM should be treated as exposing the following public backend surface on Apple platforms:
- `CPU`
- `GPU`

Important interpretation notes:
- there is no separate public `Metal` backend in the LiteRT-LM API surface used by Python or Swift
- there is no separate public `CoreML` backend in the LiteRT-LM API surface
- there is no public Apple `NPU` backend exposed in the same way
- on Apple platforms, the practical interpretation is that `GPU` is the public selector and Apple-specific acceleration happens behind that selector

Current working interpretation for this repo:
- macOS development should assume LiteRT-LM `GPU` means the Apple-native GPU path, not a Linux-style Vulkan or WebGPU path
- iPhone and iPad deployment should also be reasoned about as `CPU` or `GPU` at the public LiteRT-LM API layer
- Apple-specific hardware details should remain encapsulated behind an Apple-native adapter rather than leaking into shared app logic

Applicable business requirements:
- `[[03-br-apple-deployment-authority]]`
- `[[01-br-sandboxed-on-device-inference-target]]`
- `[[06-br-shared-swift-core-portability-requirements]]`

Applicable design decisions:
- `[[03-dd-runtime-adapter-pattern]]`
- `[[11-dd-apple-native-runtime-adapter]]`
- `[[12-dd-apple-engine-and-conversation-lifecycle]]`

Implications:
- do not design the shared runtime contract around Linux GPU implementation details
- do not wait for a hypothetical Apple-specific public backend enum before planning the Apple path
- do keep Apple engine initialization, cache location, and conversation ownership behind the Apple-native runtime adapter

## 6. Effects Of Sandboxing When Running LiteRT-LM On iOS

For this project, the important effects of iOS sandboxing are not just file permissions. They are architectural constraints that should shape how LiteRT-LM is integrated.

### 6.1 Writable state is constrained and owned

Effects:
- model location is controlled by app packaging and provisioning
- writable caches and generated artifacts must live in app-approved sandbox directories
- there is no acceptable dependence on user-global caches, ad hoc shell state, or host-global mutable directories

What this means for LiteRT-LM:
- model location, cache location, and generated runtime artifacts must be explicit inputs
- runtime preparation must be inspectable and deterministic
- bootstrap policy cannot rely on hidden host defaults

Applicable requirements and decisions:
- `[[01-br-sandboxed-on-device-inference-target]]`
- `[[03-br-apple-deployment-authority]]`
- `[[09-dd-model-bootstrap-and-runtime-pinning]]`

### 6.2 Engine startup cost matters as product behavior

Effects:
- engine initialization latency affects interaction readiness
- model load cost, cache warmup, and memory footprint are part of the product behavior, not just implementation details

What this means for LiteRT-LM:
- one-engine-many-conversations is preferred over repeated engine creation
- initialization should happen off the main thread
- cache reuse and startup cost need explicit validation

Applicable requirements and decisions:
- `[[03-br-apple-deployment-authority]]`
- `[[11-dd-apple-native-runtime-adapter]]`
- `[[12-dd-apple-engine-and-conversation-lifecycle]]`

### 6.3 Conversation state must remain isolated and portable

Effects:
- transcript state, selection state, and runtime-owned conversation state must remain coherent under app lifecycle constraints
- the app model should not own engine internals directly

What this means for LiteRT-LM:
- the app should speak through a shared runtime contract
- Apple-native runtime objects should remain behind an adapter boundary
- the Linux backend path should model the same conversation semantics even if the execution mechanism differs

Applicable requirements and decisions:
- `[[06-br-shared-swift-core-portability-requirements]]`
- `[[03-dd-runtime-adapter-pattern]]`
- `[[12-dd-apple-engine-and-conversation-lifecycle]]`

### 6.4 Resource ceilings are real product constraints

Effects:
- memory pressure, thermal behavior, startup latency, and sustained token generation all matter on real iPhone hardware
- success on a desktop host does not prove acceptability on device

What this means for LiteRT-LM:
- performance validation must move onto real iPhone or iPad hardware before the architecture is treated as proven
- macOS and Linux are approximation environments only

Applicable requirements and decisions:
- `[[03-br-apple-deployment-authority]]`
- `[[01-br-sandboxed-on-device-inference-target]]`

## 7. Approximating Those Effects With Mac Catalyst On macOS

Mac Catalyst is not the final truth, but it is the closest Apple-hosted approximation for many of the sandbox and lifecycle consequences above.

### 7.1 What Mac Catalyst matches well

Mac Catalyst is useful for validating:
- Apple-native LiteRT-LM integration shape
- app-bundle resource lookup
- Apple-style writable cache directory handling
- one-engine-many-conversations lifecycle
- shared Swift app-model integration through `AppleLiteRTRuntime`

Applicable requirements and decisions:
- `[[03-br-apple-deployment-authority]]`
- `[[11-dd-apple-native-runtime-adapter]]`
- `[[12-dd-apple-engine-and-conversation-lifecycle]]`

### 7.2 What Mac Catalyst does not fully match

Mac Catalyst does not fully prove:
- iPhone-class thermal limits
- iPhone-class memory ceilings
- exact mobile GPU behavior
- final deployment truth on real devices

So it should be used to validate architecture and lifecycle shape, not to close product validation.

### 7.3 Recommended macOS solution direction

On macOS, the preferred approach is:
- implement and use `AppleLiteRTRuntime`
- run LiteRT-LM through the Apple-native `GPU` path where supported
- keep the backend HTTP path as a comparison or fallback mode, not as the primary Apple development story

This is the right direction because:
- it is closer to the authoritative platform family than Linux
- it validates the adapter shape required by `[[11-dd-apple-native-runtime-adapter]]`
- it keeps shared runtime semantics aligned with `[[03-dd-runtime-adapter-pattern]]`

## 8. Matching iOS Sandbox Effects On Linux By Proposed Solution

Linux should be judged by how well it preserves the iOS-relevant effects above, not by whether it can literally behave like iOS.

### 8.1 Pure Nix userland plus host driver passthrough bridge

Match quality:
- good for explicit runtime ownership and controlled startup inputs
- moderate for explicit writable-root discipline
- weak for approximating Apple-native packaging and Apple-native runtime behavior

Best-matched effects:
- explicit cache and runtime setup
- controlled process startup
- avoidance of accidental host-shell dependence

Mismatch risks:
- still deeply Linux-driver-specific
- validates Linux GPU bridging more than Apple-native integration

Use it for:
- local Linux GPU rehearsal once Apple-side adapter behavior is already defined elsewhere

### 8.2 Split controlled runtime from controlled driver interface

Match quality:
- good for making runtime versus platform responsibility explicit
- moderate for sandbox-style observability
- weak for Apple-native lifecycle approximation by itself

Best-matched effects:
- explicit ownership of what the repo controls versus what the platform provides
- inspectable startup contract

Mismatch risks:
- can devolve into platform-contract documentation without enough product-lifecycle validation

Use it for:
- turning Linux GPU support into an explicit platform contract rather than a hidden accident

### 8.3 Containerized GPU backend with Nix/Flox build inputs

Match quality:
- strong for explicit artifact ownership, startup reproducibility, and inspectable runtime state
- strong for preserving a process boundary
- only moderate for approximating in-app Apple-native execution

Best-matched effects:
- explicit model and cache ownership
- controlled startup sequence
- observable runtime artifact production

Mismatch risks:
- container deployment is closer to a backend service artifact than to native iOS in-app execution

Use it for:
- Linux deployment rehearsal and remote GPU packaging, not as a substitute for Apple-native runtime proof

### 8.4 Dedicated Linux GPU runtime env, separate from general dev env

Match quality:
- moderate as an organizational tool
- weak by itself as a sandbox approximation strategy

Best-matched effects:
- makes the Linux GPU path explicit
- helps keep special-case GPU behavior isolated from normal development

Mismatch risks:
- does not solve driver-boundary realism or Apple-lifecycle approximation on its own

Use it for:
- reducing contamination and making Linux GPU work maintainable when combined with another solution

### 8.5 Remote GPU backend as the canonical GPU path

Match quality:
- strong for preserving process boundaries, contract-level validation, and multi-host realism
- weak for approximating Apple-native in-app execution
- strong for validating shared Swift runtime semantics across hosts

Best-matched effects:
- explicit runtime boundary
- stable app-to-runtime contract
- cross-host reproducibility of backend behavior

Mismatch risks:
- does not directly validate Apple-native engine ownership, bundle layout, or on-device resource ceilings

Use it for:
- canonical Linux and provider-side GPU validation once Apple-native execution is treated as a separate adapter path

### 8.6 Vendor the open-source GPU userspace where possible

Match quality:
- strong for explicit dependency ownership on compatible Linux fleets
- weak to moderate for broad portability
- weak for approximating Apple-native runtime shape directly

Best-matched effects:
- explicit runtime ownership
- reduced hidden host dependence

Mismatch risks:
- current value depends heavily on hardware standardization
- NVIDIA-heavy fleets still break the approximation story

Use it for:
- controlled Linux fleets where open userspace can make runtime behavior more reproducible

### 8.7 Overall Linux matching conclusion

No Linux solution perfectly matches iOS-native execution.

The best mapping of Linux solutions to the iOS-driven requirements is:
- for Apple-lifecycle approximation: none beat Mac Catalyst; Linux should not be the primary proof here
- for explicit runtime ownership and inspectable startup: `3.1`, `3.2`, and `3.6`
- for deployment and backend-boundary realism: `3.3` and `3.5`
- for maintainability and isolation of Linux-specific GPU work: `3.4`

The strongest combined Linux posture is therefore:
- `3.5` as the canonical backend-boundary validation path
- `3.3` for deployable GPU artifact validation
- `3.1` or `3.4` for local Linux GPU rehearsal where needed

## 9. Gradual Validation And Convergence Plan

The project should converge in stages rather than choosing a Linux solution in the abstract.

### 9.1 Stage 1: Validate the Apple-native contract shape

Goals:
- prove that the shared runtime contract is sufficient for Apple-native LiteRT-LM use
- prove that one-engine-many-conversations works cleanly through the Apple adapter

Actions:
- implement `AppleLiteRTRuntime`
- validate prepare, create, list, send, stream, and remove semantics on macOS
- ensure model and cache inputs are explicit and adapter-owned

Exit criteria:
- the shared app model can run against Apple-native runtime without leaking engine details

### 9.2 Stage 2: Validate sandbox effects on Mac Catalyst

Goals:
- prove bundle lookup, writable cache ownership, startup cost shape, and conversation lifecycle on an Apple-hosted approximation

Actions:
- run the Apple-native path in Mac Catalyst
- measure initialization latency, cache behavior, and multi-conversation reuse
- confirm no reliance on host-global writable paths

Exit criteria:
- the repo has a reproducible Mac-side validation path for Apple adapter behavior

### 9.3 Stage 3: Validate the authoritative path on real iPhone or iPad hardware

Goals:
- test the real deployment authority

Actions:
- validate startup cost, memory pressure, thermal behavior, cache ownership, and interaction quality on device
- record the practical constraints that Linux and macOS approximation paths must preserve

Exit criteria:
- the team has a concrete list of authoritative runtime constraints instead of inferred ones

### 9.4 Stage 4: Turn those constraints into Linux evaluation criteria

Goals:
- judge Linux solutions against real product constraints rather than convenience

Actions:
- derive a Linux evaluation checklist from stages 2 and 3:
  - explicit writable roots
  - inspectable runtime preparation
  - stable runtime contract
  - realistic startup and lifecycle handling
  - reproducible deployment behavior

Exit criteria:
- every Linux solution can be scored against the same sandbox-driven criteria

### 9.5 Stage 5: Evaluate Linux solutions in increasing commitment order

Recommended order:
1. `3.4` dedicated Linux GPU env
   - lowest structural risk
   - clarifies boundaries even if it is not sufficient alone
2. `3.1` host driver passthrough bridge
   - best first local GPU rehearsal attempt
3. `3.3` containerized GPU backend
   - best next step for reproducible deployment-grade validation
4. `3.5` remote GPU backend canonicalization
   - best cross-host and provider-level validation path
5. `3.6` vendored open-source userspace where fleet constraints make it practical

Why this order:
- it avoids prematurely locking the repo onto a Linux-specific workaround before Apple constraints are validated
- it separates local rehearsal from canonical deployment validation

### 9.6 Stage 6: Converge on the optimal solution set

The likely end state is a combination, not a single winner:
- Apple-native LiteRT-LM adapter for macOS and iOS validation
- Linux remote or containerized GPU backend for canonical Linux/provider validation
- optional local Linux GPU bridge for developer rehearsal where justified

The optimal solution should be selected by evidence from the previous stages, not by initial preference.

## 10. Current Working Interpretation

Given the current repository behavior and diagnostics:
- CPU inference inside Flox works
- GPU backend selection inside Flox works
- host Vulkan enumeration works in a clean host environment
- proprietary NVIDIA Vulkan/GLX userspace is not yet safely consumable from the Flox/Nix-launched Python server process

So the immediate problem is not backend selection logic. It is the Linux GPU-driver runtime boundary.

## 11. Immediate Next Steps

The next implementation work should be evaluated in this order:

1. Implement `AppleLiteRTRuntime`
   - make the Apple-native adapter concrete before further Linux-policy hardening

2. Validate Apple-native lifecycle on macOS and Mac Catalyst
   - prove bundle lookup, cache ownership, engine reuse, and conversation semantics

3. Validate the authoritative path on real iPhone or iPad hardware
   - record the actual runtime constraints that matter

4. Define the Linux evaluation checklist from those findings
   - use sandbox effects and lifecycle invariants, not convenience, as the scoring basis

5. Evaluate Linux options in staged order
   - `3.4` then `3.1` for local rehearsal
   - `3.3` then `3.5` for deployment-grade validation

## 12. Decision Criteria

Any chosen solution should be judged against these questions:

1. Does it preserve repository-controlled dependency boundaries as much as possible?
2. Does it avoid undocumented reliance on host shell state?
3. Can it be explained and verified across multiple Linux hosts?
4. Does it keep macOS and iOS development paths clean rather than coupling them to Linux GPU specifics?
5. Can it be validated through the existing backend HTTP contract and Swift transport tests?
6. Is the resulting deployment story realistic for both local development and remote GPU providers?
7. Does it preserve a clean path to Apple-native runtime validation on macOS and real iPhone hardware?
8. How well does it preserve the concrete sandbox effects observed on Mac Catalyst and real iPhone hardware?

## 13. Non-Recommendations

The project should not rely on the following as durable solutions:
- manual `LD_LIBRARY_PATH` patching in ad hoc developer shells
- undocumented `LD_PRELOAD` interactions
- implicit host session state
- one-off machine-specific fixes that are not codified as wrappers or contracts
- treating Linux GPU backend behavior as a substitute for Apple-native runtime validation
- choosing a Linux path primarily because it is the easiest local bootstrap path

Those techniques may be useful for diagnosis, but they are not acceptable as the long-term portable runtime strategy.

## 14. Maintenance Rule

This document should be updated whenever one of the following changes:
- the chosen Linux GPU bridge strategy
- the canonical host GPU contract
- the remote GPU deployment strategy
- the Apple-native runtime integration strategy
- the LiteRT-LM backend behavior on Linux
- the LiteRT-LM public backend surface on Apple platforms
- the repo’s recommended portable runtime architecture

Changes should preserve the proposed solution set in Section 3 and then record:
- which option was chosen or rejected
- why
- what verification path proves that decision