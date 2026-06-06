# hybrid-ai: Determinate Nix + Flox Setup Runbook

Date: 2026-06-03
Scope: Operational setup and maintenance runbook for the Linux manual-daemon Determinate Nix and Flox workflow used by `hybrid-ai`.

## 1. Purpose

This document is the operational companion to the portable workflow design.

It covers:
- the canonical Determinate Nix and Flox install procedure
- bind-mount persistence for `/nix -> /opt/bin/dev/nix`
- verification and cleanup steps
- practical learnings and pitfalls observed during live execution

For the higher-level environment design, module layout, and portability goals, see `docs/chat/devenv_portable_workflow.md`.

## 2. Canonical Host Model

The host model used by this repository is:
- logical Nix path: `/nix`
- physical backing path: `/opt/bin/dev/nix`
- mount model: bind mount `/opt/bin/dev/nix` onto `/nix`
- installer mode: Determinate Nix on Linux with `install linux --no-start-daemon`
- daemon model: the host Determinate Nix runtime must provide the daemon socket; project scripts validate it but do not start host services automatically
- Flox model: Flox installed on top of the Determinate Nix install and used through normal-user repository wrappers with `NIX_REMOTE=daemon`

Key constraints:
- persistent Nix store payload must not live on the root partition
- normal-user Nix and Flox commands depend on daemon socket availability
- the default developer workflow must not use a chroot store

## 3. Canonical Procedure

### 3.1 Preflight

1. Confirm `sudo` works for the current user.
2. Confirm no incompatible root-backed Nix install is present.
3. Confirm `/opt/bin/dev/nix` is the intended physical backing path.
4. Confirm `/nix` is either absent, empty, or already bind-mounted from `/opt/bin/dev/nix`.

Important behavior:
- the repository root-required helpers use `sudo -n`, not an interactive password prompt
- either run them as `root`, use a host with passwordless sudo for the required commands, or refresh the sudo timestamp first with `sudo -v`

If a stale or incompatible Nix install exists, use:
- `CONFIRM_REMOVE_ROOT_NIX=YES scripts/env/toolchain/nix/root_nix_remove.sh`

### 3.2 Bootstrap the Bind-Mount Layout

Run:

```bash
scripts/env/toolchain/nix/host_bootstrap.sh
```

What it does:
- creates the physical backing tree under `/opt/bin/dev/nix`
- creates `/nix` as the logical mountpoint
- bind-mounts `/opt/bin/dev/nix` onto `/nix`
- ensures `/etc/nix` exists for the Determinate installer

### 3.3 Install Determinate Nix

Run:

```bash
scripts/env/toolchain/nix/nix_determinate_install.sh
```

What it does:
- downloads the installer from `https://install.determinate.systems/nix`
- runs `install linux --no-confirm --no-modify-profile --diagnostic-endpoint="" --no-start-daemon`
- installs the real Determinate installer at `/nix/nix-installer`
- installs the Determinate Nix runtime under `/nix`
- creates convenience wrappers under `/opt/bin/dev/nix/bin`

Installed paths of interest:
- real installer: `/nix/nix-installer`
- receipt: `/nix/receipt.json`
- daemon profile script: `/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`
- daemon socket after the daemon is running: `/nix/var/nix/daemon-socket/socket`
- repo wrapper for `nix`: `/opt/bin/dev/nix/bin/nix`
- repo wrapper for `nix-installer`: `/opt/bin/dev/nix/bin/nix-installer`

### 3.4 Install Flox

Run:

```bash
scripts/env/toolchain/nix/flox_install.sh
```

What it does:
- installs Flox via the Determinate-provided Nix command set
- installs Flox into `/nix/var/nix/profiles/flox`
- creates a convenience wrapper at `/opt/bin/dev/nix/bin/flox`
- recreates the `nix` wrapper automatically if the reinstall removed it

### 3.5 Validate or Manually Start the Nix Daemon

Before using any normal-user wrapper, make sure the daemon socket exists. The
repository validates this prerequisite but does not start a host Nix service
automatically.

Check:

```bash
test -S /nix/var/nix/daemon-socket/socket && echo daemon_socket_present
```

Notes:
- if the socket is absent, start the daemon manually and keep it running while using normal-user Nix/Flox:

  ```bash
  sudo /nix/var/nix/profiles/default/bin/nix-daemon
  ```

- the repository wrappers only require the socket; they do not own the host service lifecycle
- `--no-start-daemon` means the installer does not launch a host service from this repository workflow

### 3.6 Initialize the Managed Flox Environment

Run:

```bash
scripts/env/toolchain/nix/flox_env_init.sh
```

What it does:
- requires the daemon socket and activates Flox as the current user
- initializes and syncs any included module environments under `env/*` before syncing the composed top-level environment
- initializes the root managed Flox environment at `.flox` if it does not exist yet
- syncs the repository manifest `.flox/env/manifest.toml` into the managed Flox environment
- fails fast with ownership repair instructions if stale root-owned cache or `.flox` state is still present from older workflows

### 3.7 Repository Bootstrap Shortcut

The combined workflow is:

```bash
scripts/env/toolchain/nix/toolchain_install.sh
```

Expectation:
- treat this as a convenience/resume helper, not as the primary onboarding path
- this shortcut now assumes the daemon socket is already available before it reaches `scripts/env/toolchain/nix/flox_env_init.sh`
- if the socket is absent, the script stops with a host-prerequisite error and prints the manual daemon command
- on a fresh machine this usually means the first run gets through bootstrap, Determinate Nix install, and Flox install, then stops at the daemon-socket check; start the daemon manually with `sudo /nix/var/nix/profiles/default/bin/nix-daemon`, then rerun `scripts/env/toolchain/nix/toolchain_install.sh` or continue with `scripts/env/toolchain/nix/flox_env_init.sh`

It runs, in order:
1. `scripts/env/toolchain/nix/host_bootstrap.sh`
2. `scripts/env/toolchain/nix/nix_determinate_install.sh`
3. `scripts/env/toolchain/nix/flox_install.sh`
4. daemon socket availability check
5. `scripts/env/toolchain/nix/flox_env_init.sh`
6. `scripts/env/toolchain/nix/nix_isolation_check.sh`
7. `scripts/env/toolchain/doctor.sh`

### 3.8 Verification

Verification commands:

```bash
scripts/env/toolchain/check_env.sh
scripts/env/toolchain/python/python_env_check.sh
scripts/env/toolchain/swift/swift_env_check.sh
scripts/env/toolchain/nix/nix_isolation_check.sh
scripts/env/toolchain/doctor.sh
test -S /nix/var/nix/daemon-socket/socket && echo daemon_socket_present
scripts/env/toolchain/python/python_run.sh -c 'import sys; print(sys.executable)'
scripts/env/toolchain/python/python_run.sh -c 'import numpy as np; values = np.array([1.0, 2.0, 3.0]); print(values.sum())'
scripts/env/toolchain/nix/flox_with.sh swift --version
```

Expected outcomes:
- the shared isolation layer reports project-local `HOME` and `XDG_*` paths
- the Python runtime verifier reports the managed Flox venv under `.flox/cache/python`
- the Swift runtime verifier reports the Swiftly-managed Swift toolchain and `build/swift` paths inside the Flox project environment
- `/nix` is bind-mounted from `/opt/bin/dev/nix`
- `/nix/nix-installer` exists
- `/nix/receipt.json` exists
- the daemon socket is present
- Python resolves to the managed Flox venv under `.flox/cache/python`
- NumPy native extensions load successfully from the Flox-managed runtime (`6.0` proof)
- `swift` resolves to `/opt/bin/dev/swiftly/bin` inside the Flox environment

## 4. Bind-Mount Persistence

### 4.1 Check or Print the Canonical fstab Entry

```bash
scripts/env/toolchain/nix/nix_fstab_manage.sh status
scripts/env/toolchain/nix/nix_fstab_manage.sh print
```

Canonical entry:

```fstab
/opt/bin/dev/nix /nix none bind 0 0
```

### 4.2 Install the Entry

```bash
CONFIRM_WRITE_FSTAB=YES scripts/env/toolchain/nix/nix_fstab_manage.sh install
```

Behavior:
- checks for conflicts on `/nix`
- writes a backup of `/etc/fstab`
- appends the canonical entry only once

### 4.3 Remove the Entry

```bash
CONFIRM_REMOVE_FSTAB=YES scripts/env/toolchain/nix/nix_fstab_manage.sh remove
```

## 5. Cleanup and Recovery

### 5.1 Remove Incompatible Root-Backed Nix Leftovers

```bash
CONFIRM_REMOVE_ROOT_NIX=YES scripts/env/toolchain/nix/root_nix_remove.sh
```

Use this for:
- legacy root-backed `/nix` installs
- stale `/etc/nix` and related profile hooks
- leftover root-managed Nix artifacts that are not part of the bind-mounted `/opt/bin/dev/nix` workflow

### 5.2 Check Bind-Mount State

```bash
scripts/env/toolchain/nix/nix_mount_manage.sh status
```

### 5.3 Non-Destructive Uninstall/Reinstall Check

```bash
scripts/env/toolchain/nix/determinate_cycle_test.sh
scripts/env/toolchain/nix/determinate_cycle_test.sh --download-installer
```

Behavior:
- validates the active bind mount
- reports wrapper and receipt state
- runs `nix-installer uninstall --explain` when an installed installer exists
- can prepare an installer-side preflight for a reinstall path

## 6. User Manual

### 6.1 Day-to-Day Usage

Enter the environment:

```bash
scripts/env/toolchain/nix/flox_enter.sh
```

If `scripts/env/toolchain/nix/flox_enter.sh` or `scripts/env/toolchain/nix/flox_with.sh` reports a missing daemon socket, start the daemon manually first:

```bash
sudo /nix/var/nix/profiles/default/bin/nix-daemon
```

Project scripts do not start host Nix services automatically.

Run one command inside the Flox environment:

```bash
scripts/env/toolchain/python/python_run.sh -c 'import sys; print(sys.executable)'
scripts/env/toolchain/nix/flox_with.sh swift --version
```

Dedicated environment verification helpers:

```bash
scripts/env/toolchain/check_env.sh
scripts/env/toolchain/python/python_env_check.sh
scripts/env/toolchain/swift/swift_env_check.sh
```

Canonical Python shell workflow:

```bash
flox activate
cd src/python
python -m hybrid_ai.hello_world
```

Notes:
- `flox activate` from the repository root is now the canonical interactive Python shell entry point
- the managed Python venv lives under `.flox/cache/python`
- repository Python wrappers source `scripts/env/toolchain/python/python_env.sh` so non-activated shells reach the same managed venv and runtime-library setup

Use task-specific wrappers:

```bash
scripts/env/toolchain/python/python_run.sh ...
scripts/env/toolchain/python/python_server_run.sh ...
scripts/env/toolchain/swift/swift_run.sh ...
scripts/env/run_inference_local.sh "healthcheck"
```

Launch portable VS Code through the repository wrapper so the editor process,
extension host, Copilot, Python extension, and Swift extension inherit the
Flox-managed toolchain:

```bash
scripts/env/start_vscode.sh
```

If the portable editor binary is not on `PATH`, set it explicitly:

```bash
VSCODE_BIN=/absolute/path/to/code scripts/env/start_vscode.sh
```

Portable directory defaults used by the wrapper:
- user data: `$HOST_HOME/appdata/.vscode/data`
- extensions: `$HOST_HOME/appdata/.vscode/data/extensions`
- portable settings file: `$HOST_HOME/appdata/.vscode/data/User/settings.json`

Detailed workflow document:
- `docs/usecases/01-vscode-portable-project-env.md`

Verify the editor launch environment before opening the UI:

```bash
scripts/env/start_vscode.sh --print-env
scripts/env/start_vscode.sh --check
```

Inside VS Code, the repository workspace settings and tasks continue to pin tool
execution to the repository wrappers:
- `.vscode/settings.json` points editor extensions at `python` and `swift` from the launcher-activated `PATH`
- `.vscode/tasks.json` keeps task execution pinned to repository wrappers such as `scripts/env/toolchain/python/python_run.sh` and `scripts/env/toolchain/swift/swift_run.sh`
- `.vscode/tasks.json` exposes `vscode:print-env` to print the live editor toolchain and portable data roots after launch
- `scripts/env/start_vscode.sh` activates the root `.flox` environment, then sources `scripts/env/toolchain/python/python_env.sh` and `scripts/env/toolchain/swift/swift_env.sh` before launching the editor, so editor-side `python` resolves to the managed venv and `swift` resolves to Swiftly
- Python CLI/server and native-extension verification should still use the wrappers for repeatable command-line checks, but the editor launch path now shares the same managed Python venv activation model

### 6.2 Learnings and Pitfalls From This Session

#### Bind-Mount Validation

- A stricter source-root comparison produced false negatives on this host because kernel mount metadata reported an internal subtree path rather than a visible host pathname.
- The current workflow now only requires that `/nix` is mounted and that the daemon socket exists before wrapper-based commands proceed.
- Practical implication: bind-mount health is still verified, but wrappers no longer reject the environment based on a brittle source-path equality check.

#### Empty `/nix` Is Not a Completed Install

- An empty `/nix` directory is only a mountpoint candidate.
- A completed Determinate install is indicated by `/nix/nix-installer` and `/nix/receipt.json`.
- If those files are missing, treat the setup as incomplete even if `/nix` exists.

#### Manual-Daemon Determinate Nix Makes User Tooling Depend On The Socket

- The repository no longer uses the daemonless `--init none` install.
- Normal-user wrappers now depend on `/nix/var/nix/daemon-socket/socket` being present.
- `scripts/env/toolchain/nix/flox_with.sh` and `scripts/env/toolchain/nix/flox_env_init.sh` fail fast when the socket is absent so they do not silently fall back to a root shell.
- If the daemon process exits or the host reboots without restarting it, normal-user Nix and Flox commands stop working until the socket is restored.

#### Flox Managed Environments Need Initialization

- Installing Flox alone is not enough.
- `flox init` creates the root `.flox` environment and any directly activated module environments under `env/*/.flox`.
- The repository manifests have to be explicitly synced into those managed Flox environments before the root composed top-level environment can be refreshed cleanly.
- This is now automated by `scripts/env/toolchain/nix/flox_env_init.sh`.

#### Python Now Uses A Flox-Managed Venv

- The canonical Python runtime is no longer a project-local `.venv` under `src/python`.
- The managed venv now lives under `.flox/cache/python` and is created/synced by Flox hooks via `scripts/env/toolchain/python/python_env.sh`.
- Direct shell usage works through `flox activate` from the repository root; wrapper-based usage works through `scripts/env/toolchain/python/python_run.sh` and `scripts/env/toolchain/python/python_server_run.sh`.
- Python package caches and bytecode now live under `.flox/cache/*`, not under `build/python/*`.

#### Host-Derived `LD_LIBRARY_PATH` Was The Wrong Fix Layer

- Earlier iterations tried to export `LD_LIBRARY_PATH` from host `g++` inside `scripts/env/toolchain/common.sh`.
- That polluted shell runtime linking and contributed to wrapper failures.
- The working model is now: declare the native runtime in Flox (`libgcc` in the active composed environment) and export the runtime library path from the Flox-managed Python helper instead of deriving it from the host compiler.
- After this change, NumPy imports successfully through both the wrapper path and the activated-shell path.

#### Root-Owned Flox Cache State Causes Permission Errors

- Older root-oriented revisions of this workflow created root-owned directories under `build/xdg/*/flox` and sometimes under `.flox`.
- The current user-mode initialization path does not auto-`chown`; it stops and tells you exactly what to repair.
- This keeps the normal path unprivileged while still allowing recovery from older state.

Exact recovery steps:

```bash
sudo chown -R "$(id -un)":"$(id -gn)" build/xdg/config/flox build/xdg/cache/flox build/xdg/data/flox
sudo chown -R "$(id -un)":"$(id -gn)" .flox
```

How to verify ownership is fixed:

```bash
find build/xdg -maxdepth 3 -path '*/flox*' -printf '%u:%g %p\n'
find .flox -maxdepth 3 -printf '%u:%g %p\n'
```

If Git was failing on `.flox/env/manifest.lock`, verify specifically with:

```bash
ls -l .flox/env/manifest.lock
```

Expected owner:
- your login user and primary group, not `root:root`

#### Managed `.flox` State Must Stay Local

- The root `.flox` directory contains managed runtime state created by Flox.
- It is not the declarative project source of truth.
- The declarative source of truth is `.flox/env/manifest.toml` plus the included module manifests.
- The managed `.flox` directory should be treated like cache or generated environment metadata, not committed repository content.

Exact rules to follow:

1. Commit `.flox/env/manifest.toml` and `.flox/env.json`.
2. Do not commit generated root `.flox` state such as `.flox/cache`, `.flox/run`, or `.flox/env/manifest.lock`.
3. If you change the environment definition, sync the managed environment from the manifest instead of editing `.flox` files by hand.

Repository protection already in place:

```gitignore
.flox/*
!.flox/env.json
!.flox/env/
.flox/env/*
!.flox/env/manifest.toml
```

How to check Git will ignore the managed directory:

```bash
git check-ignore -v .flox/env/manifest.lock
git status --short .flox
```

Expected result:
- `git check-ignore` reports the `.gitignore` rule
- `git status` does not show `.flox` contents as tracked changes

If `.flox` was already staged accidentally:

```bash
git restore --staged .flox/cache .flox/run .flox/env/manifest.lock
```

If `.flox` was committed previously and must be removed from the index while keeping local files:

```bash
git rm -r --cached .flox/cache .flox/run .flox/env/manifest.lock
```

Then confirm the ignore rule is present and commit that cleanup.

Safe workflow when changing the environment:

```bash
# edit the declarative manifest
$EDITOR .flox/env/manifest.toml

# sync the managed environment from the manifest
scripts/env/toolchain/nix/flox_env_init.sh

# verify the tools you care about
scripts/env/toolchain/nix/flox_with.sh python --version
scripts/env/toolchain/nix/flox_with.sh swift --version
```

Pitfall note:
- If you still run Flox operations with `sudo` and do not normalize ownership afterward, both Git and user-mode Flox commands can fail on `.flox/env/manifest.lock` or related metadata.
- If `git add .` or `git commit` reports permission errors inside `.flox`, treat that as a local state ownership problem, not as a project-file problem.

#### Reinstalling Determinate Nix Removes Flox Until You Restore It

- The daemon-capable reinstall restored the base Determinate Nix profile but removed the Flox profile and convenience wrappers.
- If `scripts/env/toolchain/nix/flox_with.sh` fails with `flox is required but not installed or not in PATH`, reinstall Flox before debugging the wrapper layer.
- `scripts/env/toolchain/nix/flox_install.sh` now recreates the `nix` wrapper automatically when the base Nix binary exists but `/opt/bin/dev/nix/bin/nix` was removed during reinstall.

Recovery sequence:

```bash
scripts/env/toolchain/nix/flox_install.sh
test -S /nix/var/nix/daemon-socket/socket && echo daemon_socket_present
scripts/env/toolchain/nix/flox_with.sh python --version
```

#### fstab Persistence Should Be Explicit and Backed Up

- Writing the bind-mount entry to `/etc/fstab` should never be implicit.
- `scripts/env/toolchain/nix/nix_fstab_manage.sh` requires explicit confirmation and creates a timestamped backup before modification.

#### Stale Mounts Can Look Like Real Installs

- A stale `/nix` bind mount from the wrong backing path can coexist with no actual installer, no receipt, and no Nix wrappers.
- Before assuming Nix is installed, always inspect:
  - `/nix/nix-installer`
  - `/nix/receipt.json`
  - `/opt/bin/dev/nix/bin/nix`

#### Legacy nix-portable State Can Leave Read-Only Trees

- Older revisions of this repository used `nix-portable` with `HOME` redirected to `build/home`.
- That can leave behind `build/home/.nix-portable` and `build/home/.nix-profile` even after the repository switches to Determinate Nix.
- The `nix-portable` store content may be user-owned but marked read-only like a Nix store, so plain `rm -rf` can fail with `Permission denied`.
- If cleanup is needed, restore user write bits first and then remove the legacy tree.

Example cleanup:

```bash
chmod -R u+w build/home/.nix-portable
rm -rf build/home/.nix-portable
rm -f build/home/.nix-profile
```

#### Installer Self-Test Warnings Do Not Always Mean Install Failure

- During the live install, the Determinate installer reported self-test warnings related to shell execution.
- Despite those warnings, the install still completed successfully and produced working wrappers, receipt, and runtime.
- Treat those warnings as signals to verify the installed paths rather than as automatic install failure.

### 6.3 Recommended Fresh-Machine Command Sequence

```bash
sudo -v
scripts/env/toolchain/nix/host_bootstrap.sh
scripts/env/toolchain/nix/nix_determinate_install.sh
scripts/env/toolchain/nix/flox_install.sh
# if needed, manually start: sudo /nix/var/nix/profiles/default/bin/nix-daemon
scripts/env/toolchain/nix/flox_env_init.sh
scripts/env/toolchain/nix/nix_isolation_check.sh
scripts/env/toolchain/doctor.sh
scripts/env/toolchain/nix/flox_with.sh python --version
scripts/env/toolchain/nix/flox_with.sh swift --version
```

Optional persistence:

```bash
CONFIRM_WRITE_FSTAB=YES scripts/env/toolchain/nix/nix_fstab_manage.sh install
```

Fresh-machine note:
- `scripts/env/toolchain/nix/toolchain_install.sh` is a convenience shortcut, but on a fresh machine the explicit step-by-step sequence above is the most predictable path
- if you prefer the shortcut and it stops on a missing daemon socket, start the daemon manually with `sudo /nix/var/nix/profiles/default/bin/nix-daemon` and rerun `scripts/env/toolchain/nix/flox_env_init.sh` or the full shortcut