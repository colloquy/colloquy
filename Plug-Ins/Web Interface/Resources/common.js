function extendClass( subClass, baseClass ) {
	function inheritance() {}
	inheritance.prototype = baseClass.prototype;

	subClass.prototype = new inheritance();
	subClass.prototype.constructor = subClass;
	subClass.baseConstructor = baseClass;
	subClass.superClass = baseClass.prototype;
}

var UserDefaults = {
	minimumActivityCheckInterval: 500,
	maximumActivityCheckInterval: 5000,
	scrollBackMessageLimit: 300
};

var activityCheckInterval = null;
var currentActivityCheckInterval = ( UserDefaults.maximumActivityCheckInterval / 2 );
var foreground = true;

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
							if( ( ( ! foreground && panel.active ) || ! panel.active ) ) {
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
							panel.appendMessage( event.firstChild.nodeValue );
						}
						break;
					}
				}
			}

			if( ! updateIntervalDelta ) updateIntervalDelta = 100;

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

	this.listItem = $(document.createElement( "li" ));
	this.listItem.className = "listItem";
	this.listItem.addEventListener( "click", function( event ) { panel.show(); }, false );

	var iconElement = $(document.createElement( "div" ));
	iconElement.className = "icon";
	this.listItem.appendChild( iconElement );

	this.labelElement = $(document.createElement( "div" ));
	this.labelElement.className = "label";
	this.labelElement.appendChild( document.createTextNode( this.name ) );
	this.listItem.appendChild( this.labelElement );

	this.infoLabelElement = $(document.createElement( "div" ));
	this.infoLabelElement.className = "info";
	this.infoLabelElement.appendChild( document.createTextNode( this.server ) );
	this.listItem.appendChild( this.infoLabelElement );

	var waitingElement = $(document.createElement( "div" ));
	waitingElement.className = "waiting";

	this.highlightsElement = $(document.createElement( "div" ));
	this.highlightsElement.className = "highlights";
	waitingElement.appendChild( this.highlightsElement );

	this.messagesElement = $(document.createElement( "div" ));
	this.messagesElement.className = "messages";
	waitingElement.appendChild( this.messagesElement );

	this.listItem.appendChild( waitingElement );

	this.frame = $(document.createElement( "iframe" ));
	this.frame.className = "panel";

	if( ChatController.panels.length )
		this.frame.style.setProperty( "visibility", "hidden", "" );

	ChatController.panels.push( this );
	$("sidebar").appendChild( this.listItem );
	$("panels").appendChild( this.frame );

	if( ChatController.panels.length == 1 )
		this.show();
}

Panel.prototype.toString = function() {
	return this.name + " (" + this.type + ":" + this.id + ")";
}

Panel.prototype.show = function() {
	if( this.active ) return;

	for( var i = 0, l = ChatController.panels.length; i < l; ++i ) {
		var panel = ChatController.panels[i];
		if( panel.id == this.id ) {
			ChatController.activePanel = panel;
			panel.frame.style.setProperty( "visibility", "visible", "" );
			panel.listItem.addClassName( "selected" );
			panel.active = true;
			panel.focused();
		} else {
			panel.frame.style.setProperty( "visibility", "hidden", "" );
			panel.listItem.removeClassName( "selected" );
			panel.active = false;
		}
	}
}

Panel.prototype.close = function() {
	for( var i = 0, l = ChatController.panels.length; i < l; ++i )
		if( ChatController.panels[i].id == this.id ) break;

	if( i < ChatController.panels.length )
		ChatController.panels.slice( i, 1 );

	this.frame.parentNode.removeChild( this.frame );
	this.listItem.parentNode.removeChild( this.listItem );

	ChatController.panels[0].show();
}

function DirectChatPanel( node ) {
	DirectChatPanel.baseConstructor.call( this, node );

	this.newMessages = 0;
	this.newHighlightMessages = 0;

	this.listItem.addClassName( "directChat" );

	var panel = this;
	this.frame.onload = function() {
		panel.contentFrame = $(panel.frame.document.getElementById( "content" ));
		panel.contentFrame.onload = function() { panel.scrollToBottom() };
		panel.contentFrame.src = "/command/panelContents?panel=" + panel.id;
	};

	this.frame.src = "/resources/base.html";
}

extendClass( DirectChatPanel, Panel );

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

DirectChatPanel.prototype.appendMessage = function( html ) {
	var scrollNeeded = this.checkIfScrollToBottomIsNeeded();

	var frame = this.contentFrame;
	var bodyNode = frame.document.getElementById( "contents" );
	if( ! bodyNode ) bodyNode = frame.document.body;

	var consecutive = ( html.indexOf( "<?message type=\"consecutive\"?>" ) != -1 );
	if( ! consecutive ) consecutive = ( html.indexOf( "<?message type=\"subsequent\"?>" ) != -1 );

	var insert = frame.document.getElementById( "consecutiveInsert" );

	if( consecutive && insert ) {
		var range =  frame.document.createRange();
		range.selectNode( insert.parentNode );
		var documentFragment = range.createContextualFragment( html );
		insert.parentNode.replaceChild( documentFragment, insert );
	} else {
		if( insert ) insert.parentNode.removeChild( insert );

		var range = frame.document.createRange();
		range.selectNode( bodyNode );
		var documentFragment = range.createContextualFragment( html );
		bodyNode.appendChild( documentFragment );
	}

	this.enforceScrollBackLimit();
	if( scrollNeeded ) this.scrollToBottom();
}

DirectChatPanel.prototype.enforceScrollBackLimit = function() {
	var frame = this.contentFrame;
	var bodyNode = frame.document.getElementById( "contents" );
	if( ! bodyNode ) bodyNode = frame.document.body;
	if( UserDefaults.scrollBackMessageLimit > 0 && bodyNode.childNodes.length > UserDefaults.scrollBackMessageLimit )
		for( var i = 0; bodyNode.childNodes.length > UserDefaults.scrollBackMessageLimit && i < ( bodyNode.childNodes.length - UserDefaults.scrollBackMessageLimit ); ++i )
			bodyNode.removeChild( bodyNode.childNodes[0] );
}

DirectChatPanel.prototype.scrollToBottom = function() {
	var frame = this.contentFrame;
	var bodyNode = frame.document.getElementById( "contents" );
	if( ! bodyNode ) bodyNode = frame.document.body;
	bodyNode.scrollTop = bodyNode.scrollHeight;
}

DirectChatPanel.prototype.checkIfScrollToBottomIsNeeded = function() {
//	var frame = this.contentFrame;
	return true;
/*	var bodyNode = frame.document.getElementById( "contents" );
	if( ! bodyNode ) bodyNode = frame.document.body;
	scrollToBottomIsNeeded = ( bodyNode.scrollTop >= ( bodyNode.offsetHeight - ( window.innerHeight * 1.1 ) ) ); */
}

DirectChatPanel.prototype.updateNewMessageCount = function( messages ) {
	this.newMessages = messages;

	if( messages == 0 ) this.listItem.title = "No messages waiting";
	else if( messages == 1 ) this.listItem.title = "1 message waiting";
	else this.listItem.title = messages + " messages waiting";

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
	ChatRoomPanel.baseConstructor.call( this, node );

	this.memberListVisible = false;

	this.listItem.removeClassName( "directChat" );
	this.listItem.addClassName( "chatRoom" );

	this.members = new Array();

	this.memberList = $(document.createElement( "ol" ));
	this.memberList.className = "memberList";
	this.memberList.style.setProperty( "display", "none", "" );
	$("sidebar").appendChild( this.memberList );

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

		member.listItem = $(document.createElement( "li" ));
		member.listItem.title = member.hostmask;
		member.listItem.className = "listItem member" + ( member.type ? " " + member.type : "" );

		var iconElement = $(document.createElement( "div" ));
		iconElement.className = "icon";
		member.listItem.appendChild( iconElement );

		member.labelElement = $(document.createElement( "div" ));
		member.labelElement.className = "label";
		member.labelElement.appendChild( document.createTextNode( member.name ) );
		member.listItem.appendChild( member.labelElement );

		this.memberList.appendChild( member.listItem );
	}

	var panel = this;
	this.listItem.addEventListener( "dblclick", function( event ) { panel.toggleMemberList(); event.preventDefault(); event.stopPropagation(); }, false );
}

extendClass( ChatRoomPanel, DirectChatPanel );

ChatRoomPanel.prototype.toggleMemberList = function() {
	this.memberListVisible = ! this.memberListVisible;
	if( this.memberListVisible ) this.memberList.style.setProperty( "display", "none", "" );
	else this.memberList.style.setProperty( "display", "block", "" );
}

ChatRoomPanel.prototype.close = function() {
	ChatRoomPanel.superClass.close.call(this);
	this.memberList.parentNode.removeChild( this.memberList );
}

window.addEventListener( "load", setup, false );

function setup() {
	$("input").addEventListener( "keydown", inputKeyDown, false );
	window.addEventListener( "blur", windowBlured, false );
	window.addEventListener( "focus", windowFocused, false );

	new Ajax.Request( "/command/setup", {
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
}

function windowBlured() {
	foreground = false;
}

function windowFocused() {
	foreground = true;

	if( ChatController.activePanel )
		ChatController.activePanel.focused();
}

function inputKeyDown( event ) {
	if( event.keyCode == 13 && ! event.altKey ) {
		var input = $("input");
		ChatController.activePanel.sendMessage( input.innerText );
		input.innerHTML = "";
		event.preventDefault();
	}
}
