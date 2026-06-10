# Use Case 05: Inference Server Workflow

Date: 2026-06-09
Status: Implemented for CPU serving and for Linux GPU serving on the supported NVIDIA plus Vulkan host class
Primary scripts:
- `scripts/env/setup_litert_lm.sh`
- `scripts/env/setup_gemma4_e4b.sh`
- `scripts/env/run_inference_local_gpu_smoke.sh`
- `scripts/env/toolchain/inference/linux_gpu_contract.sh`
- `scripts/modules/inference_srv_py/gpu_validate.sh`
- `scripts/modules/inference_srv_py/gpu_smoke.sh`
- `scripts/modules/inference_srv_py/server_run.sh`
- `scripts/modules/inference_srv_py/server_gpu_run.sh`
- `scripts/modules/inference_srv_py/run.sh`

## 1. Goal

Run the Linux inference server inside the repository-managed Python environment
so that:
- LiteRT-LM is resolved from the Poetry-managed Python dependency set
- the pinned Gemma 4 E4B model file lives under `volumes/models/litert-lm`
- backend readiness checks validate the pinned runtime and pinned model assets
- no host-global Python environment or host-global cache becomes part of the
  runtime path

This workflow covers the complete promoted path for CPU serving and the complete
promoted path for Linux GPU serving on the supported host class:
- Flox activation
- Python environment sync
- LiteRT-LM dependency verification
- Linux GPU host-contract verification
- Linux GPU managed-runtime validation
- pinned model bootstrap
- CPU server startup
- CPU readiness and chat smoke tests
- Swift live integration validation against the running Python backend

For Linux GPU specifically:
- `preflight` is promoted
- `validate` is promoted
- `serve` is promoted for the current supported Linux host class:
  - NVIDIA driver stack
  - Vulkan ICD discovery
  - repo-managed Python runtime under `env/python`

## 2. Why This Workflow Exists

The inference server is more constrained than a generic Python workflow.

It must keep all of the following aligned:
- the dedicated Flox Python module at `env/python`
- the managed Python venv at `env/python/.flox/cache/python`
- the Poetry dependency lock under `src/inference_srv_py`
- the pinned LiteRT-LM version written to `build/artifacts/litert-lm.version`
- the pinned model metadata written under `volumes/models/litert-lm`
- the pinned model file under `volumes/models/litert-lm/gemma4-e4b`

Without this workflow, these failures are likely:
- `litert_lm` is missing because `poetry sync` removed an out-of-band install
- the server starts from the wrong Flox environment and uses the wrong venv
- model metadata exists but the actual `.litertlm` artifact is missing
- readiness checks fail because native runtime libraries are not available in the
  active environment

## 3. Scope And Assumptions

This workflow assumes:
- Determinate Nix and Flox are installed and usable
- the nix daemon socket exists at `/nix/var/nix/daemon-socket/socket`
- the repository root is `/home/nkse/projects/hybrid-ai`
- the Python dependency graph is managed by Poetry under `src/inference_srv_py`
- the CPU workflow is the currently promoted serving path on Linux
- the GPU workflow is supported for the current NVIDIA plus Vulkan host class

## 4. Files Involved

Environment and wrappers:
- `env/python/manifest.toml`
- `env/inference-litert-linux-gpu/manifest.toml`
- `scripts/env/toolchain/nix/flox_env_init.sh`
- `scripts/env/toolchain/nix/flox_with.sh`
- `scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh`
- `scripts/modules/inference_srv_py/run.sh`
- `scripts/modules/inference_srv_py/server_run.sh`
- `scripts/modules/inference_srv_py/server_gpu_run.sh`
- `scripts/modules/inference_srv_py/server_gpu_inner.sh`
- `scripts/env/toolchain/inference_env.sh`
- `scripts/env/toolchain/inference/linux_gpu_contract.sh`

Pinned setup scripts:
- `scripts/env/setup_litert_lm.sh`
- `scripts/env/setup_gemma4_e4b.sh`

Python backend source:
- `src/inference_srv_py/pyproject.toml`
- `src/inference_srv_py/poetry.lock`
- `src/inference_srv_py/inference_srv_py/bootstrap.py`
- `src/inference_srv_py/inference_srv_py/backend.py`
- `src/inference_srv_py/inference_srv_py/server.py`

Pinned runtime and model artifacts:
- `build/artifacts/litert-lm.version`
- `volumes/models/litert-lm/litert-lm.model`
- `volumes/models/litert-lm/litert-lm.model-path`
- `volumes/models/litert-lm/litert-lm.model-file`
- `volumes/models/litert-lm/gemma4-e4b/gemma-4-E4B-it.litertlm`

Logs:
- `volumes/logs/python_server.log`

## 5. Effective Runtime Behavior

### 5.1 Flox And Python Activation

The default CPU inference server uses the dedicated Python Flox environment at `env/python`.

The Linux GPU wrappers use the dedicated LiteRT-LM GPU Flox environment at `env/inference-litert-linux-gpu`.

That environment is expected to provide:
- Python 3.11
- Poetry
- the Vulkan loader runtime library needed by the LiteRT-LM Python wheel

The managed Python venv is created under the active Flox environment cache:
- `env/python/.flox/cache/python` for the default CPU path
- `env/inference-litert-linux-gpu/.flox/cache/python` for the Linux GPU path

The wrappers intentionally target their own Flox environment boundary even if the current shell
was entered through the repository root Flox environment.

Composition now differs by path:
- `env/python` remains the standalone CPU-safe Python runtime and includes `env/base`
- `env/inference-litert-linux-gpu` composes `env/python` directly and sets the LiteRT engine selection locally
- `env/inference-litert-base` remains a reusable LiteRT inference layer on top of `env/base`

That means the Linux GPU env inherits the Python toolchain from `env/python` and adds the LiteRT-LM GPU-native
closure itself. A resync must account for direct packages in the selected runtime env and packages inherited from
included environments.

Note: `env/inference/` was removed because it only added packages (curl, jq, git) already provided by `env/base`.
Its inference_env.sh exports are now sourced directly by the scripts that need them.

### 5.2 LiteRT-LM Dependency Management

LiteRT-LM is a Poetry-managed dependency under `src/inference_srv_py/pyproject.toml`.

`scripts/env/setup_litert_lm.sh` no longer performs an ad hoc `pip install`.
Instead, it verifies that:
- `litert-lm==0.13.1` is present in the managed Python venv
- the `litert_lm` module imports successfully from that venv

### 5.3 Model Bootstrap

`scripts/env/setup_gemma4_e4b.sh` records the pinned model metadata and ensures a
concrete `.litertlm` file exists at the pinned location.

The script accepts either:
- `HYBRID_AI_LITERT_MODEL_SOURCE` for a project-local source file
- `HYBRID_AI_LITERT_MODEL_URL` for a direct download URL

### 5.4 Backend Lifecycle

`scripts/modules/inference_srv_py/server_run.sh`:
- activates `env/python`
- activates the managed Python venv
- runs `python -m inference_srv_py.server`
- appends output to `volumes/logs/python_server.log`

The backend:
- validates pinned runtime and model metadata through `/ready`
- initializes LiteRT-LM against the pinned model file
- defaults to `HYBRID_AI_LITERT_BACKEND=cpu`
- maintains one runtime with many backend-managed conversations

The Linux GPU path adds a host-contract check before server startup that verifies
device visibility, Vulkan ICD registration, and vendor library resolution.

The GPU-specific wrappers default to `env/inference-litert-linux-gpu` rather than `env/python`.
The standalone `gpu_validate.sh` script remains available as a diagnostic tool but is
no longer called as part of the normal server launch path.

Current promotion status:
- the repo supports Linux GPU `preflight`, `validate`, and `serve` for the current NVIDIA plus Vulkan host class
- the supported serve bridge is narrow absolute-path loading of the resolved vendor library before LiteRT-LM engine creation
- broad host-library mutation through `LD_LIBRARY_PATH` remains rejected

Supported shell entrypoints:
- `scripts/env/run_inference_local_gpu_smoke.sh`
- `scripts/modules/inference_srv_py/gpu_smoke.sh`

## 6. Complete Workflow

### 6.1 Sync The Dedicated Python Flox Environment

Run this after changes to `env/python/manifest.toml` or if Flox reports a stale
manifest/lock mismatch:

```bash
cd /home/nkse/projects/hybrid-ai
FLOX_ENV_DIR=$PWD/env/python FLOX_MANIFEST_PATH=$PWD/env/python/manifest.toml \
./scripts/env/toolchain/nix/flox_env_init.sh
```

Also run this if the backend reports a missing native library such as
`libvulkan.so.1` even though the package was already added to the manifest. In
that case, the usual cause is a stale realized Flox environment under
`env/python/.flox/` rather than a bad Python venv activation.

What this resync does:
- validates that the target Flox manifest exists
- initializes `env/python/.flox/` if it has not been created yet
- syncs included environments first, such as `env/base`
- refreshes the realized environment metadata under `env/python/.flox/env/`
- refreshes the realized runtime under `env/python/.flox/run/`
- upgrades include wiring and then re-syncs the top-level `env/python` env

What this resync does not do:
- it does not invent missing native dependencies; if a package is not declared in
  `env/python/manifest.toml` or an included manifest, a resync will still leave
  it absent
- it does not replace Python dependency management; Python packages still come
  from `src/inference_srv_py/pyproject.toml` and `src/inference_srv_py/poetry.lock`
- it does not update an already running backend process; that process must be
  restarted after the resync

### 6.2 Verify The LiteRT-LM Dependency

Ensure the Python Flox environment is synced first (see [Section 6.1](#61-sync-the-dedicated-python-flox-environment)).

```bash
cd /home/nkse/projects/hybrid-ai

# Sync the Python env if not already done
FLOX_ENV_DIR=$PWD/env/python FLOX_MANIFEST_PATH=$PWD/env/python/manifest.toml \
./scripts/env/toolchain/nix/flox_env_init.sh

# Verify the dependency
./scripts/env/setup_litert_lm.sh
```

Expected result:
- `Verified litert-lm==0.13.1`

### 6.3 Bootstrap The Pinned Gemma 4 E4B Model

This step does not require Flox activation — it only writes model metadata and
downloads the artifact.

```bash
cd /home/nkse/projects/hybrid-ai
HYBRID_AI_LITERT_MODEL_URL='https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm?download=true' \
./scripts/env/setup_gemma4_e4b.sh
```

Expected result:
- pinned model metadata is written under `volumes/models/litert-lm`
- the model file exists at `volumes/models/litert-lm/gemma4-e4b/gemma-4-E4B-it.litertlm`

### 6.4 Readiness Smoke Test

In another terminal:

```bash
cd /home/nkse/projects/hybrid-ai
curl -i http://127.0.0.1:8080/ready
```

Expected result:
- HTTP `200`
- JSON payload with `"ready": true`
- `"backend": "cpu"`

For Linux GPU on supported hosts, expected result is:
- HTTP `200`
- JSON payload with `"ready": true`
- `"backend": "gpu"`

### 6.5 Health Smoke Test

```bash
cd /home/nkse/projects/hybrid-ai
curl -i http://127.0.0.1:8080/health
```

Expected result:
- HTTP `200`
- JSON payload containing service name, pinned model info, and issue list

### 6.6 Conversation Smoke Test

Create a conversation:

```bash
cd /home/nkse/projects/hybrid-ai
curl -sS -X POST http://127.0.0.1:8080/v1/conversations \
  -H 'Content-Type: application/json' \
  -d '{"system_prompt":"You are a concise local assistant."}'
```

Expected result:
- JSON with a `conversation_id`

Send a message, substituting the returned id:

```bash
cd /home/nkse/projects/hybrid-ai
curl -sS -X POST http://127.0.0.1:8080/v1/conversations/<conversation-id>/messages \
  -H 'Content-Type: application/json' \
  -d '{"text":"Say hello in one sentence."}'
```

Expected result:
- JSON payload with an assistant message

Delete the conversation:

```bash
cd /home/nkse/projects/hybrid-ai
curl -i -X DELETE http://127.0.0.1:8080/v1/conversations/<conversation-id>
```

Expected result:
- HTTP `204`

### 6.7 Linux GPU End-To-End Smoke

The repo now has a single-command GPU smoke workflow that mirrors the staged Flox serving style as closely as the current LiteRT-LM Linux path allows.

Run:

```bash
cd /home/nkse/projects/hybrid-ai
./scripts/env/run_inference_local_gpu_smoke.sh
```

What it does:
- runs `nvidia-smi` to confirm the host driver sees a GPU
- runs `inference_srv_py_gpu_validate.sh`
- starts the GPU server with the current narrow serve bridge
- polls `/ready`
- fetches `/health`
- creates one conversation
- sends one message and verifies a normalized assistant text reply exists

Useful overrides:
- `HYBRID_AI_PORT`
- `HYBRID_AI_HOST`
- `HYBRID_AI_GPU_DEBUG` — set to any non-empty value to enable runtime snapshot capture during server launch
- `HYBRID_AI_GPU_DEBUG_SNAPSHOT_DIR` — directory for snapshot output (defaults to `/tmp/hybrid-ai-gpu-snapshot-$$`)
- `HYBRID_AI_GPU_SMOKE_SYSTEM_PROMPT`
- `HYBRID_AI_GPU_SMOKE_MESSAGE`
- `HYBRID_AI_GPU_SMOKE_STARTUP_TIMEOUT_SECONDS`
- the wrapper fails fast if the requested port is already in use
- server logs are written per port under `/tmp/hybrid-ai-gpu-smoke-server-<port>.log`

### 6.8 Start The CPU Or GPU Inference Server

The server wrappers activate Flox internally, but the environment must be synced
first. If not already done:

```bash
cd /home/nkse/projects/hybrid-ai

# Sync Python env (CPU path)
FLOX_ENV_DIR=$PWD/env/python FLOX_MANIFEST_PATH=$PWD/env/python/manifest.toml \
./scripts/env/toolchain/nix/flox_env_init.sh

# Sync GPU env (GPU path)
FLOX_ENV_DIR=$PWD/env/inference-litert-linux-gpu \
FLOX_MANIFEST_PATH=$PWD/env/inference-litert-linux-gpu/manifest.toml \
./scripts/env/toolchain/nix/flox_env_init.sh
```

Default local server:

```bash
cd /home/nkse/projects/hybrid-ai
HYBRID_AI_LITERT_BACKEND=cpu ./scripts/modules/inference_srv_py/server_run.sh
```

Explicit host and port:

```bash
cd /home/nkse/projects/hybrid-ai
HYBRID_AI_HOST=127.0.0.1 HYBRID_AI_PORT=8080 \
./scripts/modules/inference_srv_py/server_run.sh
```

Linux GPU preflight:

```bash
cd /home/nkse/projects/hybrid-ai
./scripts/env/toolchain/inference/linux_gpu_contract.sh
```

Expected result:
- `linux_gpu_contract=ok`
- `gpu_device_nodes=...`
- `gpu_icd_files=...`
- `gpu_vendor_libraries=...`

Linux GPU managed-runtime validation:

```bash
cd /home/nkse/projects/hybrid-ai
./scripts/modules/inference_srv_py/gpu_validate.sh
```

Expected result:
- JSON payload containing `"gpu_validation": "ok"`
- `libvulkan` is resolved
- the payload includes the pinned `.litertlm` model file

Linux GPU serve:

```bash
cd /home/nkse/projects/hybrid-ai
HYBRID_AI_HOST=127.0.0.1 HYBRID_AI_PORT=8080 \
./scripts/modules/inference_srv_py/server_gpu_run.sh
```

The GPU server uses a two-file linear design:
- `server_gpu_run.sh` — outer entry point that recovers `LD_AUDIT`/`GLIBC_TUNABLES` from the root env when missing, strips inherited Flox/venv state, then activates the GPU env and exec's the inner script
- `server_gpu_inner.sh` — inner script that ensures the Python venv is active, runs the GPU host-contract check, applies the Vulkan bridge env, and exec's the Python server

Expected result:
- the host-contract check passes
- the server starts and can satisfy `/ready`, `/health`, and conversation requests on supported hosts
- the server uses the narrow vendor-library prewarm bridge rather than broad host linker-path mutation
- `LD_AUDIT` is present in the server process (recovered from root env if launched from an external shell)

### 6.9 Swift Live Integration Test Against The Promoted Server Path

After the Python backend is already running and `/ready` returns `"ready": true`,
validate the Swift app-side transport against the live server:

```bash
cd /home/nkse/projects/hybrid-ai
./scripts/env/run_swift_backend_integration_tests.sh
```

If the backend is running on a non-default URL, override it explicitly:

```bash
cd /home/nkse/projects/hybrid-ai
HYBRID_AI_BACKEND_BASE_URL=http://127.0.0.1:8080 \
./scripts/env/run_swift_backend_integration_tests.sh
```

What this validates:
- the Swift transport runtime can call `/ready`
- conversation create/list/delete works through the Swift runtime
- message send works through the Swift runtime
- current stream behavior works through the Swift runtime
- not-found errors from the backend surface correctly through the Swift client
- assistant text returned through the Swift runtime is normalized plain text rather than a repr-shaped structured payload

Expected result:
- the Swift test runner reports the `liveBackend*` tests as passing
- no server restart is required because this workflow assumes the Python backend is already running

### 6.10 Stop Any Running Inference Server

Before starting a new server, ensure no existing instance is occupying the target port:

```bash
pkill -f 'python -m inference_srv_py.server' 2>/dev/null || true
```

Or target a specific port:

```bash
pids="$(ss -ltnp '( sport = :8080 )' 2>/dev/null | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' | sort -u)"
[[ -z "$pids" ]] || kill $pids
```

Verify the port is free:

```bash
ss -ltnp '( sport = :8080 )' || echo "port free"
```

### 6.11 GPU Clean-Shell Resync And Server Start

Use this when starting from a completely fresh external shell with no prior Flox
state, or after manifest changes to `env/inference-litert-linux-gpu/manifest.toml`:

```bash
cd /home/nkse/projects/hybrid-ai
export PATH="/opt/bin/dev/nix/bin:$PATH"

# 1. Re-lock the GPU env after manifest changes
flox edit -d env/inference-litert-linux-gpu -f env/inference-litert-linux-gpu/manifest.toml

# 2. Reinstall litert_lm in the new venv (venv is recreated after re-lock)
FLOX_ENV_DIR=$PWD/env/inference-litert-linux-gpu \
FLOX_MANIFEST_PATH=$PWD/env/inference-litert-linux-gpu/manifest.toml \
./scripts/env/toolchain/nix/flox_with.sh bash -lc '
  source scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh
  inference_srv_py_activate_env
  poetry -C src/inference_srv_py sync --no-interaction
'

# 3. Verify litert_lm is installed
./scripts/env/setup_litert_lm.sh

# 4. Start the GPU server
HYBRID_AI_HOST=127.0.0.1 HYBRID_AI_PORT=18091 \
./scripts/modules/inference_srv_py/server_gpu_run.sh
```

In another terminal, verify:

```bash
curl -sS http://127.0.0.1:18091/ready | python3 -m json.tool
```

Expected result:
- `{"ready": true, "backend": "gpu", "issues": []}`

What the outer script (`server_gpu_run.sh`) handles automatically:
- recovers `LD_AUDIT` and `GLIBC_TUNABLES` from the root project env when they
  are missing (external shell case)
- strips inherited `FLOX_ENV`, `VIRTUAL_ENV`, and `VIRTUAL_ENV_PROMPT`
- activates `env/inference-litert-linux-gpu` via `flox_with.sh`
- exec's `server_gpu_inner.sh` which ensures the venv, runs the contract check,
  applies the Vulkan bridge, and starts the Python server

No manual `env -u` flags or `LD_AUDIT` setup is needed by the caller.

### 6.12 Optional Interactive Activation

If you want an interactive shell inside the dedicated Python Flox environment:

```bash
cd /home/nkse/projects/hybrid-ai
export PATH="/opt/bin/dev/nix/bin:$PATH"
flox activate -d env/python
source scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh
inference_srv_py_activate_env
```

This is optional. The wrappers above can activate the same environment without a
manual shell setup.

Important:
- `flox activate -d env/python` activates the current realized environment, but it
  does not rebuild a stale `env/python/.flox/env/manifest.lock`
- if `env/python/manifest.toml` changed, rerun [Section 6.1](#61-sync-the-dedicated-python-flox-environment) before starting the server
- if the server was already running before the resync, stop it and start it again so the new runtime libraries are picked up
- if `curl /ready` fails from a shell that already has `env/python` active, do not assume activation is enough; first resync the Flox env, then restart the server process

Recommended activation-to-ready preflight sequence:

```bash
cd /home/nkse/projects/hybrid-ai
export PATH="/opt/bin/dev/nix/bin:$PATH"

FLOX_ENV_DIR=$PWD/env/python FLOX_MANIFEST_PATH=$PWD/env/python/manifest.toml \
./scripts/env/toolchain/nix/flox_env_init.sh

flox activate -d env/python
source scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh
inference_srv_py_activate_env

./scripts/env/setup_litert_lm.sh
./scripts/modules/inference_srv_py/run.sh -c "import ctypes.util; print(ctypes.util.find_library('vulkan'))"

HYBRID_AI_HOST=127.0.0.1 HYBRID_AI_PORT=8080 HYBRID_AI_LITERT_BACKEND=cpu \
./scripts/modules/inference_srv_py/server_run.sh
```

Expected preflight results before `curl /ready`:
- `setup_litert_lm.sh` prints `Verified litert-lm==0.13.1`
- the Vulkan check prints `libvulkan.so.1`
- the server starts without an immediate native-library error

If either preflight check fails:
- for missing `libvulkan.so.1`, verify `vulkan-loader` is declared in
  `env/python/manifest.toml` and rerun the Flox resync from [Section 6.1](#61-sync-the-dedicated-python-flox-environment)
- for missing `litert_lm`, verify `litert-lm` is declared in
  `src/inference_srv_py/pyproject.toml`, the lockfile is current, and rerun the Poetry sync
  path described in [Section 9.1](#91-litert_lm-missing-from-the-managed-venv)

## 7. Verification Workflow

### 7.1 Verify The Active Python Path

```bash
cd /home/nkse/projects/hybrid-ai
./scripts/modules/inference_srv_py/run.sh -c "import sys; print(sys.executable)"
```

Expected result:
- the interpreter path points into `env/python/.flox/cache/python/bin/python`

### 7.2 Verify The LiteRT-LM Module Path

```bash
cd /home/nkse/projects/hybrid-ai
./scripts/modules/inference_srv_py/run.sh -c "import litert_lm; print(litert_lm.__file__)"
```

Expected result:
- the module path points into `env/python/.flox/cache/python/lib/python3.11/site-packages`

### 7.3 Verify Vulkan Loader Resolution

```bash
cd /home/nkse/projects/hybrid-ai
./scripts/modules/inference_srv_py/run.sh -c "import ctypes.util; print(ctypes.util.find_library('vulkan'))"
```

Expected result:
- output is `libvulkan.so.1`

### 7.4 Verify The Linux GPU Contract

```bash
cd /home/nkse/projects/hybrid-ai
./scripts/env/toolchain/inference/linux_gpu_contract.sh
```

Expected result:
- the script reports at least one GPU device node
- the script reports one or more Vulkan ICD files
- the script reports one or more resolved vendor libraries
- the output is observational and does not imply that those host libraries should
  be injected into `LD_LIBRARY_PATH`

### 7.5 Verify Managed GPU Validation

```bash
cd /home/nkse/projects/hybrid-ai
./scripts/modules/inference_srv_py/gpu_validate.sh
```

Expected result:
- JSON payload with `"gpu_validation": "ok"`
- the validation runs from the managed Python environment under `env/python`
- no `LD_LIBRARY_PATH` mutation is required for the validated path

Important note:
- a passing `inference_srv_py_gpu_validate.sh` does not prove the long-lived live server process has every transitive userspace dependency needed by the resolved NVIDIA vendor library
- if live `/ready` still fails, inspect the troubleshooting path in [docs/chat/linux_gpu_runtime_portability_runbook.md](docs/chat/linux_gpu_runtime_portability_runbook.md)

### 7.6 Promotion Boundary Summary

Current Linux GPU boundary:
- promoted: `scripts/env/toolchain/inference/linux_gpu_contract.sh`
- promoted: `scripts/modules/inference_srv_py/gpu_validate.sh`
- promoted: live GPU serving through `scripts/modules/inference_srv_py/server_gpu_run.sh`
- promoted: end-to-end live verification through `scripts/env/run_inference_local_gpu_smoke.sh`

Reason:
- the current LiteRT-LM Linux GPU path now has a verified narrow driver-facing
  serve bridge based on absolute-path loading of the resolved vendor library
  without broad host dynamic-linker mutation

Important packaging note:
- the current `env/python/manifest.toml` explicitly installs the Vulkan loader,
  Vulkan diagnostics tooling, and the Linux userspace graphics libraries needed
  by the resolved NVIDIA vendor path
- this is an interim runtime-closure expression, not the desired long-term
  application manifest shape
- the design target is a higher-level LiteRT-LM Linux GPU runtime environment or
  package that would own:
  - pinned Python and LiteRT-LM
  - the supported native-library closure
  - the `preflight`, `validate`, and `serve` wrapper commands
  - the documented host-driver contract
- until that runtime exists, the explicit manifest entries remain the honest
  and reproducible way to express the current supported Linux GPU boundary
- the intended long-term direction is a composed runtime layout rather than a
  single application env curating all engine-specific native closures directly;
  see the design notes in
  [docs/chat/linux_gpu_runtime_portability_runbook.md](docs/chat/linux_gpu_runtime_portability_runbook.md)
  for:
  - reusable Flox runtime patterns from `llama.cpp`, `vLLM`, `SGLang`,
    `Triton`, `LM Studio`, and `Ollama`
  - the future multi-engine environment layout for this repo
  - the separate Apple-hosted LiteRT-LM environment needed to support the iOS
    deployment path

### 7.7 Verify The Server Log Path

```bash
cd /home/nkse/projects/hybrid-ai
ls -l volumes/logs/python_server.log
```

Expected result:
- the file exists under `volumes/logs`

### 7.8 Verify The Swift Live Integration Path

Run the dedicated live integration test script:

```bash
cd /home/nkse/projects/hybrid-ai
./scripts/env/run_swift_backend_integration_tests.sh
```

Expected result:
- the live Swift integration tests pass against the already-running backend
- the test output includes:
  - `liveBackendPrepareAndConversationLifecycle()`
  - `liveBackendSendAndStreamSemantics()`
  - `liveBackendUnknownConversationSurfacesNotFound()`
- the live send and stream assertions reject assistant payloads that still contain serialized `role` or `content` structures

## 8. Expected Outcomes

When this workflow is correct:
- the server runs from the dedicated Python Flox environment at `env/python`
- the managed venv is rooted at `env/python/.flox/cache/python`
- `litert-lm==0.13.1` is present as a Poetry-managed dependency
- the pinned Gemma model file exists under `volumes/models/litert-lm/gemma4-e4b`
- `/ready` returns `200` with `"ready": true`
- conversation create/send/delete operations succeed through the backend HTTP API
- assistant responses returned by the backend API are normalized plain text
- the Swift backend transport can pass its live integration tests against the running Python server

## 9. Failure Modes And Recovery

### 9.1 `litert_lm` Missing From The Managed Venv

Symptom:
- `ModuleNotFoundError: No module named 'litert_lm'`

Recovery:

```bash
cd /home/nkse/projects/hybrid-ai
FLOX_ENV_DIR=$PWD/env/python FLOX_MANIFEST_PATH=$PWD/env/python/manifest.toml \
./scripts/env/toolchain/nix/flox_with.sh bash -lc 'source scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh; inference_srv_py_activate_env; poetry -C src/inference_srv_py lock; poetry -C src/inference_srv_py sync --no-interaction'
```

Why this happens:
- `litert_lm` is a Python dependency, not a Flox native package
- if it is missing from `src/inference_srv_py/pyproject.toml`, `poetry sync` will not keep
  it installed
- if it was installed out of band, `poetry sync` can remove it because the lock
  file is the source of truth for the managed venv
- if the Flox environment was re-locked (via `flox edit -f`), the Python venv is
  recreated from scratch and `litert_lm` must be reinstalled via Poetry sync

Then rerun:

```bash
./scripts/env/setup_litert_lm.sh
```

### 9.2 Readiness Fails With Missing `libvulkan.so.1`

Symptom:
- `/ready` returns `503`
- issue mentions `libvulkan.so.1`
- this can happen even from an already activated `env/python` shell if the
  realized Flox environment is stale

Recovery:
- resync `env/python` so `vulkan-loader` is included
- verify `ctypes.util.find_library('vulkan')` returns `libvulkan.so.1`
- restart the backend through `scripts/modules/inference_srv_py/server_run.sh`

Why this happens:
- `libvulkan.so.1` is provided by the Flox native environment, not by Poetry
- if `vulkan-loader` is missing from the manifest graph, no amount of Python venv
  activation will provide the shared library
- if `vulkan-loader` is present in the manifest graph but the realized env is
  stale, activation alone will continue to expose the old runtime until the env is
  re-synced

### 9.3 Live GPU `/ready` Fails With `Found 0 adapters` Even Though Validation Passes

Symptom:
- `./scripts/modules/inference_srv_py/gpu_validate.sh` passes
- `inference_srv_py_server_gpu_run.sh` starts
- live `/ready` still returns `503`
- server log contains:
  - `Found 0 adapters`
  - `Failed to initialize WebGPU environment: No adapters found`

Likely cause on this host class:
- the live server process cannot load the NVIDIA vendor library because a transitive X11/XCB dependency is missing inside `env/python`

Observed concrete examples during troubleshooting:
- `libX11.so.6`
- `libXext.so.6`

Recovery:

1. Re-sync `env/python` after updating [env/python/manifest.toml](env/python/manifest.toml)

```bash
cd /home/nkse/projects/hybrid-ai
FLOX_ENV_DIR=$PWD/env/python FLOX_MANIFEST_PATH=$PWD/env/python/manifest.toml \
./scripts/env/toolchain/nix/flox_env_init.sh
```

2. Verify direct library load in the managed runtime

```bash
cd /home/nkse/projects/hybrid-ai
FLOX_ENV_DIR=$PWD/env/python FLOX_MANIFEST_PATH=$PWD/env/python/manifest.toml \
./scripts/env/toolchain/nix/flox_with.sh bash -lc '
source scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh
inference_srv_py_activate_env
python - <<'"'"'PY'"'"'
import ctypes
ctypes.CDLL("/usr/lib/x86_64-linux-gnu/libGLX_nvidia.so.0")
print("libGLX_nvidia.so.0: ok")
PY
'
```

3. Restart the GPU server on a fresh port and recheck `/ready`

Important constraint:
- do not try to fix this by broadening `LD_LIBRARY_PATH`
- the supported repair path is to add the missing userspace runtime libraries to `env/python`

Concrete recovery sequence:

```bash
cd /home/nkse/projects/hybrid-ai
FLOX_ENV_DIR=$PWD/env/python FLOX_MANIFEST_PATH=$PWD/env/python/manifest.toml \
./scripts/env/toolchain/nix/flox_env_init.sh

./scripts/modules/inference_srv_py/run.sh -c "import ctypes.util; print(ctypes.util.find_library('vulkan'))"

HYBRID_AI_HOST=127.0.0.1 HYBRID_AI_PORT=8080 HYBRID_AI_LITERT_BACKEND=cpu \
./scripts/modules/inference_srv_py/server_run.sh
```

### 9.3 Wrong Flox Environment Selected

Symptom:
- Python path resolves into `.flox/cache/python` at the repository root instead of `env/python/.flox/cache/python`

Recovery:
- use the Python wrappers from this document
- avoid assuming a repo-root Flox shell is equivalent to `env/python`
- if you must override the target env explicitly, set:

```bash
HYBRID_AI_PYTHON_FLOX_ENV_DIR=/home/nkse/projects/hybrid-ai/env/python
```

### 9.4 Model Metadata Exists But `.litertlm` File Is Missing

Symptom:
- `/ready` returns `503`
- issue mentions no `.litertlm` model file found

Recovery:
- rerun `scripts/env/setup_gemma4_e4b.sh` with either `HYBRID_AI_LITERT_MODEL_SOURCE` or `HYBRID_AI_LITERT_MODEL_URL`

### 9.5 Nix Daemon Socket Missing

Symptom:
- Flox wrappers fail before Python starts

Recovery:

```bash
sudo /nix/var/nix/profiles/default/bin/nix-daemon
```

## 10. Relationship To Other Docs

Use this document for the concrete Linux inference server setup, startup, and
smoke-test workflow.

Related documents:
- `docs/usecases/02-python-cli-and-server.md`: general Python CLI and Python server development workflow
- `docs/usecases/04-isolation-verification.md`: explicit isolation checks and recovery
- `docs/chat/determinate_nix_flox_setup.md`: operational Nix and Flox runbook
- `docs/design-domain/09-dd-model-bootstrap-and-runtime-pinning.md`: pinned runtime and model bootstrap policy
- `docs/design-domain/14-dd-linux-backend-runtime-and-conversation-lifecycle.md`: lifecycle model for one runtime with many conversations
- `src/swift/Tests/HybridAITests/HybridAIBackendIntegrationTests.swift`: live Swift transport validation against the running backend