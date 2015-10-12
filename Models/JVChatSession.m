#import "JVChatSession.h"
#import "JVChatSession_Private.h"
#include <libxml/tree.h>

@interface JVChatSession ()
@property (readwrite, setter=_setNode:) xmlNode *node;

@end

@implementation JVChatSession {
@protected
	xmlNode *_node;
	NSScriptObjectSpecifier *_objectSpecifier;
	__weak JVChatTranscript *_transcript;
	NSDate *_startDate;
}

@synthesize transcript = _transcript;
@synthesize node = _node;

#pragma mark -

- (JVChatTranscript *) transcript {
	return _transcript;
}

- (NSDate *) startDate {
	return _startDate;
}

- (instancetype) initWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript {
	if( ( self = [self init] ) ) {
		_node = node;
		_transcript = transcript; // weak reference
		
		if( ! _node || node -> type != XML_ELEMENT_NODE ) {
			return nil;
		}
		
		@synchronized( _transcript ) {
			xmlChar *startedStr = xmlGetProp( (xmlNode *) _node, (xmlChar *) "started" );
			_startDate = ( startedStr ? [[NSDate allocWithZone:nil] initWithString:@((char *) startedStr)] : nil );
			xmlFree( startedStr );
		}
	}
	
	return self;
}

@end
