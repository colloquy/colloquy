function extendClass( subClass, baseClass ) {
	function inheritance() {}
	inheritance.prototype = baseClass.prototype;

	subClass.prototype = new inheritance();
	subClass.prototype.constructor = subClass;
	subClass.baseConstructor = baseClass;
	subClass.superClass = baseClass.prototype;
}

var activityCheckInterval = null;
var activityCheckSpeed = 4000;
var scrollBackLimit = 300;
var activePanel = null;
var foreground = true;

var ChatController = {
	panels: new Array()
};

ChatController.createPanel = function( node ) {
	var type = node.getAttribute( "class" );
	if( type == "JVDirectChatPanel" )
		return new DirectChatPanel( node );
	else if( type == "JVChatRoomPanel" )
		return new ChatRoomPanel( node );
	return undefined;
};

ChatController.panel = function( id ) {
	for( var i = 0, l = this.panels.length; i < l; ++i )
		if( this.panels[i].id == id ) return this.panels[i];
	return undefined;
}

ChatController.checkActivity = function() {
	new Ajax.Request( "/command/checkActivity", {
		method: "get",
		onSuccess: function( transport ) {
			var updateIntervalDelta = 100;

			if( transport.responseText && transport.responseXML ) {
				var children = transport.responseXML.documentElement.childNodes;
				for( var i = 0; i < children.length; ++i ) {
					switch( children[i].tagName ) {
					case "open":
						ChatController.createPanel( children[i] );
						break;
					case "close":
						var panel = ChatController.panel( children[i].getAttribute( "identifier" ) );
						panel.close();
						break;
					case "message":
						var message = children[i];
						if( message.firstChild ) {
							var panel = ChatController.panel( message.getAttribute( "panel" ) );
							panel.appendMessage( message.firstChild.nodeValue );
							if( ( ( ! foreground && panel.active ) || ! panel.active ) && ! panel.listItem.hasClassName( "newMessage" ) ) {
								panel.listItem.addClassName( "newMessage" );
								panel.newMessage++;
								panel.listItem.title = panel.newMessage + " messages waiting";
							}
						}
						break;
					}
				}

				if( children.length >= 1 )
					updateIntervalDelta = ( -500 * children.length ) - 100;
			}

			var newActivityCheckSpeed = Math.max( Math.min( ( activityCheckSpeed + updateIntervalDelta ), 4000 ), 500 );
			if( newActivityCheckSpeed != activityCheckSpeed ) {
				activityCheckSpeed = newActivityCheckSpeed;

				clearInterval( activityCheckInterval );
				activityCheckInterval = setInterval( ChatController.checkActivity, activityCheckSpeed );

				$("timer").innerText = activityCheckSpeed / 1000 + " secs";
			}
		},
		onFailure: function( transport ) {
			clearInterval( activityCheckInterval );
			activityCheckInterval = setInterval( ChatController.checkActivity, 1000 );
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
	this.listItem.appendChild( document.createTextNode( this.name ) );

	this.frame = $(document.createElement( "iframe" ));
	this.frame.className = "panel";

	if( ChatController.panels.length )
		this.frame.style.setProperty( "visibility", "hidden", "" );

	ChatController.panels.push( this );
	$("panelList").appendChild( this.listItem );
	$("panels").appendChild( this.frame );

	if( ChatController.panels.length == 1 )
		this.show();
}

Panel.prototype.toString = function() {
	return this.name + " (" + this.type + ":" + this.id + ")";
}

Panel.prototype.show = function() {
	for( var i = 0, l = ChatController.panels.length; i < l; ++i ) {
		var panel = ChatController.panels[i];
		if( panel.id == this.id ) {
			if( ! panel.active ) {
				panel.frame.style.setProperty( "visibility", "visible", "" );
				panel.listItem.addClassName( "selected" );
				panel.active = true;
				panel.newMessage = 0;
				panel.newHighlightMessage = 0;
				panel.listItem.removeClassName( "newMessage" );
				panel.listItem.removeClassName( "newHighlight" );
				panel.listItem.title = "No messages waiting";
				activePanel = panel;
			}
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

	this.newMessage = 0;
	this.newHighlightMessage = 0;

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
			clearInterval( activityCheckInterval );
			activityCheckInterval = setInterval( ChatController.checkActivity, 250 );
		},
		onException: function( transport, exception ) {
			throw exception;
		}
	} );
}

DirectChatPanel.prototype.appendMessage = function( html ) {
	var frame = this.contentFrame;

	var consecutive = ( html.indexOf( "<?message type=\"consecutive\"?>" ) != -1 );
	if( ! consecutive ) consecutive = ( html.indexOf( "<?message type=\"subsequent\"?>" ) != -1 );
	if( consecutive && frame.document.getElementById( "consecutiveInsert" ) ) {
		this.appendConsecutiveMessage( html );
		return;
	}

	var needed = this.checkIfScrollToBottomIsNeeded();

	var bodyNode = frame.document.getElementById( "contents" );
	if( ! bodyNode ) bodyNode = frame.document.body;

	var insert = frame.document.getElementById( "consecutiveInsert" );
	if( insert ) insert.parentNode.removeChild( insert );

	var range = frame.document.createRange();
	range.selectNode( bodyNode );
	var documentFragment = range.createContextualFragment( html );
	bodyNode.appendChild( documentFragment );

	this.enforceScrollBackLimit();
	if( needed ) this.scrollToBottom();
}

DirectChatPanel.prototype.appendConsecutiveMessage = function( html ) {
	var frame = this.contentFrame;
	var needed = this.checkIfScrollToBottomIsNeeded();

	var insert = frame.document.getElementById( "consecutiveInsert" );
	if( ! insert ) {
		this.appendMessage( html );
		return;
	}

	var range =  frame.document.createRange();
	range.selectNode( insert.parentNode );
	var documentFragment = range.createContextualFragment( html );
	insert.parentNode.replaceChild( documentFragment, insert );

	this.enforceScrollBackLimit();
	if( needed ) this.scrollToBottom();
}

DirectChatPanel.prototype.enforceScrollBackLimit = function() {
	var frame = this.contentFrame;
	var bodyNode = frame.document.getElementById( "contents" );
	if( ! bodyNode ) bodyNode = frame.document.body;
	if( scrollBackLimit > 0 && bodyNode.childNodes.length > scrollBackLimit )
		for( var i = 0; bodyNode.childNodes.length > scrollBackLimit && i < ( bodyNode.childNodes.length - scrollBackLimit ); ++i )
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

function ChatRoomPanel( node ) {
	ChatRoomPanel.baseConstructor.call( this, node );

	this.memberListVisible = false;

	this.listItem.removeClassName( "directChat" );
	this.listItem.addClassName( "chatRoom" );

	this.members = new Array();

	this.memberList = $(document.createElement( "ol" ));
	this.memberList.className = "memberList";
	this.memberList.style.setProperty( "display", "none", "" );
	$("panelList").appendChild( this.memberList );

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
		member.listItem.appendChild( document.createTextNode( member.name ) );

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
			activityCheckInterval = setInterval( ChatController.checkActivity, activityCheckSpeed );
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
	if( ! activePanel ) return;

	activePanel.newMessage = 0;
	activePanel.newHighlightMessage = 0;
	activePanel.listItem.removeClassName( "newMessage" );
	activePanel.listItem.removeClassName( "newHighlight" );
	activePanel.listItem.title = "No messages waiting";
}

function inputKeyDown( event ) {
	if( event.keyCode == 13 && ! event.altKey ) {
		var input = $("input");
		activePanel.sendMessage( input.innerText );
		input.innerHTML = "";
		event.preventDefault();
	}
}
