# AI resources

This folder is the shared brief for any language model working on GONODES. Cursor, Copilot, Claude, and a model that was only given a link can all start here. Do not copy these files into a second, tool-specific set.

`.vscode/` is editor settings for the people writing code. It is not part of this brief.

## Brief an agent

Tell the agent to read this file, or paste the path `ai/README.md`. Then tell it which of the two jobs it has.

### Developing GONODES

Use this when the agent will change the engine, an operator, the editor, the build, or an extension.

1. Read this file.
2. Read `.github/copilot-instructions.md` and follow the hard rules. Breaking one breaks the engine.
3. Read `ai/MEMORY.md` for decisions that are easy to undo by accident.
4. Open `GONODES_CONTEXT.md` only for the section the task needs. It is the long architecture reference, not a file to load whole.
5. Same change, same docs. A parameter, port, or behavior change updates `docs/OPERATORS.md` and the operator's `.cfg` description. A change that makes a sentence in `llms.txt` false updates `llms.txt`. A download or build-step change updates `dev_docs/BUILD.md` and the matching script.

### Writing a patch

Use this when the agent will write or edit a `.gnpatch`. It does not need the engine hard rules.

1. Read `llms.txt` at the repository root.
2. Before setting a parameter, port, or enum, read that operator in `docs/OPERATORS.md`.
3. When the shape is unclear, copy a help patch under `addons/gonodes/help/` or `addons/gn_ext_*/help/`.

`llms.txt` stays at the root on purpose. Models look for `/llms.txt`. Do not move it into this folder, and do not paste the operator catalog into it.

## Files

| File | What it is |
|------|------------|
| `ai/README.md` | This index. Start here. |
| `.github/copilot-instructions.md` | Hard rules, operator patterns, build. Copilot injects this path. Do not move it. |
| `ai/MEMORY.md` | Short dated decisions. Add a line. Do not paste a work log. |
| `ai/pushback.md` | Disagree in the open when an idea is weaker than another. |
| `llms.txt` | How to write a valid patch. Root file, any model. |
| `AGENTS.md` | Root pointer for agents that look for that name. It sends them here. |
| `docs/OPERATORS.md` | Operator catalog. Read the one operator you are about to set. |
| `GONODES_CONTEXT.md` | Engine internals, by section. |
| `.cursor/rules/` | What Cursor loads by itself. The files point here. |
| `.cursorignore`, `.copilotignore` | Paths agents should not pull into context. |

## What each tool loads by itself

| Tool | Loads without being asked |
|------|---------------------------|
| GitHub Copilot, including in VS Code | `.github/copilot-instructions.md` |
| Cursor | `.cursor/rules/*.mdc` |
| Anything else | `AGENTS.md`, then this file |

A model that never sees those tool folders still gets the same rules if you point it at this file.
