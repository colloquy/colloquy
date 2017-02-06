#include <libxml/tree.h>

#import "JVChatMessage.h"
#import "JVBuddy.h"
#import "JVChatRoomMember.h"
#import "JVChatTranscript.h"
#import "JVChatRoomPanel.h"
#import "JVChatRoomMember.h"
#import "NSAttributedStringMoreAdditions.h"
#import <ChatCore/NSDateAdditions.h>

NS_ASSUME_NONNULL_BEGIN

@implementation JVChatMessage
@synthesize node = _node;
@synthesize objectSpecifier = _objectSpecifier;
@synthesize transcript = _transcript;
@synthesize messageIdentifier = _messageIdentifier;

+ (void) initialize {
	[super initialize];
	static BOOL tooLate = NO;
	if( ! tooLate ) {
		[[NSScriptCoercionHandler sharedCoercionHandler] registerCoercer:[self class] selector:@selector( coerceMessage:toString: ) toConvertFromClass:[JVChatMessage class] toClass:[NSString class]];
		[[NSScriptCoercionHandler sharedCoercionHandler] registerCoercer:[self class] selector:@selector( coerceString:toMessage: ) toConvertFromClass:[NSString class] toClass:[JVChatMessage class]];
		[[NSScriptCoercionHandler sharedCoercionHandler] registerCoercer:[self class] selector:@selector( coerceMessage:toTextStorage: ) toConvertFromClass:[JVChatMessage class] toClass:[NSTextStorage class]];
		[[NSScriptCoercionHandler sharedCoercionHandler] registerCoercer:[self class] selector:@selector( coerceTextStorage:toMessage: ) toConvertFromClass:[NSTextStorage class] toClass:[JVChatMessage class]];
		tooLate = YES;
	}
}

+ (id) coerceString:(id) value toMessage:(Class) class {
	return [[JVMutableChatMessage alloc] initWithText:value sender:nil];
}

+ (id) coerceMessage:(id) value toString:(Class) class {
	return [value bodyAsPlainText];
}

+ (id) coerceTextStorage:(id) value toMessage:(Class) class {
	return [[JVMutableChatMessage alloc] initWithText:value sender:nil];
}

+ (id) coerceMessage:(id) value toTextStorage:(Class) class {
	return [value body];
}

#pragma mark -

- (void) load {
	if( _loaded ) return;
	[_transcript _loadMessage:self];
}

- (void) loadBody {
	if( _bodyLoaded ) return;
	[_transcript _loadBodyForMessage:self];
}

- (void) loadSender {
	if( _senderLoaded ) return;
	[_transcript _loadSenderForMessage:self];
}

#pragma mark -

- (instancetype) init {
	if( ( self = [super init] ) ) {
		_ignoreStatus = JVNotIgnored;
		_type = JVChatMessageNormalType;
	}

	return self;
}

- (id) mutableCopyWithZone:(nullable NSZone *) zone {
	JVMutableChatMessage *ret =  nil;

	@synchronized( _transcript ) {
		ret = [[JVMutableChatMessage allocWithZone:zone] init];

		ret -> _loaded = YES;
		ret -> _senderLoaded = YES;
		ret -> _bodyLoaded = YES;

		// release anything alloced in [JVMutableChatMessage init] and [JVChatMessage init] that we copy below

		ret -> _senderIsLocalUser = [self senderIsLocalUser];
		ret -> _senderIdentifier = [[self senderIdentifier] copyWithZone:zone];
		ret -> _senderName = [[self senderName] copyWithZone:zone];
		ret -> _senderHostmask = [[self senderHostmask] copyWithZone:zone];
		ret -> _senderClass = [[self senderClass] copyWithZone:zone];
		ret -> _senderBuddyIdentifier = [[self senderBuddyIdentifier] copyWithZone:zone];
		ret -> _attributedMessage = [[self body] mutableCopyWithZone:zone];
		ret -> _source = [[self source] copyWithZone:zone];
		ret -> _date = [[self date] copyWithZone:zone];
		ret -> _action = [self isAction];
		ret -> _highlighted = [self isHighlighted];
		ret -> _ignoreStatus = [self ignoreStatus];
		ret -> _type = [self type];
		ret -> _attributes = [[self attributes] copyWithZone:zone];
	}

	return ret;
}

- (void) dealloc {
	_node = NULL;
	_transcript = nil;
	_messageIdentifier = nil;
	_attributedMessage = nil;
	_date = nil;
	_source = nil;
	_objectSpecifier = nil;

	_senderIdentifier = nil;
	_senderName = nil;
	_senderNickname = nil;
	_senderHostmask = nil;
	_senderClass = nil;
	_senderBuddyIdentifier = nil;

	if( _doc ) xmlFreeDoc( _doc );
	_doc = NULL;
}

#pragma mark -

- (nullable xmlNode *) node {
	if( ! _node ) {
		NSDictionary *options = @{@"IgnoreFonts": @YES, @"IgnoreFontSizes": @YES};
		NSString *htmlMessage = ( [self body] ? [[self body] HTMLFormatWithOptions:options] : @"" );
		const char *msgStr = [[NSString stringWithFormat:@"<message>%@</message>", [htmlMessage stringByStrippingIllegalXMLCharacters]] UTF8String];

		if( !msgStr) {
			NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSSet setWithObjects:@"error", @"encoding", nil], @"CSSClasses", nil];
			NSTextStorage *messageString = [[NSTextStorage alloc] initWithString:NSLocalizedString( @"incompatible encoding", "encoding of the message different than your current encoding" ) attributes:attributes];
			htmlMessage = ( messageString ? [messageString HTMLFormatWithOptions:options] : @"" );
			msgStr = [[NSString stringWithFormat:@"<message>%@</message>", [htmlMessage stringByStrippingIllegalXMLCharacters]] UTF8String];
		}

		if( _doc ) xmlFreeDoc( _doc );
		_doc = xmlNewDoc( (xmlChar *) "1.0" );

		xmlNodePtr child = NULL;
		xmlNodePtr root = xmlNewNode( NULL, (xmlChar *) "envelope" );
		xmlDocSetRootElement( _doc, root );

		if( _source ) xmlSetProp( root, (xmlChar *) "source", (xmlChar *) [[[self source] absoluteString] UTF8String] );

		id sender = nil;
		if( [self respondsToSelector:@selector( sender )] )
			sender = [self performSelector:@selector( sender )];

		if( sender && [sender respondsToSelector:@selector( xmlDescriptionWithTagName: )] ) {
			const char *sendDesc = [(NSString *)[sender performSelector:@selector( xmlDescriptionWithTagName: ) withObject:@"sender"] UTF8String];

			if( sendDesc ) {
				xmlDocPtr tempDoc = xmlParseMemory( sendDesc, (int)strlen( sendDesc ) );
				if( ! tempDoc ) return NULL; // somthing bad with the message contents

				child = xmlDocCopyNode( xmlDocGetRootElement( tempDoc ), _doc, 1 );
				xmlAddChild( root, child );
				xmlFreeDoc( tempDoc );
			}
		} else {
			child = xmlNewTextChild( root, NULL, (xmlChar *) "sender", ( [self senderName] ? (xmlChar *) [[self senderName] UTF8String] : (xmlChar *) "" ) );
			if( [self senderIsLocalUser] ) xmlSetProp( child, (xmlChar *) "self", (xmlChar *) "yes" );
			if( [self senderNickname] && ! [[self senderName] isEqualToString:[self senderNickname]] )
				xmlSetProp( child, (xmlChar *) "nickname", (xmlChar *) [[self senderNickname] UTF8String] );
			if( [self senderHostmask] )
				xmlSetProp( child, (xmlChar *) "hostmask", (xmlChar *) [[self senderNickname] UTF8String] );
			if( [self senderIdentifier] )
				xmlSetProp( child, (xmlChar *) "identifier", (xmlChar *) [[self senderIdentifier] UTF8String] );
			if( [self senderClass] )
				xmlSetProp( child, (xmlChar *) "class", (xmlChar *) [[self senderClass] UTF8String] );
			if( [self senderBuddyIdentifier] && ! [self senderIsLocalUser] )
				xmlSetProp( child, (xmlChar *) "buddy", (xmlChar *) [[self senderBuddyIdentifier] UTF8String] );
		}

		xmlDocPtr msgDoc = xmlParseMemory( msgStr, (int)strlen( msgStr ) );
		if( ! msgDoc ) return NULL; // somthing bad with the message contents

		_node = child = xmlDocCopyNode( xmlDocGetRootElement( msgDoc ), _doc, 1 );
		xmlSetProp( child, (xmlChar *) "id", (xmlChar *) [[self messageIdentifier] UTF8String] );
		xmlSetProp( child, (xmlChar *) "received", (xmlChar *) [[[self date] localizedDescription] UTF8String] );
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

- (void) _setNode:(nullable xmlNode *) node {
	if( _doc ) {
		xmlFreeDoc( _doc );
		_doc = NULL;
	}

	_node = node;
}

#pragma mark -

- (NSDate *) date {
	[self load];
	return _date;
}

#pragma mark -

- (NSUInteger) consecutiveOffset {
	[self load];
	return _consecutiveOffset;
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
	NSDictionary *options = @{@"IgnoreFonts": @YES, @"IgnoreFontSizes": @YES};
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

- (NSURL *) source {
	[self load];
	return _source;
}

#pragma mark -

- (NSDictionary *) attributes {
	// Add important attributes which are set via normal setters, and therefore don't exist normally in the attributes-dict.
	if( ! _attributes )
		_attributes = [[NSMutableDictionary alloc] init];
	_attributes[@"action"] = @(_action);

	return _attributes;
}

- (nullable id) attributeForKey:(id) key {
	return _attributes[key];
}

#pragma mark -

- (NSString *) description {
	return [self bodyAsPlainText];
}

- (NSString *) debugDescription {
	return [NSString stringWithFormat:@"<%@ %p [%@]: (%@) %@>", NSStringFromClass( [self class] ), self, _messageIdentifier, [self senderNickname], [self body]];
}

#pragma mark -

- (nullable id) valueForUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The message id %@ doesn't have the \"%@\" property.", [self messageIdentifier], key]];
		return nil;
	}

	return [super valueForUndefinedKey:key];
}

- (void) setValue:(nullable id) value forUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		// this is a non-mutable message, give AppleScript a good error if this is a script command call
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The properties of message id %@ are read only.", key]];
		return;
	}

	[super setValue:value forUndefinedKey:key];
}
@end

#pragma mark -

@implementation JVMutableChatMessage
@dynamic action;
@dynamic highlighted;
@dynamic ignoreStatus;
@dynamic type;
@dynamic date;
@dynamic bodyAsPlainText;
@dynamic bodyAsHTML;
@dynamic source;
@dynamic messageIdentifier;

+ (void) initialize {
	[super initialize];
	static BOOL tooLate = NO;
	if( ! tooLate ) {
		[[NSScriptCoercionHandler sharedCoercionHandler] registerCoercer:[self class] selector:@selector( coerceMessage:toString: ) toConvertFromClass:[JVMutableChatMessage class] toClass:[NSString class]];
		[[NSScriptCoercionHandler sharedCoercionHandler] registerCoercer:[self class] selector:@selector( coerceString:toMessage: ) toConvertFromClass:[NSString class] toClass:[JVMutableChatMessage class]];
		[[NSScriptCoercionHandler sharedCoercionHandler] registerCoercer:[self class] selector:@selector( coerceMessage:toTextStorage: ) toConvertFromClass:[JVMutableChatMessage class] toClass:[NSTextStorage class]];
		[[NSScriptCoercionHandler sharedCoercionHandler] registerCoercer:[self class] selector:@selector( coerceTextStorage:toMessage: ) toConvertFromClass:[NSTextStorage class] toClass:[JVMutableChatMessage class]];
		tooLate = YES;
	}
}

+ (instancetype) messageWithText:(id) body sender:(nullable id) sender {
	return [[self alloc] initWithText:body sender:sender];
}

#pragma mark -

- (instancetype) init {
	if( ( self = [super init] ) ) {
		_loaded = YES;
		_bodyLoaded = YES;
		_senderLoaded = YES;
		self.date = [NSDate date];
		self.messageIdentifier = [NSString locallyUniqueString];
	}

	return self;
}

- (instancetype) initWithText:(id) body sender:(nullable id) sender {
	if( ( self = [self init] ) ) {
		[self setBody:body];
		self.sender = sender;
	}

	return self;
}

#pragma mark -

- (void) setDate:(NSDate *) date {
	[self _setNode:NULL];
	_date = [date copy];
}

#pragma mark -

- (void) setSender:(id) sender {
	[self _setNode:NULL];
	_sender = sender;
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
		identifier = [(NSData*)identifier base64EncodedStringWithOptions:0];
	//identifier = [[NSString alloc] initWithData:[[NSData alloc] initWithBase64EncodedData:identifier options:0] encoding:NSUTF8StringEncoding];

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
		else if( [(JVChatRoomMember *)[self sender] roomAdministrator] ) return @"room administrator";
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
	[self _setNode:NULL];
	if( ! _attributedMessage ) {
		if( [message isKindOfClass:[NSTextStorage class]] ) _attributedMessage = [message mutableCopy];
		else if( [message isKindOfClass:[NSAttributedString class]] ) _attributedMessage = [[NSTextStorage alloc] initWithAttributedString:message];
		else if( [message isKindOfClass:[NSString class]] ) _attributedMessage = [[NSTextStorage alloc] initWithString:(NSString *)message];
	} else if( _attributedMessage && [message isKindOfClass:[NSAttributedString class]] ) {
		[_attributedMessage setAttributedString:message];
	} else if( _attributedMessage && [message isKindOfClass:[NSString class]] ) {
		id string = [[NSAttributedString alloc] initWithString:(NSString *)message];
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
	[self _setNode:NULL];
	_action = action;
}

- (void) setHighlighted:(BOOL) highlighted {
	[self _setNode:NULL];
	_highlighted = highlighted;
}

- (void) setIgnoreStatus:(JVIgnoreMatchResult) ignoreStatus {
	[self _setNode:NULL];
	_ignoreStatus = ignoreStatus;
}

- (void) setType:(JVChatMessageType) type {
	[self _setNode:NULL];
	_type = type;
}

#pragma mark -

- (void) setSource:(NSURL *) source {
	[self _setNode:NULL];
	_source = [source copy];
}

- (void) setMessageIdentifier:(NSString *) identifier {
	[self _setNode:NULL];
	_messageIdentifier = [identifier copy];
}

- (NSMutableDictionary *) attributes {
	// This depends on the implementation of JVChatMessage using an NSMutableDictionary for its attributes, and actually returning a mutable version of it.
	return (NSMutableDictionary *)[super attributes];
}

- (void) setAttributes:(NSDictionary *) attributes {
	[self _setNode:NULL];
	_attributes = [attributes mutableCopy];
}

- (void) setAttribute:(id) object forKey:(id) key {
	if( ! _attributes )
		_attributes = [[NSMutableDictionary alloc] init];
	_attributes[key] = object;
}

#pragma mark -

- (void) setValue:(nullable id) value forUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The \"%@\" property of message id %@ is read only.", key, [self messageIdentifier]]];
		return;
	}

	[super setValue:value forUndefinedKey:key];
}
@end

NS_ASSUME_NONNULL_END
