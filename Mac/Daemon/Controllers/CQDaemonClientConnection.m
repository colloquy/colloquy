#import "CQDaemonClientConnection.h"

NSString *CQDaemonClientConnectionDidCloseNotification = @"CQDaemonClientConnectionDidCloseNotification";

@implementation CQDaemonClientConnection
- (void) close {
	[[NSNotificationCenter defaultCenter] postNotificationName:CQDaemonClientConnectionDidCloseNotification object:self];
}
@end
