var scrollToBottomIsNeeded = false;
var scrollBackLimit = 500;

function prependMessages( html ) {
	checkIfScrollToBottomIsNeeded();
	
	bodyNode = document.getElementsByTagName( "body" ).item( 0 );
	range = document.createRange();
	range.selectNode( bodyNode );
	documentFragment = range.createContextualFragment( html );
	if( bodyNode.children.length ) document.body.insertBefore( documentFragment, bodyNode.children[0] );
	else bodyNode.appendChild( documentFragment );
	
	scrollToBottomIfNeeded();
}

function appendMessage( html ) {
	checkIfScrollToBottomIsNeeded();
	removeConsecutiveInsertPoint();
	
	bodyNode = document.getElementsByTagName( "body" ).item( 0 );
	range = document.createRange();
	range.selectNode( bodyNode );
	documentFragment = range.createContextualFragment( html );
	bodyNode.appendChild( documentFragment );
	
	enforceScrollBackLimit();
	scrollToBottomIfNeeded();
}

function appendConsecutiveMessage( html ) {
	checkIfScrollToBottomIsNeeded();
	
	insert = document.getElementById( "consecutiveInsert" );
	if( ! insert ) {
		appendMessage( html );
		return;
	}
	
	range = document.createRange();
	range.selectNode( insert.parentNode );
	documentFragment = range.createContextualFragment( html );
	insert.parentNode.replaceChild( documentFragment, insert );
	
	enforceScrollBackLimit();
	scrollToBottomIfNeeded();
}

function removeConsecutiveInsertPoint() {
	insert = document.getElementById( "consecutiveInsert" );
	if( insert ) insert.parentNode.removeChild( insert );
}

function scrollBackMessageCount() {
	bodyNode = document.getElementsByTagName( "body" ).item( 0 );
	return bodyNode.children.length;
}

function enforceScrollBackLimit() {
	bodyNode = document.getElementsByTagName( "body" ).item( 0 );
	if( scrollBackLimit > 0 && bodyNode.children.length > scrollBackLimit )
		for( i = 0; bodyNode.children.length > scrollBackLimit && i < ( bodyNode.children.length - scrollBackLimit ); i++ )
			bodyNode.removeChild( bodyNode.children[0] );
}

function messageIsInScrollback( id ) {
	return ( document.getElementById( id ).id.length ? 1 : 0 );
}

function locationOfMessage( id ) {
	element = document.getElementById( id );
	return element.offsetTop;
}

function locationOfElementAtIndex( index ) {
	bodyNode = document.getElementsByTagName( "body" ).item( 0 );
	return bodyNode.children[index].offsetTop;
}

function scrollToBottom() {
	document.body.scrollTop = document.body.offsetHeight;
}

function checkIfScrollToBottomIsNeeded() {
	scrollToBottomIsNeeded = ( document.body.scrollTop >= ( document.body.offsetHeight - ( window.innerHeight * 1.1 ) ) );
}

function scrollToBottomIfNeeded() {
	if( scrollToBottomIsNeeded )
		scrollToBottom();
}

function setStylesheet( id, url ) {
	styleNode = document.getElementById( id );
	styleNode.href = url;
}

function showTopic( topic ) {
	hideTopic(); // just in case
	
	code = "<div id=\"topic-floater\"><div class=\"close\" onclick=\"hideTopic()\"></div>" + topic + "</div>";
	
	bodyNode = document.getElementsByTagName( "body" ).item(0);
	range = document.createRange();
	range.selectNode( bodyNode );
	documentFragment = range.createContextualFragment( code );
	bodyNode.appendChild( documentFragment );
}

function hideTopic( topic ) {
	div = document.getElementById( "topic-floater" );
	if( div ) div.parentNode.removeChild( div );
}

function mark() {
	var elt = document.getElementById( "mark" );
	if( elt ) elt.parentNode.removeChild( elt );
	elt = document.createElement( "hr" );
	elt.id = "mark";
	document.getElementsByTagName( "body" ).item(0).appendChild( elt );
	scrollToBottom();
	return elt.offsetTop;
}

function resetSearchHighlight( id ) {
	var div = document.getElementById( id );
	if( ! div ) div = document.getElementsByTagName( "body" ).item(0);

	function resetHighlight(node) {
		if( node.nodeType == 1 ) {
			if( node.className == "searchHighlight" ) {
				var text = node.firstChild.nodeValue;
				var newNode = document.createTextNode( text );
				var par = node.parentNode;
				node.parentNode.replaceChild( newNode, node );
				par.innerHTML = par.innerHTML; // this will merge text nodes
				return true;
			} else if( ! node.nodeName.match( /button|select|textarea/i ) ) {
				// Recurse into child nodes
				if( ! node.childNodes.length ) return;
				for( var i = ( node.childNodes.length - 1 ); i >= 0; i-- )
					if( resetHighlight( node.childNodes[i] ) )
						for( ; i >= node.childNodes.length; i-- ) ;
			}
		}
		return false;
	}

	resetHighlight( div );
}

function searchHighlight( id, words ) {
	var div = document.getElementById( id );
	if( ! div ) div = document.getElementsByTagName( "body" ).item(0);

	function highlightWord( node, word ) {
		// If this node is a text node and contains the search word, highlight it by
		// surrounding it with a span element

		if( node.nodeType == 3 ) { // Node.TEXT_NODE
			var pos = node.nodeValue.toLowerCase().indexOf( word.toLowerCase() );
			if( pos >= 0 ) {
				var span = document.createElement( "span" );
				span.className = "searchHighlight";
				span.appendChild( document.createTextNode( node.nodeValue.substr( pos, word.length ) ) );
				var newNode = node.splitText( pos );
				newNode.nodeValue = newNode.nodeValue.substr( word.length );
				node.parentNode.insertBefore( span, newNode );
				return true;
			}
		} else if( ! node.nodeName.match( /button|select|textarea/i )) {
			// Recurse into child nodes
			for( var i = 0; i < node.childNodes.length; i++ ) {
				if( highlightWord( node.childNodes[i], word ) ) i++;
			}
		}

		return false;
	}

	highlightWord( div, words );
}