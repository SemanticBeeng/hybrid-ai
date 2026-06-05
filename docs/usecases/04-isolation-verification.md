# Use Case 04: Verify Full Isolation Requirements

Date: 2026-06-04
Status: Implemented
Primary scripts:
- `scripts/env/toolchain/doctor.sh`
- `scripts/env/toolchain/check_env.sh`
- `scripts/env/toolchain/python/python_env_check.sh`
- `scripts/env/toolchain/swift/swift_env_check.sh`
- `scripts/env/toolchain/swift/swifty_check.sh`
- `scripts/env/toolchain/nix/nix_isolation_check.sh`
- `scripts/env/toolchain/python/python_run.sh`
- `scripts/env/toolchain/swift/swift_run.sh`
- `scripts/env/toolchain/nix/flox_with.sh`

## 1. Goal

Verify that the repository's current environment actually satisfies the project
isolation requirements, not just the intended design.

This use case covers:
- project-local writable paths
- host-level Nix/Flox isolation assumptions
- Python and Swift runtime isolation
- verification script consistency
- the formal target state where all isolation checks pass cleanly

## 2. Why This Workflow Exists

The repository has two different truths that can drift apart:
- the documented isolation model
- the scripts that claim to verify it

A setup can appear to work for day-to-day commands while still failing the
repository's own validation tools. That means isolation may be operationally
acceptable but not formally verified.

This use case exists to answer two separate questions:
- is the current runtime behavior isolated correctly?
- do the host-level verification tools and formal checks agree with that state?

## 3. Isolation Requirements In Scope

This document verifies the requirements currently documented in
`docs/chat/devenv_portable_workflow.md`.

Key requirements:
- no writes to the real user home for project processes
- all intended writable paths remain under the repository or the isolated Nix backing path
- Python uses the managed Flox venv under `env/hybrid-ai/.flox/cache/python`
- Python caches and bytecode stay under `env/hybrid-ai/.flox/cache/`
- Swift uses Swiftly-managed Swift `6.3.2` under `/opt/bin/dev/swiftly`, activated from inside the Flox environment
- Swift build outputs stay under `build/swift`
- Swift native build-time dependency resolution sees Flox/Nix `CPATH`, `LIBRARY_PATH`, and `PKG_CONFIG_PATH` before host OS defaults
- Swift runtime dynamic library resolution does not inherit Flox/Nix `LD_LIBRARY_PATH`; `scripts/env/toolchain/swift/swift_env.sh` sanitizes or unsets it
- `/nix` is mounted and usable for the Determinate Nix + Flox workflow
- normal-user wrappers require the daemon socket
- verification tooling itself stays aligned with the actual live workflow

## 4. Files Involved

Verification scripts:
- `scripts/env/toolchain/doctor.sh`
- `scripts/env/toolchain/check_env.sh`
- `scripts/env/toolchain/python/python_env_check.sh`
- `scripts/env/toolchain/swift/swift_env_check.sh`
- `scripts/env/toolchain/swift/swifty_check.sh`
- `scripts/env/toolchain/nix/nix_isolation_check.sh`

Runtime scripts used for proof:
- `scripts/env/toolchain/python/python_run.sh`
- `scripts/env/toolchain/python/python_server_run.sh`
- `scripts/env/toolchain/nix/flox_with.sh`
- `scripts/env/toolchain/swift/swift_run.sh`

Reference docs:
- `docs/chat/devenv_portable_workflow.md`
- `docs/chat/determinate_nix_flox_setup.md`
- `docs/usecases/02-python-cli-and-server.md`
- `docs/usecases/03-swift-build-and-test.md`

## 5. Current Verification Layers

### 5.1 Runtime Isolation Checks

These prove that the actual developer workflows are using isolated paths and
toolchains:
- Python wrapper environment
- Python interpreter path
- managed Python venv path
- Python cache paths
- NumPy native-extension import proof
- Swiftly binary path
- Swift build path
- Swift native build-time search paths
- Swift runtime library path sanitization

### 5.2 Host-Level Verification Tooling Consistency

This is a separate requirement from runtime isolation.

It means the scripts that are supposed to validate isolation must themselves be
kept consistent with the current environment model.

Current examples:
- `scripts/env/toolchain/check_env.sh` should stay focused on the common/shared isolation layer
- `scripts/env/toolchain/python/python_env_check.sh` should verify the Python-specific managed Flox venv layer
- `scripts/env/toolchain/swift/swift_env_check.sh` should verify the Swift-specific runtime/toolchain layer, where Swiftly owns Swift and Flox owns the surrounding project shell
- `scripts/env/toolchain/nix/nix_isolation_check.sh` must follow the current mount policy implemented in `common.sh`: mounted and usable `/nix` is required, but brittle source-root equality is not

So host-level verification tooling consistency is satisfied only when the
verification scripts reflect the current live workflow instead of older design
assumptions.

### 5.3 Formal “All Isolation Checks Pass” State

This is the strongest target state.

It means:
- runtime isolation checks succeed
- host-level verification scripts succeed
- no stale assumptions remain in the verification path
- the repository can claim not only that isolation works, but that its own
  formal checks prove it cleanly

At the time of writing, this formal target is met when the verification scripts below pass and the runtime proofs succeed.

## 6. How To Run The Verification

### 6.1 Baseline Repository Doctor

Run:

```bash
scripts/env/toolchain/doctor.sh
```

What it checks today:
- required repository paths exist
- `HOME` and `XDG_*` paths are under the repository root
- daemon profile and daemon socket exist when Nix/Flox wrappers are available
- forbidden byproducts such as `src/python/__pycache__` and `src/swift/.build` are absent

Expected result:

```text
doctor: OK
```

### 6.2 Environment Variable Inspection

Run:

```bash
scripts/env/toolchain/check_env.sh
```

Intended purpose:
- print the core isolation variables and daemon state

Current status:
- this script is now generic/common again
- it inspects the shared isolation layer from `scripts/env/toolchain/common.sh`
- it does not claim to prove Python or Swift runtime state by itself

### 6.3 Python Runtime Environment Check

Run:

```bash
scripts/env/toolchain/python/python_env_check.sh
```

Intended purpose:
- print the Python-specific managed Flox venv state directly

Expected outputs include:
- `FLOX_ENV`
- `FLOX_ENV_CACHE`
- `HYBRID_AI_PYTHON_VENV`
- `VIRTUAL_ENV`
- Python cache paths under `env/hybrid-ai/.flox/cache/`
- `sys.executable` under `env/hybrid-ai/.flox/cache/python/bin/python`

### 6.4 Swift Runtime Environment Check

Run:

```bash
scripts/env/toolchain/swift/swift_env_check.sh
```

Intended purpose:
- print the Swift-specific runtime/toolchain state directly

Expected outputs include:
- `swift_bin=/opt/bin/dev/swiftly/bin/swift`
- `clang_bin=/opt/bin/dev/swiftly/bin/clang`
- Swift `6.3.2`
- `SWIFTLY_ROOT=/opt/bin/dev/swiftly`
- `SWIFT_BUILD_PATH` under `build/swift`
- Swift cache/module-cache paths under `build/swift`

This check proves that Swift-specific tools come from Swiftly, not from Nix Swift packages. Flox still provides the shell and non-Swift native build inputs.

### 6.5 Host-Level Nix Isolation Check

Run:

```bash
scripts/env/toolchain/nix/nix_isolation_check.sh
```

Intended purpose:
- verify the `/nix` mount and the expected isolated-root behavior
- verify daemon socket and Determinate Nix install markers

Current status:
- this script now follows the current mount-validation policy: `/nix` must be mounted and usable, the daemon socket must be present, and kernel-reported mount-root mismatches are treated as warnings rather than false-failing the workflow

### 6.6 Python Runtime Isolation Proof

Run:

```bash
scripts/env/toolchain/python/python_run.sh -c 'import sys, os; print(sys.executable); print(os.environ["VIRTUAL_ENV"]); print(os.environ["PIP_CACHE_DIR"])'
scripts/env/toolchain/python/python_run.sh -c 'import numpy as np; values = np.array([1.0, 2.0, 3.0]); print(values.sum())'
```

Expected results:
- `sys.executable` points into `env/hybrid-ai/.flox/cache/python/bin/python`
- `VIRTUAL_ENV` points into `env/hybrid-ai/.flox/cache/python`
- Python caches point into `env/hybrid-ai/.flox/cache/`
- NumPy prints `6.0`

### 6.7 Swift Runtime Isolation Proof

Run:

```bash
scripts/env/toolchain/swift/swift_run.sh build
scripts/env/toolchain/swift/swift_run.sh run hybrid-ai-cli
scripts/env/toolchain/swift/swift_run.sh test
scripts/env/toolchain/nix/flox_with.sh bash -lc 'source scripts/env/toolchain/swift/swift_env.sh; hybrid_ai_activate_swift_env; command -v swift; command -v clang; printf "%s\n" "$SWIFT_BUILD_PATH"; printf "LD_LIBRARY_PATH=%s\n" "${LD_LIBRARY_PATH:-unset}"'
```

Expected results:
- `swift` resolves to `/opt/bin/dev/swiftly/bin/swift`
- `clang` resolves to `/opt/bin/dev/swiftly/bin/clang`
- `SWIFT_BUILD_PATH` points at `build/swift`
- `LD_LIBRARY_PATH` is unset or sanitized for Swiftly tools
- Swift build, run, and test use `build/swift` rather than `src/swift/.build`

Native build-time dependency proof:

```bash
flox activate -d env/hybrid-ai -- bash -lc 'source scripts/env/toolchain/swift/swift_env.sh; hybrid_ai_activate_swift_env; printf "CPATH=%s\n" "${CPATH:-unset}"; printf "LIBRARY_PATH=%s\n" "${LIBRARY_PATH:-unset}"; printf "PKG_CONFIG_PATH=%s\n" "${PKG_CONFIG_PATH:-unset}"; printf "LD_LIBRARY_PATH=%s\n" "${LD_LIBRARY_PATH:-unset}"'
```

Expected result:
- `CPATH`, `LIBRARY_PATH`, and `PKG_CONFIG_PATH` expose Flox/Nix build-time paths before host OS defaults
- `LD_LIBRARY_PATH` remains unset or sanitized so Swiftly does not load incompatible Flox/Nix runtime libraries

## 7. Current Expected Outcomes

### 7.1 What Should Pass Today

These checks should pass in the current setup:
- `scripts/env/toolchain/doctor.sh`
- `scripts/env/toolchain/check_env.sh`
- `scripts/env/toolchain/python/python_env_check.sh`
- `scripts/env/toolchain/swift/swift_env_check.sh`
- `scripts/env/toolchain/nix/nix_isolation_check.sh`
- Python wrapper/runtime isolation proofs
- NumPy import proof
- Swift path/build-path proof

Verified on 2026-06-04:
- `doctor.sh` passed after removing a generated `src/swift/.build` byproduct.
- `check_env.sh`, `python_env_check.sh`, `swift_env_check.sh`, and `nix_isolation_check.sh` passed.
- `nix_isolation_check.sh` emitted the expected mount metadata warning: kernel-reported root `/bin/dev/nix` differs from configured `/opt/bin/dev/nix`, but current policy only requires `/nix` to be mounted and usable.
- Python proof resolved `sys.executable` to `env/hybrid-ai/.flox/cache/python/bin/python`.
- NumPy proof printed `6.0`.
- Swift proof resolved `swift`, `swiftc`, and `clang` to `/opt/bin/dev/swiftly/bin/...`.
- Swift native build-time paths exposed Flox/Nix `CPATH`, `LIBRARY_PATH`, and `PKG_CONFIG_PATH`; `LD_LIBRARY_PATH` was unset.
- `scripts/env/toolchain/swift/swift_run.sh build`, `scripts/env/toolchain/swift/swift_run.sh run hybrid-ai-cli`, and `scripts/env/toolchain/swift/swift_run.sh test` passed.

## 8. Interpreting Results

### 8.1 Runtime Isolation Satisfied

This means:
- Python resolves into the intended Flox-managed venv path
- Swift resolves into the intended Swiftly-managed toolchain path from inside the Flox project environment
- writable runtime paths stay under the repository or `env/*/.flox`
- native Python extensions can load Flox-provided runtime libraries
- Swift native build-time resolution prefers Flox/Nix paths before host OS defaults, while Swift runtime dynamic library resolution avoids Flox/Nix `LD_LIBRARY_PATH`

### 8.2 Host-Level Verification Tooling Consistency Satisfied

This means:
- the runtime is correct
- and the verification scripts reflect the current managed Python venv model and current mount-validation policy

Warnings can still appear when kernel mount metadata reports an internal mount
root that differs from the configured isolated root path, but that no longer
blocks a passing verification result under the current policy.

### 8.3 Formal “All Isolation Checks Pass” Satisfied

This means:
- the strongest compliance target has been reached for the current policy
- more specifically, the runtime proofs pass and the repository verification scripts now align with the current managed Python venv model and current `/nix` mount-validation model

## 9. Failure Modes And Recovery

### 9.1 `doctor.sh` Fails

Meaning:
- required repository paths are missing, forbidden byproducts exist, or daemon prerequisites are missing

Recovery:
- read the specific failing message
- remove forbidden byproducts such as `src/swift/.build` if they were created outside wrappers
- restore the daemon socket if required

### 9.2 `check_env.sh` Fails With Unbound Variables

Meaning:
- the verification flow is no longer aligned with the managed Flox Python env or with the current shell state

Recovery:
- confirm Python runtime isolation with `scripts/env/toolchain/python/python_run.sh`
- verify Flox activation and daemon socket state
- update the verification script only if the live Python env model changes again

### 9.3 `nix_isolation_check.sh` Fails On Missing Function Or Source-Path Mismatch

Meaning:
- either the host mount/daemon prerequisites are genuinely broken or the host reports mount metadata that differs from the configured isolated-root path

Recovery:
- check daemon socket presence and `/nix` mount status separately
- treat mount-root mismatch warnings as informational under the current policy
- only treat the result as failed if `/nix` is not mounted, required install markers are missing, or the daemon prerequisites are absent

## 10. Definition Of Done For This Use Case

This use case is fully satisfied only when all of the following are true:
- `scripts/env/toolchain/doctor.sh` passes
- `scripts/env/toolchain/check_env.sh` passes and prints the common/shared env model correctly
- `scripts/env/toolchain/python/python_env_check.sh` passes and prints the Python runtime env correctly
- `scripts/env/toolchain/swift/swift_env_check.sh` passes and prints the Swiftly-backed Swift runtime env correctly
- `scripts/env/toolchain/nix/nix_isolation_check.sh` passes and reflects the current mount-validation model correctly
- Python runtime proof passes
- NumPy proof passes
- Swift runtime proof passes
- Swift build/run/test use `build/swift` and do not leave `src/swift/.build`

With these conditions met:
- runtime isolation is verified
- host-level verification tooling consistency is verified
- formal isolation verification is complete for the current policy

## 11. Relationship To Other Docs

Use this document when you want to prove end-to-end isolation compliance and
separate runtime correctness from verification-tool correctness.

Related documents:
- `docs/chat/determinate_nix_flox_setup.md`: host bootstrap and daemon runbook
- `docs/chat/devenv_portable_workflow.md`: high-level isolation design and requirements
- `docs/usecases/02-python-cli-and-server.md`: Python runtime workflow details
- `docs/usecases/03-swift-build-and-test.md`: Swift runtime workflow details