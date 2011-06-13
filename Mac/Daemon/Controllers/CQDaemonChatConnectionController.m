#import "CQDaemonChatConnectionController.h"

@implementation CQDaemonChatConnectionController
+ (CQDaemonChatConnectionController *) defaultController {
	static BOOL creatingSharedInstance = NO;
	static CQDaemonChatConnectionController *sharedInstance = nil;

	if (!sharedInstance && !creatingSharedInstance) {
		creatingSharedInstance = YES;
		sharedInstance = [[self alloc] init];
	}

	return sharedInstance;
}

- (id) init {
	if (!(self = [super init]))
		return nil;

	_connections = [[NSMutableArray alloc] initWithCapacity:5];

	return self;
}

- (void) dealloc {
	[_connections release];

	[super dealloc];
}
@end
