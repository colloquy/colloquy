#import <ChatCore/NSAttributedStringAdditions.h>
#import <libxml/xinclude.h>
#import <libxml/debugXML.h>
#import <libxslt/transform.h>
#import <libxslt/xsltutils.h>

#import "JVChatMessage.h"
#import "JVChatTranscript.h"
#import "JVChatRoom.h"
#import "JVChatRoomMember.h"
#import "NSAttributedStringMoreAdditions.h"

@implementation JVChatMessage
+ (id) messageWithNode:(/* xmlNode */ void *) node messageIndex:(unsigned long long) messageNumber andTranscript:(JVChatTranscript *) transcript {
	return [[[self alloc] initWithNode:node messageIndex:messageNumber andTranscript:transcript] autorelease];
}

#pragma mark -

- (void) load {
	if( _loaded ) return;

	xmlChar *dateStr = xmlGetProp( _node, "received" );
	_date = ( dateStr ? [[NSDate dateWithString:[NSString stringWithUTF8String:dateStr]] retain] : nil );
	xmlFree( dateStr );

	_attributedMessage = [[NSTextStorage attributedStringWithXHTMLTree:_node baseURL:nil defaultFont:nil] retain];
	_action = ( xmlHasProp( _node, "action" ) ? YES : NO );
	_highlighted = ( xmlHasProp( _node, "highlight" ) ? YES : NO );
	_ignoreStatus = ( xmlHasProp( _node, "ignored" ) ? JVMessageIgnored : _ignoreStatus );
	_ignoreStatus = ( xmlHasProp( ((xmlNode *) _node ) -> parent, "ignored" ) ? JVUserIgnored : _ignoreStatus );

	xmlNode *subNode = ((xmlNode *) _node ) -> parent -> children;

	do {
		if( ! strncmp( "sender", subNode -> name, 6 ) ) {
			xmlChar *senderStr = xmlGetProp( subNode, "nickname" );
			if( ! senderStr ) senderStr = xmlNodeGetContent( subNode );
			if( senderStr ) _sender = [NSString stringWithUTF8String:senderStr];
			xmlFree( senderStr );

			if( _sender && [[self transcript] isKindOfClass:[JVChatRoom class]] ) {
				JVChatRoomMember *member = [(JVChatRoom *)[self transcript] chatRoomMemberWithName:_sender];
				if( member ) _sender = member;
			}

			[_sender retain];
		}
	} while( ( subNode = subNode -> next ) ); 

	_loaded = YES;
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_loaded = NO;
		_objectSpecifier = nil;
		_transcript = nil;
		_messageNumber = 0;
		_envelopeNumber = 0;
		_sender = nil;
		_htmlMessage = nil;
		_attributedMessage = nil;
		_date = nil;
		_action = NO;
		_highlighted = NO;
		_ignoreStatus = JVNotIgnored;
	}

	return self;
}

- (id) initWithNode:(/* xmlNode */ void *) node messageIndex:(unsigned long long) messageNumber andTranscript:(JVChatTranscript *) transcript {
	if( ( self = [self init] ) ) {
		_node = node;
		_transcript = transcript;
		_messageNumber = messageNumber;

		id classDesc = [NSClassDescription classDescriptionForClass:[transcript class]];
		[self setObjectSpecifier:[[[NSIndexSpecifier alloc] initWithContainerClassDescription:classDesc containerSpecifier:[transcript objectSpecifier] key:@"messages" index:messageNumber] autorelease]];

		xmlChar *idStr = xmlGetProp( ((xmlNode *) _node ) -> parent, "id" );
		_envelopeNumber = ( idStr ? strtoul( idStr, NULL, 0 ) : 0 );
		xmlFree( idStr );
	}

	return self;
}

- (id) mutableCopyWithZone:(NSZone *) zone {
	[self load];

	JVMutableChatMessage *ret = [[JVMutableChatMessage allocWithZone:zone] initWithText:_attributedMessage sender:_sender andTranscript:_transcript];
	[ret setDate:_date];
	[ret setAction:_action];
	[ret setHighlighted:_highlighted];
	[ret setMessageNumber:_messageNumber];
	[ret setEnvelopeNumber:_envelopeNumber];

	return ret;
}

- (void) dealloc {
	[_sender release];
	[_htmlMessage release];
	[_attributedMessage release];
	[_date release];
	[_objectSpecifier release];

	_node = NULL;
	_transcript = NULL;
	_sender = nil;
	_htmlMessage = nil;
	_attributedMessage = nil;
	_date = nil;
	_objectSpecifier = nil;

	[super dealloc];
}

#pragma mark -

- (void *) node {
	return _node;
}

#pragma mark -

- (NSDate *) date {
	[self load];
	return _date;
}

- (id) sender {
	[self load];
	return _sender;
}

#pragma mark -

- (NSTextStorage *) body {
	[self load];
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

#pragma mark -

- (JVChatTranscript *) transcript {
	return _transcript;
}

- (unsigned long long) messageNumber {
	return _messageNumber;
}

- (unsigned long long) envelopeNumber {
	return _envelopeNumber;
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
	[self load];
	return [self bodyAsPlainText];
}

- (NSString *) debugDescription {
	[self load];
	return [NSString stringWithFormat:@"<%@ 0x%x: (%@) %@>", NSStringFromClass( [self class] ), (unsigned long) self, [self sender], [self body]];
}
@end

#pragma mark -

@implementation JVMutableChatMessage
+ (id) messageWithText:(NSAttributedString *) body sender:(NSString *) sender andTranscript:(JVChatTranscript *) transcript {
	return [[[self alloc] initWithText:body sender:sender andTranscript:transcript] autorelease];
}

- (id) initWithText:(NSAttributedString *) body sender:(NSString *) sender andTranscript:(JVChatTranscript *) transcript {
	if( ( self = [self init] ) ) {
		_loaded = YES;
		[self setTranscript:transcript];
		[self setDate:[NSDate date]];
		[self setBody:body];
		[self setSender:sender];
	}

	return self;
}

#pragma mark -

- (void) setNode:(/* xmlNode */ void *) node {
	_node = node;
}

#pragma mark -

- (void) setDate:(NSDate *) date {
	[_date autorelease];
	_date = [date copy];
}

- (void) setSender:(id) sender {
	if( [sender isKindOfClass:[NSString class]] && [[self transcript] isKindOfClass:[JVChatRoom class]] ) {
		JVChatRoomMember *member = [(JVChatRoom *)[self transcript] chatRoomMemberWithName:sender];
		if( member ) sender = member;
	}

	[_sender autorelease];
	_sender = ( [sender conformsToProtocol:@protocol( NSCopying)] ? [sender copy] : [sender retain] );
}

#pragma mark -

- (void) setBody:(NSAttributedString *) message {
	if( ! _attributedMessage ) {
		if( [message isKindOfClass:[NSTextStorage class]] ) _attributedMessage = [message retain];
		else if( [message isKindOfClass:[NSAttributedString class]] ) _attributedMessage = [[NSTextStorage alloc] initWithAttributedString:message];
		else if( [message isKindOfClass:[NSString class]] ) _attributedMessage = [[NSAttributedString alloc] initWithString:(NSString *)message];
	} else if( _attributedMessage && [message isKindOfClass:[NSAttributedString class]] ) {
		[_attributedMessage setAttributedString:message];
	} else if( _attributedMessage && [message isKindOfClass:[NSString class]] ) {
		id string = [[[NSAttributedString alloc] initWithString:(NSString *)message] autorelease];
		[_attributedMessage setAttributedString:string];
	}
}

- (void) setBodyAsPlainText:(NSString *) message {
	[self setBody:[[[NSAttributedString alloc] initWithString:message] autorelease]];
}

- (void) setBodyAsHTML:(NSString *) message {
	[self setBody:[NSAttributedString attributedStringWithHTMLFragment:message baseURL:nil]];
}

#pragma mark -

- (void) setAction:(BOOL) action {
	_action = action;
}

- (void) setHighlighted:(BOOL) highlighted {
	_highlighted = highlighted;
}

- (void) setIgnoreStatus:(JVIgnoreMatchResult) ignoreStatus {
	_ignoreStatus = ignoreStatus;
}

#pragma mark -

- (void) setTranscript:(JVChatTranscript *) transcript {
	[_transcript autorelease];
	_transcript = [transcript retain];
}

- (void) setMessageNumber:(unsigned long long) number {
	_messageNumber = number;
}

- (void) setEnvelopeNumber:(unsigned long long) number {
	_envelopeNumber = number;
}
@end