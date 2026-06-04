# Development Workflow Use Cases

This folder contains one Markdown file per concrete development workflow.

Each use-case document should describe:
- the goal of the workflow
- prerequisites and assumptions
- the exact commands to run
- what VS Code, Copilot, Python, Swift, or other tools are expected to do
- how to verify the workflow is actually using the intended environment
- common failure modes and recovery steps

Current use cases:
- `vscode-portable-project-env.md`: start portable VS Code inside the project Flox environment so the editor, Copilot, Python, and Swift resolve from the repository toolchain, with Python CLI/runtime workflows still using the managed Flox Python venv helper
- `python-cli-and-server.md`: run the Python CLI entrypoint and the Python development server through the Flox-managed Python venv, either from an activated Flox shell or via repository wrappers
- `swift-build-and-test.md`: run Swift build and test workflows through the Flox-managed repository wrapper with artifacts forced under `build/swift`

Planned future use cases:
- Inference local workflow
- Inference remote workflow
- Cross-machine bootstrap and editor handoff workflow