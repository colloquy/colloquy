#import "CQColloquyDaemonProtocol.h"
#import "CQColloquyClientProtocol.h"

extern NSString * const CQDaemonClientConnectionDidConnectNotification;
extern NSString * const CQDaemonClientConnectionDidCloseNotification;

@interface CQDaemonClientConnection : NSObject <CQColloquyDaemon>
#pragma mark Properties

@property (readonly) id <CQColloquyClient> client;

#pragma mark -
#pragma mark Methods

- (void) close;
@end
