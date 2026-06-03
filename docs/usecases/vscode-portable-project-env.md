# Use Case: Start Portable VS Code Inside The Project Environment

Date: 2026-06-03
Status: Implemented
Primary script: `scripts/env/start_vscode.sh`

## 1. Goal

Start portable VS Code in a way that makes the editor process, extension host,
Copilot, Python extension, and Swift extension use the repository toolchain
instead of the host machine defaults.

For this repository, that means:
- the editor is launched through the composed Flox environment at `env/hybrid-ai`
- Python resolves to the Flox-managed Python runtime
- Swift resolves to the Flox-managed Swift toolchain
- the portable VS Code user-data root remains under `$HOME/appdata/.vscode/data`
- workspace-level VS Code settings continue to route task execution through the repository wrappers

## 2. Why This Workflow Exists

This repository deliberately isolates developer tooling from the host machine.

The normal command-line wrappers already do this:
- `scripts/env/run_python.sh`
- `scripts/env/run_py_server.sh`
- `scripts/env/run_swift.sh`
- `scripts/env/with_flox.sh`

However, editor extensions do not automatically inherit those wrappers just
because the workspace contains `.vscode/settings.json`.

Without a dedicated editor launch workflow, these problems can occur:
- the Python extension discovers a host interpreter instead of the project interpreter
- the Swift extension discovers a host toolchain instead of the project toolchain
- Copilot-generated commands, tasks, or debugging flows are evaluated in an editor process that was started outside the repository environment
- portable VS Code state and extension behavior become inconsistent between shells and the editor UI

The launcher script closes that gap by activating Flox first and only then
starting VS Code.

## 3. Scope And Assumptions

This workflow assumes:
- Determinate Nix is installed using the repository's manual-daemon bind-mounted host model
- the `/nix` mount is active and backed by `/opt/bin/dev/nix`
- the nix daemon socket exists at `/nix/var/nix/daemon-socket/socket`
- Flox is installed and the managed environment at `env/hybrid-ai/.flox` has already been initialized
- VS Code is installed in portable mode
- the portable VS Code user-data root is under `$HOME/appdata/.vscode/data`

This workflow does not attempt to install VS Code itself.

## 4. Files Involved

Core runtime files:
- `scripts/env/start_vscode.sh`
- `.vscode/settings.json`
- `.vscode/tasks.json`
- `.vscode/extensions.json`

Portable VS Code state:
- `$HOME/appdata/.vscode/data/User/settings.json`
- `$HOME/appdata/.vscode/data/extensions`

Supporting environment files:
- `scripts/env/toolchain/common.sh`
- `scripts/env/with_flox.sh`
- `env/hybrid-ai/manifest.toml`

## 5. Effective Behavior

When `scripts/env/start_vscode.sh` is used, the workflow does all of the
following before the editor opens:

1. Resolves the real host home directory from the user account instead of trusting an already-overridden `HOME`.
2. Sources `scripts/env/toolchain/common.sh`.
3. Enforces the active bind-mounted Determinate Nix layout.
4. Requires the nix daemon socket.
5. Resolves Flox and activates `env/hybrid-ai`.
6. Forces the portable VS Code user-data and extensions directories.
7. Launches the real VS Code binary inside the activated Flox environment.

As a result:
- `python` inside the editor environment comes from Flox
- `swift` inside the editor environment comes from Flox
- integrated terminals still inherit the repository workspace terminal environment settings
- Python and Swift extension paths remain pinned by `.vscode/settings.json`

## 6. Required VS Code Settings Context

The workspace settings do not replace user settings wholesale. VS Code merges
user settings and workspace settings by scope.

In this repository:
- portable user settings remain in `$HOME/appdata/.vscode/data/User/settings.json`
- workspace settings remain in `.vscode/settings.json`

The intended split is:
- user settings keep machine-specific editor preferences such as `remote.SSH.serverInstallPath`
- workspace settings pin repository-specific tool resolution such as `python.defaultInterpreterPath` and `swift.path`

This matters because the portable editor still needs its machine-level storage
configuration, while the repository needs to override interpreter/toolchain
selection for this workspace only.

## 7. How To Run It

### 7.1 Preferred Path

If the editor binary is already on `PATH`:

```bash
scripts/env/start_vscode.sh
```

This opens the current repository folder in portable VS Code.

### 7.2 Explicit Editor Binary Path

If the portable editor binary is not on `PATH`, set it explicitly:

```bash
VSCODE_BIN=/absolute/path/to/code scripts/env/start_vscode.sh
```

Examples of acceptable values:
- the portable `code` launcher binary
- a local `code-insiders` binary
- another VS Code-compatible launcher if that is what the portable install uses

### 7.3 Open A Different Folder Or Pass Arguments

Any extra arguments are passed through to the editor binary:

```bash
scripts/env/start_vscode.sh -- /home/nkse/projects/hybrid-ai
```

## 8. Verification Workflow

### 8.1 Preflight Without Opening The UI

Print the effective launch environment:

```bash
scripts/env/start_vscode.sh --print-env
```

This should show:
- `vscode_user_data_dir=/home/.../appdata/.vscode/data`
- `vscode_extensions_dir=/home/.../appdata/.vscode/data/extensions`
- a Flox-managed Python binary
- a Flox-managed Swift binary

Run the explicit preflight:

```bash
scripts/env/start_vscode.sh --check
```

This validates the same environment and additionally requires that the VS Code
binary can actually be resolved.

### 8.2 Verify From Inside VS Code

After the editor opens:

1. Run the task `vscode:print-env`.
2. Confirm the printed `python_bin` and `python_executable` point into `env/hybrid-ai/.flox/run/...`.
3. Confirm `swift_bin` points into `env/hybrid-ai/.flox/run/...`.
4. Confirm `vscode_user_data_dir` and `vscode_extensions_dir` point at the portable root under `$HOME/appdata/.vscode/data`.

### 8.3 Verify Workspace-Level Tool Pinning

Check these workspace settings:
- `.vscode/settings.json` sets `python.defaultInterpreterPath` to `python`
- `.vscode/settings.json` sets `swift.path` to `swift`

This means:
- extension-launched Python actions resolve to the Flox-managed Python interpreter from the activated editor `PATH`
- extension-launched Swift actions resolve to the Flox-managed Swift binary from the activated editor `PATH`
- Copilot-generated tasks remain aligned with repository scripts rather than host binaries

## 9. Expected Outcomes

When this workflow is working correctly:
- the editor process is launched from a shell that already activated Flox
- editor-side Python resolves to the project environment
- editor-side Swift resolves to the project environment
- user settings such as `remote.SSH.serverInstallPath` still come from the portable user settings file
- workspace settings override only the repository-specific keys that need pinning
- Copilot suggestions and generated commands are grounded in the same repository toolchain used by the wrappers and tasks

## 10. Failure Modes And Recovery

### 10.1 Missing Nix Daemon Socket

Symptom:
- `scripts/env/start_vscode.sh` fails before launch with a socket error

Recovery:

```bash
sudo /nix/var/nix/profiles/default/bin/nix-daemon
```

Then retry the launcher.

### 10.2 VS Code Binary Not Found

Symptom:
- `--check` reports that no VS Code executable was found

Recovery:
- set `VSCODE_BIN=/absolute/path/to/code`
- rerun `scripts/env/start_vscode.sh --check`

### 10.3 Portable Settings File Not Found

Symptom:
- the launcher warns that `$HOME/appdata/.vscode/data/User/settings.json` is missing

Meaning:
- the portable root exists, but the expected user settings file is absent or the portable install is laid out differently than assumed

Recovery:
- verify the portable VS Code layout on disk
- override `VSCODE_USER_DATA_DIR` if needed

### 10.4 Editor Uses Wrong Python Or Swift

Symptom:
- extension behavior suggests host Python or host Swift is being used

Checks:
- run `scripts/env/start_vscode.sh --print-env`
- run the `vscode:print-env` task inside the editor
- inspect `.vscode/settings.json`

Recovery:
- relaunch the editor with `scripts/env/start_vscode.sh`
- do not open the workspace from a host-launched editor window that bypasses the launcher

## 11. Relationship To The Other Docs

Use this document when you want the detailed operational workflow for the editor
startup path.

Use the following documents for broader context:
- `docs/chat/determinate_nix_flox_setup.md`: runbook for Determinate Nix, Flox, daemon, and repository wrappers
- `docs/chat/devenv_portable_workflow.md`: high-level architecture, portability model, and phased plan

## 12. Current Status In This Repository

Implemented now:
- `scripts/env/start_vscode.sh`
- workspace settings pinned to repository Python and Swift wrappers
- task `vscode:print-env`
- portable-root-aware editor documentation

Known limitation:
- the launcher can only auto-resolve the VS Code binary if it is on `PATH` or matches one of the expected portable locations; otherwise `VSCODE_BIN` must be provided explicitly