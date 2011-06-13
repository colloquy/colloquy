@interface CQDaemonChatConnectionController : NSObject {
@private
	NSMutableArray *_connections;
}
+ (CQDaemonChatConnectionController *) defaultController;
@end
