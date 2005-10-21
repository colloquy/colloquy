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

function createPanel( id, name, server, type ) {
	if( panelForIdentifier( id ) ) return;

	var panel = new Object();
	panel.id = id;
	panel.name = name;
	panel.server = server;
	panel.type = type;
	panel.newMessage = 0;
	panel.newHighlightMessage = 0;
	panel.active = false;
	panel.frame = document.createElement( "iframe" );
	panel.listItem = document.createElement( "li" );
	panels.push( panel );

	panel.frame.id = "panel" + id;
	panel.frame.className = "panel";
	panel.frame.src = "/command/panelContents?panel=" + id;
	if( panels.length > 1 ) panel.frame.style.setProperty( "visibility", "hidden", "" );
	document.getElementById( "panels" ).appendChild( panel.frame );

	panel.listItem.id = "listItem" + id;
	panel.listItem.className = "listItem";

	if( type == "JVChatRoomPanel" ) panel.listItem.className += " chatRoom";
	else if( type == "JVDirectChatPanel" ) panel.listItem.className += " directChat";

	panel.listItem.setAttribute( "onclick", "switchPanel(" + id + ")" );
	panel.listItem.appendChild( document.createTextNode( name ) );
	document.getElementById( "panelList" ).appendChild( panel.listItem );

	if( panels.length == 1 ) switchPanel( id );
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

		for( var i = 0; i < children.length; i++ ) {
			var panel = children[i];
			createPanel( panel.getAttribute( "identifier" ), panel.getAttribute( "name" ), panel.getAttribute( "server" ), panel.getAttribute( "class" ) );
		}

		checkQueue();
		queueCheckInterval = setInterval( checkQueue, queueCheckSpeed );
	}
}

function processQueue() {
	if( currentRequest.readyState == 4 && currentRequest.status == 200 ) {
		var xml = currentRequest.responseXML;
		var children = xml.documentElement.childNodes;

		var messages = 0;
		for( var i = 0; i < children.length; i++ ) {
			switch( children[i].tagName ) {
			case "open":
				var panel = children[i];
				createPanel( panel.getAttribute( "identifier" ), panel.getAttribute( "name" ), panel.getAttribute( "server" ), panel.getAttribute( "class" ) );
				break;
			case "close":
				var panel = children[i];
				closePanel( panel.getAttribute( "identifier" ) );
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