function senderHash(nickname) {
	var result = 0;
	for (var i = 0; i < nickname.length; ++i)
		result += nickname.charCodeAt(i);
	return result;
}

function appendMessage(container, senderNickname, messageHTML, highlighted, action, self, previousSession) {
	var className = "message-wrapper";
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

	var aElement = document.createElement("a");
	aElement.setAttribute("href", "colloquy://" + senderNickname);
	aElement.setAttribute("style", "text-decoration: none");

	var senderElement = document.createElement("div");
	senderElement.className = className;
	senderElement.appendChild(aElement);
	senderElement.textContent = senderText(senderNickname, highlighted, action, self);

	aElement.appendChild(senderElement);
	messageWrapperElement.appendChild(aElement);

	var messageElement = document.createElement("div");
	messageElement.className = "message";
	messageElement.innerHTML = messageHTML;
	messageWrapperElement.appendChild(messageElement);

	container.appendChild(messageWrapperElement);
}
