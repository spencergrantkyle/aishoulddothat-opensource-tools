# flow-stepper

A Claude skill that builds animated, step-through diagram walkthroughs: boxes and wires on a grid,
numbered captions, Back/Next buttons and arrow keys. You describe a process, Claude writes a small
JSON spec, and `build.py` turns it into one self-contained HTML page that works offline, in light
or dark mode.

## Install

Download `skill.zip` from the [latest release](https://github.com/spencergrantkyle/flow-stepper/releases/latest).

**Claude Code** (CLI, desktop app or IDE): unzip so the folder lands at

```
~/.claude/skills/flow-stepper/SKILL.md
```

On Windows that is `C:\Users\<you>\.claude\skills\flow-stepper\SKILL.md`. Start a new session and
it shows up as the `flow-stepper` skill. Python 3 must be on the PATH. It uses no third-party
packages.

**claude.ai** (with code execution on): Settings → Capabilities → Skills → upload `skill.zip`.

## Use

Ask for something like:

- "Use flow-stepper to build a walkthrough of how our deploy pipeline works"
- "Make a step-by-step visual guide to how a support ticket moves between teams"

Give Claude the source material, such as a doc, a README or a description of the steps. The
better it knows the actors and the order things happen in, the better the diagram.

To try it by hand:

```bash
python build.py examples/code-release.json -o code-release.html --title "Code Release Flow"
```

Then open `code-release.html` in a browser.

## Files

| File | What it is |
|---|---|
| `SKILL.md` | Instructions Claude follows: the spec format, layout rules and how to check the result |
| `build.py` | Validates a spec and renders the page |
| `engine.html` | The page template and runtime (CSS and JavaScript, no dependencies) |
| `examples/code-release.json` | A worked example: branch → CI → review → staging → production, with a failure arc |

## Licence

MIT. Free to use, change and share. A gift from [aishoulddothat.com](https://aishoulddothat.com).
