#!/bin/zsh
# Installs a skin: builds the theme, the DevTools painter and its LaunchAgent, and the badge mod.
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
  claude plugin uninstall skin-badge@skin-badge-local >/dev/null 2>&1 || true
  claude plugin uninstall skin-badge@desktop-skin >/dev/null 2>&1 || true  # where versions before 0.3 put it
  claude plugin marketplace remove skin-badge-local >/dev/null 2>&1 || true
  rm -rf $plist $dst ~/Library/Caches/$label.pid
  echo "uninstalled; Developer Mode stays on (delete ~/Library/Application Support/Claude/developer_settings.json to turn it off)"
  exit 0
fi
[[ -f $src/themes/$1.json ]] || { echo "usage: install.sh <theme> [--name NAME] [--sub SUB]; themes: $(ls $src/themes | sed "s/.json$//" | paste -sd, -)"; exit 1 }
theme=$1; shift

python3 -I $src/build_theme.py $theme
mkdir -p $dst ~/Library/LaunchAgents
# the badge mod is drawn into its own copy, so your name never lands in the repo
rm -rf $dst/badge && mkdir -p $dst/badge && cp -R $src/plugins/skin-badge/{.claude-plugin,hooks} $dst/badge/
python3 -I $src/make_badge.py $theme --out $dst/badge "$@"
print -r '{"name":"skin-badge-local","owner":{"name":"claude-skin"},"plugins":[{"name":"skin-badge","source":"./"}]}' > $dst/badge/.claude-plugin/marketplace.json

cp $src/on-launch.sh $src/apply-skin.applescript $src/dist/$theme/console-snippet.js $src/dist/$theme/menu-labels.txt $dst/
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

echo "installed $theme. Painter: $dst (log ~/Library/Logs/$label.log)."
if ! command -v claude >/dev/null; then
  echo "no claude command: skipped the badge. Install Claude Code, then rerun this." >&2
else
  claude plugin uninstall skin-badge@desktop-skin >/dev/null 2>&1 || true  # where versions before 0.3 put it
  # Claude Code loads a cached copy of the mod, so a new name or theme needs a fresh install
  claude plugin uninstall skin-badge@skin-badge-local >/dev/null 2>&1 || true
  claude plugin marketplace add $dst/badge >/dev/null 2>&1 || claude plugin marketplace update skin-badge-local >/dev/null 2>&1 || true
  claude plugin install skin-badge@skin-badge-local --scope user >/dev/null 2>&1 || true
  if claude plugin list 2>/dev/null | grep -q "skin-badge@skin-badge-local"; then echo "badge: skin-badge@skin-badge-local"
  else echo "badge NOT installed: run claude plugin install skin-badge@skin-badge-local" >&2; fi
fi
echo "Quit and reopen Claude. The first paint asks for Accessibility: allow it, then quit and reopen once more."
