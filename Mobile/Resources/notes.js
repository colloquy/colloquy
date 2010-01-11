function senderText(senderNickname, highlighted, action, self) {
	return (action ? "\u2022" : "" ) + senderNickname + (action ? " " : ": ");
}
