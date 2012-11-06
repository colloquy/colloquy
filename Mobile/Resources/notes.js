function senderText(senderNickname, highlighted, action, notice, self) {
	return (notice ? "—" : "") + (action ? "\u2022" : "" ) + senderNickname + (action ? " " : ": ");
}
