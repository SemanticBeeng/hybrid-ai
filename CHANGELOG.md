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
- changed workspace editor settings to resolve `python` and `swift` from the Flox-activated `PATH` instead of pointing extensions at task wrapper scripts
- observed that `scripts/env/start_vscode.sh` can still trigger early VS Code extension/toolchain startup errors, but Python and Swift ultimately resolve correctly for Copilot and the launched editor session once startup settles

### Use-case docs
- added `docs/usecases/README.md` as the landing page for concrete development workflow documents
- added `docs/usecases/vscode-portable-project-env.md` with the full workflow for launching portable VS Code inside the repository environment
- added `docs/usecases/python-cli-and-server.md` for Python CLI and server execution through repository wrappers
- added `docs/usecases/swift-build-and-test.md` for Swift build and test execution through the Flox-managed wrapper path

### Pending Python wrapper issue
- verified that `poetry -C src/python run python -m hybrid_ai.hello_world` works from an already-active Flox shell
- recorded that `scripts/env/run_python.sh` and `scripts/env/with_flox.sh` still hit a pending shell runtime failure (`bash: undefined symbol: rl_completion_rewrite_hook`) that must be resolved so wrapper-based Python commands work again

### Pending shell/runtime investigation
- TODO: continue tracing the wrapper failure with the current evidence chain preserved
- minimal repro is already confirmed: `./scripts/env/with_flox.sh env` fails before Poetry or Python are involved
- current shell resolves `bash` from `env/hybrid-ai/.flox/run/x86_64-linux.hybrid-ai.dev/bin/bash`, which points at `bash-interactive-5.3p9`
- direct `flox activate -d env/hybrid-ai -- ...` currently fails during `hook.on-activate` with host-tool GLIBC mismatches (`dirname` and `mkdir` requiring `GLIBC_2.42`)
- `common.sh` currently exports `LD_LIBRARY_PATH` from the host compiler before Flox activation by resolving `g++ -print-file-name=libstdc++.so.6` to `/usr/lib/gcc/x86_64-linux-gnu/14/../../../x86_64-linux-gnu/libstdc++.so.6`
- current root-cause hypothesis to verify next: pre-activation `LD_LIBRARY_PATH` from host `g++` is poisoning the shell/runtime environment and contributing to the `bash`/`readline` symbol failure