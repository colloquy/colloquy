@class MVChatConnection;

NS_ASSUME_NONNULL_BEGIN

@interface CQConnectionPushEditController : UITableViewController
@property (nonatomic, strong) MVChatConnection *connection;
@property (nonatomic, assign) BOOL newConnection;
@end

NS_ASSUME_NONNULL_END
