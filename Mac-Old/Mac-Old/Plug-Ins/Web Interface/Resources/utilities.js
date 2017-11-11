var ElementUtilities = {
	firstParentWithClass: function( element, className ) {
		element = $(element);

		var parent = element.parentNode;
		while( ! $(parent).hasClassName( className ) ) {
			if( parent == element.ownerDocument ) 
				return null;
			parent = parent.parentNode;
		}

		return parent;
	},

	removeChildren: function( element ){
		element = $(element);
		while( element.firstChild ) 
			element.removeChild( element.firstChild );        
	}
}

Element.addMethods(ElementUtilities);
