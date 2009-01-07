function appendMessage(senderNickname, messageHTML, highlighted, action, self, suppressScroll, previousSession) {
	if (autoscrollSuspended)
		suppressScroll = true;

	var wasNearBottom = (!suppressScroll && nearBottom());

	var className = "message-wrapper";
	if (action) className += " action";
	if (highlighted) className += " highlight";
	if (previousSession) className += " previous-session";
	if (self) className += " self";

	var messageWrapperElement = document.createElement("div");
	messageWrapperElement.className = className;

	var messageElement = document.createElement("div");
	messageElement.className = "message";
	messageWrapperElement.appendChild(messageElement);

	var messageContentElement = document.createElement("div");
	messageContentElement.className = "content";
	messageElement.appendChild(messageContentElement);

	var senderElement = document.createElement("div");
	senderElement.className = "sender";
	senderElement.textContent = senderNickname;
	messageWrapperElement.appendChild(senderElement);

	document.body.appendChild(messageWrapperElement);

	if (action) messageHTML = "\u2022 " + senderNickname + " " + messageHTML;

	var range = document.createRange();
	range.selectNode(messageContentElement);

	var messageFragment = range.createContextualFragment(messageHTML);
	messageContentElement.appendChild(messageFragment);

	if (!suppressScroll && (alwaysScroll || wasNearBottom))
		scrollToBottom(true);
}
