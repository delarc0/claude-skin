# claude-skin

Your colours in the Claude desktop app on macOS, and your name above the Claude Code prompt.

- **Theme.** `build_theme.py` reads the app's own `--cds-*` design tokens out of `app.asar` and repaints
  its colour ramps from a small JSON palette. Every step keeps the app's lightness, so contrast holds;
  the build fails if a text or fill pair drops below WCAG AA.
- **Painter.** A LaunchAgent notices each Claude launch and runs an AppleScript that opens DevTools in
  every window, pastes the theme into the Console and closes it. It checks the front window before
  every keystroke and stops if anything else is in front.
- **Badge.** `skin-badge` is a Claude Code mod that draws an SVG name badge in the band above the prompt
  (plain text in the terminal), in the theme's colours.

## Quick start

Needs macOS, the Claude desktop app, Claude Code and python3.

```bash
git clone <this repo> ~/claude-skin && cd ~/claude-skin
python3 build_theme.py lab37-cyberpunk --check
python3 preview.py lab37-cyberpunk        # open preview/lab37-cyberpunk.html
./install.sh lab37-cyberpunk --name YOURNAME --sub YOURTEAM
```

Then restart Claude. The first run asks for Accessibility for `osascript`
(System Settings, Privacy and Security, Accessibility).

Or let Claude do it: install the skill with
`claude plugin marketplace add <this repo>` and `claude plugin install desktop-skin@desktop-skin`,
then ask Claude to skin your app.

## Make your own theme

Copy `themes/lab37-cyberpunk.json` to `themes/<yours>.json` and change the colours. Only the example theme is tracked; your own themes stay out of git. See `skills/desktop-skin/SKILL.md` for every field.

| Theme | Look |
| --- | --- |
| `lab37-cyberpunk` | neon cyan, lime and magenta on near-black violet, JetBrains Mono |

## Limits

- It uses Developer Mode (`developer_settings.json` in Claude's settings folder) and DevTools. That is
  a supported Claude feature, but the theme sits on internal tokens: an app update can rename them.
  The build then fails loudly instead of shipping a broken skin; rebuild after updates.
- A window that fully reloads loses the skin until Claude's next launch.
- The painter needs Accessibility for `osascript`, which lets any script you run with it control the
  keyboard. Remove it in System Settings if you uninstall.

`./install.sh --uninstall` removes the painter, the LaunchAgent and the mod. It leaves Developer Mode on.
