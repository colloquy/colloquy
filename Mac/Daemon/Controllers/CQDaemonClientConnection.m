#import "CQDaemonClientConnection.h"
#import "CQDaemonClientConnectionPrivate.h"

NSString * const CQDaemonClientConnectionDidConnectNotification = @"CQDaemonClientConnectionDidConnectNotification";
NSString * const CQDaemonClientConnectionDidCloseNotification = @"CQDaemonClientConnectionDidCloseNotification";

@implementation CQDaemonClientConnection
#pragma mark Properties

- (id <CQColloquyClient>) client {
	@throw @"Needs implemented by concrete subclass, don't call super.";
}

#pragma mark -
#pragma mark Methods

- (void) close {
	[[NSNotificationCenter defaultCenter] postNotificationName:CQDaemonClientConnectionDidCloseNotification object:self];
}

#pragma mark -
#pragma mark Daemon Protocol


#pragma mark -
#pragma mark Private

- (void) _didConnect {
	[[NSNotificationCenter defaultCenter] postNotificationName:CQDaemonClientConnectionDidConnectNotification object:self];
}
@end
