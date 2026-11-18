# Free tools from aishoulddothat

Small tools I built for my own work and now give away. Take them, change them, share them.
Everything here is under the [MIT licence](LICENSE).

| Tool | What it does | Runs on |
| --- | --- | --- |
| [screenshot-tool](screenshot-tool/) | Two hotkeys that put a screenshot on the clipboard, ready to paste into an AI chat. Can also save each one to a folder. | macOS, with Hammerspoon |
| [nextkey](nextkey/) | Press a hotkey, say what you want to do, and get the keyboard shortcut for the app you are in. | macOS 14 or later |
| [flow-stepper](flow-stepper/) | A Claude skill that turns a process description into an animated, step-through diagram page. | Claude Code or claude.ai, with Python 3 |

## Install with your AI assistant

Paste this into Claude Code, Codex, Claude or ChatGPT:

```text
Read https://raw.githubusercontent.com/spencergrantkyle/aishoulddothat-opensource-tools/main/INSTALL.md and help me install one of the tools. Ask me which one first.
```

An assistant that can run commands on your machine (Claude Code, Codex) does the install for
you. One that can only chat walks you through it. [INSTALL.md](INSTALL.md) also works fine
read by a person.

## Install by hand

Each folder has its own README with install steps. To get everything, use **Code → Download
ZIP** above, or:

```bash
git clone https://github.com/spencergrantkyle/aishoulddothat-opensource-tools.git
```

## Where these came from

I showed the screenshot tool and NextKey at Founders Week in November 2026, in a talk on
practical AI at work. They solve the same problem from two sides: getting what is on your
screen in front of an AI quickly, and getting an answer back without leaving the keyboard.
flow-stepper came from wanting to explain a release process without a wall of text.

## Found a problem, or made one better?

Open an issue or a pull request. If you have an idea for something AI should do, add it at
[aishoulddothat.com](https://aishoulddothat.com).

`catalogue.json` lists the tools in a form the website reads.
