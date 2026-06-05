# Use Case 01: Start Portable VS Code Inside The Project Environment

Date: 2026-06-03
Status: Implemented
Primary script: `scripts/env/start_vscode.sh`

## 1. Goal

Start portable VS Code in a way that makes the editor process, extension host,
Copilot, Python extension, and Swift extension use the repository toolchain
instead of the host machine defaults.

For this repository, that means:
- the editor is launched through the root-attached composed Flox environment at `.flox/env/manifest.toml`
- Python resolves to the managed venv under `.flox/cache/python`
- Python CLI, server, editor, and native-extension workflows share the same managed venv activation helper
- Swift resolves to the Swiftly-managed Swift toolchain activated inside the Flox project environment
- the portable VS Code user-data root remains under `$HOME/appdata/.vscode/data`
- workspace-level VS Code settings continue to route task execution through the repository wrappers

## 2. Why This Workflow Exists

This repository deliberately isolates developer tooling from the host machine.

The normal command-line wrappers already do this:
- `scripts/env/toolchain/python/python_run.sh`
- `scripts/env/toolchain/python/python_server_run.sh`
- `scripts/env/toolchain/swift/swift_run.sh`
- `scripts/env/toolchain/nix/flox_with.sh`

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
- Flox is installed and the root-attached managed environment under `.flox` has already been initialized
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
- `scripts/env/toolchain/vscode_paths.sh`
- `scripts/env/toolchain/nix/nix_flox_env.sh`
- `scripts/env/toolchain/python/python_env.sh`
- `scripts/env/toolchain/swift/swift_env.sh`
- `scripts/env/toolchain/nix/flox_with.sh`
- `.flox/env/manifest.toml`

Design boundary:
- `common.sh` is the full-session compatibility aggregator used by the launcher and interactive shells.
- `vscode_paths.sh` owns portable VS Code paths and binary resolution.
- `python_env.sh` owns Python venv setup, host-venv cleanup, cache paths, dependency sync, and activation.
- `swift_env.sh` owns Swiftly activation and sources the Swift build/cache path module internally.
- Flox manifests source the narrow concern modules they need instead of sourcing `common.sh`.

## 5. Effective Behavior

When `scripts/env/start_vscode.sh` is used, the workflow does all of the
following before the editor opens:

1. Resolves the real host home directory from the user account instead of trusting an already-overridden `HOME`.
2. Sources `scripts/env/toolchain/common.sh`.
3. Enforces the active bind-mounted Determinate Nix layout.
4. Requires the nix daemon socket.
5. Resolves Flox and ensures the root-attached fullstack environment is ready.
6. Forces the portable VS Code user-data and extensions directories.
7. Activates the root-attached fullstack environment, then sources `python_env.sh` and `swift_env.sh` inside that activation.
8. Activates the managed Python venv and Swiftly toolchain before launching the real VS Code binary.

As a result:
- `python` inside the editor environment comes from `.flox/cache/python`
- `swift` inside the editor environment comes from `/opt/bin/dev/swiftly/bin` after Swiftly activation
- integrated terminals still inherit the repository workspace terminal environment settings
- Python and Swift extension paths remain pinned by `.vscode/settings.json`

Important current split:
- the editor process starts inside the composed Flox environment
- the managed Python venv under `.flox/cache/python` is the canonical runtime for Python CLI, server, editor, and native-extension workflows
- wrapper-based Python commands, activated Flox shells, and the VS Code launcher source `scripts/env/toolchain/python/python_env.sh` to activate that managed venv
- Swift workflows source `scripts/env/toolchain/swift/swift_env.sh`, which activates Swiftly and applies Swift build/cache path policy

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
- a Swiftly-managed Swift binary activated inside the Flox project environment

Run the explicit preflight:

```bash
scripts/env/start_vscode.sh --check
```

This validates the same environment and additionally requires that the VS Code
binary can actually be resolved.

### 8.2 Verify From Inside VS Code

After the editor opens:

1. Run the task `vscode:print-env`.
2. Confirm the printed `python_bin` and `python_executable` point into `.flox/cache/python`.
3. Confirm `swift_bin` points into `/opt/bin/dev/swiftly/bin`.
4. Confirm `vscode_user_data_dir` and `vscode_extensions_dir` point at the portable root under `$HOME/appdata/.vscode/data`.

### 8.3 Verify Workspace-Level Tool Pinning

Check these workspace settings:
- `.vscode/settings.json` sets `python.defaultInterpreterPath` to `python`
- `.vscode/settings.json` sets `swift.path` to `swift`

This means:
- extension-launched Python actions resolve to the managed venv interpreter from the activated editor `PATH`
- extension-launched Swift actions resolve to the Swiftly-managed Swift binary from the activated editor `PATH`
- Copilot-generated tasks remain aligned with repository scripts rather than host binaries

Current Python nuance:
- `.vscode/settings.json` intentionally points to `python`, not directly to `.flox/cache/python/bin/python`
- this keeps the editor aligned with the activated launcher environment while avoiding direct extension reliance on the CLI/server wrapper scripts
- the launcher activates the managed venv before starting VS Code, so `python` resolves to the same runtime used by wrapper-based Python commands and native-extension checks such as NumPy

## 9. Expected Outcomes

When this workflow is working correctly:
- the editor process is launched from a shell that already activated Flox
- editor-side Python resolves to the managed Flox venv
- editor-side Swift resolves to the Swiftly-managed toolchain inside the project environment
- user settings such as `remote.SSH.serverInstallPath` still come from the portable user settings file
- workspace settings override only the repository-specific keys that need pinning
- Copilot suggestions and generated commands are grounded in the same repository toolchain used by the wrappers and tasks
- Python CLI/server commands remain reproducible because the repository wrappers, activated Flox shells, and VS Code launcher all source the managed Python helper before running Python code

## 10. Failure Modes And Recovery

### 10.1 Missing Nix Daemon Socket

Symptom:
- `scripts/env/start_vscode.sh` fails before launch with a socket error

Recovery:
- restore the host Determinate Nix runtime so `/nix/var/nix/daemon-socket/socket` exists
- do not start host Nix services from the project workflow
- retry the launcher after the host prerequisite is restored

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

### 10.5 Editor Python Is Not The Managed Venv

Symptom:
- editor-side Python features resolve a Flox run interpreter or host interpreter instead of `.flox/cache/python/bin/python`

Meaning:
- the editor was not launched through the current `scripts/env/start_vscode.sh` path, or an existing VS Code window/terminal was reused after environment scripts changed

Recovery:
- close stale VS Code windows and relaunch with `scripts/env/start_vscode.sh`
- run `scripts/env/start_vscode.sh --print-env` and confirm `python_executable` points into `.flox/cache/python`
- use `scripts/env/toolchain/python/python_run.sh` as the authoritative CLI runtime check if editor state is still unclear

## 11. Relationship To The Other Docs

Use this document when you want the detailed operational workflow for the editor
startup path.

Use the following documents for broader context:
- `docs/chat/determinate_nix_flox_setup.md`: runbook for Determinate Nix, Flox, daemon, and repository wrappers
- `docs/chat/devenv_portable_workflow.md`: high-level architecture, portability model, and phased plan

## 12. Current Status In This Repository

Implemented now:
- `scripts/env/start_vscode.sh`
- workspace settings pinned to repository Flox-resolved `python` and `swift`
- task `vscode:print-env`
- portable-root-aware editor documentation

Known limitation:
- the launcher can only auto-resolve the VS Code binary if it is on `PATH` or matches one of the expected portable locations; otherwise `VSCODE_BIN` must be provided explicitly
- already-open VS Code windows and integrated terminals do not retroactively pick up launcher or activation changes; restart the editor after environment script changes

----

# Design Work

## Q: If `start_vscode.sh` is canonical and `common.sh` is sourced once, what can scripts assume?

Assumptions under discussion:

1. `scripts/env/start_vscode.sh` is the canonical entrypoint when using VS Code and GitHub Copilot.
2. `scripts/env/toolchain/common.sh` is sourced once in every external shell session before running project scripts.

Under that model, the following conclusions hold.

### 1. `start_vscode.sh` inherits `common.sh` environment variables and activates Flox

Yes.

`scripts/env/start_vscode.sh` sources the project environment aggregator and then launches VS Code through the composed Flox environment.

The launcher is responsible for:

- loading the common project environment
- loading VS Code portable path defaults
- validating the Nix daemon and `/nix` mount assumptions
- ensuring the Flox environment is ready
- launching the editor through the root-attached Flox environment

The `--check` path confirms that the effective editor environment contains the project-local XDG/HOME paths, the Flox-managed Python runtime, and the Swiftly-managed Swift toolchain.

### 2. VS Code terminals and Copilot inherit that environment

Mostly yes.

When VS Code is launched through `scripts/env/start_vscode.sh`, the editor process inherits the project/Flox environment. VS Code extension hosts, including GitHub Copilot, generally inherit the editor process environment. Integrated terminals inherit the editor process environment plus explicit workspace terminal overrides from `.vscode/settings.json`.

Important caveats:

- already-open VS Code windows do not retroactively inherit launcher changes
- already-open integrated terminals do not retroactively inherit environment changes
- after changing environment scripts, restart VS Code or create a new terminal

### 3. External shells can inherit `common.sh` state once

Yes, if the shell uses `source`, not script execution:

```bash
source scripts/env/toolchain/common.sh
```

After that, child processes inherit exported variables from the common project environment, including XDG/HOME isolation, Nix/Flox path defaults, Swift build/cache paths, and inference/model/cache paths.

Important distinction:

- exported variables are inherited by child scripts
- shell functions are not normally inherited by child scripts unless explicitly exported with `export -f`

Therefore, if scripts stop sourcing modules and only rely on a once-sourced shell, they can rely on variables such as `PROJECT_ROOT`, `XDG_CACHE_HOME`, `FLOX_ENV_DIR`, and `SWIFT_BUILD_PATH`, but not on functions such as `run_as_root`, `use_nix_daemon`, `require_flox_bin`, or `hybrid_ai_assert_under_project` unless those scripts are executed in the same shell context or still source the needed module.

### 4. Directory creation and isolation verification can be sufficient once at session start

Mostly yes, for a stable session.

Sourcing `scripts/env/toolchain/common.sh` creates the project-local directory structure through the concern modules:

- `xdg_env.sh` creates project-local XDG and HOME directories
- `swift_env.sh` sources the Swift path module, which creates Swift build/cache directories
- `inference_env.sh` creates model/cache/log/artifact/dependency directories

`scripts/env/start_vscode.sh` performs the startup isolation checks needed for the editor session:

- checks the Nix daemon profile
- checks the `/nix` mount
- checks the Nix daemon socket
- ensures the Flox environment is activatable or syncs stale state

For normal VS Code usage, doing this once at editor startup is sufficient.

Important caveats:

- if `/nix` is unmounted later, the daemon stops, or caches are pruned during the session, assumptions can become stale
- destructive scripts such as cache cleanup and Nix mount management should keep local safety checks
- if the project later supports discretionary module-specific Flox activation, each module activation boundary should verify the module environment it is about to activate

### Design implication

This supports a session-initialization model:

- `scripts/env/start_vscode.sh` is the canonical VS Code/Copilot session initializer
- external shells should source `scripts/env/toolchain/common.sh` once before running project workflows
- scripts can gradually reduce repeated environment discovery if they are only intended to run inside initialized sessions
- scripts that require helper functions should still source the specific concern module they use, or a narrower concern aggregator

The guiding rule becomes:

> Variables can be inherited once from `common.sh`; functions and destructive safety checks should remain explicitly sourced or verified at the boundary that uses them.

## Q: What is the root-attached Flox environment migration model?

The target model is **Model A: root fullstack plus module environments**.

In that model:

- `.flox/env/manifest.toml` is the canonical fullstack developer environment attached to the repository root
- `env/base/manifest.toml`, `env/python/manifest.toml`, `env/swift/manifest.toml`, and `env/inference/manifest.toml` remain reusable module environments
- activating from the repository root with `flox activate` makes `FLOX_ENV_PROJECT` equal the repository root
- module environments can still be activated directly with `flox activate -d env/python`, `flox activate -d env/swift`, and similar commands

This follows the same broad pattern used by many `flox/floxenvs` examples: attach the primary project environment to the project root, use `[include]` for reusable layers, use `$FLOX_ENV_PROJECT` for project-relative paths, and use `$FLOX_ENV_CACHE/<module>` for generated runtime state.

The previous canonical fullstack environment under `env/hybrid-ai` has been retired. The root-attached environment is now the only canonical fullstack activation boundary; `env/base`, `env/python`, `env/swift`, and `env/inference` remain as reusable module environments.

Once the root-attached environment is fully validated, most `PROJECT_ROOT="$(cd "$FLOX_ENV_PROJECT/../.." && pwd)"` style path recovery can be removed from the canonical fullstack activation path. Module manifests may keep a fallback root-discovery path if direct standalone activation remains supported.
