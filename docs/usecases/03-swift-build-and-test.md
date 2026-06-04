# Use Case 03: Swift Build And Test Development Workflow

Date: 2026-06-03
Status: Implemented
Primary script: `scripts/env/run_swift.sh`

## 1. Goal

Run Swift package build and test workflows through the repository wrapper so the
Swift toolchain comes from the Flox-managed environment and all build artifacts
stay under `build/swift` instead of leaking into the source tree.

## 2. Why This Workflow Exists

SwiftPM defaults are convenient for local experiments, but this repository wants
explicit control over:
- which Swift toolchain is used
- where build outputs are written
- how editor and shell workflows stay aligned

The wrapper ensures that:
- `swift` is resolved from the repository environment
- `--build-path` always points at `build/swift`
- CLI usage, VS Code tasks, and Copilot-generated build commands all share the same execution path

## 3. Scope And Assumptions

This workflow assumes:
- Determinate Nix and Flox are working for the repository
- the nix daemon socket exists
- `env/hybrid-ai/.flox` has already been initialized and synced
- the Swift package exists under `src/swift`

## 4. Files Involved

Runtime wrappers:
- `scripts/env/run_swift.sh`
- `scripts/env/with_flox.sh`
- `scripts/env/toolchain/common.sh`

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
- always appends `--build-path "$PROJECT_ROOT/build/swift"`

This means every wrapper-based Swift command uses the repository-local build
directory even if the caller forgets to provide one.

Current Swift package shape:
- package name: `HybridAI`
- library target: `HybridAI`
- executable target: `HybridAICLI`
- test target: `HybridAITests`

Current executable behavior:
- `src/swift/Sources/HybridAICLI/main.swift` prints the library status value

Current test behavior:
- `HybridAITests.testStatus()` asserts the status string equals `hybrid-ai swift module ready`

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

### 6.4 Show The Active Swift Toolchain

```bash
scripts/env/with_flox.sh swift --version
```

## 7. Verification Workflow

### 7.1 Verify The Swift Binary Path

```bash
scripts/env/with_flox.sh bash -lc 'command -v swift'
```

Expected result:
- the path points into `env/hybrid-ai/.flox/run/.../bin/swift`

### 7.2 Verify Build Output Location

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

### 7.3 Verify Tests

```bash
scripts/env/run_swift.sh test
```

Expected result:
- tests pass under the Flox-managed Swift toolchain

### 7.4 Verify The CLI Executable Behavior

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
- Swift builds run with the Flox-managed toolchain
- all SwiftPM artifacts stay under `build/swift`
- shell and editor task behavior match
- no source-adjacent `.build` directory appears as a byproduct of normal wrapper use

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
- `scripts/env/with_flox.sh swift --version` or `command -v swift` indicates a host toolchain rather than the Flox-managed one

Recovery:
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
- verify the daemon socket exists
- inspect recent changes in `src/swift/Package.swift`, sources, or tests

## 10. Relationship To Other Docs

Use this document for the concrete Swift build and test workflow.

Related documents:
- `docs/usecases/01-vscode-portable-project-env.md`: editor-side startup path for Python and Swift tooling
- `docs/chat/determinate_nix_flox_setup.md`: operational runbook for Nix, Flox, wrappers, and recovery
- `docs/chat/devenv_portable_workflow.md`: high-level architecture and workflow plan