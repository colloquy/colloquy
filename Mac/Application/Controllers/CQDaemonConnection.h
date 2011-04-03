#import "CQColloquyClientProtocol.h"
#import "CQColloquyDaemonProtocol.h"

extern NSString * const CQDaemonConnectionDidConnectNotification;
extern NSString * const CQDaemonConnectionDidCloseNotification;

@interface CQDaemonConnection : NSObject <CQColloquyClient>
#pragma mark Properties

@property (readonly) id <CQColloquyDaemon> daemon;

#pragma mark -
#pragma mark Methods

- (void) connect;
- (void) close;
@end
