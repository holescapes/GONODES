# AI resources

This folder is the shared brief for any language model working on GONODES. Do not copy these files into a tool-specific set.

`.cursor/` and `.vscode/` are personal. Both are gitignored. A clone does not contain them, and Cursor does not create them from this folder on its own.

## Prompt to paste

Give this to a fresh agent in Cursor, VS Code, or any other tool. It sets the agent up and catches it up.

```
Read ai/README.md, then ai/RULES.md, then ai/MEMORY.md, and follow them. When you disagree, follow ai/pushback.md.

If you are running inside Cursor, create these two local files. Do not commit them. .cursor is gitignored.

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

If you are writing or editing a .gnpatch, stop after llms.txt and the one operator in docs/OPERATORS.md. You do not need the engine rules for that job.
```

Copilot in VS Code already loads `.github/copilot-instructions.md`, which only points at `ai/RULES.md`. Do not paste the rules into a second file.

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

`llms.txt` stays at the root on purpose. Models look for `/llms.txt`. Do not move it into this folder, and do not paste the operator catalog into it.

`AGENTS.md` stays at the root as a four-line pointer, because some agents open that path and no other. The brief is this file.

## Files

| File | What it is |
|------|------------|
| `ai/README.md` | This index. Start here. |
| `ai/RULES.md` | Hard rules, operator patterns, build. The only copy. |
| `ai/MEMORY.md` | Short dated decisions. Add a line. Do not paste a work log. |
| `ai/pushback.md` | Disagree in the open when an idea is weaker than another. |
| `llms.txt` | How to write a valid patch. Root file, any model. |
| `AGENTS.md` | Root pointer. It sends the agent here. |
| `.github/copilot-instructions.md` | Copilot's required path. It only says to read `ai/RULES.md`. |
| `docs/OPERATORS.md` | Operator catalog. Read the one operator you are about to set. |
| `GONODES_CONTEXT.md` | Engine internals, by section. |
| `.cursorignore`, `.copilotignore` | Paths agents should not pull into context. |
