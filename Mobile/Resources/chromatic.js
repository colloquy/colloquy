function senderHash(nickname) {
	var result = 0;
	for (var i = 0; i < nickname.length; ++i)
		result += nickname.charCodeAt(i);
	return result;
}

function appendMessage(container, senderNickname, messageHTML, highlighted, action, self, previousSession, type, timestamp) {
	var className = type + "-wrapper";
	if (action) className += " action";
	if (highlighted) className += " highlight";
	if (previousSession) className += " previous-session";

	var parent = (container.lastChild ? container : document.body);
	if (parent.lastChild && parent.lastChild.senderNickname === senderNickname && parent.lastChild.previousSession == previousSession)
		parent.lastChild.className += " subsequent";

	var messageWrapperElement = document.createElement("div");
	messageWrapperElement.className = className;
	messageWrapperElement.senderNickname = senderNickname;
	messageWrapperElement.previousSession = previousSession;

	className = "sender";
	if (self) className += " self";
	else className += (" user" + (senderHash(senderNickname) % 18));

	if (!previousSession && timestamp !== null) {
		var timestampElement = document.createElement("div");
		timestampElement.className = "timestamp";
		timestampElement.innerHTML = timestamp;
		messageWrapperElement.appendChild(timestampElement);
	}

	var aElement = document.createElement("a");
	aElement.className = "nickname"
	aElement.setAttribute("href", "colloquy-nav://" + senderNickname);

	var senderElement = document.createElement("div");
	senderElement.className = className;
	senderElement.appendChild(aElement);
	senderElement.textContent = senderText(senderNickname, highlighted, action, type === "notice", self);

	aElement.appendChild(senderElement);
	messageWrapperElement.appendChild(aElement);

	var messageElement = document.createElement("div");
	messageElement.className = type;
	messageElement.innerHTML = messageHTML;
	messageWrapperElement.appendChild(messageElement);

	container.appendChild(messageWrapperElement);
}
