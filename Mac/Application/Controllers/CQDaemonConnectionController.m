#import "CQDaemonConnectionController.h"

#import "CQLocalDaemonConnection.h"

@implementation CQDaemonConnectionController
+ (CQDaemonConnectionController *) defaultController {
	MVDefaultController;
}

#pragma mark -

- (id) init {
	if (!(self = [super init]))
		return nil;

	_daemonConnections = [[NSMutableArray alloc] initWithCapacity:5];

	CQLocalDaemonConnection *localConnection = [[CQLocalDaemonConnection alloc] init];
	[_daemonConnections addObject:localConnection];

	[localConnection connect];

	return self;
}
@end
