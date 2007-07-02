Colloquy = {};

Colloquy.loaded = function(event)
{
	this.mainElement = $("main");
	this.mainTitleElement = $("main-title");
	this.colloquyTitleElement = $("colloquy-title");
	this.colloquiesElement = $("colloquies");

	this.backElement = $("back");
	this.backElement.addEventListener("click", function(event) { Colloquy.showColloquiesList(event) }, false);

	this.joinElement = $("join");

	this.membersElement = $("members");
	this.membersElement.addEventListener("click", function(event) { ChatController.activePanel.showMembersList(event) }, false);

	new Image().src = "images/bottomShadow.png";
	new Image().src = "images/gradientHighlight.png";
	new Image().src = "images/blueGradient.png";
	new Image().src = "images/backButton.png";
	new Image().src = "images/button.png";
	new Image().src = "images/squareBlueButton.png";
	new Image().src = "images/person.png";
	new Image().src = "images/messagesNormalSmall.png";
	new Image().src = "images/messagesNormalMedium.png";
	new Image().src = "images/messagesNormalLarge.png";
	new Image().src = "images/highlightsNormalSmall.png";
	new Image().src = "images/highlightsNormalMedium.png";
	new Image().src = "images/highlightsNormalLarge.png";

	window.location.hash = "bottom"; // pan to the bottom, hides the location bar

	new Ajax.Request( "/command/setup?overrideStyle=info.colloquy.style.xml", {
		method: "get",
		onSuccess: function( transport ) {
			var xml = transport.responseXML;
			var children = xml.documentElement.getElementsByTagName( "panels" ).item( 0 ).childNodes;

			for( var i = 0; i < children.length; ++i )
				ChatController.createPanel( children[i] );

			ChatController.checkActivity();

			if( activityCheckInterval ) clearInterval( activityCheckInterval );
			activityCheckInterval = setInterval( ChatController.checkActivity, currentActivityCheckInterval );
		},
		onException: function( transport, exception ) {
			throw exception;
		}
	} );

	window.addEventListener( "beforeunload", function(event) { Colloquy.teardown(event) }, false );
	window.addEventListener( "unload", function(event) { Colloquy.teardown(event) }, false );
}

window.addEventListener("load", function(event) { Colloquy.loaded(event) }, false);

Colloquy.teardown = function(event)
{
	if( finished ) return;
	finished = true;

	new Ajax.Request( "/command/logout", {
		method: "get",
		asynchronous: false,
		onException: function( transport, exception ) {
			throw exception;
		}
	} );
}

Colloquy.updateMainTitle = function()
{
	var waitingMsgs = 0;
	var waitingHighlightMsgs = 0;

	for (var i = 0; i < ChatController.panels.length; ++i) {
		var panel = ChatController.panels[i];
		if (panel.active)
			continue;
		if ("newMessages" in panel && panel.type == "JVDirectChatPanel")
			waitingMsgs += panel.newMessages;
		if ("newHighlightMessages" in panel && panel.type == "JVChatRoomPanel")
			waitingHighlightMsgs += panel.newHighlightMessages;
	}

	var title = "Colloquy";
	if (waitingMsgs + waitingHighlightMsgs)
		title += " (" + (waitingMsgs + waitingHighlightMsgs) + ")";

	Colloquy.mainTitleElement.textContent = title;
	Colloquy.backElement.textContent = title;
}

Colloquy.showColloquiesList = function(event)
{
	if (Colloquy.animatingMenu) return;

	Colloquy.animatingMenu = true;

	var animations = [{element: this.backElement, end: {left: 120, opacity: 0}},
		{element: this.joinElement, end: {opacity: 1}}, {element: this.membersElement, end: {opacity: 0}},
		{element: this.colloquyTitleElement, end: {left: 200, opacity: 0}},
		{element: this.mainTitleElement, end: {left: 0, top: 0, "font-size": 20, "line-height": 42}},
		{element: this.colloquiesElement, end: {left: 0}}, {element: ChatController.activePanel.panelElement, end: {left: 320}}];

	Colloquy.joinElement.style.display = null;
	Colloquy.mainTitleElement.style.display = null;

	var panel = this;
	var animateStyleFinished = function() {
		Colloquy.backElement.style.display = null;
		Colloquy.colloquyTitleElement.style.display = null;
		Colloquy.membersElement.style.display = null;

		ChatController.activePanel.setKeyboardVisible(false);
		ChatController.activePanel.active = false;

		if (ChatController.activePanel.closeAfterAnimate)
			ChatController.activePanel.close();

		ChatController.activePanel = null;

		delete Colloquy.animatingMenu;
	};

	this.animateStyle(animations, (event.shiftKey ? 2500 : 250), animateStyleFinished);
}

Colloquy.animateStyle = function(animations, duration, callback, complete)
{
	if (complete === undefined)
		complete = 0;
	var slice = (1000 / 15); // 15 frames per second

	var defaultUnit = "px";
	var propertyUnit = {opacity: ""};

	for (var i = 0; i < animations.length; ++i) {
		var animation = animations[i];
		var element = null;
		var start = null;
		var current = null;
		var end = null;
		for (key in animation) {
			if (key === "element")
				element = animation[key];
			else if (key === "start")
				start = animation[key];
			else if (key == "current")
				current = animation[key];
			else if (key === "end")
				end = animation[key];
		}

		if (!element || !end)
			continue;

		var computedStyle = element.ownerDocument.defaultView.getComputedStyle(element);
		if (!start) {
			start = {};
			for (key in end)
				start[key] = parseFloat(computedStyle.getPropertyValue(key));
			animation.start = start;
		} else if (complete == 0)
			for (key in start)
				element.style.setProperty(key, start[key] + (key in propertyUnit ? propertyUnit[key] : defaultUnit));

		if (!current) {
			current = {};
			for (key in start)
				current[key] = start[key];
			animation.current = current;
		}

		function cubicInOut(t, b, c, d)
		{
			if ((t/=d/2) < 1) return c/2*t*t*t + b;
			return c/2*((t-=2)*t*t + 2) + b;
		}

		var style = element.style;
		for (key in end) {
			var startValue = start[key];
			var currentValue = current[key];
			var endValue = end[key];
			if ((complete + slice) < duration) {
				var delta = (endValue - startValue) / (duration / slice);
				var newValue = cubicInOut(complete, startValue, endValue - startValue, duration);
				style.setProperty(key, newValue + (key in propertyUnit ? propertyUnit[key] : defaultUnit));
				current[key] = newValue;
			} else {
				style.setProperty(key, endValue + (key in propertyUnit ? propertyUnit[key] : defaultUnit));
			}
		}
	}

	if (complete < duration)
		setTimeout(Colloquy.animateStyle, slice, animations, duration, callback, complete + slice);
	else if (callback)
		callback();
}

function extendClass( subClass, baseClass ) {
	function inheritance() {}
	inheritance.prototype = baseClass.prototype;

	subClass.prototype = new inheritance();
	subClass.prototype.constructor = subClass;
	subClass.baseConstructor = baseClass;
	subClass.superClass = baseClass.prototype;
}

var UserDefaults = {
	minimumActivityCheckInterval: 2000,
	maximumActivityCheckInterval: 10000,
	activityCheckIntervalIncrement: 200,
	scrollBackMessageLimit: 200
};

var activityCheckInterval = null;
var currentActivityCheckInterval = ( UserDefaults.maximumActivityCheckInterval / 2 );
var finished = false;

var ChatController = {
	panels: new Array(),
	activePanel: null
};

ChatController.createPanel = function( node ) {
	var panel = ChatController.panel( node.getAttribute( "identifier" ) );
	if( panel ) return panel;

	var type = node.getAttribute( "class" );
	if( type == "JVDirectChatPanel" )
		return new DirectChatPanel( node );
	else if( type == "JVChatRoomPanel" )
		return new ChatRoomPanel( node );
	return null;
};

ChatController.panel = function( id ) {
	for( var i = 0, l = this.panels.length; i < l; ++i )
		if( this.panels[i].id == id ) return this.panels[i];
	return null;
}

ChatController.checkActivity = function() {
	new Ajax.Request( "/command/checkActivity", {
		method: "get",
		onSuccess: function( transport ) {
			var updateIntervalDelta = 0;

			if( transport.responseText && transport.responseXML ) {
				var children = transport.responseXML.documentElement.childNodes;
				for( var i = 0; i < children.length; ++i ) {
					switch( children[i].tagName ) {
					case "open":
						updateIntervalDelta -= 200;
						ChatController.createPanel( children[i] );
						break;
					case "close":
						var panel = ChatController.panel( children[i].getAttribute( "identifier" ) );
						panel.close();
						break;
					case "message":
						updateIntervalDelta -= 500;
						var message = children[i];
						if( message.firstChild ) {
							var panel = ChatController.panel( message.getAttribute( "panel" ) );
							panel.appendMessage( message.firstChild.nodeValue );
							if( ! panel.active ) {
								panel.updateNewMessageCount( panel.newMessages + 1 );
								if( message.getAttribute( "highlighted" ) )
									panel.updateHighlightMessageCount( panel.newHighlightMessages + 1 );
							}
						}
						break;
					case "event":
						updateIntervalDelta -= 200;
						var event = children[i];
						if( event.firstChild ) {
							var panel = ChatController.panel( event.getAttribute( "panel" ) );
							//panel.appendEvent( event.firstChild.nodeValue );
						}
						break;
					}
				}
			}

			if( ! updateIntervalDelta ) updateIntervalDelta = UserDefaults.activityCheckIntervalIncrement;

			var newActivityCheckInterval = Math.min( ( currentActivityCheckInterval + updateIntervalDelta ), UserDefaults.maximumActivityCheckInterval );
			newActivityCheckInterval = Math.max( newActivityCheckInterval, UserDefaults.minimumActivityCheckInterval );

			if( newActivityCheckInterval != currentActivityCheckInterval ) {
				currentActivityCheckInterval = newActivityCheckInterval;

				if( activityCheckInterval ) clearInterval( activityCheckInterval );
				activityCheckInterval = setInterval( ChatController.checkActivity, currentActivityCheckInterval );
			}
		},
		onFailure: function( transport ) {
			if( activityCheckInterval ) clearInterval( activityCheckInterval );
			activityCheckInterval = setInterval( ChatController.checkActivity, UserDefaults.minimumActivityCheckInterval );
		},
		onException: function( transport, exception ) {
			throw exception;
		}
	} );
};

function Panel( node ) {
	var panel = this;

	this.id = node.getAttribute( "identifier" );
	this.name = node.getAttribute( "name" );
	this.server = node.getAttribute( "server" );
	this.type = node.getAttribute( "class" );
	this.active = false;

	this.menuElement = $(document.createElement( "div" ));
	this.menuElement.className = "colloquy";
	this.menuElement.addEventListener( "click", function( event ) { panel.show(); }, false );

	this.menuTitleElement = $(document.createElement( "div" ));
	this.menuTitleElement.className = "colloquy-title";
	this.menuTitleElement.textContent = this.name + " (" + this.server + ")";
	this.menuElement.appendChild(this.menuTitleElement);

	this.menuPreviewElement = $(document.createElement( "div" ));
	this.menuPreviewElement.className = "colloquy-preview";
	this.menuElement.appendChild(this.menuPreviewElement);

	var waitingElement = $(document.createElement( "div" ));
	waitingElement.className = "waiting";

	this.highlightsElement = $(document.createElement( "div" ));
	this.highlightsElement.className = "highlights";
	waitingElement.appendChild( this.highlightsElement );

	this.messagesElement = $(document.createElement( "div" ));
	this.messagesElement.className = "messages";
	waitingElement.appendChild( this.messagesElement );

	this.menuElement.appendChild( waitingElement );

	this.panelElement = $(document.createElement( "div" ));
	this.panelElement.className = "colloquy-panel";

	Colloquy.mainElement.appendChild(this.panelElement);

	ChatController.panels.push( this );
	Colloquy.colloquiesElement.appendChild( this.menuElement );
}

Panel.prototype.toString = function() {
	return this.name + " (" + this.type + ":" + this.id + ")";
}

Panel.prototype.show = function() {
	if( ChatController.activePanel || Colloquy.animatingMenu ) return;

	Colloquy.animatingMenu = true;

	var animations = [{element: Colloquy.backElement, end: {left: 6, opacity: 1}},
		{element: Colloquy.joinElement, end: {opacity: 0}},
		{element: Colloquy.colloquyTitleElement, end: {left: 0, opacity: 1}},
		{element: Colloquy.mainTitleElement, end: {left: -110, top: 6, "font-size": 12, "line-height": 28}},
		{element: Colloquy.colloquiesElement, end: {left: -321}}, {element: this.panelElement, end: {left: 0}}];

	if (this.type == "JVChatRoomPanel")
		animations.push({element: Colloquy.membersElement, end: {opacity: 1}});

	Colloquy.backElement.style.display = "block";
	Colloquy.colloquyTitleElement.style.display = "block";
	Colloquy.membersElement.style.display = "block";

	Colloquy.colloquyTitleElement.textContent = this.name;

	var panel = this;
	var animateStyleFinished = function() {
		panel.menuElement.removeClassName( "selected" );
		Colloquy.joinElement.style.display = "none";
		Colloquy.mainTitleElement.style.display = "none";
		delete Colloquy.animatingMenu;
	};

	Colloquy.animateStyle(animations, (event.shiftKey ? 2500 : 250), animateStyleFinished);

	this.menuElement.addClassName( "selected" );
	this.active = true;
	this.focused();

	ChatController.activePanel = this;
}

Panel.prototype.close = function() {
	if (this.active) {
		this.closeAfterAnimate = true;
		Colloquy.showColloquiesList();
		return;
	}

	for( var i = 0, l = ChatController.panels.length; i < l; ++i )
		if( ChatController.panels[i].id == this.id ) break;

	if( i < ChatController.panels.length )
		ChatController.panels.slice( i, 1 );

	this.panelElement.parentNode.removeChild( this.panelElement );
	this.menuElement.parentNode.removeChild( this.menuElement );

	Colloquy.updateMainTitle();
}

function DirectChatPanel( node ) {
	var panel = this;

	DirectChatPanel.baseConstructor.call( this, node );

	this.newMessages = 0;
	this.newHighlightMessages = 0;

	this.menuElement.addClassName( "directChat" );

	this.panelTranscriptElement = $(document.createElement( "div" ));
	this.panelTranscriptElement.className = "colloquy-panel-transcript";
	this.panelElement.appendChild(this.panelTranscriptElement);

	this.panelInputBarElement = $(document.createElement( "div" ));
	this.panelInputBarElement.className = "colloquy-panel-input";
	this.panelElement.appendChild(this.panelInputBarElement);

	var form = document.createElement("form");
	form.addEventListener("submit", function(event) { event.preventDefault(); panel.send() }, false);

	this.panelInputElement = document.createElement("input");
	form.appendChild(this.panelInputElement);

	this.panelInputElement.addEventListener("focus", function(event) { panel.setKeyboardVisible(true) }, false);
	this.panelInputElement.addEventListener("blur", function(event) { panel.setKeyboardVisible(false) }, false);

	this.panelInputBarElement.appendChild(form);
}

extendClass( DirectChatPanel, Panel );

DirectChatPanel.prototype.send = function() {
	this.sendMessage(this.panelInputElement.value);

	this.panelInputElement.focus();

	var valueLength = this.panelInputElement.value.length;
	this.panelInputElement.selectionStart = valueLength;
	this.panelInputElement.selectionEnd = valueLength;

	document.execCommand("selectAll");
	document.execCommand("delete");
}

DirectChatPanel.prototype.setKeyboardVisible = function(visible) {
	this.keyboardVisible = visible;

	if( visible ) {
		this.panelTranscriptElement.style.height = "119px";

		this.panelInputElement.focus();

		var valueLength = this.panelInputElement.value.length;
		this.panelInputElement.selectionStart = valueLength;
		this.panelInputElement.selectionEnd = valueLength;
	} else {
		this.panelTranscriptElement.style.height = null;
	}

	this.scrollToBottom();
}

DirectChatPanel.prototype.sendMessage = function( html ) {
	if( ! html.length ) return;

	new Ajax.Request( "/command/send?panel=" + this.id, {
		method: "post",
		contentType: "text/html",
		postBody: html,
		onSuccess: function( transport ) {
			if( activityCheckInterval ) clearInterval( activityCheckInterval );
			activityCheckInterval = setInterval( ChatController.checkActivity, 250 );
		},
		onException: function( transport, exception ) {
			throw exception;
		}
	} );
}

DirectChatPanel.prototype.appendMessage = function( xml ) {
	var xmlobject = (new DOMParser()).parseFromString(xml, "text/xml");
	var sender = xmlobject.getElementsByTagName("sender")[0];
	var message = xmlobject.getElementsByTagName("message")[0];

	var preview = $(document.createElement("div"));

	var senderNode = document.createElement("b");
	senderNode.textContent = sender.firstChild.nodeValue + ": ";

	preview.appendChild(senderNode);

	var links = xmlobject.getElementsByTagName("a");
	for (var i = 0; i < links.length; ++i) {
		var link = links[i];
		link.setAttribute("target", "_blank");
	}

	var msgString = "";
	var current = message.firstChild;
	while (current) {
		msgString += (new XMLSerializer()).serializeToString(current);
		current = current.nextSibling;
	}

	var msgSpan = document.createElement("span");
	msgSpan.innerHTML = msgString;
	preview.appendChild(msgSpan);

	if (this.menuPreviewElement.childNodes.length > 1)
		this.menuPreviewElement.removeChild(this.menuPreviewElement.firstChild);

	this.menuPreviewElement.appendChild(preview);

	var messageWrapper = document.createElement("div");
	messageWrapper.className = "message-wrapper";

	var senderDiv = document.createElement("div");
	senderDiv.className = "sender";
	senderDiv.textContent = sender.firstChild.nodeValue;

	var messageDiv = document.createElement("div");
	messageDiv.className = "message";
	messageDiv.innerHTML = msgString;

	messageWrapper.appendChild(senderDiv);
	messageWrapper.appendChild(messageDiv);

	var scrolledNearBottom = this.scrolledNearBottom();

	this.panelTranscriptElement.appendChild(messageWrapper);

	this.enforceScrollBackLimit();
	if( scrolledNearBottom ) this.scrollToBottom();
}

DirectChatPanel.prototype.enforceScrollBackLimit = function() {
	var bodyNode = this.panelTranscriptElement;
	if( UserDefaults.scrollBackMessageLimit > 0 && bodyNode.childNodes.length > UserDefaults.scrollBackMessageLimit )
		for( var i = 0; bodyNode.childNodes.length > UserDefaults.scrollBackMessageLimit && i < ( bodyNode.childNodes.length - UserDefaults.scrollBackMessageLimit ); ++i )
			bodyNode.removeChild( bodyNode.firstChild );
}

DirectChatPanel.prototype.scrollToBottom = function() {
	this.panelTranscriptElement.scrollTop = this.panelTranscriptElement.scrollHeight;
}

DirectChatPanel.prototype.scrolledNearBottom = function() {
	var transcriptHeight = this.panelTranscriptElement.offsetHeight;
	return ( ( transcriptHeight + this.panelTranscriptElement.scrollTop ) >= ( this.panelTranscriptElement.scrollHeight - 15 ) );
}

DirectChatPanel.prototype.updateNewMessageCount = function( messages ) {
	this.newMessages = messages;

	Colloquy.updateMainTitle();

	if( messages == 0 ) this.menuElement.title = "No messages waiting";
	else if( messages == 1 ) this.menuElement.title = "1 message waiting";
	else this.menuElement.title = messages + " messages waiting";

	this.messagesElement.removeClassName( "small" );
	this.messagesElement.removeClassName( "medium" );
	this.messagesElement.removeClassName( "large" );

	if( messages > 0 && messages <= 9 ) {
		if( ! this.messagesElement.hasClassName( "small" ) )
			this.messagesElement.addClassName( "small" );
	} else if( messages >= 10 && messages <= 99 ) {
		if( ! this.messagesElement.hasClassName( "medium" ) )
			this.messagesElement.addClassName( "medium" );
	} else if( messages >= 100 ) {
		if( ! this.messagesElement.hasClassName( "large" ) )
			this.messagesElement.addClassName( "large" );
	}

	this.messagesElement.innerText = ( messages > 0 ? messages : "" );
}

DirectChatPanel.prototype.updateHighlightMessageCount = function( messages ) {
	this.newHighlightMessages = messages;

	Colloquy.updateMainTitle();

	this.highlightsElement.removeClassName( "small" );
	this.highlightsElement.removeClassName( "medium" );
	this.highlightsElement.removeClassName( "large" );

	if( messages > 0 && messages <= 9 ) {
		if( ! this.highlightsElement.hasClassName( "small" ) )
			this.highlightsElement.addClassName( "small" );
	} else if( messages >= 10 && messages <= 99 ) {
		if( ! this.highlightsElement.hasClassName( "medium" ) )
			this.highlightsElement.addClassName( "medium" );
	} else if( messages >= 100 ) {
		if( ! this.highlightsElement.hasClassName( "large" ) )
			this.highlightsElement.addClassName( "large" );
	}

	this.highlightsElement.innerText = ( messages > 0 ? messages : "" );
}

DirectChatPanel.prototype.focused = function() {
	this.updateNewMessageCount( 0 );
	this.updateHighlightMessageCount( 0 );
}

function ChatRoomPanel( node ) {
	var panel = this;

	ChatRoomPanel.baseConstructor.call( this, node );

	this.memberListVisible = false;

	this.menuElement.removeClassName( "directChat" );
	this.menuElement.addClassName( "chatRoom" );

	this.membersElement = $(document.createElement("div"));
	this.membersElement.className = "colloquy-members";

	var header = document.createElement("div");
	header.className = "header";

	var title = document.createElement("div");
	title.className = "colloquy-members-title";
	title.textContent = this.name + " Members";

	header.appendChild(title);

	var done = document.createElement("div");
	done.className = "button action";
	done.textContent = "Done";

	done.addEventListener("click", function(event) { panel.hideMembersList(event) }, false);

	header.appendChild(done);

	this.membersElement.appendChild(header);

	this.membersListElement = document.createElement("div");
	this.membersListElement.className = "colloquy-member-list";

	this.membersElement.appendChild(this.membersListElement);

	Colloquy.mainElement.appendChild(this.membersElement);

	this.members = new Array();

	var memberNodes = node.childNodes;
	for( var i = 0; i < memberNodes.length; ++i ) {
		var memberNode = memberNodes[i];

		var member = new Object();
		member.name = memberNode.firstChild.nodeValue;
		member.nickname = memberNode.getAttribute( "nickname" );
		member.hostmask = memberNode.getAttribute( "hostmask" );
		member.identifier = memberNode.getAttribute( "identifier" );
		member.buddy = memberNode.getAttribute( "buddy" );
		member.type = memberNode.getAttribute( "class" );
		member.self = ( memberNode.getAttribute( "self" ) == "yes" );

		this.members.push( member );

		var memberElement = document.createElement( "div" );
		memberElement.title = member.hostmask;
		memberElement.className = "member" + ( member.type ? " " + member.type : "" );
		memberElement.textContent = member.name + " ";

		this.membersListElement.appendChild(memberElement);
	}
}

extendClass( ChatRoomPanel, DirectChatPanel );

ChatRoomPanel.prototype.showMembersList = function(event) {
	if (this.showingMembers)
		return;

	this.showingMembers = true;

	var animations = [{element: this.membersElement, end: {top: 0}}];

	this.membersElement.style.display = "block";

	Colloquy.animateStyle(animations, (event.shiftKey ? 2500 : 250));
}

ChatRoomPanel.prototype.hideMembersList = function(event) {
	if (!this.showingMembers)
		return;

	var animations = [{element: this.membersElement, end: {top: 416}}];

	this.membersElement.style.display = "block";

	var panel = this;
	var animateStyleFinished = function() {
		delete panel.showingMembers;
	};

	Colloquy.animateStyle(animations, (event.shiftKey ? 2500 : 250), animateStyleFinished);
}
