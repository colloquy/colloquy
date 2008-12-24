var realScrollTop = 0;

function animateProperty(animations, duration, callback, complete) {
    if (complete === undefined)
        complete = 0;
    var slice = (1000 / 30); // 30 frames per second

    for (var i = 0; i < animations.length; ++i) {
        var animation = animations[i];
        var target = null;
        var start = null;
        var end = null;
        for (key in animation) {
            if (key === "target")
                target = animation[key];
            else if (key === "start")
                start = animation[key];
            else if (key === "end")
                end = animation[key];
        }

        if (!target || !end)
            continue;

        if (!start) {
            start = {};
            for (key in end)
                start[key] = parseFloat(target[key]);
            animation.start = start;
        }

        function cubicInOut(t, b, c, d) {
            if ((t/=d/2) < 1) return c/2*t*t*t + b;
            return c/2*((t-=2)*t*t + 2) + b;
        }

        for (key in end) {
            var startValue = start[key];
            var currentValue = target[key];
            var endValue = end[key];
            if ((complete + slice) < duration) {
                var delta = (endValue - startValue) / (duration / slice);
                var newValue = cubicInOut(complete, startValue, endValue - startValue, duration);
                target[key] = newValue;
            } else {
                target[key] = endValue;
            }
        }
    }

    if (complete < duration)
        setTimeout(animateProperty, slice, animations, duration, callback, complete + slice);
    else if (callback)
        callback();
}

function appendComponents(components, previousSession, suppressScroll, suppressScrollAnimation) {
	var componentsLength = components.length;
	for (var i = 0; i < componentsLength; ++i) {
		var component = components[i];
		if (component.type === "message")
			appendMessage(component.sender, component.message, component.highlighted, component.action, component.self, true);
	}

	if (!suppressScroll)
		scrollToBottom((suppressScrollAnimation ? false : true));
}

function appendMessage(senderNickname, messageHTML, highlighted, action, self, suppressScroll) {
	var className = "message-wrapper";
	if (action) className += " action";
	if (highlighted) className += " highlight";

	var messageWrapperElement = document.createElement("div");
	messageWrapperElement.className = className;

	className = "sender";
	if (self) className += " self";

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

	if (!suppressScroll)
		scrollToBottom(true);
}

function updateScrollPosition(position) {
	realScrollTop = position;
}

function scrollToBottom(animated) {
	if (!animated) {
		document.body.scrollTop = document.body.scrollHeight;
		realScrollTop = (document.body.scrollHeight  - window.innerHeight);
		return;
	}

	var newScrollTop = (document.body.scrollHeight  - window.innerHeight);
	animateProperty([{target: document.body, start: {scrollTop: realScrollTop}, end: {scrollTop: newScrollTop}}], 250);
	realScrollTop = newScrollTop;
}
