@interface CQDaemonConnectionController : NSObject {
@private
    NSMutableArray *_daemonConnections;
}
+ (CQDaemonConnectionController *) defaultController;
@end
