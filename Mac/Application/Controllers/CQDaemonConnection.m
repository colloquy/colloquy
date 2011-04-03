#import "CQDaemonConnection.h"
#import "CQDaemonConnectionPrivate.h"

NSString * const CQDaemonConnectionDidConnectNotification = @"CQDaemonConnectionDidConnectNotification";
NSString * const CQDaemonConnectionDidCloseNotification = @"CQDaemonConnectionDidCloseNotification";

@implementation CQDaemonConnection
#pragma mark Properties

- (id <CQColloquyDaemon>) daemon {
	@throw @"Needs implemented by concrete subclass, don't call super.";
}

#pragma mark -
#pragma mark Methods

- (void) connect {
	// Nothing to do.
}

- (void) close {
	[[NSNotificationCenter defaultCenter] postNotificationName:CQDaemonConnectionDidCloseNotification object:self];
}

#pragma mark -
#pragma mark Client Protocol


#pragma mark -
#pragma mark Private

- (void) _didConnect {
	[[NSNotificationCenter defaultCenter] postNotificationName:CQDaemonConnectionDidConnectNotification object:self];
}
@end
