#import "JVChatSession.h"
#include <libxml/tree.h>

@interface JVChatSession ()
@property (readwrite, setter=_setNode:) xmlNode *node;

@end

@implementation JVChatSession

@synthesize transcript = _transcript;
@synthesize node = _node;

#pragma mark -

- (JVChatTranscript *) transcript {
	return _transcript;
}

- (NSDate *) startDate {
	return _startDate;
}
@end
