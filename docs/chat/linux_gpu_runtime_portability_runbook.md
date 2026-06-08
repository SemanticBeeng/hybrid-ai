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