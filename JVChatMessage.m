#import <Cocoa/Cocoa.h>
#import <ChatCore/NSAttributedStringAdditions.h>
#import <libxml/xinclude.h>
#import <libxml/debugXML.h>
#import <libxslt/transform.h>
#import <libxslt/xsltutils.h>

#import "JVChatMessage.h"
#import "JVChatTranscript.h"

@implementation JVChatMessage
+ (id) messageWithNode:(/* xmlNode */ void *) node andTranscript:(JVChatTranscript *) transcript {
	return [[[self alloc] initWithNode:node andTranscript:transcript] autorelease];
}

- (id) init {
	if( ( self = [super init] ) ) {
		_loaded = NO;
		_transcript = nil;
		_messageNumber = 0;
		_sender = nil;
		_htmlMessage = nil;
		_attributedMessage = nil;
		_date = nil;
		_action = NO;
		_highlighted = NO;
	}

	return self;
}

- (id) initWithNode:(/* xmlNode */ void *) node andTranscript:(JVChatTranscript *) transcript {
	if( ( self = [self init] ) ) {
		_node = node;
		_transcript = transcript;

		xmlChar *idStr = xmlGetProp( _node, "id" );
		_messageNumber = ( idStr ? strtoul( idStr, NULL, 0 ) : 0 );
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

	xmlNode *subNode = ((xmlNode *) _node ) -> children;;

	do {
		if( ! strncmp( "sender", subNode -> name, 6 ) ) {
			xmlChar *senderStr = xmlGetProp( subNode, "nickname" );
			if( ! senderStr ) senderStr = xmlNodeGetContent( subNode );
			if( senderStr ) _sender = [NSString stringWithUTF8String:senderStr];
			xmlFree( senderStr );
		} else if( ! strncmp( "message", subNode -> name, 7 ) ) {
			xmlBufferPtr buffer = xmlBufferCreate();
			xmlNodeDump( buffer, subNode -> doc, subNode, 0, 0 );
			if( buffer -> content ) _htmlMessage = [NSString stringWithUTF8String:buffer -> content];
			xmlBufferFree( buffer );

			if( [_htmlMessage length] > 19 ) {
				_htmlMessage = [_htmlMessage substringToIndex:( [_htmlMessage length] - 10 )]; // length of </message>
				_htmlMessage = [_htmlMessage substringFromIndex:9]; // length of <message>
			} else _htmlMessage = nil;

			_action = ( xmlHasProp( subNode, "action" ) ? YES : NO );
			_highlighted = ( xmlHasProp( subNode, "highlight" ) ? YES : NO );
		}
	} while( ( subNode = subNode -> next ) ); 

	[_htmlMessage retain];
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
	if( ! _attributedMessage )
		_attributedMessage = [[NSTextStorage attributedStringWithHTMLFragment:[self messageAsHTML] baseURL:nil] retain];
	return _attributedMessage;
}

- (NSString *) messageAsPlainText {
	return [[self message] string];
}

- (NSString *) messageAsHTML {
	[self load];
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

- (unsigned long) messageNumber {
	return _messageNumber;
}

#pragma mark -

- (NSString *) description {
	[self load];
	return [NSString stringWithFormat:@"<%@ 0x%x: (%@) %@>", NSStringFromClass( [self class] ), (unsigned long) self, _sender, _htmlMessage];
}
@end
