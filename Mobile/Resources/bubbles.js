function appendMessage(container, senderNickname, messageHTML, highlighted, action, self, previousSession, type, timestamp) {
	var className = type + "-wrapper";
	if (action) className += " action";
	if (highlighted) className += " highlight";
	if (previousSession) className += " previous-session";
	if (self) className += " self";
	if (action) messageHTML = "\u2022\u2008" + senderNickname + " " + messageHTML;

	var messageWrapperElement = document.createElement("div");
	messageWrapperElement.className = className;

	var messageElement = document.createElement("div");
	messageElement.className = type;
	messageWrapperElement.appendChild(messageElement);

	if (!previousSession && timestamp !== null) {
		var timestampElement = document.createElement("div");
		timestampElement.className = "timestamp";
		timestampElement.innerHTML = timestamp;
		messageWrapperElement.appendChild(timestampElement);
	}

	var messageContentElement = document.createElement("div");
	messageContentElement.className = "content";
	messageContentElement.innerHTML = messageHTML;
	messageElement.appendChild(messageContentElement);

	var senderElement = document.createElement("div");
	senderElement.className = "sender";
	senderElement.textContent = senderText(senderNickname, highlighted, action, type === "notice", self);

	messageWrapperElement.appendChild(senderElement);

	container.appendChild(messageWrapperElement);
}
