# Use Case 02: Python CLI And Python Server Development

Date: 2026-06-03
Status: Implemented
Primary scripts:
- `scripts/modules/inference_srv_py/enter.sh`
- `scripts/modules/inference_srv_py/run.sh`
- `scripts/modules/inference_srv_py/server_run.sh`

## 1. Goal

Run Python development workflows through the Flox-managed Python module so the
interpreter, managed virtual environment, dependency resolution, caches,
bytecode, and logs stay inside the repository-managed environment.

This use case covers two closely related paths:
- the Python CLI module entrypoint
- the lightweight Python HTTP server entrypoint

It does not cover the LiteRT-backed inference server workflow or the Swift live
integration path. Those live in `docs/usecases/05-inference-server-workflow.md`.

## 2. Why This Workflow Exists

The repository does not treat the host Python installation as a valid runtime.

Instead, Python execution is expected to flow through:
- the Determinate Nix install under the bind-mounted `/nix`
- the root-attached composed Flox environment under `.flox`
- the managed Python venv created under `.flox/cache/python`
- repository wrappers only when the shell is not already activated

Without the Flox activation model, these failures become likely:
- the wrong Python interpreter is used
- package resolution drifts from the declared repository environment
- caches and bytecode are written outside the repository
- native Python extensions miss their declared system runtime libraries

## 3. Scope And Assumptions

This workflow assumes:
- Determinate Nix and Flox are already installed according to the runbook
- the nix daemon socket exists and normal-user Flox access is working
- the root `.flox` environment has already been initialized and synced
- the Python module source exists under `src/inference_srv_py`

## 4. Files Involved

Runtime wrappers:
- `scripts/modules/inference_srv_py/enter.sh`
- `scripts/modules/inference_srv_py/run.sh`
- `scripts/modules/inference_srv_py/server_run.sh`
- `scripts/env/toolchain/nix/flox_with.sh`
- `scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh`

Session support:
- `scripts/env/toolchain/common.sh` remains available as a compatibility aggregator for broad external-shell setup, but it is not central to Python activation.
- Python manifests and wrappers use `scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh` as their narrow runtime source of truth.
- `env/python/manifest.toml` uses Flox `[vars]` for static Python behavior flags: `PYTHONDONTWRITEBYTECODE`, `PIP_DISABLE_PIP_VERSION_CHECK`, and `POETRY_VIRTUALENVS_CREATE`.
- Normal Python wrappers compute their own local `project_root`; they do not require a pre-sourced `common.sh` shell.

Python source:
- `src/inference_srv_py/pyproject.toml`
- `src/inference_srv_py/inference_srv_py/__init__.py`
- `src/inference_srv_py/inference_srv_py/__main__.py`
- `src/inference_srv_py/inference_srv_py/server.py`

Repository-managed writable paths used by this workflow:
- `build/home`
- `.flox/cache/python`
- `.flox/cache/pip-cache`
- `.flox/cache/poetry-cache`
- `.flox/cache/uv-cache`
- `.flox/cache/pycache`
- `volumes/logs/python_server.log`

## 5. Effective Runtime Behavior

### 5.1 CLI Wrapper

`scripts/modules/inference_srv_py/run.sh` does the following:
- defaults to `python -m inference_srv_py` when no explicit arguments are given
- if already inside the active Flox environment, it activates the managed venv and runs `python` directly
- otherwise it launches through `scripts/env/toolchain/nix/flox_with.sh` and activates the managed venv in the command shell
- dynamic paths such as `PYTHON_DIR`, `HYBRID_AI_PYTHON_VENV`, and cache directories remain in `inference_srv_py_env.sh` because they depend on the checkout path or `FLOX_ENV_CACHE`
- uses `scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh` as the single source of truth for host virtualenv cleanup, venv creation, dependency sync, cache paths, and venv activation

`scripts/modules/inference_srv_py/enter.sh` does the following:
- activates the composed Flox environment
- sources `scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh`
- activates the managed Python venv
- drops into an interactive shell rooted at `src/inference_srv_py`

Current default behavior of the module entrypoint:
- `src/inference_srv_py/inference_srv_py/__main__.py` dispatches to the HTTP server entrypoint
- `src/inference_srv_py/inference_srv_py/__init__.py` exposes `hello()`, which currently returns `inference-srv-py ready`

### 5.2 Server Wrapper

`scripts/modules/inference_srv_py/server_run.sh` does the following:
- creates `volumes/logs` if needed
- appends server output to `volumes/logs/python_server.log`
- activates the managed venv and runs `python -m inference_srv_py.server`

Current server behavior:
- binds to `127.0.0.1:8080` by default
- supports overrides via `HYBRID_AI_HOST` and `HYBRID_AI_PORT`
- responds with JSON describing the service plus selected Python-related environment values

## 6. How To Run The Workflow

### 6.1 Python CLI Default Entry

Run the default module entrypoint:

```bash
scripts/modules/inference_srv_py/run.sh
```

Expected behavior today:
- starts the Python inference server through `python -m inference_srv_py`
- binds to `127.0.0.1:8080` unless overridden

### 6.2 Direct Flox Shell Workflow

When you are already in a Flox shell, direct Python commands are valid after the
managed venv has been activated by the Flox profile:

```bash
flox activate
cd src/inference_srv_py
python -m inference_srv_py.hello_world
```

### 6.3 One-Command Python Shell Workflow

If you want an interactive shell with the managed Python venv already active,
use:

```bash
scripts/modules/inference_srv_py/enter.sh
```

This enters the composed Flox environment, activates the managed Python venv,
and lands in `src/inference_srv_py`.

### 6.4 Python CLI With Explicit Python Arguments

Run arbitrary Python commands inside the repository environment:

```bash
scripts/modules/inference_srv_py/run.sh -c 'import sys; print(sys.executable)'
scripts/modules/inference_srv_py/run.sh -c 'import inference_srv_py; print(inference_srv_py.hello())'
scripts/modules/inference_srv_py/run.sh -m inference_srv_py
```

### 6.5 Python Server

Start the server with defaults:

```bash
scripts/modules/inference_srv_py/server_run.sh
```

Override host and port when needed:

```bash
HYBRID_AI_HOST=0.0.0.0 HYBRID_AI_PORT=8090 scripts/modules/inference_srv_py/server_run.sh
```

## 7. Verification Workflow

### 7.1 Verify The Python Interpreter

Use the wrapper to print the active interpreter path:

```bash
scripts/modules/inference_srv_py/run.sh -c 'import sys; print(sys.executable)'
```

Expected result:
- the interpreter path should point into `.flox/cache/python/bin/python`
- it should not resolve to a host-global Python installation

You can verify the interactive Python shell path too:

```bash
scripts/modules/inference_srv_py/enter.sh
which python
```

Expected result:
- `which python` points into `.flox/cache/python/bin/python`

### 7.2 Verify Repository-Local Caches And Bytecode

Print the key Python paths:

```bash
scripts/modules/inference_srv_py/run.sh -c 'import os; print(os.environ["PIP_CACHE_DIR"]); print(os.environ["POETRY_CACHE_DIR"]); print(os.environ["UV_CACHE_DIR"]); print(os.environ["PYTHONPYCACHEPREFIX"])'
```

Expected result:
- all paths should resolve under `.flox/cache/`

### 7.3 Verify The Default CLI Entry

```bash
scripts/modules/inference_srv_py/run.sh -c 'import inference_srv_py; print(inference_srv_py.hello())'
```

Expected result:
- output should be `inference-srv-py ready`

### 7.4 Verify Native Runtime Support

Use the wrapper to prove NumPy can load its native extension runtime:

```bash
scripts/modules/inference_srv_py/run.sh -c 'import numpy as np; values = np.array([1.0, 2.0, 3.0]); print(values.sum())'
```

Expected result:
- output should be `6.0`

### 7.5 Verify The Server Response

Start the server in one terminal:

```bash
scripts/modules/inference_srv_py/server_run.sh
```

Then query it from another terminal:

```bash
curl -fsS http://127.0.0.1:8080/
```

Expected JSON payload fields:
- `service`
- `python`
- `cache`

Current expected service name:
- `hybrid-ai-python-server`

### 7.6 Verify The Server Log Path

After running the server, confirm the log file exists:

```bash
ls -l volumes/logs/python_server.log
```

Expected result:
- the file exists under `volumes/logs`
- logs are not written to a host-global temp or home directory

## 8. Expected Outcomes

When this workflow is correct:
- `flox activate` yields a shell that can run project Python commands against the managed venv
- `scripts/modules/inference_srv_py/enter.sh` yields an interactive Python-focused shell with the managed venv already active
- wrapper-based Python commands bootstrap the same managed venv when no activated shell exists
- bytecode and Python package caches are written under `.flox/cache/`
- server logs are written under `volumes/logs`
- NumPy and other native Python extensions can resolve their Flox-provided runtime libraries

## 9. Failure Modes And Recovery

### 9.1 Missing Nix Daemon Socket

Symptom:
- wrappers fail before Python starts

Recovery:
- start the daemon manually so `/nix/var/nix/daemon-socket/socket` exists:

	```bash
	sudo /nix/var/nix/profiles/default/bin/nix-daemon
	```

- project scripts do not start host Nix services automatically
- retry the wrapper after the host prerequisite is restored

### 9.2 Wrong Python Interpreter

Symptom:
- `sys.executable` does not point into `.flox/cache/python/bin/python`

Recovery:
- rerun through `scripts/modules/inference_srv_py/run.sh`
- activate the environment with `flox activate` before invoking `python` directly
- or use `scripts/modules/inference_srv_py/enter.sh` to enter a shell with the managed Python venv already active
- if the editor is involved, relaunch it via `scripts/env/start_vscode.sh`

### 9.3 Server Does Not Start

Symptom:
- `scripts/modules/inference_srv_py/server_run.sh` exits immediately

Checks:
- inspect `volumes/logs/python_server.log`
- verify port conflicts on `127.0.0.1:8080`
- verify the Flox environment is initialized and the daemon socket exists

### 9.4 Logs Or Caches Outside The Repository

Symptom:
- Python writes appear under the real user home or another unexpected location

Recovery:
- inspect `scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh`
- rerun `scripts/env/toolchain/check_env.sh`
- make sure the command was started via `scripts/modules/inference_srv_py/run.sh`, `scripts/modules/inference_srv_py/enter.sh`, or an activated Flox shell rather than host Python

## 10. Relationship To Other Docs

Use this document for the concrete Python CLI and server workflow.

Related documents:
- `docs/usecases/01-vscode-portable-project-env.md`: editor-side startup path for Python and Swift tooling
- `docs/chat/determinate_nix_flox_setup.md`: operational runbook for Nix, Flox, wrappers, and recovery
- `docs/chat/devenv_portable_workflow.md`: high-level architecture and workflow plan