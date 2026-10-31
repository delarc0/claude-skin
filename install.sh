#!/bin/zsh
# Installs a skin: builds the theme and badge, the DevTools painter and its LaunchAgent, and the badge mod.
#   ./install.sh <theme> [--name NAME] [--sub SUB]     e.g. ./install.sh my-brand --name ALEX
#   ./install.sh --uninstall
# The runtime lives outside ~/Documents: macOS privacy blocks launchd's zsh from reading files there.
set -e
src=${0:A:h}
label=local.claude-skin
dst=$HOME/Library/Application\ Support/claude-skin
plist=$HOME/Library/LaunchAgents/$label.plist

if [[ $1 == --uninstall ]]; then
  launchctl bootout gui/$UID/$label 2>/dev/null || true
  rm -rf $plist $dst ~/Library/Caches/$label.pid
  claude plugin uninstall skin-badge@desktop-skin 2>/dev/null || true
  claude plugin marketplace remove desktop-skin 2>/dev/null || true
  echo "uninstalled; Developer Mode stays on (delete ~/Library/Application Support/Claude/developer_settings.json to turn it off)"
  exit 0
fi
[[ -f $src/themes/$1.json ]] || { echo "usage: install.sh <theme> [--name NAME] [--sub SUB]; themes: $(ls $src/themes | sed "s/.json$//" | paste -sd, -)"; exit 1 }
theme=$1; shift

python3 -I $src/build_theme.py $theme
python3 -I $src/plugins/skin-badge/make_badge.py $theme "$@"

mkdir -p $dst ~/Library/LaunchAgents
cp $src/on-launch.sh $src/apply-skin.applescript $src/dist/$theme/console-snippet.js $dst/
# Developer Mode is what puts "Show All Dev Tools" in Claude's menus
python3 -I - <<PY
import json, pathlib
p = pathlib.Path.home() / "Library/Application Support/Claude/developer_settings.json"
s = json.loads(p.read_text()) if p.exists() else {}
p.parent.mkdir(parents=True, exist_ok=True); p.write_text(json.dumps({**s, "allowDevTools": True}))
PY
cat > $plist <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
	<key>Label</key><string>$label</string>
	<key>ProgramArguments</key><array><string>/bin/zsh</string><string>$dst/on-launch.sh</string></array>
	<key>StartInterval</key><integer>5</integer>
	<key>RunAtLoad</key><true/>
	<key>StandardOutPath</key><string>$HOME/Library/Logs/$label.log</string>
	<key>StandardErrorPath</key><string>$HOME/Library/Logs/$label.log</string>
</dict></plist>
PL
plutil -lint -s $plist
# mark the running Claude as done, so the painter waits for the next launch instead of grabbing focus now
ps -axo pid=,comm= | awk '$2=="/Applications/Claude.app/Contents/MacOS/Claude"{print $1; exit}' > ~/Library/Caches/$label.pid
launchctl bootout gui/$UID/$label 2>/dev/null || true
launchctl bootstrap gui/$UID $plist

claude plugin marketplace add $src >/dev/null 2>&1 || claude plugin marketplace update desktop-skin >/dev/null
claude plugin install skin-badge@desktop-skin --scope user >/dev/null 2>&1 || true
echo "installed $theme. Painter: $dst (log ~/Library/Logs/$label.log), badge: skin-badge@desktop-skin."
echo "It paints at Claude's next start; the first run asks for Accessibility for osascript."
