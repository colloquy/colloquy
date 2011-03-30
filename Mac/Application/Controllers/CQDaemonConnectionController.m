#import "CQDaemonConnectionController.h"

#import "CQLocalDaemonConnection.h"

@implementation CQDaemonConnectionController
+ (CQDaemonConnectionController *) defaultController {
	static BOOL creatingSharedInstance = NO;
	static CQDaemonConnectionController *sharedInstance = nil;

	if (!sharedInstance && !creatingSharedInstance) {
		creatingSharedInstance = YES;
		sharedInstance = [[self alloc] init];
	}

	return sharedInstance;
}

- (id) init {
	if (!(self = [super init]))
		return nil;

	_daemonConnections = [[NSMutableArray alloc] initWithCapacity:5];

	CQLocalDaemonConnection *localConnection = [[CQLocalDaemonConnection alloc] init];
	[_daemonConnections addObject:localConnection];

	[localConnection connect];
	[localConnection release];

	return self;
}

- (void) dealloc {
	[_daemonConnections release];

	[super dealloc];
}
@end
