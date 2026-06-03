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