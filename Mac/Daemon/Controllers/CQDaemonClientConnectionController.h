@interface CQDaemonClientConnectionController : NSObject <NSConnectionDelegate> {
@private
	NSConnection *_localServerConnection;
	NSMutableSet *_clientConnections;
}
+ (CQDaemonClientConnectionController *) defaultController;

- (void) close;
@end
