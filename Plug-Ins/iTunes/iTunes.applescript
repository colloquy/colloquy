tell application "System Events"
	if ((application processes whose name is equal to "iTunes") count) is greater than 0 then
		tell application "iTunes"
			if player state is playing then
				set the_artist to artist of current track
				set the_song to name of current track
				if the_artist is not "" and the_artist is not missing value then
					return "is listening to " & the_song & " by " & the_artist & "."
				else
					return "is listening to " & the_song & "."
				end if
			else if player state is paused or player state is stopped then
				return "'s iTunes is paused."
			end if
		end tell
	else
		return "'s iTunes is currently closed."
	end if
end tell