#import "CQTableViewController.h"

@class MVChatConnection;

@interface CQConnectionPushEditController : CQTableViewController {
	@protected
	MVChatConnection *_connection;
}
@property (nonatomic, strong) MVChatConnection *connection;
@property (nonatomic, assign) BOOL newConnection;
@end
