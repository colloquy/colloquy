on enocdeEntities(htmlText)
	set oldDelims to AppleScript's text item delimiters
	
	set AppleScript's text item delimiters to the "&"
	set the itemList to every text item of htmlText
	set AppleScript's text item delimiters to the "&amp;"
	set htmlText to the itemList as string
	
	set AppleScript's text item delimiters to the "<"
	set the itemList to every text item of htmlText
	set AppleScript's text item delimiters to the "&lt;"
	set htmlText to the itemList as string
	
	set AppleScript's text item delimiters to the ">"
	set the itemList to every text item of htmlText
	set AppleScript's text item delimiters to the "&gt;"
	set htmlText to the itemList as string
	
	set AppleScript's text item delimiters to the "\""
	set the itemList to every text item of htmlText
	set AppleScript's text item delimiters to the "&quot;"
	set htmlText to the itemList as string
	
	set AppleScript's text item delimiters to the "'"
	set the itemList to every text item of htmlText
	set AppleScript's text item delimiters to the "&apos;"
	set htmlText to the itemList as string
	
	set AppleScript's text item delimiters to oldDelims
	return htmlText
end enocdeEntities

using terms from application "Colloquy"
	on process user command c with arguments for view
		if c is "itunes" then
			tell application "System Events"
				set itunesRunning to ((application processes whose name is equal to "iTunes") count) is greater than 0
			end tell
			
			if (arguments is "" or arguments is missing value) then
				set msg to "isn't running iTunes currently."
				if itunesRunning then
					tell application "iTunes"
						if player state is playing then
							set theArtist to artist of current track
							set theSong to name of current track
							if theArtist is not "" and theArtist is not missing value then
								set msg to "is listening to <font color=\"orange\">" & my enocdeEntities(theSong) & "</font> by <font color=\"green\">" & my enocdeEntities(theArtist) & "</font>."
							else
								set msg to "is listening to <font color=\"orange\">" & my enocdeEntities(theSong) & "</font>."
							end if
						else if player state is paused or player state is stopped then
							set msg to "has iTunes paused."
						end if
					end tell
				end if
				tell view to send message msg with action tense
			else if first word of arguments is "open" then
				tell application "iTunes" to activate
			else if first word of arguments is "quit" and itunesRunning then
				tell application "iTunes" to quit
			else if first word of arguments is "play" then
				tell application "iTunes" to play
			else if first word of arguments is "pause" and itunesRunning then
				tell application "iTunes" to pause
			else if first word of arguments is "stop" and itunesRunning then
				tell application "iTunes" to stop
			else if first word of arguments is "next" and itunesRunning then
				tell application "iTunes" to next track
			else if first word of arguments is "previous" and itunesRunning then
				tell application "iTunes" to previous track
			end if
			
			return true
		end if
		
		return false
	end process user command
end using terms from