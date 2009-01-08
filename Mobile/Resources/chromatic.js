function senderHash(nickname) {
	var result = 0;
	for (var i = 0; i < nickname.length; ++i)
		result += nickname.charCodeAt(i);
	return result;
}

function appendMessage(senderNickname, messageHTML, highlighted, action, self, suppressScroll, previousSession) {
	if (autoscrollSuspended)
		suppressScroll = true;

	var wasNearBottom = (!suppressScroll && nearBottom());

	var className = "message-wrapper";
	if (action) className += " action";
	if (highlighted) className += " highlight";
	if (previousSession) className += " previous-session";

	if (document.body.lastChild.senderNickname === senderNickname && document.body.lastChild.previousSession == previousSession)
		document.body.lastChild.className += " subsequent";

	var messageWrapperElement = document.createElement("div");
	messageWrapperElement.className = className;
	messageWrapperElement.senderNickname = senderNickname;
	messageWrapperElement.previousSession = previousSession;

	className = "sender";
	if (self) className += " self";
	else className += (" user" + (senderHash(senderNickname) % 18));

	var senderElement = document.createElement("div");
	senderElement.className = className;
	senderElement.textContent = senderNickname;
	messageWrapperElement.appendChild(senderElement);

	var messageElement = document.createElement("div");
	messageElement.className = "message";
	messageWrapperElement.appendChild(messageElement);

	document.body.appendChild(messageWrapperElement);

	var range = document.createRange();
	range.selectNode(messageElement);

	var messageFragment = range.createContextualFragment(messageHTML);
	messageElement.appendChild(messageFragment);

	if (!suppressScroll && (alwaysScroll || wasNearBottom))
		scrollToBottom(true);
}
