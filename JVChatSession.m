#import "JVChatSession.h"
#import <libxml/xinclude.h>

@implementation JVChatSession
- (id) initWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript {
	if( ( self = [self init] ) ) {
		_node = node;
		_transcript = transcript; // weak reference

		if( ! _node || node -> type != XML_ELEMENT_NODE ) {
			[self release];
			return nil;
		}

		@synchronized( [self transcript] ) {
			xmlChar *startedStr = xmlGetProp( (xmlNode *) _node, "started" );
			_startDate = ( startedStr ? [[NSDate allocWithZone:[self zone]] initWithString:[NSString stringWithUTF8String:startedStr]] : nil );
			xmlFree( startedStr );
		}
	}

	return self;
}

+ (id) sessionWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript {
	return [[[self alloc] initWithNode:node andTranscript:transcript] autorelease];
}

- (void) dealloc {
	[_startDate release];
	_startDate = nil;
	_transcript = nil;
	_node = NULL;
	[super dealloc];
}

#pragma mark -

- (void *) node {
	return _node;
}

- (void) setNode:(xmlNode *) node {
	_node = node;
}

#pragma mark -

- (JVChatTranscript *) transcript {
	return _transcript;
}

- (NSDate *) startDate {
	return _startDate;
}
@end
