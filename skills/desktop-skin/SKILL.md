---
name: desktop-skin
description: Make a custom skin for the Claude desktop app on macOS: a colour theme from someone's palette or brand, painted into every window at launch, plus a name badge above the Claude Code prompt. Use when someone asks to theme, skin, recolour or brand their Claude app, or wants their name or company in the app.
---

# Claude skin

The repo is two folders above this file (`<base>/../..`). Everything runs from there.

## 1. Get the palette

Ask for what you can't read: the colours (a brand page, a hex list or a screenshot), the font, and the
name and sub-label for the badge. Never invent brand colours; if they give a brand name only, ask for
the hex values or a page that lists them.

## 2. Write `themes/<slug>.json`

Copy `themes/lab37-cyberpunk.json` (neon on near-black) and change it. For a brand with one hue and one
accent, set `ground.hue` to the brand colour, `roles.accent` to the accent, and leave the other roles out:

- `ground.hue`: the colour the greys lean toward. Optional pins: `deep` (dark page), `base` (dark
  sidebar), `raised` (dark hover and raised surfaces). Without pins the greys keep the app's lightness.
- `roles`: `accent`, `success`, `danger`, `warning`. Each is optional; a role left out keeps the app's
  own. The pure colour goes where dark mode reads it, and every other step is derived at the app's
  lightness, so light mode stays readable.
- `fonts.sans`, `fonts.mono`: installed font names, or leave them out.
- `badge`: `name`, `sub`, `fill`, `stroke`, `ink`, `subInk`, `mark`, `markShape` (`square` or
  `window`), `offset` (a second outline colour, or null), `chamfer` (true cuts the top-right corner).

## 3. Build and check

    python3 build_theme.py <slug> --check

It reads the app's `--cds-*` tokens straight out of `/Applications/Claude.app` and fails when a text
or fill pair drops below WCAG AA (or below what the app itself ships). On a failure, darken `deep` or
pick a stronger role colour; never lower the floor.

## 4. Show the preview before installing

    python3 preview.py <slug>

Open `preview/<slug>.html` and show it: before dark, after dark, after light, with the badge. Install
only after the person says it looks right.

## 5. Install

    ./install.sh <slug> [--name NAME] [--sub SUB]

It turns on Developer Mode, installs the painter (an AppleScript run by a LaunchAgent at each Claude
launch) and the `skin-badge` mod. Tell the person:

- The first paint asks for Accessibility for `osascript` (System Settings, Privacy and Security,
  Accessibility). They grant it, then restart Claude.
- The painter opens DevTools for each window, pastes the theme into the Console and closes it. It
  checks the front window before every keystroke and stops if anything else is in front.
- A window that fully reloads loses the skin until the next launch.

`./install.sh --uninstall` removes all of it except Developer Mode.
