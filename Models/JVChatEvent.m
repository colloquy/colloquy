#import "JVChatEvent.h"
#import "NSAttributedStringMoreAdditions.h"
#import "NSDateAdditions.h"

#import <libxml/tree.h>

@implementation JVChatEvent
- (void) dealloc {
	[_eventIdentifier release];
	[_date release];
	[_name release];
	[_message release];
	[_attributes release];

	_eventIdentifier = nil;
	_date = nil;
	_name = nil;
	_message = nil;
	_attributes = nil;

	_transcript = nil; // weak reference
	_node = NULL;

	if( _doc ) xmlFreeDoc( _doc );
	_doc = NULL;

	[super dealloc];
}

#pragma mark -

- (void) loadSmall {
	if( _loadedSmall || ! _node ) return;

	@synchronized( _transcript ) {
		xmlChar *prop = xmlGetProp( (xmlNode *) _node, (xmlChar *) "name" );
		_name = ( prop ? [[NSString allocWithZone:[self zone]] initWithUTF8String:(char *) prop] : nil );
		xmlFree( prop );

		prop = xmlGetProp( (xmlNode *) _node, (xmlChar *) "occurred" );
		_date = ( prop ? [[NSDate allocWithZone:[self zone]] initWithString:[NSString stringWithUTF8String:(char *) prop]] : nil );
		xmlFree( prop );
	}

	_loadedSmall = YES;
}

- (void) loadMessage {
	if( _loadedMessage || ! _node ) return;

	@synchronized( _transcript ) {
		xmlNode *subNode = ((xmlNode *) _node) -> children;

		do {
			if( subNode -> type == XML_ELEMENT_NODE && ! strcmp( "message", (char *) subNode -> name ) ) {
				_message = [[NSTextStorage allocWithZone:[self zone]] initWithXHTMLTree:subNode baseURL:nil defaultAttributes:nil];
				break;
			}
		} while( ( subNode = subNode -> next ) );
	}

	_loadedMessage = YES;
}

- (void) loadAttributes {
	if( _loadedAttributes || ! _node ) return;

	@synchronized( _transcript ) {
		xmlNode *subNode = ((xmlNode *) _node) -> children;
		NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

		do {
			if( subNode -> type == XML_ELEMENT_NODE && strcmp( "message", (char *) subNode -> name ) ) { // everything but "message"
				NSMutableDictionary *properties = [NSMutableDictionary dictionary];
				xmlAttrPtr prop = NULL;
				for( prop = subNode -> properties; prop; prop = prop -> next ) {
					xmlChar *value = xmlGetProp( subNode, prop -> name );
					if( value ) {
						[properties setObject:[NSString stringWithUTF8String:(char *) value] forKey:[NSString stringWithUTF8String:(char *) prop -> name]];
						xmlFree( value );
					}
				}

				xmlNode *cnode = subNode -> children;
				unsigned count = 0;

				do {
					if( cnode && cnode -> type == XML_ELEMENT_NODE ) count++;
				} while( cnode && ( cnode = cnode -> next ) );

				id value = nil;
				if( count > 0 ) {
					value = [NSTextStorage attributedStringWithXHTMLTree:subNode baseURL:nil defaultAttributes:nil];
				} else {
					xmlChar *content = xmlNodeGetContent( subNode );
					value = [NSString stringWithUTF8String:(char *) content];
					xmlFree( content );
				}

				if( [properties count] ) {
					[properties setObject:value forKey:@"value"];
					[attributes setObject:properties forKey:[NSString stringWithUTF8String:(char *) subNode -> name]];
				} else {
					[attributes setObject:value forKey:[NSString stringWithUTF8String:(char *) subNode -> name]];
				}
			}
		} while( ( subNode = subNode -> next ) );
	}

	_loadedAttributes = YES;
}

#pragma mark -

- (void *) node {
	if( ! _node ) {
		if( _doc ) xmlFreeDoc( _doc );
		_doc = xmlNewDoc( (xmlChar *) "1.0" );

		xmlNodePtr root = xmlNewNode( NULL, (xmlChar *) "event" );
		xmlSetProp( root, (xmlChar *) "id", (xmlChar *) [[self eventIdentifier] UTF8String] );
		xmlSetProp( root, (xmlChar *) "name", (xmlChar *) [[self name] UTF8String] );
		xmlSetProp( root, (xmlChar *) "occurred", (xmlChar *) [[[self date] localizedDescription] UTF8String] );
		xmlDocSetRootElement( _doc, root );

		xmlDocPtr msgDoc = NULL;
		xmlNodePtr child = NULL;
		const char *msgStr = NULL;

		if( [self message] ) {
			NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"IgnoreFonts", [NSNumber numberWithBool:YES], @"IgnoreFontSizes", nil];
			NSString *msgValue = [[self message] HTMLFormatWithOptions:options];
			msgValue = [msgValue stringByStrippingIllegalXMLCharacters];

			msgStr = [[NSString stringWithFormat:@"<message>%@</message>", msgValue] UTF8String];

			msgDoc = xmlParseMemory( msgStr, strlen( msgStr ) );
			child = xmlDocCopyNode( xmlDocGetRootElement( msgDoc ), _doc, 1 );
			xmlAddChild( root, child );
			xmlFreeDoc( msgDoc );
		}

		for( NSString *key in [self attributes] ) {
			id value = [[self attributes] objectForKey:key];

			if( [value respondsToSelector:@selector( xmlDescriptionWithTagName: )] ) {
				msgStr = [(NSString *)[value performSelector:@selector( xmlDescriptionWithTagName: ) withObject:key] UTF8String];
			} else if( [value isKindOfClass:[NSAttributedString class]] ) {
				NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"IgnoreFonts", [NSNumber numberWithBool:YES], @"IgnoreFontSizes", nil];
				value = [value HTMLFormatWithOptions:options];
				value = [value stringByStrippingIllegalXMLCharacters];
				if( [(NSString *)value length] )
					msgStr = [[NSString stringWithFormat:@"<%@>%@</%@>", key, value, key] UTF8String];
			} else if( [value isKindOfClass:[NSString class]] ) {
				value = [value stringByEncodingXMLSpecialCharactersAsEntities];
				value = [value stringByStrippingIllegalXMLCharacters];
				if( [(NSString *)value length] )
					msgStr = [[NSString stringWithFormat:@"<%@>%@</%@>", key, value, key] UTF8String];
			} else if( [value isKindOfClass:[NSData class]] ) {
				value = [value base64EncodingWithLineLength:0];
				if( [(NSString *)value length] )
					msgStr = [[NSString stringWithFormat:@"<%@ encoding=\"base64\">%@</%@>", key, value, key] UTF8String];
			}

			if( ! msgStr ) msgStr = [[NSString stringWithFormat:@"<%@ />", key] UTF8String];

			msgDoc = xmlParseMemory( msgStr, strlen( msgStr ) );
			child = xmlDocCopyNode( xmlDocGetRootElement( msgDoc ), _doc, 1 );
			xmlAddChild( root, child );
			xmlFreeDoc( msgDoc );
		}

		_node = root;
	}

	return _node;
}

- (void) _setNode:(xmlNode *) node {
	if( _doc ) {
		xmlFreeDoc( _doc );
		_doc = NULL;
	}

	_node = node;
}

#pragma mark -

- (JVChatTranscript *) transcript {
	return _transcript;
}

- (NSString *) eventIdentifier {
	return _eventIdentifier;
}

#pragma mark -

- (NSDate *) date {
	[self loadSmall];
	return _date;
}

- (NSString *) name {
	[self loadSmall];
	return _name;
}

#pragma mark -

- (NSTextStorage *) message {
	[self loadMessage];
	return _message;
}

- (NSString *) messageAsPlainText {
	return [[self message] string];
}

- (NSString *) messageAsHTML {
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"IgnoreFonts", [NSNumber numberWithBool:YES], @"IgnoreFontSizes", nil];
	return [[self message] HTMLFormatWithOptions:options];
}

#pragma mark -

- (NSDictionary *) attributes {
	[self loadAttributes];
	return _attributes;
}
@end

#pragma mark -

@implementation JVMutableChatEvent
+ (id) chatEventWithName:(NSString *) name andMessage:(id) message {
	return [[[self alloc] initWithName:name andMessage:message] autorelease];
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_loadedMessage = YES;
		_loadedAttributes = YES;
		_loadedSmall = YES;
		[self setDate:[NSDate date]];
		[self setEventIdentifier:[NSString locallyUniqueString]];
	}

	return self;
}

- (id) initWithName:(NSString *) name andMessage:(id) message {
	if( ( self = [self init] ) ) {
		[self setName:name];
		[self setMessage:message];
	}

	return self;
}

#pragma mark -

- (void) setDate:(NSDate *) date {
	[self _setNode:NULL];
	[_date autorelease];
	_date = [date copyWithZone:[self zone]];
}

- (void) setName:(NSString *) name {
	[self _setNode:NULL];
	[_name autorelease];
	_name = [name copyWithZone:[self zone]];
}

#pragma mark -

- (void) setMessage:(id) message {
	[self _setNode:NULL];
	if( ! _message ) {
		if( [message isKindOfClass:[NSTextStorage class]] ) _message = [message retain];
		else if( [message isKindOfClass:[NSAttributedString class]] ) _message = [[NSTextStorage alloc] initWithAttributedString:message];
		else if( [message isKindOfClass:[NSString class]] ) _message = [[NSTextStorage alloc] initWithXHTMLFragment:(NSString *)message baseURL:nil defaultAttributes:nil];
	} else if( _message && [message isKindOfClass:[NSAttributedString class]] ) {
		[_message setAttributedString:message];
	} else if( _message && [message isKindOfClass:[NSString class]] ) {
		id string = [NSAttributedString attributedStringWithXHTMLFragment:(NSString *)message baseURL:nil defaultAttributes:nil];
		[_message setAttributedString:string];
	}
}

- (void) setMessageAsPlainText:(NSString *) message {
	[self setMessage:[[[NSAttributedString alloc] initWithString:message] autorelease]];
}

- (void) setMessageAsHTML:(NSString *) message {
	[self setMessage:message];
}

#pragma mark -

- (void) setAttributes:(NSDictionary *) attributes {
	[self _setNode:NULL];
	[_attributes autorelease];
	_attributes = [attributes copyWithZone:[self zone]];
}

#pragma mark -

- (void) setEventIdentifier:(NSString *) identifier {
	[self _setNode:NULL];
	[_eventIdentifier autorelease];
	_eventIdentifier = [identifier copyWithZone:[self zone]];
}
@end
