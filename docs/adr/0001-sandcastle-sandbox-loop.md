# Sandcastle as the Sandbox Loop orchestrator

This is a Python template, but the Sandbox Loop is orchestrated by Sandcastle — a TypeScript tool. We chose Sandcastle over writing a custom Python script because it already handles Docker sandboxing, git worktree isolation, Claude Code session management, and branch-per-issue PR workflow out of the box. The cost of pulling in Node.js (added to the Nix flake) is lower than the cost of reimplementing those primitives.

## Considered Options

- **Custom Python script**: Would stay in-language but would require reimplementing worktree management, sandbox lifecycle, and Claude Code integration from scratch.
- **Sandcastle (chosen)**: Mature orchestrator with Docker, worktree, and Claude Code support built in. Node.js added to the Nix devShell via `pkgs.nodejs` to keep the single-shell guarantee.

## Consequences

- Node.js is a dev dependency. Contributors need `nix develop` (already required); no extra setup.
- Sandcastle is pinned in `package.json`. Version upgrades are explicit and deliberate.
- The `.sandcastle/` directory is pre-configured in the template and token-substituted by `create-python-project.sh` alongside all other template files.
