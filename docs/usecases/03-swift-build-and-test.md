# Use Case 03: Swift Build And Test Development Workflow

Date: 2026-06-04
Status: Implemented
Primary script: `scripts/env/run_swift.sh`

## 1. Goal

Run Swift package build and test workflows through the repository wrapper so the
Swift toolchain comes from Swiftly while the command still runs inside the Flox
project environment. All Swift build artifacts stay under `build/swift` instead
of leaking into the source tree.

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

## 3. Scope And Assumptions

This workflow assumes:
- Determinate Nix and Flox are working for the repository
- the nix daemon socket exists
- `env/hybrid-ai/.flox` has already been initialized and synced
- Swiftly is installed under `/opt/bin/dev/swiftly`
- `scripts/env/toolchain/swift_env.sh` activates Swiftly and validates Swift `6.3.2`
- the Swift package exists under `src/swift`

## 4. Files Involved

Runtime wrappers:
- `scripts/env/run_swift.sh`
- `scripts/env/with_flox.sh`
- `scripts/env/toolchain/common.sh`
- `scripts/env/toolchain/swift_env.sh`
- `scripts/env/toolchain/swiftly_common.sh`
- `scripts/env/toolchain/check_swift_env.sh`
- `scripts/env/toolchain/check_swiftly.sh`

Swift package files:
- `src/swift/Package.swift`
- `src/swift/Sources/HybridAI/HybridAI.swift`
- `src/swift/Sources/HybridAICLI/main.swift`
- `src/swift/Tests/HybridAITests/HybridAITests.swift`

Repository-managed writable paths used by this workflow:
- `build/swift`
- `build/swift/clang-module-cache`
- `build/swift/package-cache`

## 5. Effective Runtime Behavior

`scripts/env/run_swift.sh` does the following:
- defaults to `swift build` when no explicit arguments are provided
- launches through `scripts/env/with_flox.sh`
- sources `scripts/env/toolchain/swift_env.sh`
- activates Swiftly and validates Swift `6.3.2`
- passes `--package-path "$PROJECT_ROOT/src/swift"`
- passes `--build-path "$PROJECT_ROOT/build/swift"` before forwarded arguments

This means every wrapper-based Swift command uses the repository-local build
directory even if the caller forgets to provide one.

Swift ownership after the Swiftly migration:
- `swift`, `swiftc`, SwiftPM, `clang`, `sourcekit-lsp`, and `lldb` resolve from `/opt/bin/dev/swiftly/bin`
- Swift runtime/import libraries resolve from the Swiftly `6.3.2` toolchain
- Flox/Nix still provide the surrounding shell and non-Swift native build-time paths
- `LD_LIBRARY_PATH` is sanitized or unset for Swiftly tools so they do not load incompatible Flox/Nix runtime libraries

Current Swift package shape:
- package name: `HybridAI`
- library target: `HybridAI`
- executable target: `HybridAICLI`
- test target: `HybridAITests`

Current executable behavior:
- `src/swift/Sources/HybridAICLI/main.swift` prints the library status value

Current test behavior:
- built-in Swift `Testing` runs `status()` and expects the status string to equal `hybrid-ai swift module ready`

## 6. How To Run The Workflow

### 6.1 Build

Run the default wrapper behavior:

```bash
scripts/env/run_swift.sh
```

This is equivalent to running:

```bash
scripts/env/run_swift.sh build
```

### 6.2 Test

Run the Swift test suite:

```bash
scripts/env/run_swift.sh test
```

### 6.3 Resolve Package State Explicitly

If you want an explicit package resolution step:

```bash
scripts/env/run_swift.sh package resolve
```

This wrapper form is preferred over running `swift package resolve` directly
from `src/swift`, because direct SwiftPM commands can recreate `src/swift/.build`.

### 6.4 Show The Active Swift Toolchain

```bash
scripts/env/toolchain/check_swift_env.sh
```

For a compact direct check:

```bash
scripts/env/with_flox.sh bash -lc 'source scripts/env/toolchain/swift_env.sh; hybrid_ai_activate_swift_env; command -v swift; swift --version | head -n 1'
```

## 7. Verification Workflow

### 7.1 Verify The Swift Binary Path

```bash
scripts/env/toolchain/check_swift_env.sh
```

Expected result:
- `swift_bin=/opt/bin/dev/swiftly/bin/swift`
- `clang_bin=/opt/bin/dev/swiftly/bin/clang`
- Swift version is `6.3.2`

### 7.2 Verify Native Build-Time And Runtime Search Paths

```bash
scripts/env/with_flox.sh bash -lc 'source scripts/env/toolchain/swift_env.sh; hybrid_ai_activate_swift_env; printf "CPATH=%s\n" "${CPATH:-unset}"; printf "LIBRARY_PATH=%s\n" "${LIBRARY_PATH:-unset}"; printf "PKG_CONFIG_PATH=%s\n" "${PKG_CONFIG_PATH:-unset}"; printf "LD_LIBRARY_PATH=%s\n" "${LD_LIBRARY_PATH:-unset}"'
```

Expected result:
- `CPATH`, `LIBRARY_PATH`, and `PKG_CONFIG_PATH` expose Flox/Nix native build-time paths before host OS defaults
- `LD_LIBRARY_PATH` is unset or sanitized for Swiftly tools

### 7.3 Verify Build Output Location

Run a build:

```bash
scripts/env/run_swift.sh build
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
scripts/env/run_swift.sh test
```

Expected result:
- tests pass under Swiftly Swift `6.3.2` from inside the Flox project environment
- Swift `Testing` reports the `status()` test as passed

### 7.5 Verify The CLI Executable Behavior

After building, run the executable through SwiftPM:

```bash
scripts/env/run_swift.sh run hybrid-ai-cli
```

Expected output today:

```text
hybrid-ai swift module ready
```

## 8. Expected Outcomes

When this workflow is working correctly:
- Swift builds run with the Swiftly-managed Swift `6.3.2` toolchain
- Flox/Nix native build-time dependency paths are available before host OS defaults
- Swift runtime `LD_LIBRARY_PATH` is sanitized or unset
- all SwiftPM artifacts stay under `build/swift`
- shell and editor task behavior match
- no source-adjacent `.build` directory appears as a byproduct of normal wrapper use

Verified on 2026-06-04:
- `scripts/env/toolchain/check_swiftly.sh` reported Swiftly under `/opt/bin/dev/swiftly` with Swift `6.3.2` and SwiftPM `6.3.2`
- `scripts/env/toolchain/check_swift_env.sh` reported `swift_bin=/opt/bin/dev/swiftly/bin/swift` and `clang_bin=/opt/bin/dev/swiftly/bin/clang`
- native build-time paths exposed Flox/Nix `CPATH`, `LIBRARY_PATH`, and `PKG_CONFIG_PATH`
- `LD_LIBRARY_PATH=unset` after Swift activation
- `scripts/env/run_swift.sh package resolve`, `build`, `test`, and `run hybrid-ai-cli` passed
- `test ! -e src/swift/.build` passed after wrapper-based build/run/test
- `scripts/env/toolchain/doctor.sh` passed

## 9. Failure Modes And Recovery

### 9.1 Missing Nix Daemon Socket

Symptom:
- the wrapper fails before Swift starts

Recovery:

```bash
sudo /nix/var/nix/profiles/default/bin/nix-daemon
```

### 9.2 Wrong Swift Toolchain

Symptom:
- `scripts/env/toolchain/check_swift_env.sh` indicates a host toolchain, Nix Swift wrapper, or any Swift version other than `6.3.2`

Recovery:
- verify Swiftly with `scripts/env/toolchain/check_swiftly.sh`
- rerun through `scripts/env/run_swift.sh`
- if the editor is involved, relaunch it via `scripts/env/start_vscode.sh`

### 9.3 Source Tree `.build` Directory Appears

Symptom:
- `src/swift/.build` exists after a Swift workflow

Meaning:
- some command was likely run outside the repository wrapper path

Recovery:
- remove the unintended `.build` directory if appropriate
- rerun all build and test commands through `scripts/env/run_swift.sh`

### 9.4 Build Or Test Failures

Symptom:
- `scripts/env/run_swift.sh build` or `scripts/env/run_swift.sh test` fails

Checks:
- verify the active Flox environment is healthy
- verify Swiftly activation with `scripts/env/toolchain/check_swift_env.sh`
- verify the daemon socket exists
- inspect recent changes in `src/swift/Package.swift`, sources, or tests

### 9.5 Swiftly Loads Incompatible Flox/Nix Runtime Libraries

Symptom:
- Swiftly commands fail with glibc or `libresolv.so.2` version errors

Meaning:
- Swiftly was run without the repository Swift activation helper, so Flox/Nix `LD_LIBRARY_PATH` entries leaked into the official Swift toolchain process

Recovery:
- run through `scripts/env/run_swift.sh` or source `scripts/env/toolchain/swift_env.sh` and call `hybrid_ai_activate_swift_env`
- use `scripts/env/toolchain/check_swift_env.sh` to confirm the sanitized environment

## 10. Relationship To Other Docs

Use this document for the concrete Swift build and test workflow.

Related documents:
- `docs/usecases/01-vscode-portable-project-env.md`: editor-side startup path for Python and Swift tooling
- `docs/chat/determinate_nix_flox_setup.md`: operational runbook for Nix, Flox, wrappers, and recovery
- `docs/chat/devenv_portable_workflow.md`: high-level architecture and workflow plan