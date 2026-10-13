# GONODES — AI agents

Start at [ai/README.md](ai/README.md). That is the shared brief for any model.

Do not copy the rules into a tool-specific file. Copilot injects [.github/copilot-instructions.md](.github/copilot-instructions.md). Cursor injects [.cursor/rules/](.cursor/rules/). Both point at `ai/`.

| Task | Read |
|------|------|
| Change the engine, an operator, the editor, or the build | `ai/README.md`, then the hard rules, then `ai/MEMORY.md` |
| Write a `.gnpatch` | `llms.txt`, then `docs/OPERATORS.md` |

| Tool | What it loads on its own |
|------|--------------------------|
| GitHub Copilot, including VS Code | `.github/copilot-instructions.md` |
| Cursor | `.cursor/rules/*.mdc` |
| Any other agent | This file, then `ai/README.md` |

`.vscode/` is editor settings, not instructions.

Ignore patterns: `.cursorignore` (mirrors `.copilotignore`).
