var animatingScroll = false;
var animationInterval = null;
var startScrollTop = 0;
var currentScrollTop = 0;
var targetScrollTop = 0;
var animationComplete = 0;
var autoscrollSuspended = false;
var scrollbackLimit = 300;
var timestampPosition = null;
var firstNonTopicElement = null;

function animateScroll(target, duration, callback) {
	function cubicInOut(t, b, c, d) {
		if ((t/=d/2) < 1) return c/2*t*t*t + b;
		return c/2*((t-=2)*t*t + 2) + b;
	}

	const slice = (1000 / 30); // 30 frames per second

	animationComplete = 0;
	startScrollTop = currentScrollTop;
	targetScrollTop = target;

	if (animatingScroll) return;

	animatingScroll = true;

	function step() {
		animationComplete += slice;

		if (animationComplete < duration) {
			currentScrollTop = cubicInOut(animationComplete, startScrollTop, targetScrollTop - startScrollTop, duration);
			document.body.scrollTop = currentScrollTop;
		} else {
			currentScrollTop = targetScrollTop;
			document.body.scrollTop = currentScrollTop;

			clearInterval(animationInterval);
			animationInterval = null;

			animatingScroll = false;
			if (callback) callback();
		}
	}

	step();

	animationInterval = setInterval(step, slice);
}

function stopScrollAnimation() {
	clearInterval(animationInterval);
	animationInterval = null;
	animatingScroll = false;
}

function appendComponents(components, previousSession, suppressScroll, suppressScrollAnimation) {
	if (autoscrollSuspended)
		suppressScroll = true;

	var alwaysScroll = false;
	var wasNearBottom = (!suppressScroll && nearBottom());
	var componentsLength = components.length;
	var container = (componentsLength > 1 ? document.createDocumentFragment() : document.body);

	for (var i = 0; i < componentsLength; ++i) {
		var component = components[i];
		if (component.type === "message") {
			if (component.self) alwaysScroll = true;
			appendMessage(container, component.sender, component.message, component.highlighted, component.action, component.self, previousSession, 'message', component.timestamp);
		} else if (component.type === "event") {
			appendEventMessage(container, component.message, component.identifier, previousSession);
		} else if (component.type === "notice") {
			if (component.self) alwaysScroll = true;
			appendMessage(container, component.sender, component.message, component.highlighted, component.action, component.self, previousSession, 'notice', component.timestamp);
		} else if (component.type === "console") {
			appendConsoleMessage(container, component.message, component.outbound);
		}
	}

	if (componentsLength > 1)
		document.body.appendChild(container);

	if (!suppressScroll && (alwaysScroll || wasNearBottom))
		scrollToBottom(!suppressScrollAnimation);
}

function senderText(senderNickname, highlighted, action, notice, self) {
	return (notice ? "—" : "") + (action ? "\u2022\u2008" : "" ) + senderNickname + (action ? " " : ": ");
}

function nicknameChanged(from, to) {
	var className = "nickname " + from;
	var url = "colloquy://" + to;

	var elements = document.getElementsByClassName(className);
	for (var i = 0; i < elements.length; i++) {
		elements[i].setAttribute("href", url);
	}
}

function appendMessage(container, senderNickname, messageHTML, highlighted, action, self, previousSession, type, timestamp) {
	var className = type + "-wrapper";
	if (action) className += " action";
	if (highlighted) className += " highlight";
	if (previousSession) className += " previous-session";

	var messageWrapperElement = document.createElement("div");
	messageWrapperElement.className = className;

	if (firstNonTopicElement === null) {
		firstNonTopicElement = messageWrapperElement;
	}

	className = "sender";
	if (self) className += " self";

	var timestampClassName = timestampPosition === null ? "timestamp" : "timestamp " + timestampPosition;
	if (!previousSession && timestamp !== null) {
		var timestampElement = document.createElement("span");
		timestampElement.className = timestampClassName;
		timestampElement.innerHTML = timestamp;
		messageWrapperElement.appendChild(timestampElement);
	}

	var aElement = document.createElement("a");
	aElement.className = "nickname " + senderNickname;
	aElement.setAttribute("href", "colloquy://" + senderNickname);

	var senderElement = document.createElement("span");
	senderElement.className = className;
	senderElement.appendChild(aElement);
	senderElement.textContent = senderText(senderNickname, highlighted, action, type === "notice", self);

	aElement.appendChild(senderElement);
	messageWrapperElement.appendChild(aElement);

	var messageElement = document.createElement("span");
	messageElement.className = type;
	messageElement.innerHTML = messageHTML;
	messageWrapperElement.appendChild(messageElement);

	container.appendChild(messageWrapperElement);
}

function appendConsoleMessage(container, messageHTML, outbound) {
	var className = "console";
	if (outbound) className += " outbound";

	var consoleElement = document.createElement("div");
	consoleElement.className = className;
	consoleElement.innerHTML = messageHTML;

	if (firstNonTopicElement === null) {
		firstNonTopicElement = consoleElement;
	}

	container.appendChild(consoleElement);
}

function appendEventMessage(container, messageHTML, identifier, previousSession) {
	var className = "event";
	if (identifier) className += " " + identifier;
	if (previousSession) className += " previous-session";

	var eventElement = document.createElement("div");
	eventElement.className = className;
	eventElement.innerHTML = messageHTML;

	if (firstNonTopicElement === null) {
		firstNonTopicElement = eventElement;
	}

	container.appendChild(eventElement);
}

function markScrollback() {
	var container = document.body;
	if (container.lastChild.className === "mark")
		return;

	var markElement = document.createElement("hr");
	markElement.className = "mark";

	container.appendChild(markElement);
}

function setTimestampPosition(position) {
	timestampPosition = position;

	var className = timestampPosition === null ? "event" : "timestamp " + timestampPosition;
	var elements = document.getElementsByClassName("timestamp");
	for (var i = 0; i < elements.length; i++)
		elements[i].className = className;
}

function setScrollbackLimit(limit) {
	scrollbackLimit = limit;

	enforceScrollbackLimit();
}

function enforceScrollbackLimit() {
	if (document.body.childNodes.length < scrollbackLimit)
		return;
	while (document.body.childNodes.length > (scrollbackLimit - 25))
		document.body.removeChild(document.body.firstChild);
	scrollToBottom(false, true);
}

function suspendAutoscroll() {
	autoscrollSuspended = true;
}

function resumeAutoscroll() {
	autoscrollSuspended = false;
}

function nearBottom() {
	return (animatingScroll || currentScrollTop >= (document.body.scrollHeight - window.innerHeight - 30));
}

function scrollToBottomIfNeeded(animated) {
	if (nearBottom())
		scrollToBottom(animated);
}

function scrollToBottom(animated, suppressEnforceScrollbackLimit) {
	if (!animated) {
		stopScrollAnimation();

		if (!suppressEnforceScrollbackLimit)
			enforceScrollbackLimit();

		currentScrollTop = (document.body.scrollHeight - window.innerHeight);
		document.body.scrollTop = currentScrollTop;
		return;
	}

	function tryEnforcingScrollback() {
		if (!animatingScroll)
			enforceScrollbackLimit();
	}

	function animationFinished() {
		if (!suppressEnforceScrollbackLimit)
			setTimeout(tryEnforcingScrollback, 500);
	}

	var newScrollTop = (document.body.scrollHeight - window.innerHeight);
	animateScroll(newScrollTop, 250, animationFinished);
}

function isDocumentReady() {
	return (document.readyState === "complete");
}

function urlUnderTapAtPoint(x, y) {
	var url = null;
	var e = document.elementFromPoint(x, y);
	while (e) {
		if (typeof e.href !== "undefined" && e.href.length) {
			console.log("href: " + e.href + " prefix? " + e.href.indexOf("colloquy"));
			if (e.href.indexOf("colloquy") != 0){
				url = e.href;
				break;
			}
		}
		e = e.parentNode;
	}
	return url;
}

function addOffsetForTopicToFirstElement() {
	if (firstNonTopicElement === null) {
		return;
	}

	firstNonTopicElement.style.marginTop = '23px';
	firstNonTopicElement.style.top = 0;
	firstNonTopicElement.style.zIndex = 1;
}

function removeOffsetForTopicFromFirstElement() {
	if (firstNonTopicElement === null) {
		return;
	}

	firstNonTopicElement.style.marginTop = null;
	firstNonTopicElement.style.top = null;
	firstNonTopicElement.style.zIndex = null;
}
