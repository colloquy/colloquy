function createRequestObject() {
	if( navigator.appName == "Microsoft Internet Explorer" )
		return new ActiveXObject( "Microsoft.XMLHTTP" );
	return new XMLHttpRequest();
}

var currentRequest = createRequestObject();
currentRequest.open( "GET", "/command/setup" );
currentRequest.send( null );
currentRequest.onreadystatechange = processSetup;

function checkQueue() {
	currentRequest = createRequestObject();
	currentRequest.onreadystatechange = processQueue;
	currentRequest.open( "GET", "/command/checkActivity" );
	currentRequest.send( null );	
}

function switchPanel( id ) {
	panels = document.getElementById( "panels" ).childNodes;
	for( i = 0; i < panels.length; i++ ) {
		panel = panels[i];
		if( panel.id == "panel" + id ) {
			panel.style.setProperty( "visibility", "visible", "" );
		} else {
			panel.style.setProperty( "visibility", "hidden", "" );
		}
	}
}

function createPanel( id, name, server, type ) {
	frame = document.createElement( "iframe" );
	frame.id = "panel" + id;
	frame.className = "panel";
	frame.src = "/command/panelContents?panel=" + id;
	if( document.getElementById( "panels" ).childNodes.length )
		frame.style.setProperty( "visibility", "hidden", "" );
	document.getElementById( "panels" ).appendChild( frame );

	li = document.createElement( "li" );
	li.id = "listItem" + id;
	a = document.createElement( "a" );
	a.setAttribute( "onclick", "switchPanel( " + id + ")" );
	text = document.createTextNode( name );
	a.appendChild( text );
	li.appendChild( a );
	document.getElementById( "panelList" ).appendChild( li );
}

function closePanel( id ) {
	panel = document.getElementById( "panel" + id );
	if( panel ) panel.parentNode.removeChild( panel );
	listItem = document.getElementById( "listItem" + id );
	if( listItem ) listItem.parentNode.removeChild( listItem );
	document.getElementById( "panels" ).childNodes.item(0).style.setProperty( "visibility", "visible", "" );
}

var queueCheckInterval = null;
var queueCheckSpeed = 4000;

function processSetup() {
	if( currentRequest.readyState == 4 && currentRequest.status == 200 ) {
		xml = currentRequest.responseXML;
		panels = xml.getElementsByTagName("setup").item(0).getElementsByTagName("panels").item(0).childNodes;

		for( i = 0; i < panels.length; i++ ) {
			panel = panels[i];
			createPanel( panel.getAttribute("identifier"), panel.getAttribute("name"), panel.getAttribute("server"), panel.getAttribute("class") );
		}

		checkQueue();
		queueCheckInterval = setInterval( checkQueue, queueCheckSpeed );
	}
}

function processQueue() {
	if( currentRequest.readyState == 4 && currentRequest.status == 200 ) {
		xml = currentRequest.responseXML;
		queue = xml.getElementsByTagName("queue").item(0);

		opens = queue.getElementsByTagName("open");
		for( i = 0; i < opens.length; i++ ) {
			panel = opens[i];
			createPanel( panel.getAttribute("identifier"), panel.getAttribute("name"), panel.getAttribute("server"), panel.getAttribute("class") );
		}

		closes = queue.getElementsByTagName("close");
		for( i = 0; i < closes.length; i++ ) {
			panel = closes[i];
			closePanel( panel.getAttribute("identifier") );
		}

		messages = queue.getElementsByTagName("message");
		for( i = 0; i < messages.length; i++ ) {
			appendMessage( messages[i].getAttribute("panel"), messages[i].firstChild.nodeValue );
		}

		if( messages.length >= 1 ) {
			queueCheckSpeed -= ( 500 * messages.length );
			if( queueCheckSpeed < 500 ) queueCheckSpeed = 500;
			clearInterval( queueCheckInterval );
			queueCheckInterval = setInterval( checkQueue, queueCheckSpeed );
			document.getElementById( "timer" ).innerText = queueCheckSpeed;
		}
	} else if( currentRequest.readyState == 4 ) {
		if( queueCheckSpeed < 4000 ) {
			queueCheckSpeed += 100;
			if( queueCheckSpeed > 4000 ) queueCheckSpeed = 4000;
			clearInterval( queueCheckInterval );
			queueCheckInterval = setInterval( checkQueue, queueCheckSpeed );
			document.getElementById( "timer" ).innerText = queueCheckSpeed;
		}
	}
}

var scrollBackLimit = 300;

function appendMessage( panel, html ) {
	frame = document.getElementById("panel" + panel);
	if( html.indexOf("<?message type=\"subsequent\"?>") != -1 && frame.document.getElementById( "consecutiveInsert" ) ) {
		appendConsecutiveMessage( panel, html );
		return;
	}

	needed = checkIfScrollToBottomIsNeeded( frame );

	bodyNode = frame.document.getElementById("contents");
	if( ! bodyNode ) bodyNode = frame.document.getElementsByTagName("body").item(0);

	insert = frame.document.getElementById( "consecutiveInsert" );
	if( insert ) insert.parentNode.removeChild( insert );

	range = frame.document.createRange();
	range.selectNode( bodyNode );
	documentFragment = range.createContextualFragment( html );
	bodyNode.appendChild( documentFragment );

	enforceScrollBackLimit( frame );
	if( needed ) scrollToBottom( frame );
}

function appendConsecutiveMessage( panel, html ) {
	needed = checkIfScrollToBottomIsNeeded( frame );

	frame = document.getElementById("panel" + panel);
	insert = frame.document.getElementById( "consecutiveInsert" );
	if( ! insert ) {
		appendMessage( panel, html );
		return;
	}

	range =  frame.document.createRange();
	range.selectNode( insert.parentNode );
	documentFragment = range.createContextualFragment( html );
	insert.parentNode.replaceChild( documentFragment, insert );

	enforceScrollBackLimit( frame );
	if( needed ) scrollToBottom( frame );
}

function enforceScrollBackLimit( frame ) {
	bodyNode = frame.document.getElementById("contents");
	if( ! bodyNode ) bodyNode = frame.document.getElementsByTagName("body").item(0);
	if( scrollBackLimit > 0 && bodyNode.childNodes.length > scrollBackLimit )
		for( i = 0; bodyNode.childNodes.length > scrollBackLimit && i < ( bodyNode.childNodes.length - scrollBackLimit ); i++ )
			bodyNode.removeChild( bodyNode.childNodes[0] );
}

function scrollToBottom( frame ) {
	bodyNode = frame.document.getElementById("contents");
	if( ! bodyNode ) bodyNode = frame.document.getElementsByTagName("body").item(0);
	bodyNode.scrollTop = bodyNode.scrollHeight;
}

function checkIfScrollToBottomIsNeeded( frame ) {
	return true;
/*	bodyNode = frame.document.getElementById("contents");
	if( ! bodyNode ) bodyNode = frame.document.getElementsByTagName("body").item(0);
	scrollToBottomIsNeeded = ( bodyNode.scrollTop >= ( bodyNode.offsetHeight - ( window.innerHeight * 1.1 ) ) ); */
}