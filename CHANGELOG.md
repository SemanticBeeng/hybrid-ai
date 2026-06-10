# Changelog

## 2026-06-09

### Linux GPU inference boundary and diagnostics
- implemented Linux GPU host-contract preflight in `scripts/env/toolchain/inference/linux_gpu_contract.sh` and promoted it as part of the supported GPU rehearsal boundary
- implemented managed Linux GPU validation in `scripts/env/toolchain/inference_srv_py/inference_srv_py_gpu_validate.sh`, including phased checks for Vulkan loader resolution, LiteRT-LM import, backend selection, engine creation, conversation creation, and backend readiness
- implemented `scripts/env/toolchain/inference_srv_py/inference_srv_py_server_gpu_run.sh` as the Linux GPU launcher wrapper for the promoted supported host class
- added GPU runtime snapshot tooling in `scripts/env/toolchain/inference_srv_py/inference_srv_py_gpu_runtime_snapshot.sh` and snapshot diff tooling in `scripts/env/toolchain/inference_srv_py/inference_srv_py_gpu_snapshot_diff.sh`
- added in-process Python debug snapshots in `src/inference_srv_py/inference_srv_py/debug_snapshot.py` and wired them into `src/inference_srv_py/inference_srv_py/server.py` and `src/inference_srv_py/inference_srv_py/backend.py` so the live server process can be compared against the promoted validation path
- tightened `scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh` to deduplicate `PATH` and `LD_LIBRARY_PATH` entries during nested wrapper activation so runtime snapshots are stable and easier to compare

### Linux GPU current status
- Linux GPU is now promoted through `preflight`, `validate`, and live `serve` for the current supported NVIDIA plus Vulkan host class
- the promoted GPU gate is `scripts/env/toolchain/inference_srv_py/inference_srv_py_gpu_validate.sh`
- the promoted Linux GPU serve bridge is a narrow absolute-path vendor-library prewarm in `src/inference_srv_py/inference_srv_py/backend.py`, not broad `LD_LIBRARY_PATH` mutation
- a repo-local end-to-end shell smoke path now verifies `/ready`, `/health`, conversation creation, and message round-trip through `scripts/env/run_inference_local_gpu_smoke.sh`
- the backend now normalizes structured LiteRT response payloads to plain assistant text before returning HTTP JSON responses
- the GPU smoke wrapper now refuses occupied ports and cleans up the whole background server process group so repeated local runs do not silently talk to stale listeners
- after live-process snapshots exposed missing transitive X11/XCB dependencies for `/usr/lib/x86_64-linux-gnu/libGLX_nvidia.so.0`, `env/python/manifest.toml` was extended with the required X11 runtime libraries so the long-lived GPU server process can load the NVIDIA vendor library inside the managed runtime

### Linux GPU re-evaluation outcome
- rejected broad host dynamic-linker mutation through `LD_LIBRARY_PATH` as the normal Linux GPU fix layer because it caused Python instability and violated the intended narrow bridge model
- preserved the existing Python Flox environment at `env/python` as the single Python server runtime boundary rather than introducing a separate GPU runtime environment
- documented the current promotion boundary and Linux GPU lifecycle status in:
	- `docs/usecases/05-inference-server-workflow.md`
	- `docs/chat/linux_gpu_runtime_portability_runbook.md`
	- `docs/design-domain/13-dd-linux-backend-runtime-adapter.md`
	- `docs/design-domain/14-dd-linux-backend-runtime-and-conversation-lifecycle.md`
	- `docs/design-domain/04-dd-backend-transport-and-error-boundary.md`

### Most likely remaining cause
- wrapper-level runtime assembly is no longer the leading suspect; validate and serve-launch snapshots are effectively identical apart from process metadata
- the request-thread investigation showed that live success depends on loading the resolved NVIDIA vendor library by absolute path before LiteRT-LM engine creation in the server process
- the prewarm is now promoted as the supported narrow Linux serve bridge for the current NVIDIA plus Vulkan host class, while remaining explicitly vendor-scoped rather than treated as a generic cross-vendor abstraction

## 2026-06-05

### Toolchain source-boundary cleanup
- clarified the environment design so Flox manifests source narrow concern modules directly while `scripts/env/toolchain/common.sh` remains the full-session compatibility aggregator for external shells and launcher bootstrap
- folded the former Python path/host-venv cleanup concern into `scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh`, making it the single Python source of truth for host virtualenv cleanup, managed venv setup, dependency sync, cache paths, and runtime activation
- made `scripts/env/toolchain/swift/swift_env.sh` source Swift build/cache path setup internally, so manifests and callers no longer need to source `swift_paths.sh` directly
- documented `scripts/env/toolchain/vscode_paths.sh` as the VS Code portable path owner and updated runbooks to reflect that `scripts/env/start_vscode.sh` now activates the managed Python venv and Swiftly toolchain before launching VS Code
- updated use-case docs and setup runbooks to describe the cleaned module boundaries and current Python/Swift/VS Code activation model
- confirmed `scripts/env/start_vscode.sh --check` exits successfully with the cleaned launcher/module-source design
- started the Model A root-attached Flox migration by making `.flox/env/manifest.toml` the canonical fullstack environment while keeping `env/base`, `env/python`, `env/swift`, and `env/inference` as reusable module environments
- updated Flox initialization and wrappers to prefer the root-attached environment and expect root `.flox` cache paths
- removed the legacy fullstack environment now that the root-attached `.flox/env/manifest.toml` owns canonical fullstack activation
- updated runbooks and use cases so current Python cache, venv, activation, and verification examples point at root `.flox/cache` instead of the retired fullstack environment cache
- refreshed runbooks and use cases for the latest root-attached Flox design: `env/base` owns `HOME`/`XDG_*`, module envs include base, wrappers use local `project_root` discovery, and `scripts/env/toolchain/common.sh` is documented as a compatibility aggregator rather than the central environment policy
- moved static activation constants into Flox `[vars]`: base Nix/Flox defaults, Python behavior flags, and Swiftly version/path defaults, leaving shell helpers responsible only for dynamic project paths, `FLOX_ENV_CACHE`-derived paths, host discovery, and runtime probing

### Linux-first Swift mobile UI proof
- added a Linux-only GTK/libadwaita mobile chat proof target, `hybrid-ai-mobile-chat`, with a phone-sized single-column chat UI that imports the shared `HybridAI` module and displays the existing `hybrid-ai swift module ready` status
- added GTK/libadwaita native UI dependencies to the Flox Swift layer instead of Swiftly or the host OS, keeping the ownership split as Swiftly for Swift tools and Flox/Nix for native GUI dependencies
- added `scripts/env/toolchain/swift/swift_ui_run.sh` as the dedicated UI wrapper for GTK/libadwaita builds and runs, separate from the generic `scripts/env/toolchain/swift/swift_run.sh` wrapper
- made the GTK/libadwaita SwiftPM targets opt-in through `HYBRID_AI_ENABLE_GTK_UI=1` so generic Swift build/test workflows do not compile UI C targets or require GTK flags
- confirmed the generic Swift CLI/test workflow remains independent of the UI target while the dedicated UI wrapper can build and launch `hybrid-ai-mobile-chat`

### GTK/libadwaita trials, errors, and fixes
- first UI build failed because SwiftPM did not automatically apply GTK/libadwaita `pkg-config` flags to the C shim target; fixed in `swift_ui_run.sh` by converting `pkg-config --cflags/--libs gtk4 libadwaita-1` into SwiftPM `-Xcc` and `-Xlinker` flags
- hit `Circular swiftly proxy invocation` when C compilation used Swiftly proxy shims for `clang`/`clang++`; fixed `scripts/env/toolchain/swift/swift_env.sh` so `CC` and `CXX` point to the real Swiftly toolchain binaries under the selected Swift `6.3.2` toolchain
- generic `swift test` initially tried to build the GTK UI target and failed on missing GTK headers; fixed by gating the UI target in `Package.swift` behind `HYBRID_AI_ENABLE_GTK_UI=1`
- running the UI binary directly produced a glibc mismatch: host `/lib/x86_64-linux-gnu/libc.so.6` was mixed with Nix/Flox `libresolv.so.2`; fixed the UI wrapper to run the app through a matching Nix glibc dynamic loader with an explicit GTK/Flox/Swiftly runtime library path
- improved Nix loader selection so `swift_ui_run.sh` derives the glibc lib directory from the active Flox GTK/glib runtime closure instead of choosing an arbitrary glibc from `/nix/store`; added `HYBRID_AI_SWIFT_UI_GLIBC_LIB_DIR` as an override escape hatch
- cleared `LD_AUDIT` and `LD_PRELOAD` before launching the UI app to avoid Flox audit/preload libraries being loaded against the wrong glibc runtime
- hit a libadwaita runtime abort, `gtk_window_set_child() is not supported for AdwApplicationWindow`; fixed the C UI shim to use `adw_application_window_set_content()`
- iteratively added transitive GTK/Pango/pkg-config dependencies to the Flox Swift layer (`libsysprof-capture`, `pcre2`, `util-linux`, `libselinux`, `libsepol`, `fribidi`, `libthai`, and `libdatrie`) and taught the UI wrapper to discover missing `.pc` directories from the Nix store when Flox does not expose them directly

### Final GTK/libadwaita conclusion
- final command-line run path is `scripts/env/toolchain/swift/swift_ui_run.sh run hybrid-ai-mobile-chat`
- the app now launches successfully from the command line as a Linux-hosted, mobile-form-factor LLM chatbot proof using GTK/libadwaita
- the original host-glibc/Nix-libresolv mismatch is resolved by enforcing the Nix loader path in the UI wrapper
- the `AdwApplicationWindow` core dump is resolved by using the correct libadwaita content API
- source-adjacent SwiftPM output remains forbidden; `src/swift/.build` is not used by the wrapper-based UI workflow

## 2026-06-04

### Swiftly 6.3.2 migration and workflow verification
- updated the portable dev-environment workflow to reflect the applied setup: Determinate Nix + Flox for environment/Python/native dependencies, and Swiftly for Swift
- documented Swiftly as the active Swift owner under `/opt/bin/dev/swiftly`, with Swift `6.3.2`, SwiftPM `6.3.2`, `clang`, `sourcekit-lsp`, and `lldb` resolved from Swiftly
- removed the old Flox/Nix Swift toolchain assumptions from the workflow doc; Flox no longer owns `swift`, `swiftpm`, `swiftPackages.XCTest`, or `clang`
- verified Flox Python resolves to the managed venv under `.flox/cache/python` and passes package/NumPy smoke checks
- verified Swift build, run, and tests through `scripts/env/toolchain/swift/swift_run.sh` using Swiftly Swift `6.3.2`
- updated and re-verified `docs/usecases/03-swift-build-and-test.md` against the current Swiftly-backed workflow: `swifty_check.sh`, `swift_env_check.sh`, `package resolve`, `build`, `test`, `run hybrid-ai-cli`, native path proof, absence of `src/swift/.build`, and `doctor.sh` all passed
- documented the current Swift resolution split in the Swift use case: Swift-specific tools from Swiftly, Flox/Nix native build-time paths before host OS defaults, and sanitized/unset `LD_LIBRARY_PATH` for Swiftly runtime execution
- added `docs/chat/swift_ui_cross_platform_roadmap.md` to capture the Swift UI roadmap: verified Swiftly baseline, shared Swift core, platform-specific Linux/macOS/iOS UI shells, and next implementation checkpoints
- refined the Swift UI roadmap so the Linux GTK/libadwaita proof targets a mobile-form-factor app shell rather than a conventional desktop UI
- added `scripts/env/toolchain/swift/swift_ui_run.sh` as the dedicated GTK/libadwaita Swift UI wrapper, injecting `pkg-config` flags through SwiftPM `-Xcc` and `-Xlinker` while keeping the generic Swift wrapper product-agnostic
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
- updated `scripts/env/toolchain/nix/flox_env_init.sh` to initialize and sync included module environments before syncing the top-level composed environment
- removed `pipx` from `env/python/manifest.toml` after it blocked Flox realization with failing Nix package tests
- re-synced the managed Flox environments and verified generated activation hooks for the then-current manifest source layout

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
- moved Python environment setup into the Flox manifests via `scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh`, with hooks creating and syncing the managed venv under the Flox environment cache
- added Flox profile activation for the Python venv in both the Python module and fullstack manifests
- removed the host-derived `LD_LIBRARY_PATH` mutation from `scripts/env/toolchain/common.sh` and replaced it with Flox-managed runtime activation from the Python helper
- simplified `scripts/env/toolchain/inference_srv_py/inference_srv_py_run.sh` and `scripts/env/toolchain/inference_srv_py/inference_srv_py_server_run.sh` so they use the active Flox environment directly and only fall back to wrapper activation when needed
- declared `libgcc` in the active composed Flox environment and verified NumPy imports correctly from the managed venv (`6.0` sum proof)
- resolved the earlier wrapper/runtime failure caused by pre-activation host library path pollution

### Detailed Python workflow changes
- added `scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh` as the shared source of truth for creating, syncing, and activating the Flox-managed Python venv plus Python cache paths
- updated `env/python/manifest.toml` so the Python module now declares `python311`, `poetry`, `uv`, and `libgcc`, boots the managed venv from its hook, and activates it from Flox shell profiles
- updated the then-current top-level composed manifest so it also bootstrapped and activated the managed Python venv and explicitly exposed `libgcc` in the active runtime
- updated `scripts/env/toolchain/common.sh` to remove Python-specific cache and venv policy from the shared bootstrap and to stop exporting `LD_LIBRARY_PATH` from host `g++`
- updated `scripts/env/toolchain/nix/flox_with.sh` so no-argument mode enters a native `flox activate` shell instead of forcing `bash --noprofile --norc`
- updated `scripts/env/toolchain/inference_srv_py/inference_srv_py_run.sh` so it activates the managed venv directly when already inside Flox and otherwise activates Flox first, then sources the same Python helper in command mode
- updated `scripts/env/toolchain/inference_srv_py/inference_srv_py_server_run.sh` with the same managed-venv activation pattern used by the Python CLI wrapper
- kept direct shell usage valid through the canonical Flox activation path while preserving wrappers for non-activated shells and tasks
- verified wrapper bootstrap from a clean shell, direct Flox activation with managed venv activation, and NumPy native-extension loading through both paths