# claude-skin

Skins the Claude desktop app on macOS and draws a name badge above the Claude Code prompt.

When someone asks you to skin, theme, recolour or brand their Claude app, follow
`skills/desktop-skin/SKILL.md` step by step. It covers getting the palette, writing
`themes/<slug>.json`, the contrast check, the preview, and the install.

- Never invent brand colours. Ask for hex values or a page that lists them.
- Show the preview and wait for a yes before `./install.sh`.
- `install.sh` turns on Developer Mode and adds a LaunchAgent; say so before running it.
- After installing, tell the person to quit and reopen Claude and to allow the Accessibility request
  that follows. You cannot grant it for them.
