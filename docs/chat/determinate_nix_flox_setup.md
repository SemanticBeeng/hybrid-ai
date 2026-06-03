# hybrid-ai: Determinate Nix + Flox Setup Runbook

Date: 2026-06-03
Scope: Operational setup and maintenance runbook for the Linux daemonless Determinate Nix and Flox workflow used by `hybrid-ai`.

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
- installer mode: Determinate Nix on Linux with `install linux --init none`
- Flox model: Flox installed on top of the Determinate Nix install and used through repository wrappers

Key constraints:
- persistent Nix store payload must not live on the root partition
- daemonless Linux operation is root-oriented in practice
- the default developer workflow must not use a chroot store

## 3. Canonical Procedure

### 3.1 Preflight

1. Confirm `sudo` works for the current user.
2. Confirm no incompatible root-backed Nix install is present.
3. Confirm `/opt/bin/dev/nix` is the intended physical backing path.
4. Confirm `/nix` is either absent, empty, or already bind-mounted from `/opt/bin/dev/nix`.

If a stale or incompatible Nix install exists, use:
- `CONFIRM_REMOVE_ROOT_NIX=YES scripts/env/remove_root_nix.sh`

### 3.2 Bootstrap the Bind-Mount Layout

Run:

```bash
scripts/env/bootstrap_host.sh
```

What it does:
- creates the physical backing tree under `/opt/bin/dev/nix`
- creates `/nix` as the logical mountpoint
- bind-mounts `/opt/bin/dev/nix` onto `/nix`
- ensures `/etc/nix` exists for the Determinate installer

### 3.3 Install Determinate Nix

Run:

```bash
scripts/env/install_nix_determinate.sh
```

What it does:
- downloads the installer from `https://install.determinate.systems/nix`
- runs `install linux --init none --no-confirm --no-modify-profile --diagnostic-endpoint=""`
- installs the real Determinate installer at `/nix/nix-installer`
- installs the Determinate Nix runtime under `/nix`
- creates convenience wrappers under `/opt/bin/dev/nix/bin`

Installed paths of interest:
- real installer: `/nix/nix-installer`
- receipt: `/nix/receipt.json`
- repo wrapper for `nix`: `/opt/bin/dev/nix/bin/nix`
- repo wrapper for `nix-installer`: `/opt/bin/dev/nix/bin/nix-installer`

### 3.4 Install Flox

Run:

```bash
scripts/env/install_flox.sh
```

What it does:
- installs Flox via the Determinate-provided Nix command set
- installs Flox into `/nix/var/nix/profiles/flox`
- creates a convenience wrapper at `/opt/bin/dev/nix/bin/flox`

### 3.5 Initialize the Managed Flox Environment

Run:

```bash
scripts/env/init_flox_env.sh
```

What it does:
- repairs Flox cache ownership in `build/xdg/*/flox` when prior root operations created root-owned cache files
- initializes a managed Flox environment at `env/hybrid-ai/.flox` if it does not exist yet
- syncs the repository manifest `env/hybrid-ai/manifest.toml` into the managed Flox environment
- realizes the environment as root, which is required for the daemonless Determinate setup

### 3.6 Full One-Shot Install

The combined workflow is:

```bash
scripts/env/install_toolchain.sh
```

It runs, in order:
1. `scripts/env/bootstrap_host.sh`
2. `scripts/env/install_nix_determinate.sh`
3. `scripts/env/install_flox.sh`
4. `scripts/env/init_flox_env.sh`
5. `scripts/verify/check_nix_isolation.sh`
6. `scripts/verify/doctor.sh`

### 3.7 Verification

Verification commands:

```bash
scripts/verify/check_nix_isolation.sh
scripts/verify/doctor.sh
scripts/env/with_flox.sh python --version
scripts/env/with_flox.sh swift --version
```

Expected outcomes:
- `/nix` is bind-mounted from `/opt/bin/dev/nix`
- `/nix/nix-installer` exists
- `/nix/receipt.json` exists
- `python` resolves inside the Flox environment
- `swift` resolves inside the Flox environment

## 4. Bind-Mount Persistence

### 4.1 Check or Print the Canonical fstab Entry

```bash
scripts/env/manage_nix_fstab.sh status
scripts/env/manage_nix_fstab.sh print
```

Canonical entry:

```fstab
/opt/bin/dev/nix /nix none bind 0 0
```

### 4.2 Install the Entry

```bash
CONFIRM_WRITE_FSTAB=YES scripts/env/manage_nix_fstab.sh install
```

Behavior:
- checks for conflicts on `/nix`
- writes a backup of `/etc/fstab`
- appends the canonical entry only once

### 4.3 Remove the Entry

```bash
CONFIRM_REMOVE_FSTAB=YES scripts/env/manage_nix_fstab.sh remove
```

## 5. Cleanup and Recovery

### 5.1 Remove Incompatible Root-Backed Nix Leftovers

```bash
CONFIRM_REMOVE_ROOT_NIX=YES scripts/env/remove_root_nix.sh
```

Use this for:
- legacy root-backed `/nix` installs
- stale `/etc/nix` and related profile hooks
- leftover root-managed Nix artifacts that are not part of the bind-mounted `/opt/bin/dev/nix` workflow

### 5.2 Check Bind-Mount State

```bash
scripts/env/manage_nix_mount.sh status
```

### 5.3 Non-Destructive Uninstall/Reinstall Check

```bash
scripts/env/test_determinate_cycle.sh
scripts/env/test_determinate_cycle.sh --download-installer
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
scripts/env/enter.sh
```

Run one command inside the Flox environment:

```bash
scripts/env/with_flox.sh python --version
scripts/env/with_flox.sh swift --version
```

Use task-specific wrappers:

```bash
scripts/env/run_python.sh ...
scripts/env/run_py_server.sh ...
scripts/env/run_swift.sh ...
scripts/env/run_inference_local.sh "healthcheck"
```

### 6.2 Learnings and Pitfalls From This Session

#### Bind-Mount Validation

- On this host, `findmnt -o ROOT` was not usable for determining whether `/nix` was correctly bind-mounted.
- The reliable test was device/inode identity between `/nix` and `/opt/bin/dev/nix`.
- The scripts now validate the bind mount using `stat -Lc '%d:%i'` rather than depending on `findmnt` root output.

#### Empty `/nix` Is Not a Completed Install

- An empty `/nix` directory is only a mountpoint candidate.
- A completed Determinate install is indicated by `/nix/nix-installer` and `/nix/receipt.json`.
- If those files are missing, treat the setup as incomplete even if `/nix` exists.

#### Daemonless Determinate Nix Is Root-Oriented

- On Linux with `--init none`, environment realization and Nix store operations effectively need root privileges.
- This impacts Flox environment realization, not just the initial Determinate install.
- The helper scripts therefore use `sudo` for installation and activation-sensitive paths.

#### Flox Managed Environments Need Initialization

- Installing Flox alone is not enough.
- `flox init` created a managed environment under `env/hybrid-ai/.flox`, and that managed environment had its own manifest.
- The repository manifest had to be explicitly synced into the managed Flox environment.
- This is now automated by `scripts/env/init_flox_env.sh`.

#### Root-Owned Flox Cache State Causes Permission Errors

- Running Flox as root against project-local XDG paths created root-owned directories under `build/xdg/*/flox`.
- Subsequent user-mode Flox commands failed with permission errors until ownership was repaired.
- The initialization helper now repairs ownership before sync.

Exact recovery steps:

```bash
sudo chown -R "$(id -un)":"$(id -gn)" build/xdg/config/flox build/xdg/cache/flox build/xdg/data/flox
sudo chown -R "$(id -un)":"$(id -gn)" env/hybrid-ai/.flox
```

How to verify ownership is fixed:

```bash
find build/xdg -maxdepth 3 -path '*/flox*' -printf '%u:%g %p\n'
find env/hybrid-ai/.flox -maxdepth 3 -printf '%u:%g %p\n'
```

If Git was failing on `.flox/env/manifest.lock`, verify specifically with:

```bash
ls -l env/hybrid-ai/.flox/env/manifest.lock
```

Expected owner:
- your login user and primary group, not `root:root`

#### Managed `.flox` State Must Stay Local

- The directory `env/hybrid-ai/.flox` is managed runtime state created by Flox.
- It is not the declarative project source of truth.
- The declarative source of truth is `env/hybrid-ai/manifest.toml`.
- The managed `.flox` directory should be treated like cache or generated environment metadata, not committed repository content.

Exact rules to follow:

1. Commit `env/hybrid-ai/manifest.toml`.
2. Do not commit `env/hybrid-ai/.flox/`.
3. If you change the environment definition, sync the managed environment from the manifest instead of editing `.flox` files by hand.

Repository protection already in place:

```gitignore
env/*/.flox/
```

How to check Git will ignore the managed directory:

```bash
git check-ignore -v env/hybrid-ai/.flox/env/manifest.lock
git status --short env/hybrid-ai/.flox
```

Expected result:
- `git check-ignore` reports the `.gitignore` rule
- `git status` does not show `.flox` contents as tracked changes

If `.flox` was already staged accidentally:

```bash
git restore --staged env/hybrid-ai/.flox
```

If `.flox` was committed previously and must be removed from the index while keeping local files:

```bash
git rm -r --cached env/hybrid-ai/.flox
```

Then confirm the ignore rule is present and commit that cleanup.

Safe workflow when changing the environment:

```bash
# edit the declarative manifest
$EDITOR env/hybrid-ai/manifest.toml

# sync the managed environment from the manifest
scripts/env/init_flox_env.sh

# verify the tools you care about
scripts/env/with_flox.sh python --version
scripts/env/with_flox.sh swift --version
```

Pitfall note:
- If you run Flox operations with `sudo` and do not normalize ownership afterward, both Git and user-mode Flox commands can fail on `.flox/env/manifest.lock` or related metadata.
- If `git add .` or `git commit` reports permission errors inside `.flox`, treat that as a local state ownership problem, not as a project-file problem.

#### fstab Persistence Should Be Explicit and Backed Up

- Writing the bind-mount entry to `/etc/fstab` should never be implicit.
- `scripts/env/manage_nix_fstab.sh` requires explicit confirmation and creates a timestamped backup before modification.

#### Stale Mounts Can Look Like Real Installs

- A stale `/nix` bind mount from the wrong backing path can coexist with no actual installer, no receipt, and no Nix wrappers.
- Before assuming Nix is installed, always inspect:
  - `/nix/nix-installer`
  - `/nix/receipt.json`
  - `/opt/bin/dev/nix/bin/nix`

#### Installer Self-Test Warnings Do Not Always Mean Install Failure

- During the live install, the Determinate installer reported self-test warnings related to shell execution.
- Despite those warnings, the install still completed successfully and produced working wrappers, receipt, and runtime.
- Treat those warnings as signals to verify the installed paths rather than as automatic install failure.

### 6.3 Recommended Fresh-Machine Command Sequence

```bash
scripts/env/bootstrap_host.sh
scripts/env/install_toolchain.sh
scripts/verify/check_nix_isolation.sh
scripts/verify/doctor.sh
scripts/env/with_flox.sh python --version
scripts/env/with_flox.sh swift --version
```

Optional persistence:

```bash
CONFIRM_WRITE_FSTAB=YES scripts/env/manage_nix_fstab.sh install
```