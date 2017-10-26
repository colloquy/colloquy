#import "JVChatSession.h"
#include <libxml/tree.h>

@implementation JVChatSession
- (void) dealloc {
	_startDate = nil;
	_transcript = nil;
	_node = NULL;
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
