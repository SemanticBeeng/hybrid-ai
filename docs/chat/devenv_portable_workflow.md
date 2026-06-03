# hybrid-ai: Portable, Reproducible, Isolated Dev Environment Workflow

Date: 2026-06-02
Scope: Hybrid cloud development for Python CLI/server + Swift mobile modules, with distributed LLM inference (Gemma 4 and multiple engines) via Google LiteRT-LM, built with Flox + Nix composition and strict containment.

## 1. Requirements Analysis and Design Decisions

### 1.1 Hybrid cloud target
Requirement: Support Linux VMs, macOS cloud hardware, and on-demand GPU providers (example: Runpod) with predictable behavior.

Design:
- Use Flox-managed, composable environments as the primary dependency/runtime boundary.
- Keep environment logic in repository files and shell wrappers (not in host machine defaults).
- Split concerns into modules: base tooling, python, swift, inference, orchestration.
- Provide graceful degradation on macOS where Linux-specific Nix store layering primitives are unavailable or constrained.

### 1.2 Modular architecture with Python + Swift + inference engines
Requirement: Python (CLI/server), Swift mobile app, Gemma 4 plus multiple inference engines.

Design:
- Monorepo with explicit module folders under src/python and src/swift.
- Flox composition layers:
  - base: shared system tools, shell policy, git, direnv integration if needed.
  - python: python runtime and packaging workflow.
  - swift: swift toolchain and SwiftPM workflow.
  - inference: Google LiteRT-LM runtime helpers, model path policy, GPU provider wrappers.
  - hybrid-ai: top-level composed environment used by developers and CI.

### 1.3 Flox/Nix best-practice adoption (explicit)
Top applicable practices extracted from the listed resources and adopted here:
- Composition-first environment architecture (from Flox composition docs).
- Layering strategy for shared immutable base + writable project layer (from Flox layering content).
- Hooks and profiles for explicit environment setup and role-based behavior (from hooks/profiles guidance).
- Reproducible dev env workflow integrated with VS Code (from Flox VS Code guidance).
- Python reproducibility through Nix-integrated packaging (poetry2nix workflow family).
- Use Nix + containers together where helpful: Nix/Flox for build reproducibility, containers only for transport/runtime packaging boundaries.
- Determinate Nix setup for reproducible Nix behavior and better operational consistency.
- Agentic development guardrails: wrappers and policy scripts that prevent accidental global installs.

### 1.4 Python via Flox + poetry2nix
Requirement: Python integrated with Flox, poetry2nix.

Design:
- Python module has pyproject.toml + poetry.lock as canonical dependency inputs.
- Nix expression derives reproducible Python environment from lock metadata.
- Flox environment exposes Python executable and tooling from Nix closure.
- Runtime write paths (pip cache, poetry cache, pycache) redirected under build/.

### 1.5 Swift via Flox + swiftpm2nix
Requirement: Swift module via SwiftPM and swiftpm2nix.

Design:
- Swift package defined with Package.swift.
- swiftpm2nix used to materialize reproducible dependency graph.
- Flox swift module provides Swift toolchain and pins build behavior.
- Swift build artifacts redirected to build/swift; no implicit .build folder in source tree.

### 1.6 Explicit dependency and path controls
Requirement: Make all build/runtime paths explicit, justify exceptions.

Design:
- Central env policy script exports all required path variables.
- XDG variables always set to project-local roots.
- PYTHONPATH intentionally not globally forced by default to avoid import ambiguity; only set in module wrappers when required for controlled local package execution.

### 1.7 Isolation and cleanliness constraints
Requirement summary:
- No writes in home directory.
- Strict project-local containment.
- No writes to host root /nix store; use isolated root.
- VS Code/Copilot must honor isolation.
- Resettable upper layer.

Design:
- A single isolated root variable: NIX_ISOLATED_ROOT=/opt/bin/dev/nix.
- All Nix/Flox mutable state redirected under NIX_ISOLATED_ROOT and project directories.
- Wrapper scripts enforce and validate required vars before executing tools.
- Cleanup and reset scripts target upper writable layer only.

## 2. Canonical Folder Inventory (Explicit)

All writable data is constrained to:
- build/
  - build/python/venv
  - build/python/cache/pip
  - build/python/cache/poetry
  - build/python/cache/uv
  - build/python/pycache
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
- .flox/
- nix/
- .vscode/

Repository config and docs:
- env/base/
- env/python/
- env/swift/
- env/inference/
- env/hybrid-ai/
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
  - NIX_CONF_DIR=$NIX_ISOLATED_ROOT/etc/nix
  - NIX_CONFIG=<inline config pointing stores and experimental features>
  - XDG_CONFIG_HOME=$PWD/build/xdg/config
  - XDG_CACHE_HOME=$PWD/build/xdg/cache
  - XDG_DATA_HOME=$PWD/build/xdg/data
  - XDG_STATE_HOME=$PWD/build/xdg/state
  - HOME=$PWD/build/home (only inside controlled wrappers when tools hardcode HOME)
- Python:
  - PYTHON_DIR=$PWD/src/python
  - VIRTUAL_ENV=$PWD/build/python/venv (if venv bridge is needed)
  - PIP_CACHE_DIR=$PWD/build/python/cache/pip
  - POETRY_CACHE_DIR=$PWD/build/python/cache/poetry
  - UV_CACHE_DIR=$PWD/build/python/cache/uv
  - PYTHONPYCACHEPREFIX=$PWD/build/python/pycache
  - PYTHONDONTWRITEBYTECODE=1
  - PIP_DISABLE_PIP_VERSION_CHECK=1
- Swift:
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
- env/python: python runtime, poetry/pip/uv tooling, poetry2nix bridge.
- env/swift: swift toolchain, swift-format, swiftpm2nix bridge.
- env/inference: LiteRT-LM integration, inference helper scripts, model path policy.
- env/hybrid-ai: composed top-level environment importing base + python + swift + inference.

## 4.2 Layering and store isolation
- lower-store: read-only baseline toolchain snapshot.
- upper-cactus: writable project-specific layer (resettable without deleting lower-store).
- local overlay/local root configuration under NIX_ISOLATED_ROOT.

Suggested Nix config (conceptual):
- local-root points into NIX_ISOLATED_ROOT.
- substitute base binaries from trusted cache.
- writable overlay for project-level derivations.

## 4.3 Determinate Nix integration
- Install Determinate Nix for reliable multi-platform Nix bootstrap and configuration consistency.
- Keep all Nix config explicit inside repository scripts and generated nix config under project-controlled paths.

## 5. VS Code Portable + Copilot Isolation Model

Assumption: VS Code is already installed in portable mode.

Policy:
- Launch VS Code through project wrapper that sets XDG and HOME overrides before code starts.
- VS Code server, extension storage, and Copilot extension state are redirected into project-local build/ or .vscode-managed paths where feasible.
- Python extension interpreter path pinned to Flox-provided Python.
- Swift extension tools pinned to Flox-provided Swift binaries.

Verification requirements:
- Confirm VS Code integrated terminal inherits Flox activation variables.
- Confirm Copilot-generated run/debug tasks execute via wrapper scripts, not system Python/Swift.
- Confirm extension installation location and cache directories are not under real user home.

## 6. Execution Scenarios to Validate

### 6.1 Python CLI execution
- Command-line: run through scripts/env/run_python.sh to enforce env vars and flox activation.
- Copilot/VS Code: tasks and debug profiles invoke same wrapper.
- Validation: print sys.executable, cache dirs, pycache prefix; ensure all under build/.

### 6.2 Python server execution
- Launch server via scripts/env/run_py_server.sh.
- Validate logs to volumes/logs and temp/cache under build/ or volumes/cache.

### 6.3 Swift build and test
- Command-line: scripts/env/run_swift.sh build/test with explicit --build-path bound to SWIFT_BUILD_PATH.
- Copilot/VS Code: build tasks call same wrapper.
- Validation: no source-adjacent .build output.

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
3. Add scripts/verify/doctor.sh that fails if disallowed paths are detected.

Deliverables:
- Folder scaffold.
- Policy and validation scripts.

Phase 1: Host prerequisites and bootstrap
1. Install Determinate Nix on Linux and macOS hosts.
2. Install Flox CLI.
3. Create bootstrap script that configures NIX_ISOLATED_ROOT and writes local Nix config for isolated operation.
4. Verify no writes to host root /nix (or apply documented macOS fallback if root restrictions apply).

Deliverables:
- scripts/env/bootstrap_host.sh
- scripts/verify/check_nix_isolation.sh

Phase 2: Flox composition scaffolding
1. Create env/base, env/python, env/swift, env/inference manifests.
2. Create env/hybrid-ai composed manifest.
3. Add activation hooks that export all XDG and module-specific paths.
4. Add profiles for roles: python-dev, swift-dev, inference-dev, fullstack.

Deliverables:
- Environment manifests and hooks.
- Profile selection wrapper.

Phase 3: Python module reproducibility (poetry2nix)
1. Initialize src/python package and pyproject.toml + poetry.lock.
2. Add poetry2nix mapping in nix expressions for locked dependency resolution.
3. Add wrappers: run_python.sh, run_py_server.sh, run_py_tests.sh.
4. Add verification script for Python path/caches/bytecode policy.

Deliverables:
- Python module buildable in Flox.
- Isolation checks passing.

Phase 4: Swift module reproducibility (swiftpm2nix)
1. Initialize src/swift package with Package.swift.
2. Add swiftpm2nix generation and lock procedures.
3. Add wrappers: run_swift.sh, run_swift_tests.sh.
4. Ensure all Swift artifacts route to build/swift.

Deliverables:
- Swift module buildable/testable in Flox.
- No implicit .build folder near sources.

Phase 5: Inference engines and Gemma 4 workflows
1. Add inference profile and wrappers for local and remote providers.
2. Define model/cache/log roots under volumes/.
3. Add script to resolve latest LiteRT-LM release and install module bindings.
4. Add runtime checks ensuring endpoint/provider secrets are explicit and not globally sourced.

Deliverables:
- Unified inference command surface for Gemma 4 and secondary engines.

Phase 6: VS Code portable and Copilot integration
1. Add .vscode/settings.json to pin interpreters/tools to Flox wrappers.
2. Add .vscode/tasks.json and launch profiles using scripts/env wrappers only.
3. Add .vscode/extensions.json with required extension list.
4. Add verification script to print extension and server data paths and assert isolation.

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
- env/base/manifest.toml
- env/python/manifest.toml
- env/swift/manifest.toml
- env/inference/manifest.toml
- env/hybrid-ai/manifest.toml
- nix/python/default.nix
- nix/swift/default.nix
- scripts/env/bootstrap_host.sh
- scripts/env/enter.sh
- scripts/env/run_python.sh
- scripts/env/run_py_server.sh
- scripts/env/run_swift.sh
- scripts/env/run_inference_local.sh
- scripts/env/run_inference_remote.sh
- scripts/env/setup_litert_lm.sh
- scripts/verify/doctor.sh
- scripts/verify/check_env.sh
- scripts/clean/reset_upper_layer.sh
- .vscode/settings.json
- .vscode/tasks.json
- .vscode/extensions.json
- src/python/
- src/swift/

## 9. Practical Verification Checklist

Required pass conditions:
- No writes to real user home during bootstrap, build, run, test, or editor usage.
- No writes to host root /nix by project activities.
- Python and Swift executions resolve to Flox/Nix-managed binaries.
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
- Phase 1 bootstrap scripts and initial Nix isolation checks with host fallback behavior.
- Phase 2 Flox manifest scaffolding and activation hook strategy.
- Partial Phase 3 and Phase 4 module scaffolding (Python and Swift package skeletons + wrappers).
- Partial Phase 6 VS Code and Copilot task/settings integration.
- Partial Phase 8 cleanup/reset scripts.

Verified in this workspace:
- scripts/verify/doctor.sh passes.
- scripts/verify/check_env.sh confirms project-local HOME/XDG/cache paths.
- scripts/env/bootstrap_host.sh writes fallback nix.conf to project path when /opt/bin/dev/nix is not writable.

Pending prerequisites before full execution:
- Ensure root /nix is absent. If present, remove via CONFIRM_REMOVE_ROOT_NIX=YES scripts/env/remove_root_nix.sh.
- Run toolchain installation:
  1. NIX_ISOLATED_ROOT=/opt/bin/dev/nix scripts/env/install_toolchain.sh
  2. NIX_ISOLATED_ROOT=/opt/bin/dev/nix scripts/env/bootstrap_host.sh
  3. NIX_ISOLATED_ROOT=/opt/bin/dev/nix scripts/verify/check_nix_isolation.sh
  4. scripts/verify/doctor.sh
- After installation, run runtime checks:
  1. scripts/env/bootstrap_host.sh
  2. scripts/verify/doctor.sh
  3. scripts/env/with_flox.sh python --version
  4. scripts/env/with_flox.sh swift --version
  5. scripts/env/run_inference_local.sh "healthcheck"

Important note:
- The current env/hybrid-ai/manifest.toml is intentionally conservative and flat for compatibility. If your Flox version supports direct composition/import syntax for module manifests, replace flat install lists with explicit module composition references and keep hooks in module-local manifests.

## 13. LiteRT-LM Latest Release Setup (Python + Swift Bindings)

Use the dedicated setup script to resolve the latest upstream release tag and install Python binding inside the Flox-managed environment:
- scripts/env/setup_litert_lm.sh

Behavior:
- Resolves latest release tag from GitHub API (override with LITERT_LM_TAG when pinning).
- Stores selected tag in build/artifacts/litert-lm.version.
- Installs Python binding into project environment via pip under Flox.

Python module setup (src/python):
1. Run scripts/env/setup_litert_lm.sh.
2. Freeze lock metadata (poetry lock) after verifying compatibility.
3. Re-run scripts/verify/check_env.sh and python smoke tests.

Swift module setup (src/swift):
1. Use the resolved tag in build/artifacts/litert-lm.version.
2. Add LiteRT-LM Swift package dependency in src/swift/Package.swift with exact tag pinning.
3. Run scripts/env/run_swift.sh package resolve and scripts/env/run_swift.sh build.

Release pinning policy:
- Default is latest release for bootstrap.
- For reproducible CI and cross-machine parity, commit an explicit tag pin after validation.

## 14. Root Nix Removal Policy

Project policy forbids root-based /nix installation.

Enforced by:
- scripts/env/bootstrap_host.sh refuses NIX_ISOLATED_ROOT under /nix.
- scripts/verify/check_nix_isolation.sh fails if /nix exists.
- scripts/env/install_nix_determinate.sh blocks root /nix bootstrap.

Cleanup command:
- CONFIRM_REMOVE_ROOT_NIX=YES scripts/env/remove_root_nix.sh

## 15. Current Toolchain Install Procedure (Implemented)

This section captures the exact procedure and behavior currently implemented in scripts.

Step-by-step:
1. Ensure root /nix is absent:
  - CONFIRM_REMOVE_ROOT_NIX=YES scripts/env/remove_root_nix.sh
2. Set isolated non-/nix root:
  - export NIX_ISOLATED_ROOT=/opt/bin/dev/nix
3. Install toolchain:
  - scripts/env/install_toolchain.sh
4. Verify binaries:
  - /opt/bin/dev/nix/bin/nix --version
  - /opt/bin/dev/nix/bin/flox --version
5. Bootstrap and run verification:
  - NIX_ISOLATED_ROOT=/opt/bin/dev/nix scripts/env/bootstrap_host.sh
  - NIX_ISOLATED_ROOT=/opt/bin/dev/nix scripts/verify/check_nix_isolation.sh
  - scripts/verify/doctor.sh

Script behavior details:
- scripts/env/install_nix_determinate.sh:
  - Installs nix-portable into /opt/bin/dev/nix/bin/nix (or path from NIX_ISOLATED_ROOT).
  - Writes nix.conf under $NIX_ISOLATED_ROOT/etc/nix/nix.conf.
  - Refuses any /nix target and fails if /nix exists.
- scripts/env/install_flox.sh:
  - Installs Flox via Nix profile from FLOX_FLAKE_REF (default github:flox/flox/v1.12.2).
  - Creates wrapper at $NIX_ISOLATED_ROOT/bin/flox that executes via $NIX_ISOLATED_ROOT/bin/nix run.
  - Refuses any /nix target.
- scripts/env/install_toolchain.sh:
  - Runs both installer scripts in order and prints resulting binary paths.

Important naming note:
- Despite its filename, scripts/env/install_nix_determinate.sh currently installs nix-portable, not Determinate Nix distribution. Rename or refactor if strict Determinate Nix installer semantics are required.
