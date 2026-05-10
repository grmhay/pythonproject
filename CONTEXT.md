# zamazingo

A Python project template that scaffolds CLI and API projects with built-in tooling for human-agent collaboration on GitHub Issues.

## Language

**Sandbox Loop**:
The automated workflow that picks issues labelled `ready-for-agent`, implements them inside a Docker sandbox via Claude Code, and opens a pull request per issue.
_Avoid_: agent loop, CI loop, automation pipeline

**Agent Gate**:
The `ready-for-agent` label — the human signal that an issue is fully specified and safe for the Sandbox Loop to attempt.
_Avoid_: AFK-ready, auto-ready, agent-approved

**Sandbox**:
The isolated Docker container in which the agent executes. It has access to the repo via a git worktree but cannot affect the host filesystem directly.
_Avoid_: container, environment, box

**Scaffold**:
The act of running `create-python-project.sh` to produce a new project from the template. A Scaffolded project inherits all template conventions including the Sandbox Loop.
_Avoid_: bootstrap, initialise, generate

## Relationships

- The **Sandbox Loop** picks issues that carry the **Agent Gate** label
- Each **Sandbox Loop** run executes inside a **Sandbox** and produces one pull request per issue
- A **Scaffold** produces a new project that ships with a pre-configured **Sandbox Loop**

## Example dialogue

> **Dev:** "Should I put this issue straight into the Sandbox Loop?"
> **Domain expert:** "Not yet — it needs the Agent Gate label first. Triage it, make sure it's fully specified, then apply `ready-for-agent`."

## Flagged ambiguities

- "environment" was used to mean both the Nix dev shell and the Docker Sandbox — resolved: Sandbox refers only to the Docker container; the Nix shell is just "the dev shell".
