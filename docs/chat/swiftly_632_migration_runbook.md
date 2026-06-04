# hybrid-ai: Swiftly 6.3.2 Migration Runbook

Date: 2026-06-04
Status: Proposed roadmap
Scope: Replace Nix/Flox-provided Swift 5.x with Swiftly-managed Swift 6.3.2 while keeping Flox as the project environment manager for Python, base tools, and native host dependencies.

## 1. Decision Summary

The project should stop using Nix/Flox Swift packages for the active Swift toolchain.

Use:
- Flox for Python, common CLI tools, activation hooks, cache isolation, and native host dependencies.
- Swiftly for Swift 6.3.2, SwiftPM, XCTest/Testing, clang, lldb, SourceKit-LSP, and Swift toolchain internals.
- `/opt/bin/dev/swiftly` as the persistent host-level Swiftly backing directory, analogous to `/opt/bin/dev/nix`.

The Nix flake is not required for the core workflow once Swiftly is integrated. It should be removed or treated only as a temporary fallback until the migration is complete.

## 2. Why This Migration Is Needed

Current Nix/Flox Swift packages are too old for the intended project direction:
- nixpkgs/Flox currently provide Swift 5.10.1, not Swift 6.3.2.
- Swift core libraries are split across Nix outputs in ways that require manual activation fixes.
- `swift test` encountered Nix-specific issues around `XCTest` module discovery and `libIndexStore.so`.
- Maintaining custom Nix Swift 6.3.2 packaging would add significant maintenance burden.

Swiftly is the official Swift.org toolchain manager and supports Swift 6.3.2 directly on Linux.

## 3. Target Architecture

### 3.1 Host-Level Persistent Swiftly Layout

Canonical Swiftly physical backing path:

```bash
/opt/bin/dev/swiftly
```

Suggested directory layout:

```text
/opt/bin/dev/swiftly/
  home/          # SWIFTLY_HOME_DIR
  bin/           # SWIFTLY_BIN_DIR, swiftly-managed shims/binaries
  downloads/     # optional download/cache area if needed later
```

Recommended environment variables:

```bash
export SWIFTLY_ROOT=/opt/bin/dev/swiftly
export SWIFTLY_HOME_DIR=/opt/bin/dev/swiftly/home
export SWIFTLY_BIN_DIR=/opt/bin/dev/swiftly/bin
```

`SWIFTLY_BIN_DIR` must appear before Flox/Nix paths when resolving Swift tools.

### 3.2 Tool Ownership

Swiftly owns:
- `swift`
- `swiftc`
- `swiftpm`
- `swift-build`
- `swift-test`
- `swift-run`
- `clang` as bundled by the Swift toolchain
- `lldb`
- `sourcekit-lsp`
- Swift 6.3.2 runtime libraries
- XCTest / Swift Testing support
- `libIndexStore.so` and other toolchain internals

Flox owns:
- Python
- `uv`, Poetry, and Python cache behavior
- common CLI tools: `bash`, `coreutils`, `git`, `findutils`, `gnused`, `ripgrep`, `jq`, `yq`, `just`, `curl`
- native dependencies required by the official Swift toolchain where Swiftly or Swift reports them as missing
- project activation hooks and isolated writable directories

Nix owns:
- the store backing Flox itself through the existing Determinate Nix setup
- no active Swift compiler/toolchain for this project after migration

## 4. Flox/Nix Role After Migration

Flox remains useful and should stay as the primary project environment entry point.

However, Flox should no longer install:
- `swift`
- `swiftpm`
- `swiftPackages.XCTest`

The flake should be removed unless there is a separate, explicit need for a Nix-only fallback shell.

Rationale:
- The flake duplicates environment logic already represented by Flox manifests and repo scripts.
- It still depends on nixpkgs Swift packages unless a custom derivation is written.
- It cannot provide Swift 6.3.2 cleanly without reintroducing custom packaging work.

## 5. Staged Migration Plan

## Stage 0: Preserve Current Working State

Goal: Ensure the current repository state is recoverable before changing toolchain ownership.

Actions:
1. Confirm current Git status.
2. Commit or stash any unrelated edits.
3. Keep the current Swift package and tests intact until Swift 6.3.2 is active.

Verification:

```bash
git status --short
```

Expected result:
- only intentional migration files should be changed.

## Stage 1: Add Swiftly Host Bootstrap Scripts

Goal: Add explicit scripts for host-level Swiftly installation under `/opt/bin/dev/swiftly`.

Proposed new scripts:
- `scripts/env/toolchain/install_swiftly.sh`
- `scripts/env/toolchain/check_swiftly.sh`

`install_swiftly.sh` responsibilities:
1. Create `/opt/bin/dev/swiftly/home` and `/opt/bin/dev/swiftly/bin`.
2. Export `SWIFTLY_HOME_DIR=/opt/bin/dev/swiftly/home`.
3. Export `SWIFTLY_BIN_DIR=/opt/bin/dev/swiftly/bin`.
4. Download Swiftly from Swift.org.
5. Run `swiftly init` using the project’s configured Swiftly directories.
6. Install and select Swift 6.3.2.
7. Avoid modifying user shell profiles.
8. Print follow-up verification commands.

`check_swiftly.sh` responsibilities:
1. Verify `swiftly` exists.
2. Verify `swift --version` reports Swift 6.3.2.
3. Verify `swiftc`, `swift package`, `clang`, `sourcekit-lsp`, and `lldb` resolve from the Swiftly/toolchain path, not Nix Swift.
4. Report the effective `SWIFTLY_HOME_DIR`, `SWIFTLY_BIN_DIR`, and `PATH` ordering.

Notes:
- This is analogous to the existing Determinate Nix backing path model: `/nix` is backed by `/opt/bin/dev/nix`; Swiftly is simply backed directly by `/opt/bin/dev/swiftly`.
- Unlike Nix, Swiftly does not need a `/swiftly` logical bind mount unless a future tool requires it.

## Stage 2: Rewrite Swift Activation Helper Around Swiftly

Goal: Change `scripts/env/toolchain/swift_env.sh` from a Nix Swift wrapper helper into a Swiftly activation helper.

New behavior:
1. Set default `HYBRID_AI_SWIFT_VERSION=6.3.2`.
2. Set default `SWIFTLY_ROOT=/opt/bin/dev/swiftly`.
3. Set `SWIFTLY_HOME_DIR=$SWIFTLY_ROOT/home`.
4. Set `SWIFTLY_BIN_DIR=$SWIFTLY_ROOT/bin`.
5. Source `$SWIFTLY_HOME_DIR/env.sh` if present.
6. Prepend `$SWIFTLY_BIN_DIR` to `PATH`.
7. Export `HYBRID_AI_SWIFT_DIR=$PROJECT_ROOT/src/swift`.
8. Keep repository-local Swift build caches:
   - `SWIFT_BUILD_PATH=$PROJECT_ROOT/build/swift`
   - `CLANG_MODULE_CACHE_PATH=$PROJECT_ROOT/build/swift/clang-module-cache`
   - `SWIFTPM_PACKAGECACHE=$PROJECT_ROOT/build/swift/package-cache`
9. Validate that `swift --version` reports `6.3.2`.
10. Fail with a clear message if Swiftly or Swift 6.3.2 is not installed.

Nix-specific fallback:
- Optionally keep the old Nix `cc_wrapper` parser behind `HYBRID_AI_SWIFT_PROVIDER=nix` for temporary fallback only.
- Default provider should be `swiftly`.

## Stage 3: Update Flox Manifests

Goal: Keep Flox as the environment manager while removing old Swift packages.

Update `env/swift/manifest.toml`:
- Remove:
  - `swift.pkg-path = "swift"`
  - `swiftpm.pkg-path = "swiftpm"`
  - `xctest.pkg-path = "swiftPackages.XCTest"`
- Keep/add host tools and dependencies:
  - `cmake`
  - `pkg-config` if needed
  - `curl`
  - `git`
  - native libraries Swiftly or Swift reports as missing
- Continue to source `scripts/env/toolchain/swift_env.sh` in hooks and shell profiles.

Update `env/hybrid-ai/manifest.toml`:
- Remove duplicate Swift package entries:
  - `swiftpm`
  - `xctest`
- Continue to include `../swift` as the Swift activation layer.
- Keep Python setup unchanged.

## Stage 4: Remove or Retire the Nix Flake

Goal: Avoid maintaining duplicate environment definitions.

Preferred action:
- Delete `flake.nix` and `flake.lock` after Swiftly/Flox validation succeeds.

Alternative temporary action:
- Keep them for one short transition branch only, but remove old Swift packages from the flake and make it source the same Swiftly activation helper.

Recommended final state:
- No flake required for day-to-day development.
- Flox is the project activation boundary.
- Swiftly is the Swift toolchain source.

## Stage 5: Add Project Swift Version Pin

Goal: Make the intended Swift version visible to tools and developers.

Add:

```text
.swift-version
```

Contents:

```text
6.3.2
```

Activation scripts should treat this as the expected version when present.

## Stage 6: Validate Swift 6.3.2 Build And Test

Goal: Confirm the new toolchain works through the existing repo wrapper.

Commands:

```bash
scripts/env/toolchain/check_swiftly.sh
scripts/env/toolchain/check_swift_env.sh
scripts/env/run_swift.sh build
scripts/env/run_swift.sh run hybrid-ai-cli
scripts/env/run_swift.sh test
```

Expected results:
- `swift --version` reports Swift 6.3.2.
- `swift build` succeeds.
- `swift run hybrid-ai-cli` prints the expected status message.
- `swift test` succeeds.
- No Nix Swift wrapper path appears as the active `swift` binary.

## Stage 7: Revisit Test Framework Choice

Goal: Decide whether to keep XCTest or use Swift 6 built-in Testing.

Option A: Keep XCTest
- Conservative.
- Minimal code changes.
- Manual Linux manifests may no longer be necessary with Swiftly, but can be kept temporarily.

Option B: Move to Swift Testing
- Preferred long-term for Swift 6.
- Use the built-in `Testing` module from the Swift 6.3.2 toolchain.
- Do not add the external `apple/swift-testing` package unless there is a specific reason.

Recommended sequence:
1. First validate Swift 6.3.2 with existing XCTest tests.
2. Then remove manual Linux discovery workaround if auto-discovery works.
3. Then migrate to Swift Testing in a separate commit.

## Stage 8: Documentation And VS Code Alignment

Goal: Make all documented workflows point at the new toolchain boundary.

Update:
- `docs/usecases/swift-build-and-test.md`
- `docs/chat/devenv_portable_workflow.md`
- VS Code tasks if they mention Nix Swift specifically
- Any runbooks that describe Swift as Flox/Nix-owned

Expected documented workflow:

```bash
flox activate -d env/hybrid-ai
swift --version
scripts/env/run_swift.sh test
```

`swift --version` must show Swift 6.3.2 from Swiftly.

## 6. Proposed Final Developer Commands

Install or repair Swiftly once:

```bash
scripts/env/toolchain/install_swiftly.sh
```

Check Swiftly:

```bash
scripts/env/toolchain/check_swiftly.sh
```

Enter full project env:

```bash
flox activate -d env/hybrid-ai
```

Build Swift package:

```bash
scripts/env/run_swift.sh build
```

Run CLI:

```bash
scripts/env/run_swift.sh run hybrid-ai-cli
```

Run tests:

```bash
scripts/env/run_swift.sh test
```

## 7. Acceptance Criteria

Migration is complete when:

- Swiftly is installed under `/opt/bin/dev/swiftly`.
- `.swift-version` pins `6.3.2`.
- Flox no longer installs `swift`, `swiftpm`, or `swiftPackages.XCTest`.
- `scripts/env/toolchain/swift_env.sh` activates Swiftly by default.
- `scripts/env/run_swift.sh build` succeeds.
- `scripts/env/run_swift.sh run hybrid-ai-cli` succeeds.
- `scripts/env/run_swift.sh test` succeeds.
- `swift --version` inside activated Flox reports Swift 6.3.2.
- Active `swift` path is from Swiftly, not a Nix Swift wrapper.
- `flake.nix` and `flake.lock` are removed or explicitly marked as temporary fallback only.

## 8. Risks And Mitigations

Risk: Swiftly attempts to modify user shell startup files.
- Mitigation: install with explicit `SWIFTLY_HOME_DIR` and `SWIFTLY_BIN_DIR`; avoid relying on user profile modifications; source Swiftly env only from repo activation scripts.

Risk: Official Swift Linux binaries need host libraries not present in Flox.
- Mitigation: run Swiftly’s dependency checks; add missing host packages to `env/swift/manifest.toml` rather than using Nix Swift packages.

Risk: `/opt/bin/dev/swiftly` requires permissions setup.
- Mitigation: mirror the existing `/opt/bin/dev/nix` operational pattern; create host bootstrap/repair script if needed.

Risk: Global user Swiftly conflicts with project Swiftly.
- Mitigation: always export project `SWIFTLY_HOME_DIR` and `SWIFTLY_BIN_DIR`; ensure project Swiftly bin comes first on `PATH`.

Risk: Tests behave differently after Swift 6 migration.
- Mitigation: validate existing XCTest first; migrate to Swift Testing as a separate change.

## 9. Open Implementation Questions

- Should `/opt/bin/dev/swiftly` be created by the existing host bootstrap script or a separate Swiftly installer script?
- Should the old Nix Swift fallback remain temporarily behind `HYBRID_AI_SWIFT_PROVIDER=nix`?
- Which additional native libraries will Swiftly report as missing on this host?
- Should `LinuxMain.swift` and `XCTestManifests.swift` be removed after Swiftly validation, or kept until the Swift Testing migration?
