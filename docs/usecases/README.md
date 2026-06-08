# Development Workflow Use Cases

Clarification: in this repository, `usecases` currently means environment setup and environment utilization workflows. These are not the same thing as application functional use cases.

This folder contains one Markdown file per concrete development workflow.

Each use-case document should describe:
- the goal of the workflow
- prerequisites and assumptions
- the exact commands to run
- what VS Code, Copilot, Python, Swift, or other tools are expected to do
- how to verify the workflow is actually using the intended environment
- common failure modes and recovery steps

Current use cases:
- `01-vscode-portable-project-env.md`: start portable VS Code inside the project Flox environment so the editor, Copilot, Python, and Swift resolve from the repository toolchain, with the managed Flox Python venv and Swiftly activation applied before editor launch
- `02-python-cli-and-server.md`: run the Python CLI entrypoint and the Python development server through the Flox-managed Python venv, either from an activated Flox shell or via repository wrappers
- `03-swift-build-and-test.md`: run Swift build and test workflows through the Flox-managed repository wrapper and Swiftly activation path, with artifacts forced under `build/swift`
- `04-isolation-verification.md`: verify runtime isolation, host-level verification tooling consistency, and the target state where all formal isolation checks pass
- `05-inference-server-workflow.md`: run the full Linux inference server workflow through the dedicated Python Flox environment, including dependency verification, pinned model bootstrap, server startup, readiness checks, and conversation smoke tests

Planned future use cases:
- Cross-machine bootstrap and editor handoff workflow