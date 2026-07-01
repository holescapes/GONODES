# GONODES — AI Agent Context (cross-tool)

> **Single entry point** for Copilot, Cursor, Claude Code, and other coding agents.
> Edit the linked files below — do not fork instructions into tool-specific copies.

## Canonical instructions

**Follow `.github/copilot-instructions.md`** — architecture, hard rules, operator patterns, build system.

## Deep reference (read on demand)

| Topic | File |
|-------|------|
| Full engine docs | `GONODES_CONTEXT.md` |
| Extensions | `dev_docs/EXTENSIONS.md` |
| Build | `dev_docs/BUILD.md` |
| Testing | `dev_docs/TESTING.md` |
| Contributing / rules | `dev_docs/CONTRIBUTING.md` |
| New operator checklist | `dev_docs/NEW_OPERATOR_CHECKLIST.md` |
| New native extension checklist | `dev_docs/NEW_EXTENSION_CHECKLIST.md` |
| Curated memories | `AI_MEMORY.md` |

## Tool mapping

| Tool | Auto-reads |
|------|------------|
| GitHub Copilot | `.github/copilot-instructions.md` |
| Cursor | `.cursor/rules/gonodes.mdc` → this file + copilot-instructions |
| Any agent | This `AGENTS.md` |

## Ignore patterns for AI context

See `.cursorignore` (mirrors `.copilotignore`).
