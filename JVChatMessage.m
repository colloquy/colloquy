#import <ChatCore/MVChatUser.h>
#import <ChatCore/NSAttributedStringAdditions.h>
#import <ChatCore/NSStringAdditions.h>
#import <ChatCore/NSDataAdditions.h>
#import <libxml/xinclude.h>

#import "JVChatMessage.h"
#import "JVBuddy.h"
#import "JVChatRoomMember.h"
#import "JVChatTranscript.h"
#import "JVChatRoomPanel.h"
#import "JVChatRoomMember.h"
#import "NSAttributedStringMoreAdditions.h"

@implementation JVChatMessage
+ (void) initialize {
	[super initialize];
	static BOOL tooLate = NO;
	if( ! tooLate ) {
		[[NSScriptCoercionHandler sharedCoercionHandler] registerCoercer:[self class] selector:@selector( coerceValue:toClass: ) toConvertFromClass:[self class] toClass:[NSString class]];
		[[NSScriptCoercionHandler sharedCoercionHandler] registerCoercer:[self class] selector:@selector( coerceValue:toClass: ) toConvertFromClass:[NSString class] toClass:[self class]];
		[[NSScriptCoercionHandler sharedCoercionHandler] registerCoercer:[self class] selector:@selector( coerceValue:toClass: ) toConvertFromClass:[JVMutableChatMessage class] toClass:[NSString class]];
		[[NSScriptCoercionHandler sharedCoercionHandler] registerCoercer:[self class] selector:@selector( coerceValue:toClass: ) toConvertFromClass:[NSString class] toClass:[JVMutableChatMessage class]];
		tooLate = YES;
	}
}

+ (id) coerceValue:(id) value toClass:(Class) class {
	if( class == [NSString class] && [value isKindOfClass:[self class]] ) {
		return [value bodyAsPlainText];
	} else if( ( class == [JVChatMessage class] || class == [JVMutableChatMessage class] ) && [value isKindOfClass:[NSString class]] ) {
		return [[[JVMutableChatMessage alloc] initWithText:value sender:nil] autorelease];
	} return nil;
}

#pragma mark -

- (void) load {
	if( _loaded || ! _node ) return;

	@synchronized( [self transcript] ) {
		xmlChar *prop = xmlGetProp( _node, (xmlChar *) "received" );
		_date = ( prop ? [[NSDate allocWithZone:[self zone]] initWithString:[NSString stringWithUTF8String:(char *) prop]] : nil );
		xmlFree( prop );

		prop = xmlGetProp( _node, (xmlChar *) "action" );
		_action = ( ( prop && ! strcmp( (char *) prop, "yes" ) ) ? YES : NO );
		xmlFree( prop );

		prop = xmlGetProp( _node, (xmlChar *) "highlight" );
		_highlighted = ( ( prop && ! strcmp( (char *) prop, "yes" ) ) ? YES : NO );
		xmlFree( prop );

		prop = xmlGetProp( _node, (xmlChar *) "ignored" );
		_ignoreStatus = ( ( prop && ! strcmp( (char *) prop, "yes" ) ) ? JVMessageIgnored : _ignoreStatus );
		xmlFree( prop );

		prop = xmlGetProp( _node, (xmlChar *) "type" );
		_type = ( ( prop && ! strcmp( (char *) prop, "notice" ) ) ? JVChatMessageNoticeType : JVChatMessageNormalType );
		xmlFree( prop );

		prop = xmlGetProp( ((xmlNode *) _node) -> parent, (xmlChar *) "ignored" );
		_ignoreStatus = ( ( prop && ! strcmp( (char *) prop, "yes" ) ) ? JVUserIgnored : _ignoreStatus );
		xmlFree( prop );
	}

	_loaded = YES;
}

- (void) loadBody {
	if( _bodyLoaded || ! _node ) return;

	@synchronized( [self transcript] ) {
		_attributedMessage = [[NSTextStorage allocWithZone:[self zone]] initWithXHTMLTree:_node baseURL:nil defaultAttributes:nil];
	}

	_bodyLoaded = YES;
}

- (void) loadSender {
	if( _senderLoaded || ! _node ) return;

	@synchronized( [self transcript] ) {
		xmlNode *subNode = ((xmlNode *) _node) -> parent -> children;

		do {
			if( subNode -> type == XML_ELEMENT_NODE && ! strncmp( "sender", (char *) subNode -> name, 6 ) ) {
				_senderName = [[NSString allocWithZone:[self zone]] initWithUTF8String:(char *) xmlNodeGetContent( subNode )];

				xmlChar *prop = xmlGetProp( subNode, (xmlChar *) "nickname" );
				if( prop ) _senderNickname = [[NSString allocWithZone:[self zone]] initWithUTF8String:(char *) prop];
				xmlFree( prop );

				prop = xmlGetProp( subNode, (xmlChar *) "identifier" );
				if( prop ) _senderIdentifier = [[NSString allocWithZone:[self zone]] initWithUTF8String:(char *) prop];
				xmlFree( prop );

				prop = xmlGetProp( subNode, (xmlChar *) "hostmask" );
				if( prop ) _senderHostmask = [[NSString allocWithZone:[self zone]] initWithUTF8String:(char *) prop];
				xmlFree( prop );

				prop = xmlGetProp( subNode, (xmlChar *) "class" );
				if( prop ) _senderClass = [[NSString allocWithZone:[self zone]] initWithUTF8String:(char *) prop];
				xmlFree( prop );

				prop = xmlGetProp( subNode, (xmlChar *) "self" );
				if( prop && ! strcmp( (char *) prop, "yes" ) ) _senderIsLocalUser = YES;
				else _senderIsLocalUser = NO;
				xmlFree( prop );

				break;
			}
		} while( ( subNode = subNode -> next ) );
	}

	_senderLoaded = YES;
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_loaded = NO;
		_bodyLoaded = NO;
		_senderLoaded = NO;
		_objectSpecifier = nil;
		_transcript = nil;
		_messageIdentifier = nil;
		_htmlMessage = nil;
		_attributedMessage = nil;
		_date = nil;
		_action = NO;
		_highlighted = NO;
		_senderIsLocalUser = NO;
		_ignoreStatus = JVNotIgnored;
	}

	return self;
}

- (id) initWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript {
	if( ( self = [self init] ) ) {
		_node = node;
		_transcript = transcript; // weak reference

		if( ! _node || node -> type != XML_ELEMENT_NODE ) {
			[self release];
			return nil;
		}

		@synchronized( [self transcript] ) {
			xmlChar *idStr = xmlGetProp( (xmlNode *) _node, (xmlChar *) "id" );
			_messageIdentifier = ( idStr ? [[NSString allocWithZone:[self zone]] initWithUTF8String:(char *) idStr] : nil );
			xmlFree( idStr );
		}
	}

	return self;
}

- (id) mutableCopyWithZone:(NSZone *) zone {
	[self load];
	[self loadBody];
	[self loadSender];

	JVMutableChatMessage *ret = [[JVMutableChatMessage allocWithZone:zone] initWithText:_attributedMessage sender:nil];
	[ret setDate:_date];
	[ret setAction:_action];
	[ret setHighlighted:_highlighted];
	[ret setMessageIdentifier:_messageIdentifier];

	return ret;
}

- (void) dealloc {
	[_messageIdentifier release];
	[_htmlMessage release];
	[_attributedMessage release];
	[_date release];
	[_objectSpecifier release];

	_node = NULL;
	_transcript = nil;
	_messageIdentifier = nil;
	_htmlMessage = nil;
	_attributedMessage = nil;
	_date = nil;
	_objectSpecifier = nil;

	[super dealloc];
}

#pragma mark -

+ (id) messageWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript {
	return [[[self alloc] initWithNode:node andTranscript:transcript] autorelease];
}

#pragma mark -

- (void *) node {
	return _node;
}

- (void) setNode:(xmlNode *) node {
	_node = node;
}

#pragma mark -

- (NSDate *) date {
	[self load];
	return _date;
}

#pragma mark -

- (NSString *) senderName {
	[self loadSender];
	return _senderName;
}

- (NSString *) senderIdentifier {
	[self loadSender];
	return _senderIdentifier;
}

- (NSString *) senderNickname {
	[self loadSender];
	return _senderNickname;
}

- (NSString *) senderHostmask {
	[self loadSender];
	return _senderHostmask;
}

- (NSString *) senderClass {
	[self loadSender];
	return _senderClass;
}

- (NSString *) senderBuddyIdentifier {
	[self loadSender];
	return _senderBuddyIdentifier;
}

- (BOOL) senderIsLocalUser {
	[self loadSender];
	return _senderIsLocalUser;
}

#pragma mark -

- (NSTextStorage *) body {
	[self loadBody];
	return _attributedMessage;
}

- (NSString *) bodyAsPlainText {
	return [[self body] string];
}

- (NSString *) bodyAsHTML {
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"IgnoreFonts", [NSNumber numberWithBool:YES], @"IgnoreFontSizes", nil];
	return [[self body] HTMLFormatWithOptions:options];
}

#pragma mark -

- (BOOL) isAction {
	[self load];
	return _action;
}

- (BOOL) isHighlighted {
	[self load];
	return _highlighted;
}

- (JVIgnoreMatchResult) ignoreStatus {
	[self load];
	return _ignoreStatus;
}

- (JVChatMessageType) type {
	[self load];
	return _type;
}

#pragma mark -

- (JVChatTranscript *) transcript {
	return _transcript;
}

- (NSString *) messageIdentifier {
	return _messageIdentifier;
}

#pragma mark -

- (NSScriptObjectSpecifier *) objectSpecifier {
	return _objectSpecifier;
}

- (void) setObjectSpecifier:(NSScriptObjectSpecifier *) objectSpecifier {
	[_objectSpecifier autorelease];
	_objectSpecifier = [objectSpecifier retain];
}

#pragma mark -

- (NSString *) description {
	return [self bodyAsPlainText];
}

- (NSString *) debugDescription {
	return [NSString stringWithFormat:@"<%@ 0x%x: (%@) %@>", NSStringFromClass( [self class] ), (unsigned long) self, [self senderNickname], [self body]];
}

#pragma mark -

- (id) valueForUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The message id %@ doesn't have the \"%@\" property.", [self messageIdentifier], key]];
		return nil;
	}

	return [super valueForUndefinedKey:key];
}

- (void) setValue:(id) value forUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		// this is a non-mutable message, give AppleScript a good error if this is a script command call
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The properties of message id %@ are read only.", key, [self messageIdentifier]]];
		return;
	}

	[super setValue:value forUndefinedKey:key];
}
@end

#pragma mark -

@implementation JVMutableChatMessage
+ (id) messageWithText:(id) body sender:(id) sender {
	return [[[self alloc] initWithText:body sender:sender] autorelease];
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) _doc = NULL;
	return self;
}

- (id) initWithText:(id) body sender:(id) sender {
	if( ( self = [self init] ) ) {
		_loaded = YES;
		_bodyLoaded = YES;
		_senderLoaded = YES;
		[self setDate:[NSDate date]];
		[self setBody:body];
		[self setSender:sender];
		[self setMessageIdentifier:[NSString locallyUniqueString]];
	}

	return self;
}

- (void) dealloc {
	if( _doc ) xmlFreeDoc( _doc );
	_doc = NULL;

	[_sender release];
	_sender = nil;

	[super dealloc];
}

#pragma mark -

- (void *) node {
	if( ! _node ) {
		if( _doc ) xmlFreeDoc( _doc );
		_doc = xmlNewDoc( (xmlChar *) "1.0" );

		xmlNodePtr child = NULL;
		xmlNodePtr root = xmlNewNode( NULL, (xmlChar *) "envelope" );
		xmlDocSetRootElement( _doc, root );

		if( [[self sender] respondsToSelector:@selector( xmlDescriptionWithTagName: )] ) {
			const char *sendDesc = [(NSString *)[[self sender] performSelector:@selector( xmlDescriptionWithTagName: ) withObject:@"sender"] UTF8String];

			if( sendDesc ) {
				xmlDocPtr tempDoc = xmlParseMemory( sendDesc, strlen( sendDesc ) );
				if( ! tempDoc ) return NULL; // somthing bad with the message contents

				child = xmlDocCopyNode( xmlDocGetRootElement( tempDoc ), _doc, 1 );
				xmlAddChild( root, child );
				xmlFreeDoc( tempDoc );
			}
		} else return NULL;

		NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"IgnoreFonts", [NSNumber numberWithBool:YES], @"IgnoreFontSizes", nil];
		NSString *htmlMessage = ( [self body] ? [[self body] HTMLFormatWithOptions:options] : @"" );
		const char *msgStr = [[NSString stringWithFormat:@"<message>%@</message>", [htmlMessage stringByStrippingIllegalXMLCharacters]] UTF8String];
		xmlDocPtr msgDoc = xmlParseMemory( msgStr, strlen( msgStr ) );
		if( ! msgDoc ) return NULL; // somthing bad with the message contents

		_node = child = xmlDocCopyNode( xmlDocGetRootElement( msgDoc ), _doc, 1 );
		xmlSetProp( child, (xmlChar *) "id", (xmlChar *) [[self messageIdentifier] UTF8String] );
		xmlSetProp( child, (xmlChar *) "received", (xmlChar *) [[[self date] description] UTF8String] );
		if( [self isAction] ) xmlSetProp( child, (xmlChar *) "action", (xmlChar *) "yes" );
		if( [self isHighlighted] ) xmlSetProp( child, (xmlChar *) "highlight", (xmlChar *) "yes" );
		if( [self ignoreStatus] == JVMessageIgnored ) xmlSetProp( child, (xmlChar *) "ignored", (xmlChar *) "yes" );
		else if( [self ignoreStatus] == JVUserIgnored ) xmlSetProp( root, (xmlChar *) "ignored", (xmlChar *) "yes" );
		if( [self type] == JVChatMessageNoticeType ) xmlSetProp( child, (xmlChar *) "type", (xmlChar *) "notice" );
		xmlAddChild( root, child );

		xmlFreeDoc( msgDoc );
	}

	return _node;
}

- (void) setNode:(xmlNode *) node {
	if( _doc ) {
		xmlFreeDoc( _doc );
		_doc = NULL;
	}

	_node = node;
}

#pragma mark -

- (void) setDate:(NSDate *) date {
	[self setNode:NULL];
	[_date autorelease];
	_date = [date copyWithZone:[self zone]];
}

#pragma mark -

- (void) setSender:(id) sender {
	[self setNode:NULL];
	[_sender autorelease];
	_sender = [sender retain];
}

- (id) sender {
	return _sender;
}

- (NSString *) senderName {
	if( [[self sender] respondsToSelector:@selector( displayName )] )
		return [[self sender] displayName];
	return [super senderName];
}

- (NSString *) senderIdentifier {
	id identifier = nil;

	if( [[self sender] isKindOfClass:[MVChatUser class]] ) {
		identifier = [(MVChatUser *)[self sender] uniqueIdentifier];
	} else if( [[self sender] isKindOfClass:[JVChatRoomMember class]] ) {
		identifier = [[(JVChatRoomMember *)[self sender] user] uniqueIdentifier];
	}

	if( [identifier isKindOfClass:[NSData class]] )
		identifier = [identifier base64Encoding];

	return ( identifier ? identifier : [super senderIdentifier] );
}

- (NSString *) senderNickname {
	if( [[self sender] respondsToSelector:@selector( nickname )] )
		return [[self sender] nickname];
	return [super senderNickname];
}

- (NSString *) senderHostmask {
	if( [[self sender] respondsToSelector:@selector( hostmask )] )
		return [[self sender] hostmask];
	if( [[self sender] isKindOfClass:[MVChatUser class]] )
		return [NSString stringWithFormat:@"%@@%@", [(MVChatUser *)[self sender] username], [(MVChatUser *)[self sender] address]];
	return [super senderNickname];
}

- (NSString *) senderClass {
	if( [[self sender] isKindOfClass:[JVChatRoomMember class]] ) {
		if( [(JVChatRoomMember *)[self sender] serverOperator] ) return @"server operator";
		else if( [(JVChatRoomMember *)[self sender] roomFounder] ) return @"room founder";
		else if( [(JVChatRoomMember *)[self sender] operator] ) return @"operator";
		else if( [(JVChatRoomMember *)[self sender] halfOperator] ) return @"half operator";
		else if( [(JVChatRoomMember *)[self sender] voice] ) return @"voice";		
	} else if( [[self sender] isKindOfClass:[MVChatUser class]] ) {
		if( [(MVChatUser *)[self sender] isServerOperator] ) return @"server operator";
	}

	return [super senderClass];
}

- (NSString *) senderBuddyIdentifier {
	if( [[self sender] isKindOfClass:[JVChatRoomMember class]] )
		return [[[self sender] buddy] uniqueIdentifier];
	return [super senderBuddyIdentifier];
}

- (BOOL) senderIsLocalUser {
	if( [[self sender] respondsToSelector:@selector( isLocalUser )] )
		return [[self sender] isLocalUser];
	return [super senderIsLocalUser];
}

#pragma mark -

- (void) setBody:(id) message {
	[self setNode:NULL];
	if( ! _attributedMessage ) {
		if( [message isKindOfClass:[NSTextStorage class]] ) _attributedMessage = [message retain];
		else if( [message isKindOfClass:[NSAttributedString class]] ) _attributedMessage = [[NSTextStorage alloc] initWithAttributedString:message];
		else if( [message isKindOfClass:[NSString class]] ) _attributedMessage = [[NSTextStorage alloc] initWithString:(NSString *)message];
	} else if( _attributedMessage && [message isKindOfClass:[NSAttributedString class]] ) {
		[_attributedMessage setAttributedString:message];
	} else if( _attributedMessage && [message isKindOfClass:[NSString class]] ) {
		id string = [[[NSAttributedString alloc] initWithString:(NSString *)message] autorelease];
		[_attributedMessage setAttributedString:string];
	}
}

- (void) setBodyAsPlainText:(NSString *) message {
	[self setBody:message];
}

- (void) setBodyAsHTML:(NSString *) message {
	[self setBody:[NSAttributedString attributedStringWithXHTMLFragment:message baseURL:nil defaultAttributes:nil]];
}

#pragma mark -

- (void) setAction:(BOOL) action {
	[self setNode:NULL];
	_action = action;
}

- (void) setHighlighted:(BOOL) highlighted {
	[self setNode:NULL];
	_highlighted = highlighted;
}

- (void) setIgnoreStatus:(JVIgnoreMatchResult) ignoreStatus {
	[self setNode:NULL];
	_ignoreStatus = ignoreStatus;
}

- (void) setType:(JVChatMessageType) type {
	[self setNode:NULL];
	_type = type;
}

#pragma mark -

- (void) setMessageIdentifier:(NSString *) identifier {
	[self setNode:NULL];
	[_messageIdentifier autorelease];
	_messageIdentifier = [identifier copyWithZone:[self zone]];
}

#pragma mark -

- (void) setValue:(id) value forUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The \"%@\" property of message id %@ is read only.", key, [self messageIdentifier]]];
		return;
	}

	[super setValue:value forUndefinedKey:key];
}
@end