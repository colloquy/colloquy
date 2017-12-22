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
				par.normalize(); // this will merge text nodes
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
	if( ! div ) return;

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

function resetHighlightMessage( id ) {
	var div = document.getElementById( id );
	if( ! div ) div = document.getElementsByTagName( "body" ).item(0);

	function resetMessageHighlight( node ) {
		if( node.nodeType == 1 ) {
			if( node.className.indexOf( "searchHighlight" ) >= 0 ) {
				var cls = node.className;
				cls.replace( /searchHighlight/g, "" );
				node.className = cls;
			}

			if( ! node.childNodes.length ) return;
			for( var i = 0; i < node.childNodes.length; i++ )
				resetMessageHighlight( node.childNodes[i] );
		}
	}

	resetMessageHighlight( div );
}