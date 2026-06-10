# hybrid-ai: Portable, Reproducible, Isolated Dev Environment Workflow

Date: 2026-06-04
Scope: Hybrid cloud development for Python CLI/server + Swift mobile modules, with distributed LLM inference (Gemma 4 and multiple engines) via Google LiteRT-LM, built with Determinate Nix + Flox composition, Swiftly-managed Swift, and strict containment.

## 1. Requirements Analysis and Design Decisions

### 1.1 Hybrid cloud target
Requirement: Support Linux VMs, macOS cloud hardware, and on-demand GPU providers (example: Runpod) with predictable behavior.

Design:
- Use Flox-managed, composable environments as the primary dependency/runtime boundary.
- Keep environment logic in repository files and shell wrappers (not in host machine defaults).
- Split concerns into modules: base tooling, python, Swiftly-backed Swift activation, inference, orchestration.
- Keep Flox manifest hooks narrow: module manifests source only the concern modules they need. `scripts/env/toolchain/common.sh` remains a compatibility aggregator for broad external-shell/launcher setup, not the central policy file.
- Provide graceful degradation on macOS where Linux-specific Nix store layering primitives are unavailable or constrained.

### 1.2 Modular architecture with Python + Swift + inference engines
Requirement: Python (CLI/server), Swift mobile app, Gemma 4 plus multiple inference engines.

Design:
- Monorepo with explicit module folders under src/inference_srv_py and src/swift.
- Flox composition layers:
  - base: shared system tools, shell policy, git, direnv integration if needed.
  - python: python runtime and packaging workflow.
  - swift: native Swift support tools plus Swiftly activation for SwiftPM workflows.
  - inference: Google LiteRT-LM runtime helpers, model path policy, GPU provider wrappers.
  - root `.flox`: top-level composed environment used by developers and CI.

### 1.3 Flox/Nix best-practice adoption (explicit)
Top applicable practices extracted from the listed resources and adopted here:
- Composition-first environment architecture (from Flox composition docs).
- Layering strategy for shared immutable base + writable project layer (from Flox layering content).
- Hooks and profiles for explicit environment setup and role-based behavior (from hooks/profiles guidance).
- Reproducible dev env workflow integrated with VS Code (from Flox VS Code guidance).
- Python reproducibility through lockfile-driven packaging, with Nix-integrated packaging kept as a deferred option rather than part of the current live workflow.
- Use Nix + containers together where helpful: Nix/Flox for build reproducibility, containers only for transport/runtime packaging boundaries.
- Determinate Nix setup for reproducible Nix behavior and better operational consistency.
- Agentic development guardrails: wrappers and policy scripts that prevent accidental global installs.

### 1.4 Python via Flox
Requirement: Python integrated with Flox, with room for stricter Nix packaging later if needed.

Design:
- Python module has pyproject.toml + poetry.lock as canonical dependency inputs.
- Flox environment exposes Python executable and packaging tooling for repository workflows.
- The canonical Python runtime is a Flox-managed venv under `.flox/cache/python`, created and synced by hook logic in `scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh`.
- `scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh` also owns host virtualenv cleanup and Python cache path policy, so Python activation has one source of truth.
- Interactive shell use is expected to start with `flox activate` from the repository root; wrapper-based CLI/server use activates the same managed venv explicitly when the shell is not already activated.
- If CI or release packaging later needs a Nix-built Python artifact, that should be added as a separate explicit path rather than assumed by the default developer workflow.
- Python package caches and bytecode are redirected under `.flox/cache/`.

### 1.5 Swift via Swiftly, activated through Flox
Requirement: Swift module via SwiftPM using Swift 6.3.2 while retaining Flox as the repository environment boundary.

Design:
- Swift package defined with Package.swift.
- Swiftly owns the active Swift toolchain under `/opt/bin/dev/swiftly`.
- `scripts/env/toolchain/swift/swift_env.sh` activates Swiftly, validates Swift `6.3.2`, and sources the Swift build/cache path module inside Flox-launched shells and wrappers.
- Flox `env/swift` no longer installs Nix `swift`, `swiftpm`, or `swiftPackages.XCTest`; it only carries native support dependencies such as `cmake`.
- If reproducible Nix packaging for Swift becomes necessary later, introduce it as an explicit follow-on track, not as dormant scaffolding or a default developer path.
- Swift build artifacts redirected to `build/swift`; source-adjacent `.build` directories are ignored and treated as cleanup targets.

### 1.6 Explicit dependency and path controls
Requirement: Make all build/runtime paths explicit, justify exceptions.

Design:
- There is no central manifest policy script. Flox modules source narrow concern helpers directly.
- `env/base/manifest.toml` owns project-local `HOME`/`XDG_*` setup by sourcing `scripts/env/toolchain/xdg_env.sh`; `env/python` and `env/swift` include `env/base`.
- Flox `[vars]` own static constants: base Nix/Flox defaults, Python behavior flags, and Swiftly version/path defaults. Shell helpers keep dynamic values that depend on checkout location, `FLOX_ENV_CACHE`, host account discovery, or runtime probing.
- PYTHONPATH intentionally not globally forced by default to avoid import ambiguity; only set in module wrappers when required for controlled local package execution.

### 1.7 Isolation and cleanliness constraints
Requirement summary:
- No writes in home directory.
- Strict project-local containment.
- No persistent Nix store data on the host root partition.
- VS Code/Copilot must honor isolation.
- Resettable upper layer.

Design:
- A single isolated root variable: NIX_ISOLATED_ROOT=/opt/bin/dev/nix.
- Determinate Nix keeps `/nix` as the logical store path, but `/nix` is only a bind-mounted mountpoint backed by `$NIX_ISOLATED_ROOT`.
- Persistent Nix/Flox state lives under `$NIX_ISOLATED_ROOT`; the root filesystem may contain `/nix` only as an empty mountpoint plus mount metadata.
- Wrapper scripts enforce and validate required vars before executing tools.
- Cleanup and reset scripts target upper writable layer only.

## 2. Canonical Folder Inventory (Explicit)

All writable data is constrained to:
- build/
  - build/swift
  - build/artifacts
- volumes/
  - volumes/models
  - volumes/db
  - volumes/logs
  - volumes/cache
- deps/
  - deps/libs (symlink targets)
  - deps/models (symlink targets)
- .flox/ (root managed local Flox state; source manifest tracked, generated state ignored by Git)
  - .flox/cache/python
  - .flox/cache/pip-cache
  - .flox/cache/poetry-cache
  - .flox/cache/uv-cache
  - .flox/cache/pycache
- env/*/.flox/ (module-local managed Flox state; ignored by Git when modules are activated directly)
- .vscode/

Repository config and docs:
- env/base/
- env/python/
- env/swift/
- env/inference-litert-base/
- env/inference-litert-linux-gpu/
- .flox/env/manifest.toml
- .flox/env.json
- scripts/env/
- scripts/verify/
- scripts/clean/
- docs/chat/

Forbidden write locations:
- Home directory for any project process.
- Implicit build directories adjacent to sources (example: src/.build, __pycache__ in source tree).

## 3. Environment Variable Enforcement Matrix

Mandatory exports in Flox activation hooks and wrapper scripts:
- Core isolation:
  - NIX_ISOLATED_ROOT=/opt/bin/dev/nix
  - NIX_CONF_DIR=/etc/nix
  - XDG_CONFIG_HOME=$PWD/build/xdg/config
  - XDG_CACHE_HOME=$PWD/build/xdg/cache
  - XDG_DATA_HOME=$PWD/build/xdg/data
  - XDG_STATE_HOME=$PWD/build/xdg/state
  - HOME=$PWD/build/home (only inside controlled wrappers when tools hardcode HOME)
- Python:
  - PYTHON_DIR=$PWD/src/inference_srv_py
  - VIRTUAL_ENV=$PWD/.flox/cache/python
  - PIP_CACHE_DIR=$PWD/.flox/cache/pip-cache
  - POETRY_CACHE_DIR=$PWD/.flox/cache/poetry-cache
  - UV_CACHE_DIR=$PWD/.flox/cache/uv-cache
  - PYTHONPYCACHEPREFIX=$PWD/.flox/cache/pycache
  - PYTHONDONTWRITEBYTECODE=1
  - PIP_DISABLE_PIP_VERSION_CHECK=1
- Swift:
  - SWIFTLY_ROOT=/opt/bin/dev/swiftly
  - SWIFTLY_HOME_DIR=/opt/bin/dev/swiftly/home
  - SWIFTLY_BIN_DIR=/opt/bin/dev/swiftly/bin
  - HYBRID_AI_SWIFT_VERSION=6.3.2
  - HYBRID_AI_SWIFT_DIR=$PWD/src/swift
  - SWIFT_BUILD_PATH=$PWD/build/swift
  - CLANG_MODULE_CACHE_PATH=$PWD/build/swift/clang-module-cache
  - SWIFTPM_PACKAGECACHE=$PWD/build/swift/package-cache
- Inference:
  - CACTUS_MODEL_PATH=$PWD/volumes/models/cactus
  - LITERT_LM_MODELS=$PWD/volumes/models/litert-lm
  - HF_HOME=$PWD/volumes/cache/huggingface
  - TRANSFORMERS_CACHE=$PWD/volumes/cache/transformers

Documented exceptions:
- PYTHONPATH left unset globally. Rationale: global PYTHONPATH causes unpredictable import precedence across modules and hides packaging defects. Set it only in narrowly scoped execution wrappers when local editable package behavior is explicitly required.

## 4. Flox and Nix Architecture

## 4.1 Composition model
- env/base: shell, git, jq, yq, just, task runner, baseline utility tools, common hooks.
- env/python: python runtime, poetry/pip/uv tooling.
- env/swift: Swift support layer that activates Swiftly and carries native helper dependencies; it does not install Nix Swift packages.
- env/inference-litert-base: reusable LiteRT inference layer on top of env/base.
- env/inference-litert-linux-gpu: Linux GPU LiteRT-LM runtime composing env/python with Vulkan loader and tools.
- .flox/env/manifest.toml: root-attached composed top-level environment importing base + python + swift.

Relationship to source modules:
- env/python supports the Python source module under `src/inference_srv_py`.
- env/swift supports the Swift source module under `src/swift` by sourcing the Swiftly activation helper.
- env/inference-litert-linux-gpu supports the Linux GPU inference server workflow.
- env/base provides shared tooling and activation policy used across all source modules.
- the root `.flox` environment is the top-level developer environment used when working across the whole repository.

## 4.2 Layering and store isolation
- lower-store: read-only baseline toolchain snapshot.
- upper-cactus: writable project-specific layer (resettable without deleting lower-store).
- local overlay/local root configuration under NIX_ISOLATED_ROOT.
- logical Nix mountpoint at `/nix`, physically backed by `$NIX_ISOLATED_ROOT` via bind mount.

Suggested Nix config (conceptual):
- local-root and backing data live under `$NIX_ISOLATED_ROOT`.
- logical store remains `/nix/store` for compatibility with Determinate Nix, default substituters, and Flox.
- substitute base binaries from trusted cache.
- writable overlay for project-level derivations.

## 4.3 Determinate Nix integration
- Install Determinate Nix for reliable multi-platform Nix bootstrap and configuration consistency.
- On Linux without systemd, use the dedicated Determinate Nix and Flox runbook in `docs/chat/determinate_nix_flox_setup.md`.
- Keep all Nix config explicit inside repository scripts and generated nix config under project-controlled paths.

## 4.4 Chroot Store Policy
- Do not use a Nix chroot store as the primary host workflow for this repository.
- Reasoning:
  - Determinate Nix installer, Flox, and default binary caches assume the logical store is `/nix/store`.
  - Chroot stores keep the logical store at `/nix/store` but require namespace and chroot execution semantics, which adds operational complexity for shells, editors, wrappers, and uninstall flows.
  - Changing the logical store away from `/nix/store` is explicitly not recommended by Nix documentation because it breaks compatibility with standard substituters.
- Acceptable use:
  - Disposable experiments, CI-only sandboxes, or narrow build-isolation tests where the entire workflow is intentionally launched through `nix --store <chroot-root>`.
- Repository policy:
  - The canonical developer workflow uses a bind-mounted `/nix` backed by `/opt/bin/dev/nix`, not a chroot store.

## 5. VS Code Portable + Copilot Isolation Model

Assumption: VS Code is already installed in portable mode.

Policy:
- Launch VS Code through `scripts/env/start_vscode.sh`, which activates the composed Flox environment before the editor process starts.
- The launcher keeps the editor, extension host, Copilot, and language tools on the project Python venv and Swiftly-backed Swift toolchain while forcing the portable user-data and extensions directories.
- Portable user-data defaults to `$HOST_HOME/appdata/.vscode/data`, with the settings file at `$HOST_HOME/appdata/.vscode/data/User/settings.json`.
- Python extension interpreter path resolves to `python` from the managed Flox venv activated by `scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh`.
- Swift extension tools resolve to `swift` from `/opt/bin/dev/swiftly/bin` after `scripts/env/toolchain/swift/swift_env.sh` activates Swiftly.
- The VS Code launcher uses `scripts/env/toolchain/common.sh` only as a compatibility/helper aggregator, sources `scripts/env/toolchain/vscode_paths.sh` for portable editor paths, and then sources `inference_srv_py_env.sh` plus `swift_env.sh` inside the activated root Flox launch shell before starting the editor.

Verification requirements:
- Confirm `scripts/env/start_vscode.sh --print-env` reports the managed Flox venv `python`, Swiftly `swift`, SwiftPM `6.3.2`, Swiftly `clang`, `sourcekit-lsp`, and `lldb`.
- Confirm VS Code integrated terminal inherits Flox activation variables.
- Confirm Copilot-generated run/debug tasks execute via wrapper scripts, not system Python/Swift.
- Confirm the portable user-data and extensions directories resolve to the configured portable root.

## 6. Execution Scenarios to Validate

### 6.1 Python CLI execution
- Command-line: run through `scripts/modules/inference_srv_py/run.sh` to bootstrap the managed Flox venv when starting from a non-activated shell.
- Activated shell: `flox activate`, then run Python directly from `src/inference_srv_py`.
- Copilot/VS Code: tasks should continue to invoke the repository wrapper for authoritative CLI/runtime behavior.
- Validation: run `scripts/modules/inference_srv_py/env_check.sh`, then print `sys.executable`, cache dirs, and run a NumPy import proof; ensure the interpreter and caches resolve under `.flox/cache/`.

### 6.2 Python server execution
- Launch server via scripts/modules/inference_srv_py/server_run.sh.
- Validate logs to volumes/logs and temp/cache under build/ or volumes/cache.

### 6.3 Swift build and test
- Command-line: scripts/modules/swift/run.sh build/run/test with explicit --build-path bound to SWIFT_BUILD_PATH.
- Copilot/VS Code: build tasks call same wrapper.
- Validation: run `scripts/modules/swift/env_check.sh`, confirm Swiftly Swift `6.3.2`, run `scripts/modules/swift/run.sh build`, `scripts/modules/swift/run.sh run hybrid-ai-cli`, and `scripts/modules/swift/run.sh test`, then ensure no unintended source-adjacent build output is relied on.

### 6.4 Inference workflow (Gemma 4 + multi-engine)
- Local Linux VM: run LiteRT-LM using LITERT_LM_MODELS under volumes/models/litert-lm.
- Remote GPU provider wrapper: scripts/env/run_inference_remote.sh with explicit endpoint tokens loaded from project-local secret mechanism.
- Validation: model downloads and cache writes occur only under volumes/.

### 6.5 Cross-machine switch
- Clone repo on machine B.
- Restore or mount lower-store cache if available.
- Run bootstrap and doctor scripts.
- Compare env fingerprint output to ensure equivalent toolchain/version closure.

## 7. Phased Implementation Plan

Phase 0: Foundation and policy
1. Create directory skeleton and placeholder files for all canonical writable paths.
2. Add isolation policy doc and denylist checks.
3. Add scripts/env/toolchain/doctor.sh that fails if disallowed paths are detected.

Deliverables:
- Folder scaffold.
- Policy and validation scripts.

Phase 1: Host prerequisites and bootstrap
1. Install Determinate Nix on Linux and macOS hosts.
2. Install Flox CLI.
3. Create bootstrap script that prepares `/opt/bin/dev/nix`, mounts it onto `/nix`, and writes local Nix config for isolated operation.
4. Verify the root filesystem contains no persistent Nix payload outside the `/nix` mountpoint and related minimal config files.

Deliverables:
- scripts/env/toolchain/nix/host_bootstrap.sh
- scripts/env/toolchain/nix/nix_isolation_check.sh

Phase 2: Flox composition scaffolding
1. Create env/base, env/python, env/swift manifests.
2. Create the root `.flox/env/manifest.toml` composed manifest.
3. Add activation hooks that export all XDG and module-specific paths.
4. Keep environment labels out of manifests unless a script consumes them; activation hooks should only set functional runtime state.

Deliverables:
- Environment manifests and hooks.
- Profile selection wrapper.

Phase 3: Python module reproducibility
1. Initialize src/inference_srv_py package and pyproject.toml + poetry.lock.
2. Keep the Flox-managed runtime aligned with locked Python dependencies.
3. Add wrappers: inference_srv_py_run.sh, inference_srv_py_server_run.sh, run_py_tests.sh.
4. Add verification script for Python path/caches/bytecode policy.

Deliverables:
- Python module buildable in Flox.
- Isolation checks passing.

Phase 4: Swift module reproducibility
1. Initialize src/swift package with Package.swift.
2. Keep SwiftPM inputs and build behavior explicit under the Swiftly-managed Swift `6.3.2` toolchain activated by Flox wrappers.
3. Add wrappers: swift_run.sh, run_swift_tests.sh.
4. Ensure all Swift artifacts route to build/swift.

Deliverables:
- Swift module buildable/testable through Flox activation with Swiftly Swift.
- No required implicit `.build` folder near sources; wrapper builds use `build/swift`.

Phase 5: Inference engines and Gemma 4 workflows
1. Add inference profile and wrappers for local and remote providers.
2. Define model/cache/log roots under volumes/.
3. Add script to pin and install the selected LiteRT-LM release and module bindings.
4. Add runtime checks ensuring endpoint/provider secrets are explicit and not globally sourced.

Deliverables:
- Unified inference command surface for Gemma 4 and secondary engines.

Phase 6: VS Code portable and Copilot integration
1. Add `scripts/env/start_vscode.sh` to launch the editor inside the Flox environment while preserving the portable VS Code data root.
2. Add .vscode/settings.json to resolve interpreters/tools from the activated editor `PATH`.
3. Add .vscode/tasks.json and launch profiles using scripts/env wrappers only.
4. Add .vscode/extensions.json with required extension list.
5. Add verification command to print extension and user-data paths and confirm the active Python and Swift toolchain.

Deliverables:
- Editor actions and terminal actions produce identical isolated execution.

Phase 7: Cross-machine portability and atomic switching
1. Add machine bootstrap matrix docs for Linux VM A/B, macOS cloud host, GPU node.
2. Add scripts for environment fingerprinting and compatibility checks.
3. Define Git workflow: branch + manifest changes + lock updates + validation gates.
4. Add atomic switch script: pull + flox activate + doctor + smoke tests.

Deliverables:
- Seamless handoff workflow across machines.

Phase 8: Resetability and lifecycle hygiene
1. Add scripts/clean/reset_upper_layer.sh to clear writable layer only.
2. Add scripts/clean/prune_caches.sh with selective retention for models.
3. Add scheduled cleanup guidance and CI lint checks for pollution.

Deliverables:
- Predictable cleanup and quick recovery path.

Phase 9: Compliance verification and signoff
1. Run full isolation audit script.
2. Run reproducibility tests across Linux and macOS.
3. Record known limitations and graceful degradation behavior.
4. Publish readiness checklist.

Deliverables:
- Signed checklist and operational runbook.

## 8. Initial File and Configuration Blueprint

Recommended immediate scaffold:
- docs/chat/devenv_portable_workflow.md
- docs/chat/determinate_nix_flox_setup.md
- env/base/manifest.toml
- env/python/manifest.toml
- env/swift/manifest.toml
- env/inference-litert-base/manifest.toml
- env/inference-litert-linux-gpu/manifest.toml
- .flox/env/manifest.toml
- .flox/env.json
- scripts/env/toolchain/nix/host_bootstrap.sh
- scripts/env/toolchain/nix/flox_enter.sh
- scripts/env/start_vscode.sh
- scripts/modules/inference_srv_py/run.sh
- scripts/modules/inference_srv_py/server_run.sh
- scripts/modules/swift/run.sh
- scripts/env/run_inference_local.sh
- scripts/env/run_inference_remote.sh
- scripts/env/toolchain/nix/nix_fstab_manage.sh
- scripts/env/toolchain/nix/determinate_cycle_test.sh
- scripts/env/setup_litert_lm.sh
- scripts/env/toolchain/doctor.sh
- scripts/env/toolchain/check_env.sh
- scripts/clean/reset_upper_layer.sh
- .vscode/settings.json
- .vscode/tasks.json
- .vscode/extensions.json
- src/inference_srv_py/
- src/swift/

## 9. Practical Verification Checklist

Required pass conditions:
- No writes to real user home during bootstrap, build, run, test, or editor usage.
- No persistent Nix store data on the host root partition; `/nix` must be a bind mount backed by `/opt/bin/dev/nix`.
- Python execution resolves to the Flox-managed venv under `.flox/cache/python`.
- Swift execution resolves to Swiftly under `/opt/bin/dev/swiftly/bin`.
- Copilot-generated run/debug actions execute via wrappers and inherit explicit vars.
- All caches, build products, logs, model files remain in build/ or volumes/.
- Reset script removes upper writable layer while preserving reusable base assets.

## 10. Risks and Mitigations

Risk: Some macOS tooling may still attempt writes under user Library paths.
Mitigation: Wrap process launch with HOME/XDG overrides and verify with doctor script; document residual exceptions explicitly.

Risk: Third-party inference tooling ignores model cache vars.
Mitigation: Route execution through wrappers and set tool-specific vars; add runtime assertions and fail fast.

Risk: VS Code extension internals may not fully honor custom paths.
Mitigation: Use portable mode plus explicit data-dir/extensions-dir launch flags where applicable; audit after extension updates.

## 11. Next Implementation Step (Recommended)

Execute Phase 0 through Phase 2 first in one PR:
- establish folder scaffold,
- implement bootstrap + doctor scripts,
- create Flox composition manifests and hooks,
- wire minimum VS Code settings/tasks to wrappers.

Then implement Python and Swift modules in separate PRs to keep lockfile and environment diffs reviewable.

## 12. Execution Status (Current Workspace)

Implemented now:
- Phase 0 foundation and policy scaffolding (folders, policy-enforcing wrappers, doctor checks).
- Phase 1 Determinate Nix/Flox bootstrap scripts and isolation checks with manual daemon behavior.
- Phase 2 Flox manifest scaffolding and activation hook strategy.
- Phase 3 Python module workflow through the Flox-managed venv.
- Phase 4 Swift module workflow through Swiftly-managed Swift `6.3.2` activated by Flox wrappers.
- Phase 6 VS Code and Copilot task/settings integration through `scripts/env/start_vscode.sh`.
- Partial Phase 8 cleanup/reset scripts.

Verified in this workspace:
- `scripts/env/toolchain/check_env.sh` confirms project-local HOME/XDG/cache paths and the active daemon socket.
- `scripts/modules/inference_srv_py/env_check.sh` confirms Python resolves to `.flox/cache/python/bin/python`.
- Python smoke tests pass: `python -c 'import inference_srv_py; print(inference_srv_py.hello())'` prints `inference-srv-py ready`, and NumPy demo payload validates `dot == 8.5` and `outer_shape == [4, 4]`.
- `scripts/modules/swift/env_check.sh` confirms Swiftly paths:
  - `swift_bin=/opt/bin/dev/swiftly/bin/swift`
  - `clang_bin=/opt/bin/dev/swiftly/bin/clang`
  - `sourcekit_lsp_bin=/opt/bin/dev/swiftly/bin/sourcekit-lsp`
  - `lldb_bin=/opt/bin/dev/swiftly/bin/lldb`
  - `Swift version 6.3.2 (swift-6.3.2-RELEASE)`
- `scripts/modules/swift/run.sh build`, `scripts/modules/swift/run.sh run hybrid-ai-cli`, and `scripts/modules/swift/run.sh test` all pass.
- Swift tests use Swift 6 built-in `Testing`, not manual Linux `XCTest` manifests.
- Flox no longer installs Nix `swift`, `swiftpm`, `XCTest`, or `clang`; `env/swift` currently resolves only `cmake`.
- `flake.nix` and `flake.lock` have been removed from the canonical workflow.
- Determinate Nix and Flox setup details are tracked in `docs/chat/determinate_nix_flox_setup.md`.
- `scripts/env/start_vscode.sh --print-env` reports the portable user-data root plus managed Flox Python and Swiftly Swift `6.3.2` for editor launch.

Pending prerequisites before full execution:
- On a fresh host, follow the runbooks in `docs/chat/determinate_nix_flox_setup.md` and `docs/chat/swiftly_632_migration_runbook.md` for Determinate Nix, Flox, Swiftly, bind-mount persistence, and verification.

Important note:
- The current `.flox/env/manifest.toml` composes the module manifests via Flox `[include]`. Keep project-specific overrides in the root top-level manifest and keep shared toolchain logic in the module-local manifests.
- Flox manifest hooks source narrow concern modules directly instead of sourcing `scripts/env/toolchain/common.sh`; `common.sh` is a compatibility aggregator for broad external-shell/launcher setup, not the central environment policy.
- `env/base/manifest.toml` is the single owner of `xdg_env.sh`; module manifests include `env/base` rather than duplicating `HOME`/`XDG_*` setup.
- Static activation values now live in Flox `[vars]`: base sets Nix/Flox daemon defaults, Python sets packaging/runtime flags, and Swift sets Swiftly constants. Scripts retain fallbacks only for host-side setup or execution outside an activated Flox shell.
- The repository no longer carries dormant repo-local `nix/` scaffolding; the live workflow is driven by `env/*/manifest.toml`, repository wrappers, and the host-level Determinate Nix install documented in the runbook.
- The Python workflow now relies on `scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh` as the single source of truth for host virtualenv cleanup, managed-venv creation, dependency sync, cache paths, and venv activation.
- The Swift workflow now relies on `scripts/env/toolchain/swift/swift_env.sh` and `scripts/env/toolchain/swift/swiftly_common.sh` as the source of truth for Swiftly activation, Swift `6.3.2` validation, and Swift build paths; `swift_env.sh` sources Swift path setup internally.

## 13. Application Runtime Reference

LiteRT-LM runtime pinning, Gemma 4 E4B model pinning, and application-facing setup scripts are documented in:

- [[09-dd-model-bootstrap-and-runtime-pinning]]
- [[litert_lm_gemma4_swift_runbook]]

This portable workflow document intentionally does not own application runtime bootstrap policy.

## 14. Host Setup Reference

The full Determinate Nix and Flox host setup procedure, persistence helpers, cleanup workflow, and session learnings are documented in:

- `docs/chat/determinate_nix_flox_setup.md`

This portable workflow document intentionally stays focused on architecture, repository structure, isolation boundaries, and module-level design.

### 14.1 Manual-Daemon Multi-User Host Model

This repository now runs on a daemon-capable multi-user Determinate Nix install where `/nix` stays bind-mounted from `/opt/bin/dev/nix`, but daemon startup is left to the operator instead of being handled by a service manager.

Current canonical state:
- Determinate Nix installed in daemon-capable mode with `--no-start-daemon`
- logical store path remains `/nix`, physically backed by `/opt/bin/dev/nix`
- the host Determinate Nix runtime is expected to expose `/nix/var/nix/daemon-socket/socket`
- normal-user wrappers source `nix-daemon.sh` and use `NIX_REMOTE=daemon`
- if the socket is absent, start the daemon manually with `sudo /nix/var/nix/profiles/default/bin/nix-daemon`; project scripts do not start host services automatically
- `scripts/env/toolchain/nix/flox_with.sh`, `scripts/env/toolchain/nix/flox_enter.sh`, and `scripts/env/toolchain/nix/flox_env_init.sh` run as the normal user once the daemon is available

Migration record for this workspace:

1. The `/nix -> /opt/bin/dev/nix` bind mount was preserved unchanged.
2. Pre-migration state was captured in `build/artifacts/manual-daemon-migration-preflight.txt`.
3. The old daemonless `install linux --init none` install was uninstalled while the bind mount remained active.
4. Determinate Nix was reinstalled with `--no-start-daemon`, restoring `/nix/nix-installer`, `/nix/receipt.json`, and the default multi-user profile layout.
5. Flox was reinstalled and the convenience wrappers under `/opt/bin/dev/nix/bin` were restored.
6. The user-facing wrappers were switched to daemon mode and validated as a normal user.

Current operating sequence:

1. Keep the bind mount active.
  - `/nix` remains the logical store root.
  - `/opt/bin/dev/nix` remains the physical backing path.

2. Ensure the host Nix runtime is reachable before using normal-user tooling.
  - Preferred check: confirm `/nix/var/nix/daemon-socket/socket` exists.
  - If it does not exist, start the daemon manually with `sudo /nix/var/nix/profiles/default/bin/nix-daemon`; project scripts do not start host services automatically.

3. Use normal-user wrappers for development.
  - `scripts/env/toolchain/nix/flox_with.sh` sources the daemon profile and activates Flox as the current user.
  - `scripts/env/toolchain/nix/flox_enter.sh` opens a normal-user shell inside the Flox environment.
  - `scripts/env/toolchain/nix/flox_env_init.sh` syncs the managed Flox environment as the normal user and fails fast if stale root-owned state needs repair.

4. Verify the environment after daemon availability is established.
  - `nix --version`
  - `flox --version`
  - `scripts/env/toolchain/nix/flox_with.sh python --version`
  - `scripts/modules/inference_srv_py/env_check.sh`
  - `scripts/modules/swift/env_check.sh`
  - `scripts/env/start_vscode.sh --print-env`
  - confirm VS Code tools resolve Python from the managed Flox venv and Swift from Swiftly without a root shell

Repository implications now in force:
- `scripts/env/toolchain/nix/nix_determinate_install.sh` installs a daemon-capable multi-user layout with `--no-start-daemon`.
- `scripts/env/toolchain/nix/flox_with.sh` prefers user-mode activation with `NIX_REMOTE=daemon` and fails when the daemon socket is absent.
- `scripts/env/toolchain/nix/flox_enter.sh` is a normal-user interactive shell entrypoint.
- `scripts/env/toolchain/nix/flox_env_init.sh` treats user-owned managed Flox state as the normal path and only asks for `sudo chown` when repairing stale ownership.

Operational caveats:
- This is still a daemon-capable multi-user install even though daemon startup is manual.
- If the daemon process exits, normal-user Nix and Flox access stops until the socket is restored.
- Reboots may require an explicit daemon start before editors, shells, or tasks can rely on Nix.
- This remains less robust than a real service-managed daemon and more operationally complex than a single-user non-daemon install.
