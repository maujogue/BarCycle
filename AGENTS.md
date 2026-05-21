# Agents for BarCycle

This file documents the AI agents and related conventions used while working on the BarCycle macOS app.

## Purpose

- Provide a single place to describe automation agents and subagents used to inspect, build, and maintain this repo.
- Give contributors quick commands and pointers for common tasks that an agent might run.

## Recommended Agents

- **Explore** — fast read-only codebase exploration and Q&A. Use this agent for code search, locating symbols, and getting context about files before making changes.
- **Build** — helper that runs the build script and reports results. Useful for CI or local checks that need to reproduce the build.

Note: These agent names are descriptive; your tooling may use different names. Add custom agent config files (e.g. `.agent.md` or `.instructions.md`) in the repo root or a `.agents/` folder to customize behavior.

## Common actions (manual and agent-run)

- Build the app locally:

```bash
./build.sh
```

- Run the built app directly (macOS):

```bash
open ./BarCycle.app
# or the binary:
./BarCycle.app/Contents/MacOS/BarCycle
```

- Key source files to inspect:

- `AppSettings.swift` — app settings and preferences.
- `BarCycleApp.swift` — app entry point.
- `build.sh` — build script used by local agents and CI.

## Adding or customizing an agent

1. Create a short markdown file describing the agent's purpose and allowed actions, e.g. `.agents/explore.agent.md`.
2. Document any commands the agent may run, any files it should edit, and guardrails (files/directories it must not modify).
3. Add usage examples and any environment variables required to the agent file.

## Maintenance

- Keep this document up to date when you add new agent configs or scripts.
- If you add CI steps that run agents, add the workflow name and a short description here.

---
Maintainer: add your name and contact details here if desired.
