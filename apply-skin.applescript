-- Paints the skin into every Claude window through DevTools.
-- osascript apply-skin.applescript /path/to/console-snippet.js /path/to/menu-labels.txt
-- Every keystroke is preceded by guard(): Claude must be frontmost and its front window
-- must be a Developer Tools window, or the run stops before typing anything into the wrong place.

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
		my waitFor("main window", 90)
		-- the menu item toggles, so DevTools windows left open by an earlier run are painted as they are
		if my devToolsWindows() is {} then
			if not my clickAnyMenuItem(labels) then error "Show All Dev Tools not in the menus: is Developer Mode on, and was Claude restarted after turning it on?"
		end if
		set total to count of my waitForDevTools()
		-- DevTools windows can all be untitled, so paint whichever is first and let Cmd+W remove it
		set painted to 0
		repeat total times
			if my devToolsWindows() is {} then exit repeat
			my skinWindow()
			set painted to painted + 1
		end repeat
	on error msg
		my restoreClip(savedClip)
		error msg
	end try
	my restoreClip(savedClip)
	return "sent to " & painted & " window(s)" -- typed, not confirmed: the page gives no answer back
end run

on skinWindow()
	-- an untitled window is addressed by its place in the window list, which shifts as windows move,
	-- so look the window up again before every raise until DevTools is in front
	repeat 5 times
		set wins to my devToolsWindows()
		if wins is {} then error "the DevTools window closed"
		tell application "System Events" to perform action "AXRaise" of (item 1 of wins)
		delay 0.4
		tell application "System Events" to set frontWin to front window of process "Claude"
		if my isDevTools(frontWin) then exit repeat
	end repeat
	-- if a guard aborts, this DevTools window stays open: closing it blind could hit the wrong window
	my guard()
	tell application "System Events" to keystroke "p" using {command down, shift down} -- DevTools command menu
	delay 0.4
	my guard()
	tell application "System Events" to keystroke "Show Console"
	delay 0.4
	my guard()
	tell application "System Events" to key code 36 -- Return
	delay 0.6
	my pasteAndRun()
	-- DevTools blocks the first paste on a profile that never used its Console, until "allow pasting" is typed.
	-- When nothing was blocked this line is a harmless syntax error, and the snippet replaces itself on the rerun.
	my guard()
	tell application "System Events" to keystroke "allow pasting"
	delay 0.3
	my guard()
	tell application "System Events" to key code 36
	delay 0.4
	my pasteAndRun()
	my guard()
	tell application "System Events" to keystroke "w" using {command down} -- closes DevTools only: guard proved it is in front
	delay 0.3
end skinWindow

on pasteAndRun()
	my guard()
	tell application "System Events" to keystroke "v" using {command down}
	delay 0.3
	my guard()
	tell application "System Events" to key code 36
	delay 0.5
end pasteAndRun

-- The check before every keystroke.
on guard()
	tell application "System Events"
		if not (frontmost of process "Claude") then error "aborted: Claude is not frontmost"
		-- launcher panels take the keyboard without becoming frontmost
		-- shortcut: only these three are known, add others here if a user reports one
		-- one query: "exists process" by name takes about 3 s each when the process is absent
		repeat with launcher in (processes whose name is "Spotlight" or name is "Raycast" or name is "Alfred")
			if (count of windows of launcher) > 0 then error "aborted: " & (name of launcher) & " is open"
		end repeat
		set win to front window of process "Claude"
	end tell
	if not my isDevTools(win) then error "aborted: Claude's front window is not DevTools"
end guard

-- A DevTools window is titled "Developer Tools - <url>" ("DevTools" on older Electron),
-- or left untitled with a web page inside titled "DevTools".
on isDevTools(win)
	tell application "System Events" to set n to name of win
	if n is missing value then set n to ""
	if n starts with "Developer Tools - " or n starts with "DevTools - " or n is "DevTools" then return true
	return n is "" and my webAreaTitle(win, 0) is "DevTools"
end isDevTools

on webAreaTitle(el, depth)
	tell application "System Events"
		if role of el is "AXWebArea" then return value of attribute "AXTitle" of el
		if depth < 8 then
			repeat with c in UI elements of el
				set t to my webAreaTitle(c, depth + 1)
				if t is not "" then return t
			end repeat
		end if
	end tell
	return ""
end webAreaTitle

on devToolsWindows()
	set found to {}
	tell application "System Events" to set wins to every window of process "Claude"
	repeat with w in wins
		if my isDevTools(contents of w) then set end of found to contents of w
	end repeat
	return found
end devToolsWindows

-- Returns once the count holds for a second, so a window that opens late is not left out.
on waitForDevTools()
	set seen to 0
	repeat 10 times
		set found to my devToolsWindows()
		if found is not {} and (count of found) = seen then return found
		set seen to count of found
		delay 1
	end repeat
	if found is not {} then return found
	error "no DevTools window opened"
end waitForDevTools

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
