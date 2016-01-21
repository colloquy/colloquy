#import "JVChatEvent.h"
#import "NSAttributedStringMoreAdditions.h"
#import "NSDateAdditions.h"
#import "JVChatRoomMember.h"

#include <libxml/tree.h>

@interface JVChatEvent ()
@property (readwrite, setter=_setNode:) xmlNode *node;
@end

@implementation JVChatEvent

@synthesize node = _node;

- (void) dealloc {
	_node = NULL;

	if( _doc ) xmlFreeDoc( _doc );
	_doc = NULL;
}

#pragma mark -

- (void) loadSmall {
	if( _loadedSmall || ! _node ) return;

	@synchronized( _transcript ) {
		xmlChar *prop = xmlGetProp( (xmlNode *) _node, (xmlChar *) "name" );
		_name = ( prop ? @((char *) prop) : nil );
		xmlFree( prop );

		prop = xmlGetProp( (xmlNode *) _node, (xmlChar *) "occurred" );
		_date = ( prop ? [[NSDate alloc] initWithString:@((char *) prop)] : nil );
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
				_message = [[NSTextStorage alloc] initWithXHTMLTree:subNode baseURL:nil defaultAttributes:nil];
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
						properties[@((char *) prop -> name)] = @((char *) value);
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
					value = @((char *) content);
					xmlFree( content );
				}

				if( [properties count] ) {
					properties[@"value"] = value;
					attributes[@((char *) subNode -> name)] = properties;
				} else {
					attributes[@((char *) subNode -> name)] = value;
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
			NSDictionary *options = @{@"IgnoreFonts": @YES, @"IgnoreFontSizes": @YES};
			NSString *msgValue = [[self message] HTMLFormatWithOptions:options];
			msgValue = [msgValue stringByStrippingIllegalXMLCharacters];

			msgStr = [[NSString stringWithFormat:@"<message>%@</message>", msgValue] UTF8String];

			msgDoc = xmlParseMemory( msgStr, (int)strlen( msgStr ) );
			child = xmlDocCopyNode( xmlDocGetRootElement( msgDoc ), _doc, 1 );
			xmlAddChild( root, child );
			xmlFreeDoc( msgDoc );
		}

		for( NSString *key in [self attributes] ) {
			id value = [self attributes][key];

			if( [value respondsToSelector:@selector( xmlDescriptionWithTagName: )] ) {
				msgStr = [(NSString *)[value performSelector:@selector( xmlDescriptionWithTagName: ) withObject:key] UTF8String];
			} else if( [value isKindOfClass:[NSAttributedString class]] ) {
				NSDictionary *options = @{@"IgnoreFonts": @YES, @"IgnoreFontSizes": @YES};
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

			msgDoc = xmlParseMemory( msgStr, (int)strlen( msgStr ) );
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
	NSDictionary *options = @{@"IgnoreFonts": @YES, @"IgnoreFontSizes": @YES};
	return [[self message] HTMLFormatWithOptions:options];
}

#pragma mark -

- (NSDictionary *) attributes {
	[self loadAttributes];
	return _attributes;
}

#pragma mark - private

- (instancetype) initWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript {
	if( ( self = [self init] ) ) {
		_node = node;
		_transcript = transcript; // weak reference
		
		if( ! _node || node -> type != XML_ELEMENT_NODE ) {
			return nil;
		}
		
		@synchronized( _transcript ) {
			xmlChar *prop = xmlGetProp( (xmlNode *) _node, (xmlChar *) "id" );
			_eventIdentifier = ( prop ? @((char *) prop) : nil );
			xmlFree( prop );
		}
	}
	
	return self;
}

@end

#pragma mark -

@implementation JVMutableChatEvent
@dynamic attributes;
@dynamic eventIdentifier;
@dynamic date;
@dynamic name;
@dynamic messageAsHTML;
@dynamic messageAsPlainText;

+ (instancetype) chatEventWithName:(NSString *) name andMessage:(id) message {
	return [[self alloc] initWithName:name andMessage:message];
}

#pragma mark -

- (instancetype) init {
	if( ( self = [super init] ) ) {
		_loadedMessage = YES;
		_loadedAttributes = YES;
		_loadedSmall = YES;
		[self setDate:[NSDate date]];
		[self setEventIdentifier:[NSString locallyUniqueString]];
	}

	return self;
}

- (instancetype) initWithName:(NSString *) name andMessage:(id) message {
	if( ( self = [self init] ) ) {
		[self setName:name];
		[self setMessage:message];
	}

	return self;
}

#pragma mark -

- (void) setDate:(NSDate *) date {
	[self _setNode:NULL];
	_date = [date copy];
}

- (void) setName:(NSString *) name {
	[self _setNode:NULL];
	_name = [name copy];
}

#pragma mark -

- (void) setMessage:(id) message {
	[self _setNode:NULL];
	if( ! _message ) {
		if( [message isKindOfClass:[NSTextStorage class]] ) _message = message;
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
	[self setMessage:[[NSAttributedString alloc] initWithString:message]];
}

- (void) setMessageAsHTML:(NSString *) message {
	[self setMessage:message];
}

#pragma mark -

- (void) setAttributes:(NSDictionary *) attributes {
	[self _setNode:NULL];
	_attributes = [attributes copy];
}

#pragma mark -

- (void) setEventIdentifier:(NSString *) identifier {
	[self _setNode:NULL];
	_eventIdentifier = [identifier copy];
}
@end
