# Changelog

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

### Use-case docs
- added `docs/usecases/README.md` as the landing page for concrete development workflow documents
- added `docs/usecases/vscode-portable-project-env.md` with the full workflow for launching portable VS Code inside the repository environment
- added `docs/usecases/python-cli-and-server.md` for Python CLI and server execution through repository wrappers
- added `docs/usecases/swift-build-and-test.md` for Swift build and test execution through the Flox-managed wrapper path