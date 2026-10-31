#!/bin/zsh
# launchd runs this every 5 s (local.claude-skin); it skins each new Claude process once.
dir=${0:A:h}
state=~/Library/Caches/local.claude-skin.pid
pid=$(ps -axo pid=,comm= | awk '$2=="/Applications/Claude.app/Contents/MacOS/Claude"{print $1; exit}')
[[ -z $pid || $(cat $state 2>/dev/null) == $pid ]] && exit 0
echo $pid > $state  # once per launch, even on failure: a retry loop would keep stealing focus
sleep 8             # let the windows load their pages
echo "$(date '+%F %T') pid $pid: $(osascript $dir/apply-skin.applescript $dir/console-snippet.js 2>&1)"
