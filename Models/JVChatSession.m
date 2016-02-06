#include <libxml/tree.h>
#import "JVChatSession.h"

@interface JVChatSession ()
@property (readwrite, setter=_setNode:) xmlNode *node;

@end

@implementation JVChatSession

@synthesize transcript = _transcript;
@synthesize node = _node;
@synthesize startDate = _startDate;

@end
