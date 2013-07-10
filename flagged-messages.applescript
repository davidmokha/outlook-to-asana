set asanaAPIKey to "" -- API key
set workspaceId to "" -- ID of workspace in which to create tasks
set projectId to "" -- ID of project in which to create tasks
set emailTagId to "" -- ID of tag to tag tasks

set creationNotification to "Created Asana task"
set errorNotification to "Error creating Asana task"
set appName to "Outlook to Asana"

-- From http://www.harvey.nu/applescript_url_encode_routine.html
on urlencode(theText)
	set theTextEnc to ""
	repeat with eachChar in characters of theText
		set useChar to eachChar
		set eachCharNum to ASCII number of eachChar
		if eachCharNum = 32 then
			set useChar to "+"
		else if (eachCharNum � 42) and (eachCharNum � 95) and (eachCharNum < 45 or eachCharNum > 46) and (eachCharNum < 48 or eachCharNum > 57) and (eachCharNum < 65 or eachCharNum > 90) and (eachCharNum < 97 or eachCharNum > 122) then
			set firstDig to round (eachCharNum / 16) rounding down
			set secondDig to eachCharNum mod 16
			if firstDig > 9 then
				set aNum to firstDig + 55
				set firstDig to ASCII character aNum
			end if
			if secondDig > 9 then
				set aNum to secondDig + 55
				set secondDig to ASCII character aNum
			end if
			set numHex to ("%" & (firstDig as string) & (secondDig as string)) as string
			set useChar to numHex
		end if
		set theTextEnc to theTextEnc & useChar as string
	end repeat
	return theTextEnc
end urlencode

-- From http://www.j-schell.de/node/610
on search_replace(haystack, needle, replacement)
	set old_delimiters to AppleScript's text item delimiters
	set AppleScript's text item delimiters to needle
	set temp_list to every text item of haystack
	set AppleScript's text item delimiters to replacement
	set return_value to temp_list as text
	set AppleScript's text item delimiters to old_delimiters
	return return_value
end search_replace

tell application "GrowlHelperApp"
	set allNotificationsList to {creationNotification, errorNotification}
	set enabledNotificationsList to allNotificationsList
	
	register as application appName default notifications enabledNotificationsList all notifications allNotificationsList
end tell

tell application "Microsoft Outlook"
	set fwaccount to exchange account "Freewheel"
	set fwinbox to inbox of fwaccount
	
	repeat with msg in (messages of fwinbox whose todo flag is not not flagged)
		set msgflag to the todo flag of msg
		if msgflag is not not flagged and msgflag is not completed then
			set msgsubject to subject of msg as string
			
			set msgcontent to plain text content of msg as string
			set taskcontent to (characters 1 thru 80 of msgcontent as string) & "�"
			set taskcontent to search_replace(taskcontent, "'", "%27") of me -- Escape single quotes for commandline
						
			set msgsender to sender of msg
			-- log address of msgsender
			-- log name of msgsender
			
			set taskTitle to urlencode(msgsubject) of me
			set taskNotes to urlencode("From: " & address of msgsender) of me
			set taskNotes to taskNotes & "%0ASubject: " & taskTitle
			set taskNotes to taskNotes & "%0A%0A---%0A" & taskcontent
			
			-- Create Asana task
			try
				set asanaJSON to do shell script "curl -u '" & asanaAPIKey & "' https://app.asana.com/api/1.0/tasks " & �
					"-d 'name=" & taskTitle & "' " & �
					"-d 'workspace=" & workspaceId & "' " & �
					"-d 'projects[0]=" & projectId & "' " & �
					"-d 'assignee=me' " & �
					"-d 'notes=" & taskNotes & "'"
			on error number errNum
				if (errNum is not 0) then
					tell application "GrowlHelperApp"
						notify with name errorNotification title errorNotification description msgsubject application name appName
					end tell
					
					return
				end if
			end try
			
			tell application "JSON Helper"
				set asanaRecord to read JSON from asanaJSON
				set asanaRecord to |data| of asanaRecord
			end tell
			
			-- Asana IDs can be too big for Applescript's integer type so they end up as reals
			-- This formats the IDs back to integers from AS's real representation (scientific notation)
			set taskId to do shell script "printf '%.0f' " & |id| of asanaRecord
			
			-- Add e-mail tag to task that was created
			set asanaJSON to do shell script "curl -u '" & asanaAPIKey & "' https://app.asana.com/api/1.0/tasks/" & taskId & "/addTag " & �
				"-d 'tag=" & emailTagId & "'"
			
			-- Notify via Growl
			tell application "GrowlHelperApp"
				notify with name creationNotification title creationNotification description msgsubject application name appName
			end tell
			
			-- Unflag and mark as read
			set todo flag of msg to completed
			set is read of msg to true
		end if
	end repeat
	
end tell
