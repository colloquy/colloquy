function appendMessage(container, senderNickname, messageHTML, highlighted, action, self, previousSession) {
	var className = "message-wrapper";
	if (action) className += " action";
	if (highlighted) className += " highlight";
	if (previousSession) className += " previous-session";
	if (self) className += " self";
	if (action) messageHTML = "\u2022 " + senderNickname + " " + messageHTML;

	var messageWrapperElement = document.createElement("div");
	messageWrapperElement.className = className;

	var messageElement = document.createElement("div");
	messageElement.className = "message";
	messageWrapperElement.appendChild(messageElement);

	var messageContentElement = document.createElement("div");
	messageContentElement.className = "content";
	messageContentElement.innerHTML = messageHTML;
	messageElement.appendChild(messageContentElement);

	var senderElement = document.createElement("div");
	senderElement.className = "sender";
	senderElement.textContent = senderNickname;
	messageWrapperElement.appendChild(senderElement);

	container.appendChild(messageWrapperElement);
}
