var panels = new Array();
var queueCheckInterval = null;
var queueCheckSpeed = 4000;
var scrollBackLimit = 300;
var activePanel = null;
var foreground = true;
var currentRequest = null;

function createRequestObject() {
	if( navigator.appName == "Microsoft Internet Explorer" )
		return new ActiveXObject( "Microsoft.XMLHTTP" );
	return new XMLHttpRequest();
}

function setup() {
	document.body.addEventListener( "keypress", documentKeyInput, true );
	document.getElementById( "input" ).addEventListener( "keypress", inputKeyPressed, false );
	document.body.addEventListener( "blur", windowBlured, false );
	document.body.addEventListener( "focus", windowFocused, false );

	currentRequest = createRequestObject();
	currentRequest.onreadystatechange = processSetup;
	currentRequest.open( "GET", "/command/setup" );
	currentRequest.send( null );
}

function windowBlured() {
	foreground = false;
	document.getElementById( "timer" ).innerText = "blured";
}

function windowFocused() {
	foreground = true;
	activePanel.newMessage = 0;
	activePanel.newHighlightMessage = 0;
	activePanel.listItem.className = activePanel.listItem.className.replace( /\s*newMessage/g, "" );
	activePanel.listItem.className = activePanel.listItem.className.replace( /\s*newHighlight/g, "" );
	activePanel.listItem.title = "No messages waiting";
	document.getElementById( "timer" ).innerText = "focused";
}

function checkQueue() {
	currentRequest = createRequestObject();
	currentRequest.onreadystatechange = processQueue;
	currentRequest.open( "GET", "/command/checkActivity" );
	currentRequest.send( null );	
}

function panelForIdentifier( id ) {
	for( var i = 0; i < panels.length; i++ )
		if( panels[i].id == id )
			return panels[i];
	return null;
}

function switchPanel( id ) {
	for( var i = 0; i < panels.length; i++ ) {
		var panel = panels[i];
		if( panel.id == id ) {
			if( ! panel.active ) {
				panel.frame.style.setProperty( "visibility", "visible", "" );
				panel.listItem.className += " selected";
				panel.active = true;
				panel.newMessage = 0;
				panel.newHighlightMessage = 0;
				panel.listItem.className = panel.listItem.className.replace( /\s*newMessage/g, "" );
				panel.listItem.className = panel.listItem.className.replace( /\s*newHighlight/g, "" );
				panel.listItem.title = "No messages waiting";
				activePanel = panel;
			}
		} else {
			panel.frame.style.setProperty( "visibility", "hidden", "" );
			panel.listItem.className = panel.listItem.className.replace( /\s*selected/g, "" );
			panel.active = false;
		}
	}
}

function toggleMemberList( event, id ) {
	var panel = panelForIdentifier( id );
	panel.memberListVisible = ! panel.memberListVisible;
	if( panel.memberListVisible ) panel.memberList.style.setProperty( "display", "none", "" );
	else panel.memberList.style.setProperty( "display", "block", "" );
	event.preventDefault();
	event.stopPropagation();
}

function createPanel( node ) {
	if( panelForIdentifier( node.getAttribute( "identifier" ) ) ) return;

	var panel = new Object();
	panel.id = node.getAttribute( "identifier" );
	panel.name = node.getAttribute( "name" );
	panel.server = node.getAttribute( "server" );
	panel.type = node.getAttribute( "class" );
	panel.newMessage = 0;
	panel.newHighlightMessage = 0;
	panel.active = false;
	panel.memberListVisible = false;
	panel.frame = document.createElement( "iframe" );
	panel.listItem = document.createElement( "li" );
	panels.push( panel );

	panel.frame.id = "panel" + panel.id;
	panel.frame.className = "panel";
	panel.frame.src = "/command/panelContents?panel=" + panel.id;
	if( panels.length > 1 ) panel.frame.style.setProperty( "visibility", "hidden", "" );
	document.getElementById( "panels" ).appendChild( panel.frame );

	panel.listItem.id = "listItem" + panel.id;
	panel.listItem.className = "listItem";

	if( panel.type == "JVChatRoomPanel" ) {
		panel.listItem.className += " chatRoom";
		panel.members = new Array();
		panel.memberList = document.createElement( "ol" );
		panel.memberList.className = "memberList";
		panel.memberList.style.setProperty( "display", "none", "" );

		var memberNode = null;
		var members = node.childNodes;
		for( var i = 0; i < members.length; i++ ) {
			memberNode = members[i];

			var member = new Object();
			member.name = memberNode.firstChild.nodeValue;
			member.nickname = memberNode.getAttribute( "nickname" );
			member.hostmask = memberNode.getAttribute( "hostmask" );
			member.identifier = memberNode.getAttribute( "identifier" );
			member.buddy = memberNode.getAttribute( "buddy" );
			member.type = memberNode.getAttribute( "class" );
			member.self = ( memberNode.getAttribute( "self" ) == "yes" );
			panel.members.push( member );

			member.listItem = document.createElement( "li" );
			member.listItem.title = member.hostmask;
			member.listItem.className = "listItem member" + ( member.type ? " " + member.type : "" );
			member.listItem.appendChild( document.createTextNode( member.name ) );
			panel.memberList.appendChild( member.listItem );
		}
	} else if( panel.type == "JVDirectChatPanel" ) panel.listItem.className += " directChat";

	panel.listItem.setAttribute( "onclick", "switchPanel(" + panel.id + ")" );
	panel.listItem.setAttribute( "ondblclick", "toggleMemberList(event," + panel.id + ")" );
	panel.listItem.appendChild( document.createTextNode( panel.name ) );
	document.getElementById( "panelList" ).appendChild( panel.listItem );
	if( panel.memberList ) document.getElementById( "panelList" ).appendChild( panel.memberList );

	setTimeout( scrollToBottom, 50, panel.frame );

	if( panels.length == 1 ) switchPanel( panel.id );
}

function closePanel( id ) {
	for( var i = 0; i < panels.length; i++ )
		if( panels[i].id == id ) break;

	if( i >= panels.length ) return;

	var panel = panels[i];
	panels.slice( i, 1 );

	panel.frame.parentNode.removeChild( panel.frame );
	panel.listItem.parentNode.removeChild( panel.listItem );

	switchPanel( panels[0].id );
}

function processSetup() {
	if( currentRequest.readyState == 4 && currentRequest.status == 200 ) {
		var xml = currentRequest.responseXML;
		var children = xml.documentElement.getElementsByTagName( "panels" ).item( 0 ).childNodes;

		for( var i = 0; i < children.length; i++ )
			createPanel( children[i] );

		checkQueue();
		queueCheckInterval = setInterval( checkQueue, queueCheckSpeed );
	}
}

function processQueue() {
	if( currentRequest.readyState == 4 && currentRequest.status == 200 && currentRequest.responseText.length ) {
		var xml = currentRequest.responseXML;
		var children = xml.documentElement.childNodes;

		var messages = 0;
		for( var i = 0; i < children.length; i++ ) {
			switch( children[i].tagName ) {
			case "open":
				createPanel( children[i] );
				break;
			case "close":
				closePanel( children[i].getAttribute( "identifier" ) );
				break;
			case "message":
				messages++;
				var message = children[i];
				var id = message.getAttribute( "panel" );
				if( message.firstChild ) {
					appendMessage( id, message.firstChild.nodeValue );
					var panel = panelForIdentifier( id );
					if( ( ( ! foreground && panel.active ) || ! panel.active ) && panel.listItem.className.indexOf( "newMessage" ) == -1 ) {
						panel.listItem.className += " newMessage";
						panel.newMessage++;
						panel.listItem.title = panel.newMessage + " messages waiting";
					}
				}
				break;
			}
		}

		if( messages >= 1 ) {
			queueCheckSpeed -= ( 500 * messages );
			if( queueCheckSpeed < 500 ) queueCheckSpeed = 500;
			clearInterval( queueCheckInterval );
			queueCheckInterval = setInterval( checkQueue, queueCheckSpeed );
			document.getElementById( "timer" ).innerText = queueCheckSpeed / 1000 + " secs";
		}
	} else if( currentRequest.readyState == 4 ) {
		if( queueCheckSpeed < 4000 ) {
			queueCheckSpeed += 100;
			if( queueCheckSpeed > 4000 ) queueCheckSpeed = 4000;
			clearInterval( queueCheckInterval );
			queueCheckInterval = setInterval( checkQueue, queueCheckSpeed );
			document.getElementById( "timer" ).innerText = queueCheckSpeed / 1000 + " secs";
		}
	}
}

function documentKeyInput( event ) {
	if( event.target.id == "input" || event.target.parentNode.id == "input" ) return;
	if( event.keyCode == 13 && ! event.altKey ) inputKeyPressed( event );
	else if( event.keyCode == 32 ) input.innerHTML += "&nbsp;";
	else input.innerHTML += String.fromCharCode( event.keyCode );
}

function inputKeyPressed( event ) {
	if( event.keyCode == 13 && ! event.altKey ) {
		var input = document.getElementById( "input" );
		sendMessage( activePanel.id, input.innerText );
		input.innerHTML = "";
	}
}

function sendMessage( panel, html ) {
	if( ! html.length ) return;
	currentRequest = createRequestObject();
	currentRequest.onreadystatechange = processQueue;
	currentRequest.open( "POST", "/command/send?panel=" + panel );
	currentRequest.send( html );
	setTimeout( checkQueue, 250 );
}

function appendMessage( panel, html ) {
	var frame = document.getElementById( "panel" + panel );
	if( html.indexOf( "<?message type=\"subsequent\"?>" ) != -1 && frame.document.getElementById( "consecutiveInsert" ) ) {
		appendConsecutiveMessage( panel, html );
		return;
	}

	var needed = checkIfScrollToBottomIsNeeded( frame );

	var bodyNode = frame.document.getElementById( "contents" );
	if( ! bodyNode ) bodyNode = frame.document.body;

	var insert = frame.document.getElementById( "consecutiveInsert" );
	if( insert ) insert.parentNode.removeChild( insert );

	var range = frame.document.createRange();
	range.selectNode( bodyNode );
	var documentFragment = range.createContextualFragment( html );
	bodyNode.appendChild( documentFragment );

	enforceScrollBackLimit( frame );
	if( needed ) scrollToBottom( frame );
}

function appendConsecutiveMessage( panel, html ) {
	var needed = checkIfScrollToBottomIsNeeded( frame );

	var frame = document.getElementById( "panel" + panel );
	var insert = frame.document.getElementById( "consecutiveInsert" );
	if( ! insert ) {
		appendMessage( panel, html );
		return;
	}

	var range =  frame.document.createRange();
	range.selectNode( insert.parentNode );
	var documentFragment = range.createContextualFragment( html );
	insert.parentNode.replaceChild( documentFragment, insert );

	enforceScrollBackLimit( frame );
	if( needed ) scrollToBottom( frame );
}

function enforceScrollBackLimit( frame ) {
	var bodyNode = frame.document.getElementById( "contents" );
	if( ! bodyNode ) bodyNode = frame.document.body;
	if( scrollBackLimit > 0 && bodyNode.childNodes.length > scrollBackLimit )
		for( var i = 0; bodyNode.childNodes.length > scrollBackLimit && i < ( bodyNode.childNodes.length - scrollBackLimit ); i++ )
			bodyNode.removeChild( bodyNode.childNodes[0] );
}

function scrollToBottom( frame ) {
	var bodyNode = frame.document.getElementById( "contents" );
	if( ! bodyNode ) bodyNode = frame.document.body;
	bodyNode.scrollTop = bodyNode.scrollHeight;
}

function checkIfScrollToBottomIsNeeded( frame ) {
	return true;
/*	var bodyNode = frame.document.getElementById( "contents" );
	if( ! bodyNode ) bodyNode = frame.document.body;
	scrollToBottomIsNeeded = ( bodyNode.scrollTop >= ( bodyNode.offsetHeight - ( window.innerHeight * 1.1 ) ) ); */
}