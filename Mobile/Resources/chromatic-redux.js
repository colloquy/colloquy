function senderHash(nickname) {
	nickname = nickname.toLowerCase();

	var uContents = [];
	for (var i = 0; i < nickname.length; i++) {
		uContents.push(nickname.charCodeAt(i));
	}

	// CoreFoundation string hashing algorithm.
	// see: http://www.opensource.apple.com/source/CF/CF-635/CFString.c for reference
	var result = nickname.length;
	var pointer = 0;
	var end = uContents.length;

	while (pointer < end) {
		result *= 257;

		result = result >>> 0;

		result += uContents[pointer];
		result = result >>> 0;

		pointer++;
	}

	result += (result << (nickname.length & 31));
	result = result >>> 0;

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

	if (!previousSession && timestamp !== null) {
		var timestampElement = document.createElement("div");
		timestampElement.className = "timestamp";
		timestampElement.innerHTML = timestamp;
		messageWrapperElement.appendChild(timestampElement);
	}

	className = "sender";
	if (self) className += " self";
	else className += (" user" + (senderHash(senderNickname) % 30));

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
