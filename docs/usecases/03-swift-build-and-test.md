# Use Case 03: Swift Build And Test Development Workflow

Date: 2026-06-05
Status: Implemented
Primary scripts: `scripts/env/toolchain/swift/swift_run.sh`, `scripts/env/toolchain/swift/swift_ui_run.sh`

## 1. Goal

Run Swift package build, test, CLI, and Linux GTK/libadwaita UI workflows through
repository wrappers so the Swift toolchain comes from Swiftly while commands
still run inside the Flox project environment. All Swift build artifacts stay
under `build/swift` instead of leaking into the source tree.

## 2. Why This Workflow Exists

SwiftPM defaults are convenient for local experiments, but this repository wants
explicit control over:
- which Swift toolchain is used
- where build outputs are written
- how editor and shell workflows stay aligned

The wrapper ensures that:
- `swift` is resolved from Swiftly via the repository environment activation
- `--build-path` always points at `build/swift` before any `swift run` executable arguments
- CLI usage, VS Code tasks, and Copilot-generated build commands all share the same execution path
- GTK/libadwaita UI builds use a dedicated wrapper so UI-specific native flags and runtime loader handling do not clutter the generic Swift path

## 3. Scope And Assumptions

This workflow assumes:
- Determinate Nix and Flox are working for the repository
- the nix daemon socket exists
- the root `.flox` environment has already been initialized and synced
- Swiftly is installed under `/opt/bin/dev/swiftly`
- `scripts/env/toolchain/swift/swift_env.sh` activates Swiftly and validates Swift `6.3.2`
- GTK/libadwaita development packages are installed through `env/swift/manifest.toml` for the Linux UI proof
- the Swift package exists under `src/swift`

## 4. Files Involved

Runtime wrappers:
- `scripts/env/toolchain/swift/swift_run.sh`
- `scripts/env/toolchain/swift/swift_ui_run.sh`
- `scripts/env/toolchain/nix/flox_with.sh`
- `scripts/env/toolchain/swift/swift_env.sh`
- `scripts/env/toolchain/swift/gtk_ui_runtime.sh`
- `scripts/env/toolchain/swift/swiftly_common.sh`
- `scripts/env/toolchain/swift/swift_env_check.sh`
- `scripts/env/toolchain/swift/swifty_check.sh`

Session support:
- `scripts/env/toolchain/common.sh` can be sourced once by external shells as the full-session compatibility aggregator, but Swift manifests and wrappers use `scripts/env/toolchain/swift/swift_env.sh` as their narrow runtime source of truth.
- `scripts/env/toolchain/swift/swift_env.sh` sources the Swift path/cache module internally, so callers do not need to source `swift_paths.sh` directly.

Swift package files:
- `src/swift/Package.swift`
- `src/swift/Sources/HybridAI/HybridAI.swift`
- `src/swift/Sources/HybridAICLI/main.swift`
- `src/swift/Sources/HybridAIMobileChat/main.swift`
- `src/swift/Sources/CHybridAIMobileChat/HybridAIMobileChat.c`
- `src/swift/Sources/CHybridAIMobileChat/include/HybridAIMobileChat.h`
- `src/swift/Sources/CGTK/module.modulemap`
- `src/swift/Sources/CGTK/shim.h`
- `src/swift/Sources/CAdwaita/module.modulemap`
- `src/swift/Sources/CAdwaita/shim.h`
- `src/swift/Tests/HybridAITests/HybridAITests.swift`

Repository-managed writable paths used by this workflow:
- `build/swift`
- `build/swift/clang-module-cache`
- `build/swift/package-cache`

## 5. Effective Runtime Behavior

`scripts/env/toolchain/swift/swift_run.sh` does the following:
- defaults to `swift build` when no explicit arguments are provided
- launches through `scripts/env/toolchain/nix/flox_with.sh`
- sources `scripts/env/toolchain/swift/swift_env.sh`
- activates Swiftly, validates Swift `6.3.2`, and exports Swift build/cache paths
- passes `--package-path "$PROJECT_ROOT/src/swift"`
- passes `--build-path "$PROJECT_ROOT/build/swift"` before forwarded arguments

This means every wrapper-based Swift command uses the repository-local build
directory even if the caller forgets to provide one.

`scripts/env/toolchain/swift/swift_ui_run.sh` is the dedicated Linux GTK/libadwaita UI wrapper.
It does the following:
- defaults to `swift build --product hybrid-ai-mobile-chat` when no explicit arguments are provided
- launches through `scripts/env/toolchain/nix/flox_with.sh`
- sources `scripts/env/toolchain/swift/swift_env.sh`
- activates Swiftly, validates Swift `6.3.2`, and exports Swift build/cache paths
- sets `HYBRID_AI_ENABLE_GTK_UI=1` so the Linux UI targets are visible to SwiftPM
- verifies `pkg-config` can resolve `gtk4` and `libadwaita-1`
- converts `pkg-config --cflags gtk4 libadwaita-1` into SwiftPM `-Xcc` arguments
- converts `pkg-config --libs gtk4 libadwaita-1` into SwiftPM `-Xlinker` arguments
- for `run`, builds the UI product first, then launches the binary through `scripts/env/toolchain/swift/gtk_ui_runtime.sh` with a matching Nix glibc dynamic loader

GTK/libadwaita package ownership after the UI proof:
- Flox/Nix provide GTK/libadwaita packages, headers, `.pc` metadata, and related native dependencies from `env/swift/manifest.toml`
- Swiftly still owns Swift, SwiftPM, Swift runtime/import libraries, and the Swift toolchain `clang`
- `swift_ui_run.sh` does not own GTK packages; it only translates `pkg-config` output into SwiftPM flags and handles the GTK app runtime launch path
- some transitive `pkg-config` warnings can be non-fatal if the final UI build succeeds

Swift ownership after the Swiftly migration:
- `swift`, `swiftc`, SwiftPM, `clang`, `sourcekit-lsp`, and `lldb` resolve from `/opt/bin/dev/swiftly/bin`
- `CC` and `CXX` are set to the real Swiftly toolchain `clang`/`clang++` binaries to avoid Swiftly proxy recursion during C target compilation
- Swift runtime/import libraries resolve from the Swiftly `6.3.2` toolchain
- Flox/Nix still provide the surrounding shell and non-Swift native build-time paths
- `LD_LIBRARY_PATH` is sanitized or unset for Swiftly tools so they do not load incompatible Flox/Nix runtime libraries

Current Swift package shape:
- package name: `HybridAI`
- library target: `HybridAI`
- executable target: `HybridAICLI`
- test target: `HybridAITests`
- Linux UI targets are opt-in and appear only when `HYBRID_AI_ENABLE_GTK_UI=1`
- UI executable product: `hybrid-ai-mobile-chat`
- UI bridge/system targets: `HybridAIMobileChat`, `CHybridAIMobileChat`, `CGTK`, and `CAdwaita`

Current executable behavior:
- `src/swift/Sources/HybridAICLI/main.swift` prints the library status value
- `src/swift/Sources/HybridAIMobileChat/main.swift` launches the GTK/libadwaita mobile chat proof through the C bridge

Current test behavior:
- built-in Swift `Testing` runs `status()` and expects the status string to equal `hybrid-ai swift module ready`

## 6. How To Run The Workflow

### 6.1 Build

Run the default wrapper behavior:

```bash
scripts/env/toolchain/swift/swift_run.sh
```

This is equivalent to running:

```bash
scripts/env/toolchain/swift/swift_run.sh build
```

### 6.2 Test

Run the Swift test suite:

```bash
scripts/env/toolchain/swift/swift_run.sh test
```

### 6.3 Resolve Package State Explicitly

If you want an explicit package resolution step:

```bash
scripts/env/toolchain/swift/swift_run.sh package resolve
```

This wrapper form is preferred over running `swift package resolve` directly
from `src/swift`, because direct SwiftPM commands can recreate `src/swift/.build`.

### 6.4 Show The Active Swift Toolchain

```bash
scripts/env/toolchain/swift/swift_env_check.sh
```

For a compact direct check:

```bash
scripts/env/toolchain/nix/flox_with.sh bash -lc 'source scripts/env/toolchain/swift/swift_env.sh; hybrid_ai_activate_swift_env; command -v swift; swift --version | head -n 1'
```

### 6.5 Build The Linux GTK/libadwaita UI Proof

Use the dedicated UI wrapper instead of the generic Swift wrapper:

```bash
scripts/env/toolchain/swift/swift_ui_run.sh build --product hybrid-ai-mobile-chat
```

The UI wrapper is preferred because SwiftPM must receive GTK C and linker flags
as explicit `-Xcc` and `-Xlinker` arguments.

### 6.6 Run The Linux GTK/libadwaita UI Proof

```bash
scripts/env/toolchain/swift/swift_ui_run.sh run hybrid-ai-mobile-chat
```

For runtime diagnostics:

```bash
HYBRID_AI_SWIFT_UI_PRINT_RUNTIME=1 scripts/env/toolchain/swift/swift_ui_run.sh run hybrid-ai-mobile-chat
```

Expected diagnostics include:
- `runtime_loader=/nix/store/...-glibc.../lib/ld-linux-x86-64.so.2` on x86_64 Linux
- `runtime_library_path=...`
- `runtime_binary=.../build/swift/.../hybrid-ai-mobile-chat`

## 7. Verification Workflow

### 7.1 Verify The Swift Binary Path

```bash
scripts/env/toolchain/swift/swift_env_check.sh
```

Expected result:
- `swift_bin=/opt/bin/dev/swiftly/bin/swift`
- `clang_bin=/opt/bin/dev/swiftly/bin/clang`
- Swift version is `6.3.2`

### 7.2 Verify Native Build-Time And Runtime Search Paths

```bash
scripts/env/toolchain/nix/flox_with.sh bash -lc 'source scripts/env/toolchain/swift/swift_env.sh; hybrid_ai_activate_swift_env; printf "CPATH=%s\n" "${CPATH:-unset}"; printf "LIBRARY_PATH=%s\n" "${LIBRARY_PATH:-unset}"; printf "PKG_CONFIG_PATH=%s\n" "${PKG_CONFIG_PATH:-unset}"; printf "LD_LIBRARY_PATH=%s\n" "${LD_LIBRARY_PATH:-unset}"'
```

Expected result:
- `CPATH`, `LIBRARY_PATH`, and `PKG_CONFIG_PATH` expose Flox/Nix native build-time paths before host OS defaults
- `LD_LIBRARY_PATH` is unset or sanitized for Swiftly tools

### 7.3 Verify Build Output Location

Run a build:

```bash
scripts/env/toolchain/swift/swift_run.sh build
```

Then inspect the repository:

```bash
find build/swift -maxdepth 3 | head
test ! -e src/swift/.build && echo no_source_tree_build_dir
```

Expected result:
- outputs exist under `build/swift`
- there is no `src/swift/.build` directory created by the wrapper-based workflow

### 7.4 Verify Tests

```bash
scripts/env/toolchain/swift/swift_run.sh test
```

Expected result:
- tests pass under Swiftly Swift `6.3.2` from inside the Flox project environment
- Swift `Testing` reports the `status()` test as passed

### 7.5 Verify The CLI Executable Behavior

After building, run the executable through SwiftPM:

```bash
scripts/env/toolchain/swift/swift_run.sh run hybrid-ai-cli
```

Expected output today:

```text
hybrid-ai swift module ready
```

### 7.6 Verify GTK/libadwaita Development Metadata

```bash
scripts/env/toolchain/nix/flox_with.sh bash -lc 'pkg-config --modversion gtk4 libadwaita-1'
```

Expected result:
- `gtk4` resolves from the Flox environment
- `libadwaita-1` resolves from the Flox environment

For a compile-header smoke check:

```bash
scripts/env/toolchain/nix/flox_with.sh bash -lc 'printf "#include <gtk/gtk.h>\n#include <adwaita.h>\nint main(void){return 0;}\n" | ${CC:-cc} $(pkg-config --cflags gtk4 libadwaita-1) -x c -fsyntax-only -'
```

Expected result:
- the command exits successfully

### 7.7 Verify The Linux UI Build

```bash
scripts/env/toolchain/swift/swift_ui_run.sh build --product hybrid-ai-mobile-chat
```

Expected result:
- the `hybrid-ai-mobile-chat` product builds under `build/swift`
- no `src/swift/.build` directory is created
- non-fatal transitive `pkg-config` warnings can be ignored if the product links successfully

### 7.8 Verify The Linux UI Runtime Loader Path

```bash
HYBRID_AI_SWIFT_UI_PRINT_RUNTIME=1 scripts/env/toolchain/swift/swift_ui_run.sh run hybrid-ai-mobile-chat
```

Expected result:
- the wrapper prints a Nix glibc `runtime_loader`
- the wrapper does not run the GTK binary directly through the host ELF loader
- the app launches as the mobile-form-factor chat proof

## 8. Expected Outcomes

When this workflow is working correctly:
- Swift builds run with the Swiftly-managed Swift `6.3.2` toolchain
- Flox/Nix native build-time dependency paths are available before host OS defaults
- Swift runtime `LD_LIBRARY_PATH` is sanitized or unset
- all SwiftPM artifacts stay under `build/swift`
- shell and editor task behavior match
- no source-adjacent `.build` directory appears as a byproduct of normal wrapper use
- the generic Swift wrapper remains independent of GTK/libadwaita
- the GTK/libadwaita UI wrapper builds the opt-in `hybrid-ai-mobile-chat` product by translating `pkg-config` flags into SwiftPM `-Xcc` and `-Xlinker` arguments
- the GTK/libadwaita UI runtime is launched through a matching Nix glibc loader to avoid mixing host `libc` with Nix/Flox GTK libraries

Verified on 2026-06-05:
- `bash -n scripts/env/toolchain/swift/swift_env.sh`, `bash -n scripts/env/toolchain/swift/gtk_ui_runtime.sh`, and `bash -n scripts/env/toolchain/swift/swift_ui_run.sh` passed
- `scripts/env/toolchain/nix/flox_env_init.sh` synced the composed Flox environment
- `scripts/env/toolchain/swift/swift_run.sh build` passed
- `scripts/env/toolchain/swift/swift_run.sh test` passed
- `scripts/env/toolchain/swift/swift_ui_run.sh build --product hybrid-ai-mobile-chat` passed
- `test ! -e src/swift/.build` passed after wrapper-based generic and UI builds

Verified on 2026-06-04:
- `scripts/env/toolchain/swift/swifty_check.sh` reported Swiftly under `/opt/bin/dev/swiftly` with Swift `6.3.2` and SwiftPM `6.3.2`
- `scripts/env/toolchain/swift/swift_env_check.sh` reported `swift_bin=/opt/bin/dev/swiftly/bin/swift` and `clang_bin=/opt/bin/dev/swiftly/bin/clang`
- native build-time paths exposed Flox/Nix `CPATH`, `LIBRARY_PATH`, and `PKG_CONFIG_PATH`
- `LD_LIBRARY_PATH=unset` after Swift activation
- `scripts/env/toolchain/swift/swift_run.sh package resolve`, `build`, `test`, and `run hybrid-ai-cli` passed
- `test ! -e src/swift/.build` passed after wrapper-based build/run/test
- `scripts/env/toolchain/doctor.sh` passed

## 9. Failure Modes And Recovery

### 9.1 Missing Nix Daemon Socket

Symptom:
- the wrapper fails before Swift starts

Recovery:
- start the daemon manually so `/nix/var/nix/daemon-socket/socket` exists:

	```bash
	sudo /nix/var/nix/profiles/default/bin/nix-daemon
	```

- project scripts do not start host Nix services automatically
- retry the wrapper after the host prerequisite is restored

### 9.2 Wrong Swift Toolchain

Symptom:
- `scripts/env/toolchain/swift/swift_env_check.sh` indicates a host toolchain, Nix Swift wrapper, or any Swift version other than `6.3.2`

Recovery:
- verify Swiftly with `scripts/env/toolchain/swift/swifty_check.sh`
- rerun through `scripts/env/toolchain/swift/swift_run.sh`
- if the editor is involved, relaunch it via `scripts/env/start_vscode.sh`

### 9.3 Source Tree `.build` Directory Appears

Symptom:
- `src/swift/.build` exists after a Swift workflow

Meaning:
- some command was likely run outside the repository wrapper path

Recovery:
- remove the unintended `.build` directory if appropriate
- rerun all build and test commands through `scripts/env/toolchain/swift/swift_run.sh`

### 9.4 Build Or Test Failures

Symptom:
- `scripts/env/toolchain/swift/swift_run.sh build` or `scripts/env/toolchain/swift/swift_run.sh test` fails

Checks:
- verify the active Flox environment is healthy
- verify Swiftly activation with `scripts/env/toolchain/swift/swift_env_check.sh`
- verify the daemon socket exists
- inspect recent changes in `src/swift/Package.swift`, sources, or tests

### 9.5 Swiftly Loads Incompatible Flox/Nix Runtime Libraries

Symptom:
- Swiftly commands fail with glibc or `libresolv.so.2` version errors

Meaning:
- Swiftly was run without the repository Swift activation helper, so Flox/Nix `LD_LIBRARY_PATH` entries leaked into the official Swift toolchain process

Recovery:
- run through `scripts/env/toolchain/swift/swift_run.sh` or source `scripts/env/toolchain/swift/swift_env.sh` and call `hybrid_ai_activate_swift_env`
- use `scripts/env/toolchain/swift/swift_env_check.sh` to confirm the sanitized environment

### 9.6 GTK/libadwaita UI Target Is Missing

Symptom:
- `hybrid-ai-mobile-chat` is not visible to SwiftPM
- SwiftPM reports an unknown product or target for the UI app

Meaning:
- the generic Swift wrapper was used, or `HYBRID_AI_ENABLE_GTK_UI=1` was not set

Recovery:
- use `scripts/env/toolchain/swift/swift_ui_run.sh build --product hybrid-ai-mobile-chat`
- do not use `scripts/env/toolchain/swift/swift_run.sh` for GTK/libadwaita UI builds

### 9.7 GTK Headers Are Missing During UI Build

Symptom:
- the UI build fails with a missing header such as `gtk/gtk.h` or `adwaita.h`

Meaning:
- GTK/libadwaita development packages or their `pkg-config` metadata are not visible inside the Flox environment

Recovery:
- verify `env/swift/manifest.toml` includes `gtk4`, `libadwaita`, and `pkg-config`
- rerun `scripts/env/toolchain/nix/flox_env_init.sh`
- verify with `scripts/env/toolchain/nix/flox_with.sh bash -lc 'pkg-config --modversion gtk4 libadwaita-1'`

### 9.8 GTK UI Runtime glibc Mismatch

Symptom:
- running the UI binary directly fails with glibc or `libresolv.so.2` symbol-version errors

Meaning:
- the host ELF loader and host `libc` were mixed with Nix/Flox GTK runtime libraries

Recovery:
- do not run `build/swift/.../hybrid-ai-mobile-chat` directly
- run through `scripts/env/toolchain/swift/swift_ui_run.sh run hybrid-ai-mobile-chat`
- enable diagnostics with `HYBRID_AI_SWIFT_UI_PRINT_RUNTIME=1`

### 9.9 Non-Fatal Transitive pkg-config Warnings

Symptom:
- `pkg-config` prints warnings such as `couldn't find pc file for ...`, but the UI product still links successfully

Meaning:
- a transitive `.pc` metadata file is not exposed by the current Flox environment, but the actual build/link inputs are still sufficient

Recovery:
- do not add packages one by one unless the warning becomes a real build or runtime failure
- if the warning becomes fatal, add the missing development package to `env/swift/manifest.toml`, re-sync Flox, and rerun the UI build

## 10. Relationship To Other Docs

Use this document for the concrete Swift build and test workflow.

Related documents:
- `docs/usecases/01-vscode-portable-project-env.md`: editor-side startup path for Python and Swift tooling
- `docs/chat/determinate_nix_flox_setup.md`: operational runbook for Nix, Flox, wrappers, and recovery
- `docs/chat/devenv_portable_workflow.md`: high-level architecture and workflow plan
- `docs/chat/swift_ui_cross_platform_roadmap.md`: Swift UI strategy and GTK/libadwaita Linux proof rationale
