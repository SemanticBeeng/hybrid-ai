# hybrid-ai: Swiftly 6.3.2 Migration Runbook

Date: 2026-06-04
Status: Applied migration runbook
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

This section intentionally preserves the exact stage structure of the agreed roadmap.

## Stage 0: Freeze Current State

Goal: avoid mixing old Nix Swift with new Swiftly.

Actions:
1. Record current working commands.
2. Keep current manual `LinuxMain.swift` workaround temporarily.
3. Ensure `.build` outputs stay ignored by `.gitignore`.

Decision:
- Treat `flake.nix` as experimental/non-canonical during migration.

Execution note:
- Current working Swift commands to preserve during migration:
  - `scripts/env/run_swift.sh build`
  - `scripts/env/run_swift.sh run hybrid-ai-cli`
  - `scripts/env/run_swift.sh test`
- Current working Python verification command:
  - `scripts/env/toolchain/check_python_env.sh`
- Manual Linux XCTest workaround remains in place temporarily:
  - `src/swift/Tests/LinuxMain.swift`
  - `src/swift/Tests/HybridAITests/XCTestManifests.swift`
- `.gitignore` now ignores nested SwiftPM `.build` directories via `**/.build/`.

## Stage 1: Install Swiftly Under `/opt/bin/dev/swiftly`

Goal: install Swiftly outside the repo but inside the dev prefix.

Actions:
1. Create `/opt/bin/dev/swiftly/home`.
2. Create `/opt/bin/dev/swiftly/bin`.
3. Set `SWIFTLY_HOME_DIR=/opt/bin/dev/swiftly/home`.
4. Set `SWIFTLY_BIN_DIR=/opt/bin/dev/swiftly/bin`.
5. Install Swiftly from Swift.org.
6. Install/use Swift `6.3.2`.

Confirm:
- `swift --version` reports `Swift version 6.3.2`.
- `swift package --version` works.
- `clang --version` resolves from the Swift toolchain or Swiftly bin path.
- `sourcekit-lsp --version` works, if provided.

This should be handled by a new bootstrap script, likely:
- `scripts/env/install_swiftly.sh`

Execution note:
- Swiftly was installed under `/opt/bin/dev/swiftly`.
- `scripts/env/toolchain/check_swiftly.sh` verified:
  - `SWIFTLY_HOME_DIR=/opt/bin/dev/swiftly/home`
  - `SWIFTLY_BIN_DIR=/opt/bin/dev/swiftly/bin`
  - `swift=/opt/bin/dev/swiftly/bin/swift`
  - `clang=/opt/bin/dev/swiftly/bin/clang`
  - `sourcekit-lsp=/opt/bin/dev/swiftly/bin/sourcekit-lsp`
  - `lldb=/opt/bin/dev/swiftly/bin/lldb`
  - `Swift version 6.3.2 (swift-6.3.2-RELEASE)`
  - `Swift Package Manager - Swift 6.3.2`

## Stage 2: Make `swift_env.sh` Swiftly-First

Goal: every project entry point sees Swift `6.3.2`.

Modify `scripts/env/toolchain/swift_env.sh`:
1. Remove reliance on Nix `swift-wrapper`.
2. Source `/opt/bin/dev/swiftly/home/env.sh`.
3. Prepend `/opt/bin/dev/swiftly/bin`.
4. Validate version.
5. Keep cache variables/project paths.

Then validate through existing wrappers:
- `scripts/env/run_swift.sh`
- `scripts/env/toolchain/check_swift_env.sh`

Expected result:
- `scripts/env/toolchain/check_swift_env.sh` prints Swift `6.3.2`.
- `scripts/env/run_swift.sh build` uses Swiftly Swift, not Nix Swift.

Execution note:
- `scripts/env/toolchain/swift_env.sh` was changed to source the Swiftly helper and validate Swift `6.3.2`.
- `scripts/env/toolchain/check_swift_env.sh` now reports Swiftly paths and confirmed:
  - `swift_bin=/opt/bin/dev/swiftly/bin/swift`
  - `clang_bin=/opt/bin/dev/swiftly/bin/clang`
  - `sourcekit_lsp_bin=/opt/bin/dev/swiftly/bin/sourcekit-lsp`
  - `lldb_bin=/opt/bin/dev/swiftly/bin/lldb`
  - `Swift version 6.3.2 (swift-6.3.2-RELEASE)`

## Stage 3: Remove Swift From Flox Manifests

Goal: prevent old Nix Swift from shadowing Swiftly.

Modify `env/swift/manifest.toml`:
- remove `swift`
- remove `swiftpm`
- remove `swiftPackages.XCTest`
- keep/add native dependencies only

Modify `env/hybrid-ai/manifest.toml`:
- remove duplicate `swiftpm`
- remove duplicate `xctest`
- keep `libgcc` and Python/fullstack includes

Expected result:
- `flox activate -d env/swift` activates host libs + Swiftly Swift.
- `command -v swift` points into `/opt/bin/dev/swiftly/bin` or a Swiftly-managed shim.
- no Nix Swift wrapper is on `PATH` before Swiftly.

Execution note:
- Removed Nix Swift package entries from `env/swift/manifest.toml` and `env/hybrid-ai/manifest.toml`.
- Re-synced Flox state with `scripts/env/toolchain/init_flox_env.sh`.
- Refreshed composed includes with `flox include upgrade -d env/hybrid-ai`.
- `flox list -d env/hybrid-ai` no longer reports `swift`, `swiftpm`, `XCTest`, or `clang` packages from Nix.
- `flox activate -d env/hybrid-ai -- bash -lc 'command -v swift && swift --version | head -n 1'` reports Swiftly Swift `6.3.2`.

## Stage 4: Validate Swift Build/Run/Test

Goal: confirm Swiftly solves the old Nix split-package issues.

Run through the project wrapper:
- build
- run CLI
- test

Expected result:
- `swift build` works.
- `swift run hybrid-ai-cli` works.
- `swift test` works without `libIndexStore.so` errors.
- `XCTest` is available from the official Swift toolchain.
- `Testing` is available as a built-in Swift 6 module.

Execution note:
- `scripts/env/run_swift.sh build` succeeded with Swiftly Swift `6.3.2`.
- `scripts/env/run_swift.sh run hybrid-ai-cli` succeeded and printed `hybrid-ai swift module ready`.
- `scripts/env/run_swift.sh test` succeeded: 1 test executed, 0 failures.
- During Stage 4 validation, Swiftly initially failed because Flox-provided `LD_LIBRARY_PATH` caused the official Swift toolchain to load incompatible Nix/Flox libraries. `scripts/env/toolchain/swift_env.sh` now preserves the original value in `HYBRID_AI_ORIGINAL_LD_LIBRARY_PATH` and sanitizes `LD_LIBRARY_PATH` for Swiftly tools.

## Stage 5: Decide Test Framework

Goal: simplify tests after Swift 6.3.2 is active.

Two options:

### Conservative

Keep current `XCTest` tests and manual Linux manifests:
- `src/swift/Tests/LinuxMain.swift`
- `src/swift/Tests/HybridAITests/XCTestManifests.swift`

Pros:
- proven to work
- minimal source churn

Cons:
- manual `allTests` maintenance

### Preferred After Swift 6.3.2

Migrate to built-in Swift `Testing`:
- remove `LinuxMain.swift`
- remove `XCTestManifests.swift`
- replace `import XCTest` with `import Testing`
- replace `XCTestCase` methods with `@Test` functions
- replace `XCTAssertEqual` with `#expect`

Pros:
- modern Swift 6 path
- avoids Linux XCTest discovery edge cases
- no external `swift-testing` package needed

Recommendation: migrate to `Testing` after Swiftly is validated.

Execution note:
- Chose the preferred Swift 6 path.
- Migrated `src/swift/Tests/HybridAITests/HybridAITests.swift` from `XCTest` to built-in Swift `Testing`.
- Removed the manual Linux XCTest discovery files:
  - `src/swift/Tests/LinuxMain.swift`
  - `src/swift/Tests/HybridAITests/XCTestManifests.swift`
- `scripts/env/run_swift.sh test` succeeded with Swift Testing: 1 test, 0 failures.

## Stage 6: Decide Fate Of `flake.nix`

Goal: reduce maintenance.

Decision: remove the flake completely. The Flox environments are sufficient for
the Python environment, common tools, activation hooks, and native host
dependencies. Swift will be supplied by Swiftly, so the flake no longer owns any
unique required capability.

If Flox + Swiftly works:
- remove `flake.nix` and `flake.lock`, or mark them unsupported/experimental.
- keep one canonical path: Flox activation + Swiftly toolchain.

If keeping the flake:
- remove Nix Swift packages from `flake.nix`.
- make devShell source the same Swiftly activation helper.
- use Nix only for host libraries, not Swift.

Recommendation:

> Remove the flake unless there is a concrete need for non-Flox contributors.

Execution note:
- `scripts/env/toolchain/check_python_env.sh` was used to verify the Flox-managed Python environment.
- `flake.nix` and `flake.lock` were removed from the repository.
- Stage 6 was re-verified after the Swiftly migration: no `flake.*` files remain, Flox Python still resolves to `env/hybrid-ai/.flox/cache/python/bin/python`, and Swift resolves to `/opt/bin/dev/swiftly/bin/swift` with Swift `6.3.2`.

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

## 10. Migration Conclusion

The final environment matches the purpose of combining Swiftly with Nix/Flox:

- Swiftly owns the Swift toolchain and all Swift-specific resolution.
- Flox/Nix own the reproducible project shell, Python environment, common tools, and build-time native dependency paths.
- Nix/Flox no longer provide the active Swift compiler, SwiftPM, XCTest, Swift Testing, clang, lldb, SourceKit-LSP, or Swift toolchain internals.
- Swift commands still run inside the Flox project environment so that non-Swift tools and native dependency paths are reproducible.

The effective resolution model is:

1. Project Swift entry points use `scripts/env/run_swift.sh`.
2. The wrapper enters `env/hybrid-ai` through Flox when needed.
3. `scripts/env/toolchain/swift_env.sh` activates Swiftly and validates Swift `6.3.2`.
4. Swiftly paths win for `swift`, `swiftc`, SwiftPM, `clang`, `sourcekit-lsp`, `lldb`, Swift runtime libraries, Swift standard libraries, Swift Testing, XCTest, and toolchain internals.
5. Build-time native resolution prefers Flox/Nix before the host OS through `CPATH`, `LIBRARY_PATH`, and `PKG_CONFIG_PATH`.
6. Runtime dynamic library resolution does not prefer Flox/Nix by default because `LD_LIBRARY_PATH` is sanitized or unset for Swiftly tools.
7. Host OS include/library defaults remain available after Flox/Nix build-time paths, so Swift package native dependencies can still fall back to host system paths if not supplied by Flox/Nix.

Verified current behavior:

- `swift` resolves to `/opt/bin/dev/swiftly/bin/swift`.
- `swiftc` resolves to `/opt/bin/dev/swiftly/bin/swiftc`.
- `clang` resolves to `/opt/bin/dev/swiftly/bin/clang`.
- Swift runtime/import paths resolve under the Swiftly `6.3.2` toolchain.
- `CPATH`, `LIBRARY_PATH`, and `PKG_CONFIG_PATH` expose Flox/Nix build-time native paths before host OS defaults.
- `LD_LIBRARY_PATH` is unset after Swift activation.
- `flox list -d env/hybrid-ai` reports no Swift-specific Nix packages.

This is the intended split: Swiftly provides a current official Swift toolchain, while Flox/Nix provide reproducible non-Swift build inputs ahead of the host OS without reintroducing Nix Swift package ownership.
