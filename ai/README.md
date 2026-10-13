# AI resources

This folder is the brief for any editor and any language model. Nothing in here is written for Cursor, VS Code, or Copilot. A tool does not get its own copy of the rules in the repository.

`.cursor/`, `.vscode/`, and a tool's context-ignore file are personal. They are gitignored. A clone does not contain them.

`.editorconfig` stays at the root. That file is the cross-editor standard for charset. `AGENTS.md` stays at the root as a four-line pointer, because many agents open that path and no other. `llms.txt` stays at the root because models look for `/llms.txt`.

## Prompt to paste

Give this to a fresh agent. It catches the agent up, and it writes the local files that tool needs. Those local files are not committed.

```
Read ai/README.md, then ai/RULES.md, then ai/MEMORY.md, and follow them. When you disagree, follow ai/pushback.md.

Copy ai/context-ignore.txt into this tool's context-ignore file, if it has one. Do not commit that file. Usual names are .cursorignore, .copilotignore, .clineignore, and .aiderignore.

If this tool loads project rules from a local folder, write rules that only point at ai/. Do not paste ai/RULES.md into them. For Cursor, create these two files and do not commit them:

.cursor/rules/gonodes.mdc
---
description: GONODES project context and hard rules
alwaysApply: true
---
Read ai/README.md, then ai/RULES.md, then ai/MEMORY.md before you edit. Follow the hard rules in ai/RULES.md. Never import ui/ from core/ or operators/. To write a .gnpatch, read llms.txt and docs/OPERATORS.md instead.

.cursor/rules/honest-pushback.mdc
---
description: Push back honestly when disagreeing
alwaysApply: true
---
Read and follow ai/pushback.md. Do not agree just to be agreeable.

If you create a .vscode folder, add an empty .vscode/.gdignore so Godot does not import it. Do not commit .vscode.

If you are writing or editing a .gnpatch, stop after llms.txt and the one operator in docs/OPERATORS.md. You do not need the engine rules for that job.
```

## Developing GONODES

Use this when the agent will change the engine, an operator, the editor, the build, or an extension.

1. Read this file.
2. Read `ai/RULES.md` and follow the hard rules. Breaking one breaks the engine.
3. Read `ai/MEMORY.md` for decisions that are easy to undo by accident.
4. Open `GONODES_CONTEXT.md` only for the section the task needs. It is the long architecture reference, not a file to load whole.
5. Same change, same docs. A parameter, port, or behavior change updates `docs/OPERATORS.md` and the operator's `.cfg` description. A change that makes a sentence in `llms.txt` false updates `llms.txt`. A download or build-step change updates `dev_docs/BUILD.md` and the matching script.

## Writing a patch

Use this when the agent will write or edit a `.gnpatch`. It does not need the engine hard rules.

1. Read `llms.txt` at the repository root.
2. Before setting a parameter, port, or enum, read that operator in `docs/OPERATORS.md`.
3. When the shape is unclear, copy a help patch under `addons/gonodes/help/` or `addons/gn_ext_*/help/`.

Do not paste the operator catalog into `llms.txt`.

## Files

| File | What it is |
|------|------------|
| `ai/README.md` | This index. Start here. |
| `ai/RULES.md` | Hard rules, operator patterns, build. The only copy. |
| `ai/MEMORY.md` | Short dated decisions. Add a line. Do not paste a work log. |
| `ai/pushback.md` | Disagree in the open when an idea is weaker than another. |
| `ai/context-ignore.txt` | Paths a model should not load. Copy into the tool's own ignore file. |
| `llms.txt` | How to write a valid patch. Root file, any model. |
| `AGENTS.md` | Root pointer. It sends every agent here. |
| `docs/OPERATORS.md` | Operator catalog. Read the one operator you are about to set. |
| `GONODES_CONTEXT.md` | Engine internals, by section. |
