# NextKey

Keyboard help for the app you are using. Press **⌥⌘/** anywhere on the Mac, type what you want
to do, and NextKey tells you which keys to press.

It takes a screenshot at the moment you press the hotkey and notes which app is in front, so
the answer is for that app and that screen, for example Excel for Mac and not Excel for Windows.

## Use

1. Press ⌥⌘/ (press it again, or Esc, to close).
2. Type the question. Short works: "freeze the top row". So does a goal: "I'm reviewing a pull
   request and want to jump to the next file, then approve it".
3. Press ⏎. The shortcut appears large at the top, a short explanation sits under it, and any
   further steps are listed below. Press ⏎ again to ask a follow-up about the same screenshot.

## What you need

- macOS 14 or later.
- Xcode command line tools, to build it: `xcode-select --install`.
- An [OpenRouter](https://openrouter.ai) API key. NextKey sends your screenshot and question to
  the model you choose through OpenRouter, and you pay OpenRouter for that usage.

## Install

```bash
./build.sh
```

This builds NextKey, installs it to `~/Applications/NextKey.app` and opens it. Then:

1. Click the NextKey icon in the menu bar and paste in your OpenRouter key. It is saved to
   `~/.config/nextkey/.env`, readable only by you.
2. Allow NextKey under **System Settings → Privacy & Security → Screen & System Audio
   Recording**, then quit and reopen it from the menu bar icon.

`build.sh` signs the app ad hoc, so macOS asks for the Screen Recording permission again after
each rebuild. To avoid that, create a code-signing certificate in Keychain Access and pass its
name: `NEXTKEY_SIGN_IDENTITY="My Certificate" ./build.sh`.

## Settings

Optional, in `~/.config/nextkey/config.json`:

```json
{
  "model": "openai/gpt-6-luna",
  "hotkey": "cmd+opt+/",
  "reasoning_effort": "",
  "max_image_dimension": 1280
}
```

The model can also be switched from the menu bar. Any OpenRouter model that accepts images
works. Reasoning is off by default because it adds several seconds before the first word.

## Privacy

Each time you press the hotkey and ask a question, a screenshot of your screen goes to
OpenRouter and on to the model provider. Don't use it with anything on screen that you would
not paste into an AI chat. No screenshot or question is sent until you press ⏎, and NextKey keeps neither
after the panel closes.

## Speed

Measured on 21 October 2026 from Cape Town:

| Request | Time to first word |
| --- | --- |
| Text only | 0.6–1.0 s |
| With a 1280–1600 px screenshot | 3–6 s |
| With a 768 px screenshot | 2.7–4.7 s |

Most of the wait is the provider reading the image. Lower `max_image_dimension` for faster
answers on a busy screen.

## Limits

- The model can get a shortcut wrong. NextKey is told to say "likely" when it is unsure.
- It suggests keys. It does not press them for you.
