# Changelog

## 2026-06-04

### Swiftly 6.3.2 migration and workflow verification
- updated the portable dev-environment workflow to reflect the applied setup: Determinate Nix + Flox for environment/Python/native dependencies, and Swiftly for Swift
- documented Swiftly as the active Swift owner under `/opt/bin/dev/swiftly`, with Swift `6.3.2`, SwiftPM `6.3.2`, `clang`, `sourcekit-lsp`, and `lldb` resolved from Swiftly
- removed the old Flox/Nix Swift toolchain assumptions from the workflow doc; Flox no longer owns `swift`, `swiftpm`, `swiftPackages.XCTest`, or `clang`
- verified Flox Python still resolves to the managed venv under `env/hybrid-ai/.flox/cache/python` and passes package/NumPy smoke checks
- verified Swift build, run, and tests through `scripts/env/run_swift.sh` using Swiftly Swift `6.3.2`
- updated VS Code workflow documentation to match `scripts/env/start_vscode.sh`, which now activates both the managed Python venv and Swiftly-backed Swift before editor launch
- confirmed `scripts/env/toolchain/doctor.sh` passes after removing forbidden source-adjacent SwiftPM `.build` output

## 2026-06-03

### Cleanup and workflow alignment
- removed the dormant repo-local `nix/` scaffolding because it was not wired into the live Flox-first workflow
- cleaned the workflow documentation so it no longer presents `poetry2nix`, `swiftpm2nix`, or repo-local `nix/` files as current runtime components

### Toolchain consolidation
- moved Nix and Flox setup and verification scripts into `scripts/env/toolchain`
- updated wrappers, manifests, VS Code tasks, and docs to use `scripts/env/toolchain/common.sh`
- fixed `PROJECT_ROOT` resolution in the moved `common.sh`

### Flox environment repair
- updated `scripts/env/toolchain/init_flox_env.sh` to initialize and sync included module environments before syncing the top-level composed environment
- removed `pipx` from `env/python/manifest.toml` after it blocked Flox realization with failing Nix package tests
- re-synced the managed Flox environments and verified the generated activation hook points at `scripts/env/toolchain/common.sh`

### Repository cleanup
- removed the empty `scripts/build` shadow tree because the canonical writable tree is `build/`
- kept `env/*/.flox` as managed runtime state and `env/*/manifest.toml` as the declarative source of truth

### VS Code workflow
- added `scripts/env/start_vscode.sh` to launch portable VS Code through the composed Flox environment while preserving the portable user-data root
- added a `vscode:print-env` task and documented the editor startup and verification flow
- changed workspace editor settings to resolve `python` and `swift` from the Flox-activated `PATH` instead of pointing extensions at task wrapper scripts
- observed that `scripts/env/start_vscode.sh` can still trigger early VS Code extension/toolchain startup errors, but Python and Swift ultimately resolve correctly for Copilot and the launched editor session once startup settles

### Use-case docs
- added `docs/usecases/README.md` as the landing page for concrete development workflow documents
- added `docs/usecases/01-vscode-portable-project-env.md` with the full workflow for launching portable VS Code inside the repository environment
- added `docs/usecases/02-python-cli-and-server.md` for Python CLI and server execution through repository wrappers
- added `docs/usecases/03-swift-build-and-test.md` for Swift build and test execution through the Flox-managed wrapper path

### Python Flox alignment
- moved Python environment setup into the Flox manifests via `scripts/env/toolchain/python_env.sh`, with hooks creating and syncing the managed venv under `env/hybrid-ai/.flox/cache/python`
- added Flox profile activation for the Python venv in both `env/python/manifest.toml` and `env/hybrid-ai/manifest.toml`
- removed the host-derived `LD_LIBRARY_PATH` mutation from `scripts/env/toolchain/common.sh` and replaced it with Flox-managed runtime activation from the Python helper
- simplified `scripts/env/run_python.sh` and `scripts/env/run_py_server.sh` so they use the active Flox environment directly and only fall back to wrapper activation when needed
- declared `libgcc` in the active composed Flox environment and verified NumPy imports correctly from the managed venv (`6.0` sum proof)
- resolved the earlier wrapper/runtime failure caused by pre-activation host library path pollution

### Detailed Python workflow changes
- added `scripts/env/toolchain/python_env.sh` as the shared source of truth for creating, syncing, and activating the Flox-managed Python venv plus Python cache paths
- updated `env/python/manifest.toml` so the Python module now declares `python311`, `poetry`, `uv`, and `libgcc`, boots the managed venv from its hook, and activates it from Flox shell profiles
- updated `env/hybrid-ai/manifest.toml` so the top-level composed environment also bootstraps and activates the managed Python venv and explicitly exposes `libgcc` in the active runtime
- updated `scripts/env/toolchain/common.sh` to remove Python-specific cache and venv policy from the shared bootstrap and to stop exporting `LD_LIBRARY_PATH` from host `g++`
- updated `scripts/env/with_flox.sh` so no-argument mode enters a native `flox activate` shell instead of forcing `bash --noprofile --norc`
- updated `scripts/env/run_python.sh` so it activates the managed venv directly when already inside Flox and otherwise activates Flox first, then sources the same Python helper in command mode
- updated `scripts/env/run_py_server.sh` with the same managed-venv activation pattern used by the Python CLI wrapper
- kept direct shell usage valid by making `flox activate -d env/hybrid-ai` the canonical Python shell entry point while preserving wrappers for non-activated shells and tasks
- verified wrapper bootstrap from a clean shell, direct Flox activation with managed venv activation, and NumPy native-extension loading through both paths