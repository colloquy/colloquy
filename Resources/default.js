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
}