# Install guide (written for AI assistants and people)

This page is the single source for installing any tool in this repo. If you are an AI assistant
helping someone install one of these, follow the section for that tool exactly.

**Rules for AI assistants**

- Ask which tool the person wants before doing anything. Do not install all three by default.
- If you can run commands on their machine (Claude Code, Codex, Cursor and similar), run the
  commands below and report what each one did. If you can only chat (claude.ai, ChatGPT), give
  the person the commands one block at a time and wait for the result.
- Never ask the person to paste an API key into the chat. NextKey has its own place to enter it.
- macOS permission prompts (Screen Recording) can only be approved by the person. Tell them
  where to click and wait.
- Each section ends with a check. Do not say the install worked until the check passes.

## Step 0: get the files (all tools)

Needs `git`. On a Mac without it, `xcode-select --install` provides it.

```bash
git clone https://github.com/spencergrantkyle/aishoulddothat-opensource-tools.git ~/aishoulddothat-opensource-tools
```

If the folder already exists, update it instead:

```bash
git -C ~/aishoulddothat-opensource-tools pull
```

No git? Download
`https://github.com/spencergrantkyle/aishoulddothat-opensource-tools/archive/refs/heads/main.zip`,
unzip it, and rename the folder to `~/aishoulddothat-opensource-tools`.

## Screenshot tool

**What it does:** Ctrl+Shift+S copies a screenshot of the display under the pointer to the
clipboard. Ctrl+Shift+D lets you drag an area. **Needs:** macOS and the free Hammerspoon app.
No account and no API key.

1. Install Hammerspoon if it is missing. With Homebrew:

   ```bash
   ls /Applications/Hammerspoon.app >/dev/null 2>&1 || { command -v brew >/dev/null && brew install --cask hammerspoon || echo "No Homebrew: install Hammerspoon from https://www.hammerspoon.org, then continue"; }
   ```

   Without Homebrew, download it from https://www.hammerspoon.org and drag it to Applications.

2. Copy the module into place:

   ```bash
   mkdir -p ~/.hammerspoon/screenshotfolder && cp ~/aishoulddothat-opensource-tools/screenshot-tool/init.lua ~/.hammerspoon/screenshotfolder/init.lua
   ```

3. Load it from the Hammerspoon config. This adds two lines only if they are not already there:

   ```bash
   grep -q 'require("screenshotfolder")' ~/.hammerspoon/init.lua 2>/dev/null || printf '\nscreenshotfolder = require("screenshotfolder")\nscreenshotfolder.start()\n' >> ~/.hammerspoon/init.lua
   ```

4. Start Hammerspoon, or restart it if it was already running, so it loads the new config:

   ```bash
   osascript -e 'quit app "Hammerspoon"'; sleep 1; open -a Hammerspoon
   ```

5. **Person does this:** press Ctrl+Shift+S. macOS asks for permission. Open **System Settings →
   Privacy & Security → Screen & System Audio Recording**, turn on Hammerspoon, then run the
   step 4 command again.

**Check:** a camera icon (📷) is in the menu bar. Press Ctrl+Shift+S, then paste into any app:
a screenshot appears.

**Remove:** delete `~/.hammerspoon/screenshotfolder` and the two lines added in step 3, then
reload the Hammerspoon config.

## NextKey

**What it does:** press Option+Command+/ in any app, type what you want to do, and get the
keyboard shortcut for that app. **Needs:** macOS 14 or later, Xcode command line tools, and the
person's own OpenRouter API key (https://openrouter.ai/keys). Each question sends a screenshot
of the screen to the AI model through OpenRouter, and the person pays OpenRouter for usage. Say
this before installing.

1. Check the build tools. If this prints an error, run `xcode-select --install` and wait for it
   to finish:

   ```bash
   xcode-select -p && swift --version
   ```

2. Build and install. This takes about a minute and opens the app when done:

   ```bash
   cd ~/aishoulddothat-opensource-tools/nextkey && ./build.sh
   ```

3. **Person does this:** click the NextKey icon in the menu bar, choose **Set OpenRouter API
   Key…** and paste the key there. It is saved to `~/.config/nextkey/.env`.

4. **Person does this:** open **System Settings → Privacy & Security → Screen & System Audio
   Recording**, turn on NextKey, then quit NextKey from its menu bar icon and reopen it:

   ```bash
   open ~/Applications/NextKey.app
   ```

**Check:** `ls ~/Applications/NextKey.app` succeeds. Press Option+Command+/: a small panel
opens. Type "how do I open a new window" and press Return: an answer starting with keys appears.

**Remove:** quit NextKey, then delete `~/Applications/NextKey.app` and `~/.config/nextkey`.

## flow-stepper

**What it does:** a Claude skill. You describe a process and Claude builds an animated,
step-through diagram as one HTML file. **Needs:** Claude Code (or claude.ai with code
execution) and Python 3. No packages.

**Claude Code on macOS or Linux:**

```bash
mkdir -p ~/.claude/skills && cp -R ~/aishoulddothat-opensource-tools/flow-stepper ~/.claude/skills/flow-stepper
```

**Claude Code on Windows (PowerShell):**

```powershell
New-Item -ItemType Directory -Force "$HOME\.claude\skills" | Out-Null; Copy-Item -Recurse "$HOME\aishoulddothat-opensource-tools\flow-stepper" "$HOME\.claude\skills\flow-stepper"
```

**claude.ai:** zip the `flow-stepper` folder, then go to Settings → Capabilities → Skills and
upload the zip.

**Check:** this builds the bundled example and should print the output file name with no error:

```bash
python3 ~/.claude/skills/flow-stepper/build.py ~/.claude/skills/flow-stepper/examples/code-release.json -o ~/code-release.html --title "Code Release Flow" && open ~/code-release.html
```

A page titled "Code Release Flow" opens with Back and Next buttons. Then start a new Claude Code
session and ask: "Use flow-stepper to build a walkthrough of how a support ticket moves between
teams."

**Remove:** delete `~/.claude/skills/flow-stepper`.

## Something went wrong

Open an issue at https://github.com/spencergrantkyle/aishoulddothat-opensource-tools/issues
with the command you ran and the full error text.
