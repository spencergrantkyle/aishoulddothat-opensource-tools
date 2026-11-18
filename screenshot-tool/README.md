# Screenshot tool

Two hotkeys that put a screenshot straight on the clipboard, so you can paste it into an AI
chat without hunting for a file.

| Keys | What happens |
| --- | --- |
| ⌃⇧S (Ctrl + Shift + S) | Captures the whole display your pointer is on |
| ⌃⇧D (Ctrl + Shift + D) | Lets you drag a box around the part you want. Esc cancels |
| ⌃⌥⇧S | Turns "also save to a folder" on or off |
| ⌃⌥⇧M | Opens the tool's menu at your pointer |

Every capture goes to the clipboard. With folder saving on, a PNG copy is also written to the
folder you choose, named `Screenshot 2026-11-08 14.30.00.png`.

## Try it

Capture an error message, paste it into your AI chat, and ask: "Explain this error and the
next step I should try."

## Install

It runs inside [Hammerspoon](https://www.hammerspoon.org), a free macOS automation app.

1. Install Hammerspoon and open it once.
2. Copy `init.lua` from this folder to `~/.hammerspoon/screenshotfolder/init.lua`.
3. Add these two lines to `~/.hammerspoon/init.lua` (create the file if it does not exist):

   ```lua
   screenshotfolder = require("screenshotfolder")
   screenshotfolder.start()
   ```

4. In the Hammerspoon menu, choose **Reload Config**.
5. Press ⌃⇧S. The first time, macOS asks you to allow Hammerspoon under **System Settings →
   Privacy & Security → Screen & System Audio Recording**. Allow it, then restart Hammerspoon.

A camera icon appears in the menu bar. It shows the current mode: 📷 clipboard only, 📸●
clipboard and folder, 📷⏸ hotkeys off.

## Change the hotkeys

Edit the four lines near the top of `init.lua` (`FULL_MODS`, `SNIP_MODS`, `TOGGLE_MODS`,
`MENU_MODS` and their keys), then reload the Hammerspoon config.

## Good to know

- Nothing leaves your Mac. The tool calls macOS's own `screencapture` command.
- If the save folder is deleted or unplugged, the next capture goes to the clipboard only and
  folder saving turns off.
- On a MacBook with a notch the menu bar icon can be hidden. ⌃⌥⇧M opens the same menu.
