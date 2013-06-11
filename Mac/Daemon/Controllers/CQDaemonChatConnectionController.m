#import "CQDaemonChatConnectionController.h"

@implementation CQDaemonChatConnectionController
+ (CQDaemonChatConnectionController *) defaultController {
	MVDefaultController;
}

- (id) init {
	if (!(self = [super init]))
		return nil;

	_connections = [[NSMutableArray alloc] initWithCapacity:5];

	return self;
}
@end
