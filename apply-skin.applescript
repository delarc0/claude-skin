-- Paints the skin into every Claude window through DevTools.
-- osascript apply-skin.applescript /path/to/console-snippet.js /path/to/menu-labels.txt
-- Every keystroke is preceded by guard(): Claude must be frontmost and its front window
-- must be a DevTools window, or the run stops before typing anything into the wrong place.

on run argv
	set snippet to read (POSIX file (item 1 of argv)) as «class utf8»
	-- "Show All Dev Tools" in every language the app ships, written by build_theme.py
	set labels to paragraphs of (read (POSIX file (item 2 of argv)) as «class utf8»)
	set savedClip to missing value
	try
		set savedClip to the clipboard -- no coercion, so an image or rich text survives too
	end try
	set the clipboard to snippet
	try
		tell application "Claude" to activate
		my waitFor("main window", 30)
		if not my clickAnyMenuItem(labels) then error "Show All Dev Tools not in the menus: is Developer Mode on, and was Claude restarted after turning it on?"
		delay 2
		set painted to 0
		repeat with winName in my devToolsWindows()
			my skinWindow(winName as text)
			set painted to painted + 1
		end repeat
		if painted is 0 then error "no DevTools window opened"
	on error msg
		my restoreClip(savedClip)
		error msg
	end try
	my restoreClip(savedClip)
	return "sent to " & painted & " window(s)" -- typed, not confirmed: the page gives no answer back
end run

on skinWindow(winName)
	tell application "System Events" to tell process "Claude"
		perform action "AXRaise" of window winName
	end tell
	delay 0.4
	-- if a guard aborts, this DevTools window stays open: closing it blind could hit the wrong window
	my guard(winName)
	tell application "System Events" to keystroke "p" using {command down, shift down} -- DevTools command menu
	delay 0.4
	my guard(winName)
	tell application "System Events" to keystroke "Show Console"
	delay 0.4
	my guard(winName)
	tell application "System Events" to key code 36 -- Return
	delay 0.6
	my pasteAndRun(winName)
	-- DevTools blocks the first paste on a profile that never used its Console, until "allow pasting" is typed.
	-- When nothing was blocked this line is a harmless syntax error, and the snippet replaces itself on the rerun.
	my guard(winName)
	tell application "System Events" to keystroke "allow pasting"
	delay 0.3
	my guard(winName)
	tell application "System Events" to key code 36
	delay 0.4
	my pasteAndRun(winName)
	my guard(winName)
	tell application "System Events" to keystroke "w" using {command down} -- closes DevTools only: guard proved it is in front
	delay 0.3
end skinWindow

on pasteAndRun(winName)
	my guard(winName)
	tell application "System Events" to keystroke "v" using {command down}
	delay 0.3
	my guard(winName)
	tell application "System Events" to key code 36
	delay 0.5
end pasteAndRun

-- The check before every keystroke.
on guard(winName)
	tell application "System Events"
		if not (frontmost of process "Claude") then error "aborted: Claude is not frontmost"
		-- launcher panels take the keyboard without becoming frontmost
		-- shortcut: only these three are known, add others here if a user reports one
		repeat with launcher in {"Spotlight", "Raycast", "Alfred"}
			if exists process launcher then
				if (count of windows of process launcher) > 0 then error "aborted: " & launcher & " is open"
			end if
		end repeat
		set frontName to name of front window of process "Claude"
	end tell
	if frontName is not winName or frontName does not start with "DevTools" then error "aborted: front window is \"" & frontName & "\", not " & winName
end guard

on devToolsWindows()
	set found to {}
	tell application "System Events" to tell process "Claude"
		repeat with n in (name of every window)
			if (n as text) starts with "DevTools" then set end of found to (n as text)
		end repeat
	end tell
	return found
end devToolsWindows

-- One walk of the menus and their submenus; clicks the first item named like any label.
on clickAnyMenuItem(labels)
	tell application "System Events" to tell process "Claude"
		repeat with top in menu bar items of menu bar 1
			try
				repeat with mi in menu items of menu 1 of top
					set n to name of mi
					if n is not missing value and labels contains n then
						click mi
						return true
					end if
					try
						repeat with sub in menu items of menu 1 of mi
							set n to name of sub
							if n is not missing value and labels contains n then
								click sub
								return true
							end if
						end repeat
					end try
				end repeat
			end try
		end repeat
	end tell
	return false
end clickAnyMenuItem

on waitFor(what, maxWait)
	repeat maxWait times
		tell application "System Events"
			if (exists process "Claude") and (count of windows of process "Claude") > 0 then return
		end tell
		delay 1
	end repeat
	error "Claude has no " & what & " after " & maxWait & " s"
end waitFor

on restoreClip(savedClip)
	if savedClip is not missing value then set the clipboard to savedClip
end restoreClip
