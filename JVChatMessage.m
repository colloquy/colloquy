#import <Cocoa/Cocoa.h>
#import <ChatCore/NSAttributedStringAdditions.h>
#import <libxml/xinclude.h>
#import <libxml/debugXML.h>
#import <libxslt/transform.h>
#import <libxslt/xsltutils.h>
#import <AGRegex/AGRegex.h>

#import "JVChatMessage.h"
#import "JVChatTranscript.h"
#import "NSAttributedStringMoreAdditions.h"

@implementation JVChatMessage
+ (id) messageWithNode:(/* xmlNode */ void *) node messageIndex:(unsigned long long) messageNumber andTranscript:(JVChatTranscript *) transcript {
	return [[[self alloc] initWithNode:node messageIndex:messageNumber andTranscript:transcript] autorelease];
}

- (id) init {
	if( ( self = [super init] ) ) {
		_loaded = NO;
		_transcript = nil;
		_messageNumber = 0;
		_envelopeNumber = 0;
		_sender = nil;
		_htmlMessage = nil;
		_attributedMessage = nil;
		_date = nil;
		_action = NO;
		_highlighted = NO;
	}

	return self;
}

- (id) initWithNode:(/* xmlNode */ void *) node messageIndex:(unsigned long long) messageNumber andTranscript:(JVChatTranscript *) transcript {
	if( ( self = [self init] ) ) {
		_node = node;
		_transcript = transcript;
		_messageNumber = messageNumber;

		xmlChar *idStr = xmlGetProp( ((xmlNode *) _node ) -> parent, "id" );
		_envelopeNumber = ( idStr ? strtoul( idStr, NULL, 0 ) : 0 );
		xmlFree( idStr );
	}

	return self;
}

- (void) dealloc {
	[_sender release];
	[_htmlMessage release];
	[_attributedMessage release];
	[_date release];

	_node = NULL;
	_transcript = NULL;
	_sender = nil;
	_htmlMessage = nil;
	_attributedMessage = nil;
	_date = nil;

	[super dealloc];
}

#pragma mark -

- (void) load {
	if( _loaded ) return;

	xmlChar *dateStr = xmlGetProp( _node, "received" );
	_date = ( dateStr ? [NSDate dateWithString:[NSString stringWithUTF8String:dateStr]] : nil );
	xmlFree( dateStr );

	_attributedMessage = [NSTextStorage attributedStringWithXHTMLTree:_node baseURL:nil defaultFont:nil];
	_action = ( xmlHasProp( _node, "action" ) ? YES : NO );
	_highlighted = ( xmlHasProp( _node, "highlight" ) ? YES : NO );

	xmlNode *subNode = ((xmlNode *) _node ) -> parent -> children;

	do {
		if( ! strncmp( "sender", subNode -> name, 6 ) ) {
			xmlChar *senderStr = xmlGetProp( subNode, "nickname" );
			if( ! senderStr ) senderStr = xmlNodeGetContent( subNode );
			if( senderStr ) _sender = [NSString stringWithUTF8String:senderStr];
			xmlFree( senderStr );
		}
	} while( ( subNode = subNode -> next ) ); 

	[_attributedMessage retain];
	[_sender retain];
	[_date retain];

	_loaded = YES;
}

#pragma mark -

- (NSDate *) date {
	[self load];
	return _date;
}

- (NSString *) sender {
	[self load];
	return _sender;
}

#pragma mark -

- (NSTextStorage *) message {
	[self load];
	return _attributedMessage;
}

- (NSString *) messageAsPlainText {
	return [[self message] string];
}

- (NSString *) messageAsHTML {
	if( ! _htmlMessage ) {
		NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"IgnoreFonts", [NSNumber numberWithBool:YES], @"IgnoreFontSizes", nil];
		_htmlMessage = [[[self message] HTMLFormatWithOptions:options] retain];
	}
	return _htmlMessage;
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

- (NSString *) description {
	[self load];
	return [NSString stringWithFormat:@"<%@ 0x%x: (%@) %@>", NSStringFromClass( [self class] ), (unsigned long) self, _sender, _htmlMessage];
}

@end

#pragma mark -

@implementation JVChatMessage (JVChatMessageObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[[self transcript] class]];
	NSScriptObjectSpecifier *container = [[self transcript] objectSpecifier];
	return [[[NSIndexSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"messages" index:[self messageNumber]] autorelease];
}
@end